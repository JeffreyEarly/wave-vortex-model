function compiledKernelCoefficientAssemblyWorker(configPath,outputPath)
% Run one issue #126 coefficient-assembly candidate in a fresh MATLAB process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase"; stopPath = string(tempname)+".stop"; samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler(config.samplingIntervalSeconds);
result = emptyResult(config);
activeHandle = []; activeTransform = [];
try
    path(config.matlabPath);
    addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,config.mexDirectory);
    writePhase(phasePath,"startup");
    sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds);
    pause(config.plateauSeconds);
    writePhase(phasePath,"provider-load");
    runtime = string(config.runtimeLibrary);
    if runtime == ""
        moduleInfo = feval(config.module,'moduleInfo');
    else
        moduleInfo = feval(config.module,'moduleInfo',char(runtime));
    end
    validateIdentity(moduleInfo,config);
    pause(config.plateauSeconds);

    caseResults = repmat(emptyCase(),0,1);
    for iCase = 1:numel(config.cases)
        definition = config.cases(iCase);
        prefix = string(definition.id);
        rng(definition.seed,'twister');
        writePhase(phasePath,prefix+"-construction");
        constructionTimer = tic;
        activeTransform = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
        state = initializeWaveVortexBenchmarkState(activeTransform,definition.seed);
        moduleBefore = feval(config.module,'moduleMetrics');
        activeHandle = feval(config.module,'create',kernelConfiguration(activeTransform),config.threadCount);
        moduleAfterCreate = feval(config.module,'moduleMetrics');
        constructionSeconds = toc(constructionTimer);
        writePhase(phasePath,prefix+"-first-execution");
        [firstTotalSeconds,firstInternalSeconds] = executeTimed(config.module,activeHandle,activeTransform);
        for iWarmup = 1:definition.warmupCount
            advanceWaveVortexBenchmarkState(activeTransform,state,iWarmup);
            executeTimed(config.module,activeHandle,activeTransform);
        end
        % Attribute the scientific stages once without contaminating timed samples.
        if config.supportsDiagnostics
            feval(config.module,'setStageInstrumentation',activeHandle,true);
            executeTimed(config.module,activeHandle,activeTransform);
            diagnosticMetrics = feval(config.module,'metrics',activeHandle);
            feval(config.module,'setStageInstrumentation',activeHandle,false);
            workerLifecycle = feval(config.module,'workerLifecycle',activeHandle,20);
        else
            diagnosticMetrics = emptyDiagnosticMetrics;
            workerLifecycle = emptyWorkerLifecycle;
        end
        writePhase(phasePath,prefix+"-persistent"); pause(config.plateauSeconds);
        totalSamples = NaN(definition.sampleCount,1);
        internalSamples = NaN(definition.sampleCount,1);
        writePhase(phasePath,prefix+"-operations");
        for iSample = 1:definition.sampleCount
            advanceWaveVortexBenchmarkState(activeTransform,state,definition.warmupCount+iSample);
            [totalSamples(iSample),internalSamples(iSample)] = executeTimed(config.module,activeHandle,activeTransform);
        end
        errors = correctnessErrors(config.module,activeHandle,activeTransform);
        metrics = feval(config.module,'metrics',activeHandle);
        timings = timingRecord(totalSamples,internalSamples);
        planningSeconds = moduleAfterCreate.totalPlanningSeconds-moduleBefore.totalPlanningSeconds;
        resultCase = struct("id",prefix,"Nxyz",definition.Nxyz,"isHydrostatic",logical(definition.isHydrostatic),"shouldAntialias",logical(definition.shouldAntialias),"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"constructionSeconds",constructionSeconds,"planningSeconds",planningSeconds,"firstExecution",struct("totalSeconds",firstTotalSeconds,"internalSeconds",firstInternalSeconds),"timing",timings,"errors",errors,"maximumRelativeError",errors.nonlinearFlux,"metrics",metrics,"diagnosticMetrics",diagnosticMetrics,"workerLifecycle",workerLifecycle,"rss",emptyRSS(config.samplingIntervalSeconds),"status","complete");

        writePhase(phasePath,prefix+"-cleanup");
        feval(config.module,'delete',activeHandle); activeHandle = [];
        delete(activeTransform); activeTransform = [];
        moduleAfterDelete = feval(config.module,'moduleMetrics');
        resultCase.lifecyclePassed = moduleAfterDelete.kernelCount == moduleBefore.kernelCount && moduleAfterDelete.activePlans == moduleBefore.activePlans && moduleAfterDelete.outstandingPlanningBytes == 0 && moduleAfterDelete.totalPlansCreated-moduleAfterDelete.totalPlansDestroyed == moduleAfterDelete.activePlans;
        caseResults(end+1,1) = resultCase; %#ok<AGROW>
        pause(max(0.05,2*config.samplingIntervalSeconds));
    end
    writePhase(phasePath,"module-clear"); clearTimer = tic; eval("clear "+string(config.module)); clearSeconds = toc(clearTimer); pause(config.plateauSeconds);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    rss = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    for iCase = 1:numel(caseResults), caseResults(iCase).rss = caseRSS(rss,string(caseResults(iCase).id)); end
    result = struct("schemaVersion","1.0.0","status",conditional(all([caseResults.lifecyclePassed])&&max([caseResults.maximumRelativeError])<=1e-12,"complete","failed"),"variant",config.variant,"providerId",string(config.providerId),"threadBackend",string(config.threadBackend),"threadCount",config.threadCount,"repeatIndex",config.repeatIndex,"module",string(config.module),"moduleInfo",moduleInfo,"cases",caseResults,"rss",rss,"moduleClearSeconds",clearSeconds,"failure",emptyFailure());
catch exception
    if ~isempty(activeHandle)
        try
            feval(config.module,'delete',activeHandle);
        catch
        end
    end
    if ~isempty(activeTransform) && isvalid(activeTransform), delete(activeTransform); end
    stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name}),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
clear temporaryCleanup stateCleanup
end

function [totalSeconds,internalSeconds] = executeTimed(module,handle,wvt)
timer = tic;
[Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); %#ok<ASGLU>
totalSeconds = toc(timer);
end

function errors = correctnessErrors(module,handle,wvt)
[actualFp,actualFm,actualF0] = feval(module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
[expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
errors = struct("nonlinearFlux",max([relativeError(actualFp,expectedFp) relativeError(actualFm,expectedFm) relativeError(actualF0,expectedF0)]));
end

function record = timingRecord(totalSamples,internalSamples)
record = struct("operation","nonlinearFlux","totalSamplesSeconds",totalSamples(:)',"totalMedianSeconds",median(totalSamples),"internalSamplesSeconds",internalSamples(:)',"internalMedianSeconds",median(internalSamples),"boundaryMedianSeconds",median(totalSamples-internalSamples));
end

function validateIdentity(info,config)
if string(info.baseLibrary) ~= string(config.baseLibrary), error("WaveVortexModel:NativeFFTWBaseIdentity","%s resolved its FFTW base symbols to %s.",config.providerId,info.baseLibrary); end
if string(info.threadLibrary) ~= string(config.threadLibrary), error("WaveVortexModel:NativeFFTWThreadIdentity","%s resolved its FFTW thread symbols to %s.",config.providerId,info.threadLibrary); end
if string(config.runtimeLibrary) ~= "" && string(info.openMPRuntimeLibrary) ~= string(config.runtimeLibrary), error("WaveVortexModel:NativeFFTWOpenMPIdentity","%s resolved OpenMP to %s.",config.providerId,info.openMPRuntimeLibrary); end
if startsWith(string(info.baseLibrary),string(matlabroot)) && string(config.providerId) ~= "matlab-bundled", error("WaveVortexModel:NativeFFTWUnexpectedBundledLibrary","A native provider resolved MATLAB's bundled FFTW."); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],"omitmissing")/max(max(abs(expected(:)),[],"omitmissing"),realmin);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,mexDirectory)
addpath(repositoryRoot,benchmarkFolder,mexDirectory);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function sampler = startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler = emptySampler(interval);
if ~(ismac || isunix) || ~isfile(samplerPath), sampler.reason = "External RSS sampler unavailable."; return, end
command = sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output] = system(command); samplerPid = str2double(strtrim(output));
if status ~= 0 || ~isfinite(samplerPid), sampler.reason = "Unable to launch RSS sampler."; return, end
sampler.status = "running"; sampler.processId = samplerPid; sampler.provider = conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler = stopSampler(sampler,stopPath,interval)
if sampler.status ~= "running", return, end
writeText(stopPath,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',sampler.processId)); sampler.status = "complete";
end

function rss = samplerResult(sampler,samplePath,interval)
rss = emptyRSS(interval); rss.status = sampler.status; rss.provider = sampler.provider; rss.reason = sampler.reason;
if sampler.status ~= "complete" || ~isfile(samplePath), return, end
lines = splitlines(strtrim(string(fileread(samplePath))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t')); index = str2double(fields(1)); rssKiB = str2double(fields(3));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*rssKiB);
end
rss.samples = samples;
startup = [samples(string({samples.phase})=="startup").rssBytes]; provider = [samples(string({samples.phase})=="provider-load").rssBytes];
if ~isempty(startup), rss.startupMedianBytes = median(startup); end
if ~isempty(provider), rss.providerMedianBytes = median(provider); rss.providerIncrementBytes = rss.providerMedianBytes-rss.startupMedianBytes; end
end

function value = caseRSS(rss,caseId)
value = struct("status",rss.status,"provider",rss.provider,"samplingIntervalSeconds",rss.samplingIntervalSeconds,"baselineBytes",NaN,"persistentBytes",NaN,"peakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
if rss.status ~= "complete" || isempty(rss.samples), return, end
phases = string({rss.samples.phase}); bytes = [rss.samples.rssBytes];
baseline = bytes(phases==caseId+"-construction"); persistentSamples = bytes(phases==caseId+"-persistent"); operations = bytes(phases==caseId+"-operations");
if isempty(baseline) || isempty(persistentSamples) || isempty(operations), value.status = "unsupported"; return, end
value.baselineBytes = min(baseline); value.persistentBytes = median(persistentSamples); value.peakBytes = max(operations); value.persistentIncrementBytes = value.persistentBytes-value.baselineBytes; value.peakIncrementBytes = value.peakBytes-value.baselineBytes;
end

function writePhase(pathname,phase)
temporary = pathname+".tmp"; writeText(temporary,phase); movefile(temporary,pathname,"f");
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptySampler(interval)
value = struct("status","unsupported","provider","","reason","","processId",NaN,"samplingIntervalSeconds",interval);
end

function value = emptyRSS(interval)
value = struct("status","unsupported","provider","","reason","","samplingIntervalSeconds",interval,"samples",[],"startupMedianBytes",NaN,"providerMedianBytes",NaN,"providerIncrementBytes",NaN);
end

function value = emptyFailure
value = struct("identifier","","message","","stack",strings(0,1),"report","");
end

function value = emptyDiagnosticMetrics
value = struct("coefficientAssemblySeconds",0.0,"derivativeCoefficientAssemblySeconds",0.0,"coefficientProjectionSeconds",0.0);
end

function value = emptyWorkerLifecycle
value = struct("workerCount",1,"repetitions",0,"creationSeconds",0.0,"synchronizationSeconds",0.0,"joinSeconds",0.0);
end

function value = emptyCase
value = struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",NaN,"warmupCount",0,"sampleCount",0,"constructionSeconds",NaN,"planningSeconds",NaN,"firstExecution",struct(),"timing",struct(),"errors",struct(),"maximumRelativeError",NaN,"metrics",struct(),"diagnosticMetrics",struct(),"workerLifecycle",struct(),"rss",struct(),"status","failed","lifecyclePassed",false);
end

function value = emptyResult(config)
value = struct("schemaVersion","1.0.0","status","failed","variant",config.variant,"providerId",string(config.providerId),"threadBackend",string(config.threadBackend),"threadCount",config.threadCount,"repeatIndex",config.repeatIndex,"module",string(config.module),"moduleInfo",struct(),"cases",repmat(emptyCase(),0,1),"rss",emptyRSS(config.samplingIntervalSeconds),"moduleClearSeconds",NaN,"failure",emptyFailure());
end
