function compiledKernelNativeFFTWWorker(configPath,outputPath)
% Run one issue #137 provider/thread configuration in a fresh MATLAB process.
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
        inputs = operationInputs(activeTransform,definition.isHydrostatic);

        writePhase(phasePath,prefix+"-first-execution");
        [firstTotalSeconds,firstInternalSeconds] = executeTimed(config.module,"nonlinearFlux",activeHandle,inputs,activeTransform);
        operations = operationIdentifiers;
        for iWarmup = 1:definition.warmupCount
            advanceWaveVortexBenchmarkState(activeTransform,state,iWarmup);
            for operation = operations
                executeTimed(config.module,operation,activeHandle,inputs,activeTransform);
            end
        end
        writePhase(phasePath,prefix+"-persistent"); pause(config.plateauSeconds);
        totalSamples = NaN(definition.sampleCount,numel(operations));
        internalSamples = NaN(definition.sampleCount,numel(operations));
        writePhase(phasePath,prefix+"-operations");
        for iSample = 1:definition.sampleCount
            order = mod((0:numel(operations)-1)+(iSample-1),numel(operations))+1;
            for iOperation = order
                operation = operations(iOperation);
                if operation == "nonlinearFlux"
                    advanceWaveVortexBenchmarkState(activeTransform,state,definition.warmupCount+iSample);
                end
                [totalSamples(iSample,iOperation),internalSamples(iSample,iOperation)] = executeTimed(config.module,operation,activeHandle,inputs,activeTransform);
            end
        end
        errors = correctnessErrors(config.module,activeHandle,inputs,activeTransform,definition.isHydrostatic);
        metrics = feval(config.module,'metrics',activeHandle);
        timings = timingRecords(totalSamples,internalSamples);
        planningSeconds = moduleAfterCreate.totalPlanningSeconds-moduleBefore.totalPlanningSeconds;
        resultCase = struct("id",prefix,"Nxyz",definition.Nxyz,"isHydrostatic",logical(definition.isHydrostatic),"shouldAntialias",logical(definition.shouldAntialias),"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"constructionSeconds",constructionSeconds,"planningSeconds",planningSeconds,"firstExecution",struct("totalSeconds",firstTotalSeconds,"internalSeconds",firstInternalSeconds),"timings",timings,"errors",errors,"maximumRelativeError",max(cell2mat(struct2cell(errors))),"metrics",metrics,"rss",emptyRSS(config.samplingIntervalSeconds),"status","complete");

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
    result = struct("schemaVersion","1.0.0","status",conditional(all([caseResults.lifecyclePassed])&&max([caseResults.maximumRelativeError])<=1e-12,"complete","failed"),"stage",string(config.stage),"providerId",string(config.providerId),"threadBackend",string(config.threadBackend),"simplicityRank",config.simplicityRank,"threadCount",config.threadCount,"repeatIndex",config.repeatIndex,"module",string(config.module),"moduleInfo",moduleInfo,"cases",caseResults,"rss",rss,"moduleClearSeconds",clearSeconds,"failure",emptyFailure());
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

function identifiers = operationIdentifiers
identifiers = ["forward" "inverse" "fAll" "gAll" "nonlinearFlux"];
end

function inputs = operationInputs(wvt,isHydrostatic)
[U,V,W,N] = wvt.transformWaveVortexToUVWEta(wvt.Ap,wvt.Am,wvt.A0,wvt.t);
if isHydrostatic, fields = cat(4,U,V,N); else, fields = cat(4,U,V,W,N); end
inputs = struct("fields",fields,"Ap",wvt.Ap,"Am",wvt.Am,"A0",wvt.A0,"Apm",wvt.Ap+wvt.Am);
end

function [totalSeconds,internalSeconds] = executeTimed(module,operation,handle,inputs,wvt)
timer = tic;
switch operation
    case "forward"
        [Ap,Am,A0,internalSeconds] = feval(module,'forwardTimed',handle,inputs.fields,wvt.t,wvt.t0); %#ok<ASGLU>
    case "inverse"
        [fields,internalSeconds] = feval(module,'inverseTimed',handle,inputs.Ap,inputs.Am,inputs.A0,wvt.t,wvt.t0); %#ok<ASGLU>
    case "fAll"
        [fields,internalSeconds] = feval(module,'fAllTimed',handle,inputs.Apm,inputs.A0); %#ok<ASGLU>
    case "gAll"
        [fields,internalSeconds] = feval(module,'gAllTimed',handle,inputs.Apm,inputs.A0); %#ok<ASGLU>
    case "nonlinearFlux"
        [Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); %#ok<ASGLU>
end
totalSeconds = toc(timer);
end

function errors = correctnessErrors(module,handle,inputs,wvt,isHydrostatic)
[actualAp,actualAm,actualA0] = feval(module,'forward',handle,inputs.fields,wvt.t,wvt.t0);
if isHydrostatic
    [expectedAp,expectedAm,expectedA0] = wvt.transformUVEtaToWaveVortex(inputs.fields(:,:,:,1),inputs.fields(:,:,:,2),inputs.fields(:,:,:,3));
else
    [expectedAp,expectedAm,expectedA0] = wvt.transformUVWEtaToWaveVortex(inputs.fields(:,:,:,1),inputs.fields(:,:,:,2),inputs.fields(:,:,:,3),inputs.fields(:,:,:,4));
end
actualInverse = feval(module,'inverse',handle,inputs.Ap,inputs.Am,inputs.A0,wvt.t,wvt.t0);
[U,V,W,N] = wvt.transformWaveVortexToUVWEta(inputs.Ap,inputs.Am,inputs.A0,wvt.t);
actualF = feval(module,'fAll',handle,inputs.Apm,inputs.A0);
[F,Fx,Fy,Fz] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=inputs.Apm,A0=inputs.A0);
actualG = feval(module,'gAll',handle,inputs.Apm,inputs.A0);
[G,Gx,Gy,Gz] = wvt.transformToSpatialDomainWithGAllDerivatives(Apm=inputs.Apm,A0=inputs.A0);
[actualFp,actualFm,actualF0] = feval(module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
[expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
errors = struct("forward",max([relativeError(actualAp,expectedAp) relativeError(actualAm,expectedAm) relativeError(actualA0,expectedA0)]),"inverse",relativeError(actualInverse,cat(4,U,V,W,N)),"fAll",relativeError(actualF,cat(4,F,Fx,Fy,Fz)),"gAll",relativeError(actualG,cat(4,G,Gx,Gy,Gz)),"nonlinearFlux",max([relativeError(actualFp,expectedFp) relativeError(actualFm,expectedFm) relativeError(actualF0,expectedF0)]));
end

function records = timingRecords(totalSamples,internalSamples)
identifiers = operationIdentifiers;
records = repmat(struct("operation","","totalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalSamplesSeconds",[],"internalMedianSeconds",NaN,"boundaryMedianSeconds",NaN),numel(identifiers),1);
for iOperation = 1:numel(identifiers)
    records(iOperation) = struct("operation",identifiers(iOperation),"totalSamplesSeconds",totalSamples(:,iOperation)',"totalMedianSeconds",median(totalSamples(:,iOperation)),"internalSamplesSeconds",internalSamples(:,iOperation)',"internalMedianSeconds",median(internalSamples(:,iOperation)),"boundaryMedianSeconds",median(totalSamples(:,iOperation)-internalSamples(:,iOperation)));
end
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

function value = emptyCase
value = struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",NaN,"warmupCount",0,"sampleCount",0,"constructionSeconds",NaN,"planningSeconds",NaN,"firstExecution",struct(),"timings",[],"errors",struct(),"maximumRelativeError",NaN,"metrics",struct(),"rss",struct(),"status","failed","lifecyclePassed",false);
end

function value = emptyResult(config)
value = struct("schemaVersion","1.0.0","status","failed","stage",string(config.stage),"providerId",string(config.providerId),"threadBackend",string(config.threadBackend),"simplicityRank",config.simplicityRank,"threadCount",config.threadCount,"repeatIndex",config.repeatIndex,"module",string(config.module),"moduleInfo",struct(),"cases",repmat(emptyCase(),0,1),"rss",emptyRSS(config.samplingIntervalSeconds),"moduleClearSeconds",NaN,"failure",emptyFailure());
end
