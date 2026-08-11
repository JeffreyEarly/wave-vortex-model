function results = runCompiledKernelNonlinearFluxScheduleBenchmark(options)
% Compare sequential and paired compiled nonlinear-flux schedules.
arguments
    options.sizes (:,3) double = [256 256 65;512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot);
buildDirectory = fullfile(repositoryRoot,"Benchmarks","build");
sequentialGateway = "wv_compiled_flux_sequential_mex";
pairedGateway = "wv_compiled_flux_paired_mex";
buildCompiledKernelTransformMex(outputDirectory=buildDirectory,schedule="sequential",outputName=sequentialGateway);
buildCompiledKernelTransformMex(outputDirectory=buildDirectory,schedule="paired",outputName=pairedGateway);
addpath(buildDirectory);

if options.outputDirectory == ""
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","experiments","issue51",options.runId+"-"+computer("arch")+"-"+version("-release"));
end

cases = repmat(emptyCase(),0,1);
for iSize = 1:size(options.sizes,1)
    for isHydrostatic = options.hydrostatic
        sampleCount = options.mediumSampleCount;
        if iSize == size(options.sizes,1), sampleCount = options.largeSampleCount; end
        cases(end+1,1) = runCase(options.sizes(iSize,:),isHydrostatic,options.threadCount,options.warmupCount,sampleCount,sequentialGateway,pairedGateway); %#ok<AGROW>
    end
end
selection = selectSchedule(cases,options.sizes);
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct( ...
    "schemaVersion","1.0.0", ...
    "status","complete", ...
    "runId",options.runId, ...
    "environment",environmentRecord(options.threadCount), ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty,"coreSha256",sha256File(fullfile(repositoryRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp"))), ...
    "configuration",struct("sizes",options.sizes,"hydrostatic",options.hydrostatic,"warmupCount",options.warmupCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"speedThreshold",1.10,"memoryIncreaseLimit",0.15,"regressionLimit",0.03,"correctnessTolerance",1e-12), ...
    "cases",cases, ...
    "selection",selection);
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"nonlinear-flux-schedule-benchmark.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function result = runCase(Nxyz,isHydrostatic,threadCount,warmupCount,sampleCount,sequentialGateway,pairedGateway)
rng(5100+sum(Nxyz)+double(isHydrostatic),"twister");
wvt = WVTransformConstantStratification([15000 15000 1300],Nxyz,isHydrostatic=isHydrostatic,shouldAntialias=true);
wvt.initWithRandomFlow(uvMax=0.01);
wvt.t = 90;
configuration = kernelConfiguration(wvt);
sequentialHandle = feval(sequentialGateway,'create',configuration,threadCount);
pairedHandle = feval(pairedGateway,'create',configuration,threadCount);
sequentialCleanup = onCleanup(@()deleteKernel(sequentialGateway,sequentialHandle));
pairedCleanup = onCleanup(@()deleteKernel(pairedGateway,pairedHandle));
operations = ["matlab" "sequential" "paired"];
actions = {@()matlabFlux(wvt),@()compiledFlux(sequentialGateway,sequentialHandle,wvt),@()compiledFlux(pairedGateway,pairedHandle,wvt)};
for iWarmup = 1:warmupCount
    for iOperation = 1:numel(actions), actions{iOperation}(); end
end
samples = zeros(sampleCount,numel(actions));
orders = zeros(sampleCount,numel(actions));
for iSample = 1:sampleCount
    order = mod((0:numel(actions)-1)+(iSample-1),numel(actions))+1;
    orders(iSample,:) = order;
    for iOperation = order
        timer = tic;
        actions{iOperation}();
        samples(iSample,iOperation) = toc(timer);
    end
end
[expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
[sequentialFp,sequentialFm,sequentialF0] = feval(sequentialGateway,'nonlinearFlux',sequentialHandle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
[pairedFp,pairedFm,pairedF0] = feval(pairedGateway,'nonlinearFlux',pairedHandle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
sequentialError = max([relativeError(sequentialFp,expectedFp),relativeError(sequentialFm,expectedFm),relativeError(sequentialF0,expectedF0)]);
pairedError = max([relativeError(pairedFp,expectedFp),relativeError(pairedFm,expectedFm),relativeError(pairedF0,expectedF0)]);
sequentialMetrics = feval(sequentialGateway,'metrics',sequentialHandle);
pairedMetrics = feval(pairedGateway,'metrics',pairedHandle);
timings = repmat(struct("operation","","samplesSeconds",[],"medianSeconds",0),numel(operations),1);
for iOperation = 1:numel(operations)
    timings(iOperation) = struct("operation",operations(iOperation),"samplesSeconds",samples(:,iOperation)',"medianSeconds",median(samples(:,iOperation)));
end
memoryIncrease = pairedMetrics.scratchCapacityBytes/sequentialMetrics.scratchCapacityBytes-1;
result = struct( ...
    "id",caseId(Nxyz,isHydrostatic),"Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"Nj",wvt.Nj,"Nkl",wvt.Nkl,"warmupCount",warmupCount,"sampleCount",sampleCount,"executionOrders",orders, ...
    "timings",timings, ...
    "pairedSpeedup",median(samples(:,2))/median(samples(:,3)), ...
    "pairedScratchIncreaseFraction",memoryIncrease, ...
    "errors",struct("sequential",sequentialError,"paired",pairedError), ...
    "metrics",struct("sequential",sequentialMetrics,"paired",pairedMetrics), ...
    "correctnessPassed",max(sequentialError,pairedError)<=1e-12);
clear pairedCleanup sequentialCleanup
end

function selection = selectSchedule(cases,sizes)
qualifyingSize = "";
for iSize = 1:size(sizes,1)
    sameSize = arrayfun(@(item)isequal(item.Nxyz,sizes(iSize,:)),cases);
    candidates = cases(sameSize);
    other = cases(~sameSize);
    speedPassed = numel(candidates)==2 && all([candidates.pairedSpeedup]>=1.10);
    memoryPassed = numel(candidates)==2 && all([candidates.pairedScratchIncreaseFraction]<=0.15);
    correctnessPassed = all([candidates.correctnessPassed]);
    regressionPassed = isempty(other) || all([other.pairedSpeedup]>=1/1.03);
    if speedPassed && memoryPassed && correctnessPassed && regressionPassed
        qualifyingSize = join(string(sizes(iSize,:)),"x");
        break
    end
end
if qualifyingSize == ""
    selection = struct("selectedSchedule","sequential","pairedQualified",false,"qualifyingSize","","reason","Paired batching did not satisfy the fixed speed, memory, correctness, and regression rule.");
else
    selection = struct("selectedSchedule","paired","pairedQualified",true,"qualifyingSize",qualifyingSize,"reason","Paired batching satisfied the fixed selection rule.");
end
end

function value = matlabFlux(wvt)
[Fp,Fm,F0] = wvt.nonlinearFlux();
value = real(Fp(1)+Fm(1)+F0(1));
end

function value = compiledFlux(gateway,handle,wvt)
[Fp,Fm,F0] = feval(gateway,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
value = real(Fp(1)+Fm(1)+F0(1));
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)))/max(max(abs(expected(:))),realmin);
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = caseId(Nxyz,isHydrostatic)
value = join(string(Nxyz),"x")+"-"+conditional(isHydrostatic,"hydrostatic","nonhydrostatic");
end

function record = environmentRecord(threads)
record = struct("os",string(system_dependent("getos")),"processor",string(system_dependent("getcpu")),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"threads",threads,"fftwLibrary",fullfile(matlabroot,"bin",computer("arch"),"libmwfftw3.3.dylib"));
end

function [commit,tree,isDirty] = gitIdentity(root)
[~,commit] = system(sprintf('git -C "%s" rev-parse HEAD',root));
[~,tree] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root));
[~,status] = system(sprintf('git -C "%s" status --porcelain',root));
commit = string(strtrim(commit));
tree = string(strtrim(tree));
isDirty = strlength(strtrim(string(status)))>0;
end

function hash = sha256File(pathname)
[status,output] = system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname));
if status~=0, error("WaveVortexModel:HashFailure","Unable to hash %s",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function addRepositoryPaths(repositoryRoot)
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"));
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function deleteKernel(gateway,handle)
try, feval(gateway,'delete',handle); catch, end
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end

function value = emptyCase()
value = struct("id","","Nxyz",[],"isHydrostatic",false,"Nj",0,"Nkl",0,"warmupCount",0,"sampleCount",0,"executionOrders",[],"timings",[],"pairedSpeedup",NaN,"pairedScratchIncreaseFraction",NaN,"errors",struct,"metrics",struct,"correctnessPassed",false);
end

function markdown = summaryMarkdown(results)
lines = ["# Compiled nonlinear-flux schedule benchmark";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- Selected schedule: `"+results.selection.selectedSchedule+"`";"- Reason: "+results.selection.reason;"";"| Case | MATLAB (ms) | Sequential (ms) | Paired (ms) | Paired speedup | Scratch increase | Max error |";"|---|---:|---:|---:|---:|---:|---:|"];
for item = results.cases'
    medians = [item.timings.medianSeconds]*1e3;
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3f | %.3fx | %.1f%% | %.3g |",item.id,medians(1),medians(2),medians(3),item.pairedSpeedup,100*item.pairedScratchIncreaseFraction,max(item.errors.sequential,item.errors.paired)); %#ok<AGROW>
end
markdown = join(lines,newline)+newline;
end
