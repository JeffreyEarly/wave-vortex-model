function results = runPortableRuntimeReadinessBenchmark(options)
% Compare standalone C++ and compiled-MATLAB fixed-step integration.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65;512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.stepCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.deltaT (1,1) double {mustBePositive} = 1
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBePositive} = 0.10
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.injectWorkerFailure (1,1) logical = false
end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexBenchmark:PortableRuntimeUnsupportedPlatform","The canonical portable-runtime benchmark targets MATLAB R2026a on macOS maca64.")
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId+"-portable-runtime-"+computer("arch")+"-"+version("-release"));
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:PortableRuntimeOutputExists","Output already exists: %s",options.outputDirectory)
end
if options.shouldWriteArtifacts, mkdir(options.outputDirectory), end
results = initializeResult(options,repositoryRoot);
temporaryRoot = string(tempname);
mkdir(temporaryRoot)
temporaryCleanup = onCleanup(@()rmdir(temporaryRoot,"s"));
activeStage = "provider";
try
    capabilities = WVCompiledBackend.capabilities();
    if ~capabilities.isAvailable, capabilities = WVCompiledBackend.build(); end
    validateCapabilities(capabilities);
    results.matlabProvider = capabilities;
    [status,output] = system(sprintf('"%s" "%s"',fullfile(repositoryRoot,"tools","portable-runtime","buildWaveVortexRun.sh"),fullfile(temporaryRoot,"native-build")));
    if status ~= 0, error("WaveVortexBenchmark:PortableRuntimeBuild","Unable to build wave-vortex-run.%s%s",newline,output), end
    lines = splitlines(strtrim(string(output)));
    runner = lines(end);
    if ~isfile(runner), error("WaveVortexBenchmark:PortableRuntimeBuild","The build did not produce wave-vortex-run at %s.",runner), end
    results.runner = struct("path",runner,"sourceCommit",gitValue(repositoryRoot,"rev-parse HEAD"));

    activeStage = "inputs";
    cases = caseDefinitions(options);
    results.cases = cases;
    inputs = strings(numel(cases),1);
    for iCase = 1:numel(cases)
        inputs(iCase) = fullfile(temporaryRoot,"input-"+cases(iCase).id+".nc");
        writeInputCheckpoint(inputs(iCase),cases(iCase));
    end

    activeStage = "workers";
    implementations = ["standalone-cpp" "compiled-matlab-preview"];
    for iRun = 1:options.processRunCount
        for iCase = mod((0:numel(cases)-1)+(iRun-1),numel(cases))+1
            order = mod((0:1)+(iRun+iCase-2),2)+1;
            runOutputs = struct();
            for iImplementation = order
                implementation = implementations(iImplementation);
                fprintf("Portable runtime: %s, %s, process %d/%d.\n",implementation,cases(iCase).id,iRun,options.processRunCount);
                if options.injectWorkerFailure, workerInput = inputs(iCase)+".missing"; else, workerInput = inputs(iCase); end
                if implementation == "standalone-cpp"
                    run = runStandalone(runner,workerInput,cases(iCase),iRun,options,repositoryRoot,temporaryRoot);
                else
                    run = runMatlab(workerInput,cases(iCase),iRun,capabilities,options,repositoryRoot,benchmarkFolder,temporaryRoot);
                end
                results.runs(end+1,1) = run;
                runOutputs.(matlab.lang.makeValidName(implementation)) = string(run.outputCheckpoint);
                checkpoint(results,options)
            end
            repeatIndices = reshape([results.runs.repeatIndex],[],1);
            caseIds = reshape(string(arrayfun(@(item)item.case.id,results.runs,"UniformOutput",false)),[],1);
            selected = results.runs(repeatIndices == iRun & caseIds == cases(iCase).id);
            if numel(selected) == 2 && all(string({selected.status}) == "complete")
                results.correctness(end+1,1) = compareCheckpoints(selected(1).outputCheckpoint,selected(2).outputCheckpoint,cases(iCase),iRun);
            end
            for name = fieldnames(runOutputs)'
                if isfile(runOutputs.(name{1})), delete(runOutputs.(name{1})), end
            end
        end
    end
    failed = results.runs(string({results.runs.status}) ~= "complete");
    if ~isempty(failed)
        error("WaveVortexBenchmark:PortableRuntimeWorkers","One or more portable-runtime workers failed.")
    end
    activeStage = "aggregation";
    results.comparison = comparisonRecords(results.runs,results.correctness,cases);
    results.decision = portableRuntimeReadinessDecision(results.comparison);
    results.status = "complete";
    results.completedAtUTC = utcTimestamp;
    results.failure = emptyFailure;
    writeArtifacts(results,options)
catch exception
    results.status = "failed";
    results.completedAtUTC = utcTimestamp;
    results.failure = struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
    writeArtifacts(results,options)
    rethrow(exception)
end
clear temporaryCleanup stateCleanup
end

function results = initializeResult(options,repositoryRoot)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct("schemaVersion","portable-runtime-readiness-v1","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","environment",environmentRecord,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty),"configuration",struct("suiteId","core-v1","operation","eight fixed RK4 integration steps","processRunCount",options.processRunCount,"stepCount",options.stepCount,"deltaT",options.deltaT,"samplingIntervalSeconds",options.samplingIntervalSeconds,"speedThreshold",1.25,"memoryRatioThreshold",0.80,"correctnessTolerance",1e-12,"timingScope","integration only; startup, checkpoint I/O, construction, preparation, and output writing excluded"),"matlabProvider",struct(),"runner",struct(),"cases",[],"runs",repmat(emptyRun,0,1),"correctness",repmat(struct("id","","repeatIndex",0,"maximumRelativeError",NaN,"timeError",NaN),0,1),"comparison",[],"decision",struct(),"failure",emptyFailure);
end

function cases = caseDefinitions(options)
suite = waveVortexBenchmarkSuites("core-v1");
cases = repmat(struct("id","","Nxyz",[],"Lxyz",[15000 15000 1300],"isHydrostatic",false,"shouldAntialias",true,"seed",0),0,1);
for iSize = 1:size(options.sizes,1)
    for isHydrostatic = options.hydrostatic
        Nxyz = options.sizes(iSize,:);
        match = find(arrayfun(@(item)isequal(item.Nxyz,Nxyz)&&item.isHydrostatic==isHydrostatic,suite.cases),1);
        seed = 175000+sum(Nxyz)+100*isHydrostatic;
        if ~isempty(match), seed = suite.cases(match).seed; end
        id = sprintf("constant-%s-%dx%dx%d",conditional(isHydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        cases(end+1,1) = struct("id",id,"Nxyz",Nxyz,"Lxyz",[15000 15000 1300],"isHydrostatic",isHydrostatic,"shouldAntialias",true,"seed",seed); %#ok<AGROW>
    end
end
end

function writeInputCheckpoint(pathname,definition)
wvt = WVTransformConstantStratification(definition.Lxyz,definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
cleanup = onCleanup(@()delete(wvt));
initializeWaveVortexBenchmarkState(wvt,definition.seed);
wvt.t = 0;
wvt.t0 = 0;
wvt.setForcing(WVNonlinearAdvection(wvt));
file = wvt.writeToFile(char(pathname),shouldOverwriteExisting=true);
file.close();
clear cleanup
end

function run = runStandalone(runner,inputPath,definition,repeatIndex,options,repositoryRoot,temporaryRoot)
outputPath = fullfile(temporaryRoot,sprintf("cpp-%s-%d.nc",definition.id,repeatIndex));
reportPath = outputPath+".json";
phasePath = outputPath+".phase";
rssPath = outputPath+".rss";
stopPath = outputPath+".stop";
wrapper = fullfile(repositoryRoot,"Benchmarks","runPortableRuntimeProcess.sh");
sampler = fullfile(repositoryRoot,"Benchmarks","sampleProcessRSS.sh");
command = sprintf('"%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" %.17g %d %d %.6f',wrapper,runner,inputPath,outputPath,reportPath,phasePath,rssPath,stopPath,sampler,options.deltaT,options.stepCount,min(18,maxNumCompThreads),options.samplingIntervalSeconds);
[status,output] = system(command);
if status ~= 0 || ~isfile(reportPath)
    run = emptyRun;
    run.implementation = "standalone-cpp"; run.repeatIndex = repeatIndex; run.case = definition; run.outputCheckpoint = outputPath;
    run.failure = struct("identifier","WaveVortexBenchmark:StandaloneWorkerFailed","message",string(output),"report",string(output));
    return
end
report = jsondecode(fileread(reportPath));
rssSamples = readRSS(rssPath,options.samplingIntervalSeconds);
rss = phaseRSS(rssSamples,options.samplingIntervalSeconds);
identity = string(report.provider.id) == "native-fftw" && contains(string(report.provider.version),"3.3.11") && report.execution.planCount == 17 && report.execution.noFallback && report.storageBytes.persistentFullHermitian == 0;
run = struct("schemaVersion","portable-runtime-worker-v1","status",conditional(identity && rss.status == "complete","complete","failed"),"implementation","standalone-cpp","repeatIndex",repeatIndex,"case",definition,"integrationSeconds",report.timingSeconds.integrate,"constructionSeconds",report.timingSeconds.construct+report.timingSeconds.prepare,"readSeconds",report.timingSeconds.read+report.timingSeconds.inspect,"writeSeconds",report.timingSeconds.write,"totalSeconds",report.timingSeconds.total,"metadata",report,"rss",rss,"rssSamples",rssSamples,"outputCheckpoint",outputPath,"failure",emptyFailure);
end

function run = runMatlab(inputPath,definition,repeatIndex,capabilities,options,repositoryRoot,benchmarkFolder,temporaryRoot)
outputPath = fullfile(temporaryRoot,sprintf("matlab-%s-%d.nc",definition.id,repeatIndex));
config = struct("inputPath",inputPath,"outputCheckpoint",outputPath,"repeatIndex",repeatIndex,"caseDefinition",definition,"stepCount",options.stepCount,"deltaT",options.deltaT,"initialTime",0,"expectedModuleHash",string(capabilities.module.sha256),"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds);
configPath = string(tempname)+".json";
resultPath = string(tempname)+".json";
cleanup = onCleanup(@()deleteTemporaryFiles(configPath,resultPath));
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); portableRuntimeMatlabWorker('"+replace(configPath,"'","''")+"','"+replace(resultPath,"'","''")+"')";
command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[status,output] = system(command);
if status ~= 0 || ~isfile(resultPath)
    run = emptyRun;
    run.implementation = "compiled-matlab-preview"; run.repeatIndex = repeatIndex; run.case = definition; run.outputCheckpoint = outputPath;
    run.failure = struct("identifier","WaveVortexBenchmark:MatlabWorkerFailed","message",string(output),"report",string(output));
else
    value = jsondecode(fileread(resultPath));
    run = struct("schemaVersion",string(value.schemaVersion),"status",string(value.status),"implementation",string(value.implementation),"repeatIndex",value.repeatIndex,"case",value.case,"integrationSeconds",value.integrationSeconds,"constructionSeconds",value.constructionSeconds,"readSeconds",NaN,"writeSeconds",value.writeSeconds,"totalSeconds",value.totalSeconds,"metadata",value.metadata,"rss",value.rss,"rssSamples",value.rssSamples,"outputCheckpoint",outputPath,"failure",value.failure);
end
clear cleanup
end

function value = compareCheckpoints(firstPath,secondPath,definition,repeatIndex)
[first,firstFile] = WVTransform.waveVortexTransformFromFile(char(firstPath),iTime=Inf,shouldReadOnly=true);
firstCleanup = onCleanup(@()firstFile.close());
[second,secondFile] = WVTransform.waveVortexTransformFromFile(char(secondPath),iTime=Inf,shouldReadOnly=true);
secondCleanup = onCleanup(@()secondFile.close());
if ~isequal(size(first.Ap),size(second.Ap))
    error("WaveVortexBenchmark:PortableRuntimeOutputShape","Output coefficient shapes differ: [%s] and [%s].",num2str(size(first.Ap)),num2str(size(second.Ap)))
end
errors = [relativeError(first.Ap,second.Ap) relativeError(first.Am,second.Am) relativeError(first.A0,second.A0)];
value = struct("id",definition.id,"repeatIndex",repeatIndex,"maximumRelativeError",max(errors),"timeError",abs(first.t-second.t));
clear firstCleanup secondCleanup
end

function comparison = comparisonRecords(runs,correctness,cases)
comparison = repmat(struct("id","","status","failed","matlabIntegrationSeconds",NaN,"standaloneIntegrationSeconds",NaN,"integrationSpeedup",NaN,"maximumRelativeError",NaN,"matlabPeakIncrementRSSBytes",NaN,"standalonePeakIncrementRSSBytes",NaN,"peakIncrementRSSRatio",NaN,"nativeIdentityPassed",false,"noFallback",false,"planCount",NaN,"persistentFullHermitianBytes",NaN),numel(cases),1);
for iCase = 1:numel(cases)
    caseIds = reshape(string(arrayfun(@(item)item.case.id,runs,"UniformOutput",false)),[],1);
    selected = runs(caseIds == cases(iCase).id);
    cpp = selected(string({selected.implementation}) == "standalone-cpp");
    matlab = selected(string({selected.implementation}) == "compiled-matlab-preview");
    errors = correctness(string({correctness.id}) == cases(iCase).id);
    report = cpp(1).metadata;
    cppRSS = arrayfun(@(item)item.rss.operationPeakIncrementBytes,cpp);
    matlabRSS = arrayfun(@(item)item.rss.operationPeakIncrementBytes,matlab);
    comparison(iCase) = struct("id",cases(iCase).id,"status",conditional(all(string({selected.status}) == "complete"),"complete","failed"),"matlabIntegrationSeconds",median([matlab.integrationSeconds]),"standaloneIntegrationSeconds",median([cpp.integrationSeconds]),"integrationSpeedup",median([matlab.integrationSeconds])/median([cpp.integrationSeconds]),"maximumRelativeError",max([errors.maximumRelativeError]),"matlabPeakIncrementRSSBytes",median(matlabRSS),"standalonePeakIncrementRSSBytes",median(cppRSS),"peakIncrementRSSRatio",median(cppRSS./matlabRSS),"nativeIdentityPassed",contains(string(report.provider.version),"3.3.11"),"noFallback",report.execution.noFallback,"planCount",report.execution.planCount,"persistentFullHermitianBytes",report.storageBytes.persistentFullHermitian);
end
end

function rss = readRSS(pathname,interval)
rss = struct("status","unsupported","provider","macos-ps-rss-external","samplingIntervalSeconds",interval,"samples",[]);
if ~isfile(pathname), return, end
lines = splitlines(strtrim(string(fileread(pathname))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    index = str2double(fields(1));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3)));
end
rss.status = "complete";
rss.samples = samples;
end

function value = phaseRSS(rss,interval)
value = struct("status",rss.status,"provider",rss.provider,"samplingIntervalSeconds",interval,"steadyRetainedBytes",NaN,"operationPeakBytes",NaN,"operationPeakIncrementBytes",NaN);
if rss.status ~= "complete" || isempty(rss.samples), return, end
phases = string({rss.samples.phase}); bytes = [rss.samples.rssBytes];
retained = bytes(phases == "steady-retained"); operation = bytes(phases == "integrate" | phases == "outputs-held");
if isempty(retained) || isempty(operation), value.status = "unsupported"; return, end
value.steadyRetainedBytes = median(retained); value.operationPeakBytes = max(operation); value.operationPeakIncrementBytes = max(0,value.operationPeakBytes-value.steadyRetainedBytes);
end

function writeArtifacts(results,options)
if ~options.shouldWriteArtifacts, return, end
writeText(fullfile(options.outputDirectory,"portable-runtime-readiness.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(results));
end

function checkpoint(results,options)
if options.shouldWriteArtifacts, writeArtifacts(results,options), end
end

function value = markdownSummary(results)
lines = ["# Portable runtime readiness";"";"- Status: `"+results.status+"`";"- Runtime decision: `"+fieldOr(results.decision,"status","pending")+"`";"- Memory decision: `"+fieldOr(results.decision,"memoryStatus","pending")+"`";"- Speed gate: integration-only eight-step RK4 timing; construction and checkpoint I/O are descriptive.";"";"| Case | MATLAB preview integration (s) | Standalone integration (s) | Speedup | Error | Peak RSS ratio |";"|---|---:|---:|---:|---:|---:|"];
for item = results.comparison'
    lines(end+1) = "| "+item.id+" | "+sprintf('%.4f',item.matlabIntegrationSeconds)+" | "+sprintf('%.4f',item.standaloneIntegrationSeconds)+" | "+sprintf('%.3fx',item.integrationSpeedup)+" | "+sprintf('%.3e',item.maximumRelativeError)+" | "+sprintf('%.3f',item.peakIncrementRSSRatio)+" |"; %#ok<AGROW>
end
if string(results.failure.identifier) ~= "", lines = [lines;"";"## Failure";"";"- Stage: `"+results.failure.stage+"`";"- `"+results.failure.identifier+"`: "+results.failure.message]; end
value = join(lines,newline)+newline;
end

function validateCapabilities(value)
if ~value.isAvailable || string(value.provider.id) ~= "native-neon-pthreads" || ~value.module.identityValidated || value.libraries.openmp.detected || value.contract.version ~= 4 || value.contract.planCount ~= 17 || value.featureValidation.maximumRelativeError > 1e-12
    error("WaveVortexBenchmark:PortableRuntimeCapability","The runtime benchmark requires the validated native FFTW compiled preview.")
end
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
commit = gitValue(repositoryRoot,"rev-parse HEAD"); tree = gitValue(repositoryRoot,"rev-parse HEAD^{tree}");
[status,output] = system(sprintf('git -C "%s" status --porcelain',repositoryRoot)); isDirty = status ~= 0 || strlength(strtrim(string(output))) > 0;
end

function value = gitValue(repositoryRoot,arguments)
[status,output] = system(sprintf('git -C "%s" %s',repositoryRoot,arguments));
if status ~= 0, error("WaveVortexBenchmark:GitIdentity","Unable to read repository identity."), end
value = strtrim(string(output));
end

function value = environmentRecord
value = struct("processor",string(computer("arch")),"matlabVersion",string(version),"release",string(version("-release")),"architecture",string(computer("arch")),"requestedThreads",min(18,maxNumCompThreads));
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = relativeError(actual,expected)
value = max(abs(actual-expected),[],"all")/max(max(abs(expected),[],"all"),realmin);
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname), end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}), end, end
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = fieldOr(record,name,fallback)
if isstruct(record) && isfield(record,name), value = string(record.(name)); else, value = fallback; end
end

function value = emptyFailure
value = struct("identifier","","message","","report","");
end

function value = emptyRun
value = struct("schemaVersion","portable-runtime-worker-v1","status","failed","implementation","","repeatIndex",0,"case",struct("id",""),"integrationSeconds",NaN,"constructionSeconds",NaN,"readSeconds",NaN,"writeSeconds",NaN,"totalSeconds",NaN,"metadata",struct(),"rss",struct(),"rssSamples",struct(),"outputCheckpoint","","failure",emptyFailure);
end
