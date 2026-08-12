function results = runCompiledKernelIssue130BoundedFFTScreening(options)
% Screen author-only bounded FFT executions for issue #130 streamed targets.
arguments
    options.nativeProviderRoot (1,1) string
    options.buildDirectory (1,1) string = fullfile(tempdir,"wave-vortex-issue130-bounded-mex")
    options.outputDirectory (1,1) string = ""
    options.shouldBuild (1,1) logical = true
    options.shouldRunComplete (1,1) logical = true
    options.shouldWriteArtifacts (1,1) logical = false
end

repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
provider = nativeProvider(options.nativeProviderRoot);
configurations = configurationDefinitions;
if options.shouldBuild
    if ~isfolder(options.buildDirectory), mkdir(options.buildDirectory); end
    for iConfiguration = 1:numel(configurations)
        item = configurations(iConfiguration);
        [mexPath,build] = buildCompiledKernelTransformMex(outputDirectory=options.buildDirectory,outputName=item.module,provider=provider,issue130Variant=3,horizontalZBatch=item.horizontalZBatch,verticalHalfRowBatch=item.verticalHalfRowBatch);
        configurations(iConfiguration).mexPath = string(mexPath);
        configurations(iConfiguration).mexSha256 = string(build.mexSha256);
    end
else
    for iConfiguration = 1:numel(configurations)
        configurations(iConfiguration).mexPath = fullfile(options.buildDirectory,configurations(iConfiguration).module+"."+mexext);
        if ~isfile(configurations(iConfiguration).mexPath), error("WaveVortexModel:Issue130BoundedMexMissing","Missing bounded FFT MEX module: %s",configurations(iConfiguration).mexPath); end
        configurations(iConfiguration).mexSha256 = sha256File(configurations(iConfiguration).mexPath);
    end
end
addpath(options.buildDirectory);

results = initializeResults(repositoryRoot,provider,configurations);
cases = caseDefinitions;
for iCase = 1:numel(cases)
    definition = cases(iCase);
    fprintf("Issue #130 bounded FFT microbenchmark: %s.\n",definition.id);
    rng(definition.seed,"twister");
    wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=true);
    state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
    [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
    records = repmat(emptyCaseConfiguration,0,1);
    for iConfiguration = 1:numel(configurations)
        item = configurations(iConfiguration);
        resetState(wvt,state);
        handle = feval(item.module,'create',kernelConfiguration(wvt),16);
        handleCleanup = onCleanup(@()deleteHandle(item.module,handle));
        validateIdentity(feval(item.module,'moduleInfo'),provider);
        [actualFp,actualFm,actualF0,~,~] = execute(item.module,handle,wvt);
        errors = struct("Fp",relativeError(actualFp,expectedFp),"Fm",relativeError(actualFm,expectedFm),"F0",relativeError(actualF0,expectedF0));
        maximumRelativeError = max([errors.Fp errors.Fm errors.F0]);
        correctnessPassed = maximumRelativeError <= 1e-12;
        horizontalSamples = [];
        verticalSamples = [];
        pipelineSamples = [];
        metricsBeforeSample = feval(item.module,'metrics',handle); metrics = metricsBeforeSample;
        if correctnessPassed
            feval(item.module,'setStageInstrumentation',handle,true); execute(item.module,handle,wvt); feval(item.module,'setStageInstrumentation',handle,false);
            horizontalSamples = NaN(1,3); verticalSamples = NaN(1,3); pipelineSamples = NaN(1,3);
            for iSample = 1:3
                metricsBeforeSample = feval(item.module,'metrics',handle);
                feval(item.module,'setStageInstrumentation',handle,true);
                execute(item.module,handle,wvt);
                sampleMetrics = feval(item.module,'metrics',handle);
                feval(item.module,'setStageInstrumentation',handle,false);
                horizontalSamples(iSample) = sampleMetrics.horizontalFFTSeconds;
                verticalSamples(iSample) = sampleMetrics.verticalFFTSeconds;
                pipelineSamples(iSample) = horizontalSamples(iSample)+verticalSamples(iSample);
                metrics = sampleMetrics;
            end
        end
        records(end+1,1) = struct("id",item.id,"horizontalZBatch",item.horizontalZBatch,"verticalHalfRowBatch",item.verticalHalfRowBatch,"module",item.module,"mexSha256",item.mexSha256,"correctnessPassed",correctnessPassed,"errors",errors,"maximumRelativeError",maximumRelativeError,"horizontalFFTSamplesSeconds",horizontalSamples,"horizontalFFTMedianSeconds",median(horizontalSamples,"omitmissing"),"verticalFFTSamplesSeconds",verticalSamples,"verticalFFTMedianSeconds",median(verticalSamples,"omitmissing"),"affectedPipelineSamplesSeconds",pipelineSamples,"affectedPipelineMedianSeconds",median(pipelineSamples,"omitmissing"),"affectedPipelineImprovement",NaN,"microbenchmarkQualified",false,"complete",emptyComplete,"metrics",metricRecord(metricsBeforeSample,metrics)); %#ok<AGROW>
        clear handleCleanup
    end
    controlPipeline = records(1).affectedPipelineMedianSeconds;
    for iConfiguration = 1:numel(records)
        records(iConfiguration).affectedPipelineImprovement = 1-records(iConfiguration).affectedPipelineMedianSeconds/controlPipeline;
    end
    results.cases(end+1,1) = struct("id",definition.id,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"seed",definition.seed,"configurations",records); %#ok<AGROW>
    delete(wvt)
end

qualified = true(1,numel(configurations));
for iConfiguration = 1:numel(configurations)
    caseRecords = arrayfun(@(item)item.configurations(iConfiguration),results.cases);
    qualified(iConfiguration) = iConfiguration>1 && all([caseRecords.correctnessPassed]) && all([caseRecords.affectedPipelineImprovement]>=0.03);
end
qualified(1) = true;
for iCase = 1:numel(results.cases)
    for iConfiguration = 1:numel(configurations), results.cases(iCase).configurations(iConfiguration).microbenchmarkQualified = qualified(iConfiguration); end
end

if options.shouldRunComplete
    for iCase = 1:numel(cases)
        definition = cases(iCase);
        rng(definition.seed,"twister");
        wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=true);
        state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
        for iConfiguration = find(qualified)
            item = configurations(iConfiguration);
            resetState(wvt,state);
            handle = feval(item.module,'create',kernelConfiguration(wvt),16);
            handleCleanup = onCleanup(@()deleteHandle(item.module,handle));
            execute(item.module,handle,wvt);
            metricsBefore = feval(item.module,'metrics',handle);
            totalSamples = NaN(1,3); internalSamples = NaN(1,3);
            for iSample = 1:3, [~,~,~,internalSamples(iSample),totalSamples(iSample)] = execute(item.module,handle,wvt); end
            metrics = feval(item.module,'metrics',handle);
            results.cases(iCase).configurations(iConfiguration).complete = struct("warmupCount",1,"sampleCount",3,"totalSamplesSeconds",totalSamples,"totalMedianSeconds",median(totalSamples),"internalSamplesSeconds",internalSamples,"internalMedianSeconds",median(internalSamples),"controlImprovement",NaN,"improvesControl",false,"planCount",metrics.planCount,"planBytes",metrics.planBytes,"logicalPlanCount",metrics.logicalPlanCount,"nativeExecutionCount",(metrics.nativeExecutionCount-metricsBefore.nativeExecutionCount)/3,"horizontalNativeExecutionCount",(metrics.horizontalNativeExecutionCount-metricsBefore.horizontalNativeExecutionCount)/3,"verticalNativeExecutionCount",(metrics.verticalNativeExecutionCount-metricsBefore.verticalNativeExecutionCount)/3);
            clear handleCleanup
        end
        delete(wvt)
        controlMedian = results.cases(iCase).configurations(1).complete.totalMedianSeconds;
        for iConfiguration = find(qualified)
            improvement = 1-results.cases(iCase).configurations(iConfiguration).complete.totalMedianSeconds/controlMedian;
            results.cases(iCase).configurations(iConfiguration).complete.controlImprovement = improvement;
            results.cases(iCase).configurations(iConfiguration).complete.improvesControl = iConfiguration>1 && improvement>0;
        end
    end
end

results.qualifiedConfigurationIds = string({configurations(qualified).id});
results.selection = selectConfiguration(results.cases,qualified,options.shouldRunComplete);
results.status = "complete";
results.completedAtUTC = utcTimestamp;
if options.shouldWriteArtifacts
    if isfolder(options.outputDirectory), error("WaveVortexModel:Issue130BoundedOutputExists","Output directory already exists: %s",options.outputDirectory); end
    mkdir(options.outputDirectory);
    writeText(fullfile(options.outputDirectory,"issue130-bounded-fft-screening.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function configurations = configurationDefinitions
horizontal = [0 16 32 64]; vertical = [0 256 1024 4096];
configurations = repmat(struct("id","","horizontalZBatch",0,"verticalHalfRowBatch",0,"module","","mexPath","","mexSha256",""),numel(horizontal)*numel(vertical),1);
iConfiguration = 0;
for horizontalZBatch = horizontal
    for verticalHalfRowBatch = vertical
        iConfiguration = iConfiguration+1;
        horizontalName = batchName(horizontalZBatch); verticalName = batchName(verticalHalfRowBatch);
        configurations(iConfiguration) = struct("id","z"+horizontalName+"-rows"+verticalName,"horizontalZBatch",horizontalZBatch,"verticalHalfRowBatch",verticalHalfRowBatch,"module","wv_issue130_z"+horizontalName+"_rows"+verticalName,"mexPath","","mexSha256","");
    end
end
end

function cases = caseDefinitions
cases = [struct("id","constant-hydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",true,"seed",1302561); struct("id","constant-nonhydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",false,"seed",1302562)];
end

function results = initializeResults(repositoryRoot,provider,configurations)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct("schemaVersion","1.0.0","status","running","generatedAtUTC",utcTimestamp,"completedAtUTC","","source",struct("commit",commit,"tree",tree,"isDirty",isDirty),"environment",struct("host","Lyra","matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"provider",provider.id,"fftwVersion",provider.version,"threadBackend",provider.threadBackend,"threadCount",16,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"baseLibrarySha256",provider.baseLibrarySha256,"threadLibrarySha256",provider.threadLibrarySha256),"configuration",struct("schedule","streamed-target-three-channel","horizontalZBatches",[16 32 64 0],"verticalHalfRowBatches",[256 1024 4096 0],"microbenchmarkWarmupCount",1,"microbenchmarkSampleCount",3,"microbenchmarkGate",0.03,"completeProcessCount",1,"completeWarmupCount",1,"completeSampleCount",3,"correctnessTolerance",1e-12,"largeCasesRun",false,"freshProcessRSSRun",false),"builds",configurations,"cases",repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"seed",0,"configurations",[]),0,1),"qualifiedConfigurationIds",strings(0,1),"selection",struct());
end

function selection = selectConfiguration(cases,qualified,completeEnabled)
selection = struct("id","zall-rowsall","selectedControl",true,"reason","No bounded configuration completed the gate and beat all/all by more than the 3% simplicity preference.","geometricMeanSeconds",NaN,"allAllWithinThreePercent",true);
if ~completeEnabled, selection.reason = "Complete-call screening was disabled."; return, end
indices = find(qualified); scores = Inf(size(indices)); improvesEveryCase = false(size(indices));
for iIndex = 1:numel(indices)
    index = indices(iIndex); medians = arrayfun(@(item)item.configurations(index).complete.totalMedianSeconds,cases); scores(iIndex) = exp(mean(log(medians)));
    improvesEveryCase(iIndex) = index>1 && all(arrayfun(@(item)item.configurations(index).complete.improvesControl,cases));
end
controlScore = scores(indices==1); valid = improvesEveryCase;
if any(valid)
    validIndices = find(valid); [bestScore,relativeBest] = min(scores(validIndices)); bestPosition = validIndices(relativeBest); bestIndex = indices(bestPosition);
    if controlScore > 1.03*bestScore
        selection = struct("id",string(cases(1).configurations(bestIndex).id),"selectedControl",false,"reason","Selected because complete nonlinearFlux improved both cases and exceeded the 3% all/all simplicity preference.","geometricMeanSeconds",bestScore,"allAllWithinThreePercent",false);
    else
        selection.geometricMeanSeconds = controlScore;
        selection.reason = "A bounded setting improved complete nonlinearFlux, but all/all remained within 3% and is preferred.";
    end
else
    selection.geometricMeanSeconds = controlScore;
end
end

function record = metricRecord(before,after)
record = struct("fftBatchSchedule",string(after.fftBatchSchedule),"horizontalZBatchSize",after.horizontalZBatchSize,"verticalHalfRowBatchSize",after.verticalHalfRowBatchSize,"planCount",after.planCount,"logicalPlanCount",after.logicalPlanCount,"planBytes",after.planBytes,"nativeExecutionCount",after.nativeExecutionCount-before.nativeExecutionCount,"horizontalNativeExecutionCount",after.horizontalNativeExecutionCount-before.horizontalNativeExecutionCount,"verticalNativeExecutionCount",after.verticalNativeExecutionCount-before.verticalNativeExecutionCount,"logicalExecutionCount",after.executionCount-before.executionCount,"horizontalLogicalExecutionCount",after.horizontalExecutionCount-before.horizontalExecutionCount,"verticalLogicalExecutionCount",after.verticalExecutionCount-before.verticalExecutionCount,"horizontalFFTSeconds",after.horizontalFFTSeconds,"verticalFFTSeconds",after.verticalFFTSeconds);
end

function markdown = summaryMarkdown(results)
lines = ["# Issue #130 bounded FFT screening handoff";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- Schedule control: `streamed-target-three-channel` with all/all FFT batches";"- Protocol: affected-FFT microbenchmark gate >=3%, then one process / one warmup / three complete-call samples for qualifiers";"- Selection: `"+results.selection.id+"` — "+results.selection.reason;""];
for caseResult = results.cases'
    lines(end+1:end+3) = ["## "+caseResult.id;"";"| Setting | Correct | Horizontal FFT (ms) | Vertical FFT (ms) | Pipeline improvement | Qualified | Complete median (ms) | Complete improvement | Plans | Native executions |"];
    lines(end+1) = "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|";
    for item = caseResult.configurations'
        completeMedian = NaN; completeImprovement = NaN; planCount = item.metrics.planCount; nativeExecutions = item.metrics.nativeExecutionCount;
        if item.complete.sampleCount > 0, completeMedian = item.complete.totalMedianSeconds; completeImprovement = item.complete.controlImprovement; planCount = item.complete.planCount; nativeExecutions = item.complete.nativeExecutionCount; end
        lines(end+1) = sprintf("| %s | %s | %.3f | %.3f | %.2f%% | %s | %.3f | %.2f%% | %d | %d |",item.id,string(item.correctnessPassed),1e3*item.horizontalFFTMedianSeconds,1e3*item.verticalFFTMedianSeconds,100*item.affectedPipelineImprovement,string(item.microbenchmarkQualified),1e3*completeMedian,100*completeImprovement,planCount,nativeExecutions); %#ok<AGROW>
    end
    lines(end+1) = "";
end
markdown = join(lines,newline)+newline;
end

function provider = nativeProvider(root)
includeDirectory = fullfile(root,"install","include"); baseLibrary = fullfile(root,"install","lib","libfftw3.3.dylib"); threadLibrary = fullfile(root,"install","lib","libfftw3_threads.3.dylib");
if ~isfile(fullfile(includeDirectory,"fftw3.h")) || ~isfile(baseLibrary) || ~isfile(threadLibrary), error("WaveVortexModel:Issue130NativeProviderMissing","The pinned FFTW provider is incomplete at %s.",root); end
provider = struct("id","native-neon-pthreads","version","3.3.11","threadBackend","pthreads","includeDirectory",string(includeDirectory),"linkLibraries",[string(threadLibrary) string(baseLibrary)],"rpathDirectories",string(fullfile(root,"install","lib")),"baseLibrary",string(baseLibrary),"threadLibrary",string(threadLibrary),"baseLibrarySha256",sha256File(baseLibrary),"threadLibrarySha256",sha256File(threadLibrary));
end

function [Fp,Fm,F0,internalSeconds,totalSeconds] = execute(module,handle,wvt)
timer = tic; [Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); totalSeconds = toc(timer);
end

function resetState(wvt,state)
wvt.t = state.t0; wvt.Ap = state.Ap; wvt.Am = state.Am; wvt.A0 = state.A0;
end

function validateIdentity(info,provider)
if ~contains(string(info.version),provider.version) || string(info.baseLibrary) ~= provider.baseLibrary || string(info.threadLibrary) ~= provider.threadLibrary, error("WaveVortexModel:Issue130ProviderIdentity","The loaded FFTW provider does not match the pinned build."); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
[status,commit] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve commit identity."); end
[status,tree] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD^{tree}"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve tree identity."); end
[~,dirty] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain"); commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(dirty)))>0;
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],"omitmissing")/max(max(abs(expected(:)),[],"omitmissing"),realmin);
end

function deleteHandle(module,handle)
try, feval(module,'delete',handle); catch, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname)); if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end, hash = extractBefore(string(strtrim(output))," ");
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function name = batchName(value)
if value == 0, name = "all"; else, name = string(value); end
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end, cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = emptyComplete
value = struct("warmupCount",0,"sampleCount",0,"totalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalSamplesSeconds",[],"internalMedianSeconds",NaN,"controlImprovement",NaN,"improvesControl",false,"planCount",NaN,"planBytes",NaN,"logicalPlanCount",NaN,"nativeExecutionCount",NaN,"horizontalNativeExecutionCount",NaN,"verticalNativeExecutionCount",NaN);
end

function value = emptyCaseConfiguration
value = struct("id","","horizontalZBatch",0,"verticalHalfRowBatch",0,"module","","mexSha256","","correctnessPassed",false,"errors",struct(),"maximumRelativeError",NaN,"horizontalFFTSamplesSeconds",[],"horizontalFFTMedianSeconds",NaN,"verticalFFTSamplesSeconds",[],"verticalFFTMedianSeconds",NaN,"affectedPipelineSamplesSeconds",[],"affectedPipelineMedianSeconds",NaN,"affectedPipelineImprovement",NaN,"microbenchmarkQualified",false,"complete",emptyComplete,"metrics",struct());
end
