function results = runCompiledKernelIssue130Screening(options)
% Screen author-only issue #130 nonlinear-flux scratch schedules on Lyra.
arguments
    options.nativeProviderRoot (1,1) string
    options.buildDirectory (1,1) string = fullfile(tempdir,"wave-vortex-issue130-mex")
    options.outputDirectory (1,1) string = ""
    options.shouldBuild (1,1) logical = true
    options.shouldTime (1,1) logical = true
    options.shouldWriteArtifacts (1,1) logical = false
end

repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
provider = nativeProvider(options.nativeProviderRoot);
variants = variantDefinitions;
if options.shouldBuild
    if ~isfolder(options.buildDirectory), mkdir(options.buildDirectory); end
    for iVariant = 1:numel(variants)
        [mexPath,build] = buildCompiledKernelTransformMex(outputDirectory=options.buildDirectory,outputName=variants(iVariant).module,provider=provider,issue130Variant=variants(iVariant).number);
        variants(iVariant).mexPath = string(mexPath);
        variants(iVariant).mexSha256 = string(build.mexSha256);
    end
else
    for iVariant = 1:numel(variants)
        variants(iVariant).mexPath = fullfile(options.buildDirectory,variants(iVariant).module+"."+mexext);
        if ~isfile(variants(iVariant).mexPath), error("WaveVortexModel:Issue130MexMissing","Missing issue #130 MEX module: %s",variants(iVariant).mexPath); end
        variants(iVariant).mexSha256 = sha256File(variants(iVariant).mexPath);
    end
end
addpath(options.buildDirectory);

results = initializeResults(repositoryRoot,provider,variants,options);
cases = caseDefinitions;
for iCase = 1:numel(cases)
    definition = cases(iCase);
    fprintf("Issue #130 screening: %s.\n",definition.id);
    rng(definition.seed,"twister");
    wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=true);
    state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
    [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
    caseResults = repmat(emptyVariantResult,0,1);
    controlMedian = NaN;
    for iVariant = 1:numel(variants)
        variant = variants(iVariant);
        wvt.t = state.t0;
        wvt.Ap = state.Ap;
        wvt.Am = state.Am;
        wvt.A0 = state.A0;
        handle = feval(variant.module,'create',kernelConfiguration(wvt),16);
        handleCleanup = onCleanup(@()deleteHandle(variant.module,handle));
        info = feval(variant.module,'moduleInfo');
        validateIdentity(info,provider);
        [actualFp,actualFm,actualF0,~] = execute(variant.module,handle,wvt);
        errors = struct("Fp",relativeError(actualFp,expectedFp),"Fm",relativeError(actualFm,expectedFm),"F0",relativeError(actualF0,expectedF0));
        maximumRelativeError = max([errors.Fp errors.Fm errors.F0]);
        correctnessPassed = maximumRelativeError <= 1e-12;
        totalSamplesSeconds = [];
        internalSamplesSeconds = [];
        if correctnessPassed && options.shouldTime
            execute(variant.module,handle,wvt);
            totalSamplesSeconds = NaN(1,3);
            internalSamplesSeconds = NaN(1,3);
            for iSample = 1:3
                advanceWaveVortexBenchmarkState(wvt,state,iSample);
                [~,~,~,internalSamplesSeconds(iSample),totalSamplesSeconds(iSample)] = execute(variant.module,handle,wvt);
            end
        end
        if iVariant == 1 && options.shouldTime, controlMedian = median(totalSamplesSeconds); end
        regression = NaN;
        if iVariant > 1 && options.shouldTime && ~isempty(totalSamplesSeconds), regression = median(totalSamplesSeconds)/controlMedian-1; end
        stoppedByRule = ~correctnessPassed || (isfinite(regression) && regression > 0.05);
        feval(variant.module,'setStageInstrumentation',handle,true);
        metricsBefore = feval(variant.module,'metrics',handle);
        if correctnessPassed, execute(variant.module,handle,wvt); end
        metricsAfter = feval(variant.module,'metrics',handle);
        feval(variant.module,'setStageInstrumentation',handle,false);
        metrics = metricRecord(metricsBefore,metricsAfter);
        caseResults(end+1,1) = struct("id",variant.id,"number",variant.number,"module",variant.module,"mexSha256",variant.mexSha256,"status",conditional(correctnessPassed,"complete","failed"),"correctnessPassed",correctnessPassed,"errors",errors,"maximumRelativeError",maximumRelativeError,"warmupCount",double(options.shouldTime&&correctnessPassed),"sampleCount",numel(totalSamplesSeconds),"totalSamplesSeconds",totalSamplesSeconds,"totalMedianSeconds",median(totalSamplesSeconds,"omitmissing"),"internalSamplesSeconds",internalSamplesSeconds,"internalMedianSeconds",median(internalSamplesSeconds,"omitmissing"),"completeCallRegression",regression,"stoppedByRule",stoppedByRule,"metrics",metrics); %#ok<AGROW>
        clear handleCleanup
        if iVariant == 1 && ~correctnessPassed, error("WaveVortexModel:Issue130ControlIncorrect","The unchanged be0f789 control failed correctness for %s.",definition.id); end
    end
    results.cases(end+1,1) = struct("id",definition.id,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"seed",definition.seed,"variants",caseResults); %#ok<AGROW>
    delete(wvt)
end
results.status = conditional(all(arrayfun(@(item)all([item.variants.correctnessPassed]),results.cases)),"complete","partial");
results.completedAtUTC = utcTimestamp;
results.candidates = candidateSummary(results.cases);
if options.shouldWriteArtifacts
    if isfolder(options.outputDirectory), error("WaveVortexModel:Issue130OutputExists","Output directory already exists: %s",options.outputDirectory); end
    mkdir(options.outputDirectory);
    writeText(fullfile(options.outputDirectory,"issue130-screening.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function variants = variantDefinitions
variants = repmat(struct("id","","number",0,"module","","mexPath","","mexSha256",""),3,1);
variants(1) = struct("id","control-be0f789","number",0,"module","wv_issue130_control","mexPath","","mexSha256","");
variants(2) = struct("id","velocity-only","number",2,"module","wv_issue130_velocity_only","mexPath","","mexSha256","");
variants(3) = struct("id","streamed-target-three-channel","number",3,"module","wv_issue130_streamed_three_channel","mexPath","","mexSha256","");
end

function cases = caseDefinitions
cases = [struct("id","constant-hydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",true,"seed",1302561); struct("id","constant-nonhydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",false,"seed",1302562)];
end

function provider = nativeProvider(root)
includeDirectory = fullfile(root,"install","include");
baseLibrary = fullfile(root,"install","lib","libfftw3.3.dylib");
threadLibrary = fullfile(root,"install","lib","libfftw3_threads.3.dylib");
if ~isfile(fullfile(includeDirectory,"fftw3.h")) || ~isfile(baseLibrary) || ~isfile(threadLibrary), error("WaveVortexModel:Issue130NativeProviderMissing","The pinned FFTW 3.3.11 NEON/pthreads provider is incomplete at %s.",root); end
provider = struct("id","native-neon-pthreads","version","3.3.11","threadBackend","pthreads","includeDirectory",string(includeDirectory),"linkLibraries",[string(threadLibrary) string(baseLibrary)],"rpathDirectories",string(fullfile(root,"install","lib")),"baseLibrary",string(baseLibrary),"threadLibrary",string(threadLibrary),"baseLibrarySha256",sha256File(baseLibrary),"threadLibrarySha256",sha256File(threadLibrary));
end

function results = initializeResults(repositoryRoot,provider,variants,options)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct("schemaVersion","1.0.0","status","running","generatedAtUTC",utcTimestamp,"completedAtUTC","","source",struct("commit",commit,"tree",tree,"isDirty",isDirty),"environment",struct("host","Lyra","matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"provider",provider.id,"fftwVersion",provider.version,"threadBackend",provider.threadBackend,"threadCount",16,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"baseLibrarySha256",provider.baseLibrarySha256,"threadLibrarySha256",provider.threadLibrarySha256),"configuration",struct("processCount",1,"warmupCount",1,"sampleCount",3,"sizes",[256 256 65],"hydrostatic",[true false],"largeCasesRun",false,"freshProcessRSSRun",false,"fullTestSuiteRun",false,"stopRegression",0.05,"correctnessTolerance",1e-12,"timingEnabled",options.shouldTime),"builds",variants,"cases",repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"seed",0,"variants",[]),0,1),"candidates",[]);
end

function [Fp,Fm,F0,internalSeconds,totalSeconds] = execute(module,handle,wvt)
timer = tic;
[Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
totalSeconds = toc(timer);
end

function record = metricRecord(before,after)
stageNames = ["phaseSeconds" "reconstructionSeconds" "derivativeReconstructionSeconds" "productSeconds" "projectionSeconds" "coefficientAssemblySeconds" "derivativeCoefficientAssemblySeconds" "coefficientProjectionSeconds"];
stages = struct;
for name = stageNames, stages.(name) = after.(name); end
record = struct("screeningVariant",string(after.screeningVariant),"nonlinearFluxSchedule",string(after.nonlinearFluxSchedule),"planCount",after.planCount,"executionCount",after.executionCount-before.executionCount,"horizontalExecutionCount",after.horizontalExecutionCount-before.horizontalExecutionCount,"verticalExecutionCount",after.verticalExecutionCount-before.verticalExecutionCount,"phaseEvaluationCount",after.nonlinearFluxPhaseEvaluationCount-before.nonlinearFluxPhaseEvaluationCount,"halfSpectrumScratchBytes",after.halfSpectrumScratchCapacityBytes,"realScratchBytes",after.realScratchCapacityBytes,"scratchBytes",after.scratchCapacityBytes,"phaseReservationBytes",after.phaseReservationBytes,"persistentBytes",after.persistentBytes,"knownMaximumLiveOwnedBytes",after.knownMaximumLiveOwnedBytes,"stages",stages);
end

function candidates = candidateSummary(cases)
ids = string({cases(1).variants.id});
candidates = repmat(struct("id","","correctnessPassed",false,"maximumCompleteCallRegression",NaN,"stoppedByRule",false,"advanceToDonut",false),numel(ids),1);
for iVariant = 1:numel(ids)
    records = arrayfun(@(item)item.variants(iVariant),cases);
    regressions = [records.completeCallRegression];
    maximumRegression = max(regressions,[],"omitmissing");
    candidates(iVariant) = struct("id",ids(iVariant),"correctnessPassed",all([records.correctnessPassed]),"maximumCompleteCallRegression",maximumRegression,"stoppedByRule",any([records.stoppedByRule]),"advanceToDonut",iVariant==1 || (all([records.correctnessPassed]) && (~any(isfinite(regressions)) || maximumRegression<=0.05)));
end
end

function markdown = summaryMarkdown(results)
lines = ["# Issue #130 Lyra scratch-screening handoff";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- Provider: FFTW `"+results.environment.fftwVersion+"` NEON/`"+results.environment.threadBackend+"`, `"+results.environment.threadCount+"` threads";"- Protocol: one process, one warmup, three medium-case samples; no large cases or fresh-process RSS";"";"| Case | Variant | Correct | Median complete call (ms) | Regression | Scratch | Phase reservation | Plans | Executions | Advance |";"|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"];
for caseResult = results.cases'
    for variant = caseResult.variants'
        candidate = results.candidates(string({results.candidates.id})==variant.id);
        lines(end+1) = sprintf("| %s | %s | %s | %.3f | %.2f%% | %.3f MiB | %.3f MiB | %d | %d | %s |",caseResult.id,variant.id,string(variant.correctnessPassed),1e3*variant.totalMedianSeconds,100*variant.completeCallRegression,variant.metrics.scratchBytes/2^20,variant.metrics.phaseReservationBytes/2^20,variant.metrics.planCount,variant.metrics.executionCount,string(candidate.advanceToDonut)); %#ok<AGROW>
    end
end
markdown = join(lines,newline)+newline;
end

function validateIdentity(info,provider)
if ~contains(string(info.version),provider.version) || string(info.baseLibrary) ~= provider.baseLibrary || string(info.threadLibrary) ~= provider.threadLibrary, error("WaveVortexModel:Issue130ProviderIdentity","The loaded FFTW provider does not match the pinned NEON/pthreads build."); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
[status,commit] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve commit identity."); end
[status,tree] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD^{tree}"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve tree identity."); end
[~,dirty] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain");
commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(dirty)))>0;
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
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname)); if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyVariantResult
value = struct("id","","number",0,"module","","mexSha256","","status","failed","correctnessPassed",false,"errors",struct(),"maximumRelativeError",NaN,"warmupCount",0,"sampleCount",0,"totalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalSamplesSeconds",[],"internalMedianSeconds",NaN,"completeCallRegression",NaN,"stoppedByRule",false,"metrics",struct());
end
