function results = runCompiledKernelValidation(options)
% Validate compiled nonlinear flux correctness, storage, lifecycle, and RSS.
arguments
    options.sizes (:,3) double = [256 256 65;512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.antialias (1,:) logical = true
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
buildDirectory = fullfile(benchmarkFolder,"build");
buildCompiledKernelTransformMex(outputDirectory=buildDirectory);
addpath(buildDirectory);
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue52",options.runId+"-"+computer("arch")+"-"+version("-release"));
end

definitions = caseDefinitions(options);
cases = repmat(emptyCase(),0,1);
for iCase = 1:numel(definitions)
    numerical = validateNumerics(definitions(iCase),options.threadCount);
    runs = repmat(emptyRun(),0,1);
    for iRun = 1:options.processRunCount
        runs(end+1,1) = runWorker(definitions(iCase),iRun,options,benchmarkFolder,repositoryRoot,buildDirectory); %#ok<AGROW>
    end
    cases(end+1,1) = aggregateCase(definitions(iCase),numerical,runs); %#ok<AGROW>
end
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
status = conditional(all(string({cases.status})=="complete"),"complete","partial");
results = struct("schemaVersion","1.0.0","status",status,"runId",options.runId, ...
    "environment",environmentRecord(options.threadCount), ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty), ...
    "configuration",struct("sizes",options.sizes,"hydrostatic",options.hydrostatic,"antialias",options.antialias,"processRunCount",options.processRunCount,"warmupCount",options.warmupCount,"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"correctnessTolerance",1e-12), ...
    "cases",cases,"staticChecks",staticChecks(repositoryRoot));
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"compiled-kernel-validation.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function definitions = caseDefinitions(options)
definitions = repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",0),0,1);
for iSize = 1:size(options.sizes,1)
    for isHydrostatic = options.hydrostatic
        for shouldAntialias = options.antialias
            Nxyz = options.sizes(iSize,:);
            id = join(string(Nxyz),"x")+"-"+conditional(isHydrostatic,"hydrostatic","nonhydrostatic")+"-"+conditional(shouldAntialias,"antialias","unfiltered");
            definitions(end+1,1) = struct("id",id,"Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"shouldAntialias",shouldAntialias,"seed",5200+iSize+10*double(isHydrostatic)+100*double(shouldAntialias)); %#ok<AGROW>
        end
    end
end
end

function numerical = validateNumerics(definition,threadCount)
rng(definition.seed,"twister");
wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
wvt.initWithRandomFlow(uvMax=0.01);
wvt.t = 90;
handle = wv_compiled_transform_mex('create',kernelConfiguration(wvt),threadCount);
cleanup = onCleanup(@()deleteKernel(handle));
[expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
[actualFp,actualFm,actualF0] = wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
[U,V,W,N] = wvt.transformWaveVortexToUVWEta(wvt.Ap,wvt.Am,wvt.A0,wvt.t);
actualFields = wv_compiled_transform_mex('inverse',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
inverseError = relativeError(actualFields,cat(4,U,V,W,N));
if definition.isHydrostatic
    fields = cat(4,U,V,N);
    [expectedAp,expectedAm,expectedA0] = wvt.transformUVEtaToWaveVortex(U,V,N);
else
    fields = cat(4,U,V,W,N);
    [expectedAp,expectedAm,expectedA0] = wvt.transformUVWEtaToWaveVortex(U,V,W,N);
end
[actualAp,actualAm,actualA0] = wv_compiled_transform_mex('forward',handle,fields,wvt.t,wvt.t0);
forwardError = max([relativeError(actualAp,expectedAp),relativeError(actualAm,expectedAm),relativeError(actualA0,expectedA0)]);
Apm = wvt.Ap+wvt.Am;
[value,x,y,z] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=Apm,A0=wvt.A0);
fAllError = relativeError(wv_compiled_transform_mex('fAll',handle,Apm,wvt.A0),cat(4,value,x,y,z));
[value,x,y,z] = wvt.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=wvt.A0);
gAllError = relativeError(wv_compiled_transform_mex('gAll',handle,Apm,wvt.A0),cat(4,value,x,y,z));
fluxError = max([relativeError(actualFp,expectedFp),relativeError(actualFm,expectedFm),relativeError(actualF0,expectedF0)]);
errors = struct("forward",forwardError,"inverse",inverseError,"fAll",fAllError,"gAll",gAllError,"nonlinearFlux",fluxError);
metrics = wv_compiled_transform_mex('metrics',handle);
maximumRelativeError = max([errors.forward errors.inverse errors.fAll errors.gAll errors.nonlinearFlux]);
numerical = struct("errors",errors,"maximumRelativeError",maximumRelativeError,"metrics",metrics,"passed",maximumRelativeError<=1e-12);
clear cleanup
end

function run = runWorker(definition,repeatIndex,options,benchmarkFolder,repositoryRoot,buildDirectory)
configPath = string(tempname)+".json";
outputPath = string(tempname)+".json";
cleanup = onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
config = struct("definition",definition,"repeatIndex",repeatIndex,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"buildDirectory",buildDirectory,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"warmupCount",options.warmupCount,"threadCount",options.threadCount);
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelValidationWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[exitCode,commandOutput] = system(command);
if exitCode~=0 || ~isfile(outputPath)
    run = emptyRun(); run.repeatIndex=repeatIndex; run.failure=struct("identifier","WaveVortexModel:CompiledKernelValidationWorkerFailed","message",string(commandOutput));
else
    decoded = jsondecode(fileread(outputPath));
    run = struct("repeatIndex",repeatIndex,"status",string(decoded.status),"ledger",decoded.ledger,"rss",decoded.rss,"moduleBefore",decoded.moduleBefore,"moduleAfter",decoded.moduleAfter,"lifecyclePassed",decoded.lifecyclePassed,"failure",decoded.failure);
end
clear cleanup
end

function result = aggregateCase(definition,numerical,runs)
complete = string({runs.status})=="complete";
persistentValues = NaN(1,numel(runs));
peak = NaN(1,numel(runs));
for iRun=1:numel(runs)
    persistentValues(iRun)=runs(iRun).rss.persistentIncrementBytes;
    peak(iRun)=runs(iRun).rss.peakIncrementBytes;
end
ledger = struct();
if any(complete), ledger=runs(find(complete,1)).ledger; end
lifecyclePassed = all(arrayfun(@(item)item.lifecyclePassed,runs(complete)));
rss = struct("persistentIncrementBytes",persistentValues,"peakIncrementBytes",peak,"medianPersistentIncrementBytes",median(persistentValues,"omitnan"),"minimumPersistentIncrementBytes",min(persistentValues,[],"omitnan"),"maximumPersistentIncrementBytes",max(persistentValues,[],"omitnan"),"medianPeakIncrementBytes",median(peak,"omitnan"),"minimumPeakIncrementBytes",min(peak,[],"omitnan"),"maximumPeakIncrementBytes",max(peak,[],"omitnan"));
status = conditional(all(complete)&&numerical.passed&&lifecyclePassed,"complete","partial");
result = struct("id",definition.id,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"status",status,"numerical",numerical,"runs",runs,"ledger",ledger,"rss",rss,"lifecyclePassed",lifecyclePassed);
end

function checks = staticChecks(repositoryRoot)
files = [fullfile(repositoryRoot,"CompiledKernel","include","WaveVortexKernel","WVKernelTypes.hpp"),fullfile(repositoryRoot,"CompiledKernel","src","WVKernelTypes.cpp"),fullfile(repositoryRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp"),fullfile(repositoryRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp")];
text = "";
for file = files, text=text+newline+string(fileread(file)); end
forbidden = ["WVGradientMasks" "nonlinearFluxWithGradientMasks" "velocity masks" "gradient masks"];
matches = forbidden(contains(lower(text),lower(forbidden)));
checks = struct("forbiddenTerms",forbidden,"matches",matches,"passed",isempty(matches));
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)))/max(max(abs(expected(:))),realmin);
end

function deleteKernel(handle)
try
    wv_compiled_transform_mex('delete',handle);
catch
end
end

function [commit,tree,isDirty] = gitIdentity(root)
[~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree]=system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); [~,status]=system(sprintf('git -C "%s" status --porcelain',root));
commit=string(strtrim(commit)); tree=string(strtrim(tree)); isDirty=strlength(strtrim(string(status)))>0;
end

function record = environmentRecord(threads)
record=struct("os",string(system_dependent("getos")),"processor",string(system_dependent("getcpu")),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"threads",threads,"fftwLibrary",matlabBundledFFTWLibrary);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function writeText(pathname,contents)
fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end
cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile=1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end

function value = emptyRun()
value=struct("repeatIndex",0,"status","failed","ledger",struct(),"rss",struct("persistentIncrementBytes",NaN,"peakIncrementBytes",NaN),"moduleBefore",struct(),"moduleAfter",struct(),"lifecyclePassed",false,"failure",struct("identifier","","message",""));
end

function value = emptyCase()
value=struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",0,"status","failed","numerical",struct(),"runs",repmat(emptyRun(),0,1),"ledger",struct(),"rss",struct(),"lifecyclePassed",false);
end

function markdown = summaryMarkdown(results)
lines=["# Compiled-kernel validation";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- Gradient-mask path absent: `"+string(results.staticChecks.passed)+"`";"";"| Case | Max error | Persistent core (MiB) | Known max live (MiB) | Persistent RSS (MiB) | Peak RSS (MiB) | Lifecycle |";"|---|---:|---:|---:|---:|---:|---:|"];
for item=results.cases'
    lines(end+1)=sprintf("| %s | %.3g | %.3f | %.3f | %.3f | %.3f | %s |",item.id,item.numerical.maximumRelativeError,item.ledger.knownPersistentBytes/2^20,item.ledger.knownMaximumLiveBytes/2^20,item.rss.medianPersistentIncrementBytes/2^20,item.rss.medianPeakIncrementBytes/2^20,string(item.lifecyclePassed)); %#ok<AGROW>
end
markdown=join(lines,newline)+newline;
end
