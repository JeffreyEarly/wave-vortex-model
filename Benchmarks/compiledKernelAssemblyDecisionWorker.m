function compiledKernelAssemblyDecisionWorker(configPath,outputPath)
% Run one issue #131 implementation in a fresh MATLAB process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase"; stopPath = string(tempname)+".stop"; samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler(config.samplingIntervalSeconds); result = emptyResult(config); handle = []; wvt = [];
try
    path(config.matlabPath); addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,config.moduleDirectory);
    writePhase(phasePath,"startup"); sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds); pause(config.plateauSeconds);
    moduleInfo = struct();
    if string(config.implementation) ~= "matlab"
        moduleInfo = feval(config.module,'moduleInfo');
        validateModuleInfo(moduleInfo,config);
    end
    caseResults = repmat(emptyCase(),0,1);
    caseOrder = mod((0:numel(config.cases)-1)+(config.repeatIndex-1),numel(config.cases))+1;
    for iCase = caseOrder
        definition = config.cases(iCase); prefix = string(definition.id); rng(definition.seed,'twister');
        writePhase(phasePath,prefix+"-baseline"); pause(config.plateauSeconds);
        writePhase(phasePath,prefix+"-construction"); constructionTimer = tic;
        wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias); state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
        moduleBefore = struct(); planningSeconds = NaN;
        if string(config.implementation) ~= "matlab"
            moduleBefore = feval(config.module,'moduleMetrics');
            handle = feval(config.module,'create',kernelConfiguration(wvt),config.threadCount);
            moduleAfterCreate = feval(config.module,'moduleMetrics');
            if isfield(moduleAfterCreate,"totalPlanningSeconds") && isfield(moduleBefore,"totalPlanningSeconds"), planningSeconds = moduleAfterCreate.totalPlanningSeconds-moduleBefore.totalPlanningSeconds; end
        end
        constructionSeconds = toc(constructionTimer);
        advanceWaveVortexBenchmarkState(wvt,state,0);
        [firstTotalSeconds,firstInternalSeconds] = executeTimed(config.implementation,config.module,handle,wvt);
        for iWarmup = 1:definition.warmupCount
            advanceWaveVortexBenchmarkState(wvt,state,iWarmup); executeTimed(config.implementation,config.module,handle,wvt);
        end
        stageMetrics = struct("status","unavailable");
        if string(config.implementation) ~= "matlab"
            try
                feval(config.module,'setStageInstrumentation',handle,true);
                executeTimed(config.implementation,config.module,handle,wvt);
                stageMetrics = feval(config.module,'metrics',handle); stageMetrics.status = "complete";
                feval(config.module,'setStageInstrumentation',handle,false);
            catch exception
                stageMetrics = struct("status","unavailable","reason",string(exception.identifier));
            end
        end
        [ledger,metrics,metadata] = implementationMetadata(config,wvt,handle,moduleInfo);
        writePhase(phasePath,prefix+"-persistent"); drawnow; pause(config.plateauSeconds);
        totalSamples = NaN(1,definition.sampleCount); internalSamples = NaN(1,definition.sampleCount); finalOutputs = cell(1,3);
        writePhase(phasePath,prefix+"-nonlinearFlux");
        for iSample = 1:definition.sampleCount
            advanceWaveVortexBenchmarkState(wvt,state,definition.warmupCount+iSample);
            [totalSamples(iSample),internalSamples(iSample),finalOutputs] = executeTimed(config.implementation,config.module,handle,wvt);
        end
        if string(config.implementation) == "matlab"
            relativeError = 0;
        else
            expected = cell(1,3); [expected{:}] = wvt.nonlinearFlux(); relativeError = waveVortexBenchmarkRelativeError(expected,finalOutputs);
        end
        clear finalOutputs
        moduleAfterDelete = struct(); lifecyclePassed = true;
        if ~isempty(handle)
            feval(config.module,'delete',handle); handle = [];
            moduleAfterDelete = feval(config.module,'moduleMetrics');
            lifecyclePassed = moduleAfterDelete.kernelCount == moduleBefore.kernelCount && moduleAfterDelete.activePlans == moduleBefore.activePlans && moduleAfterDelete.outstandingPlanningBytes == 0 && moduleAfterDelete.totalPlansCreated-moduleAfterDelete.totalPlansDestroyed == moduleAfterDelete.activePlans;
        end
        delete(wvt); wvt = [];
        caseResults(end+1,1) = struct("id",prefix,"Nxyz",definition.Nxyz,"isHydrostatic",logical(definition.isHydrostatic),"shouldAntialias",logical(definition.shouldAntialias),"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"constructionSeconds",constructionSeconds,"planningSeconds",planningSeconds,"firstCall",struct("completeMexSeconds",firstTotalSeconds,"nativeInternalSeconds",firstInternalSeconds),"completeMexSamplesSeconds",totalSamples,"completeMexMedianSeconds",median(totalSamples),"nativeInternalSamplesSeconds",internalSamples,"nativeInternalMedianSeconds",median(internalSamples,"omitnan"),"boundaryResidualMedianSeconds",median(totalSamples-internalSamples,"omitnan"),"relativeError",relativeError,"correctnessPassed",relativeError<=1e-12,"ledger",ledger,"metrics",metrics,"stageMetrics",stageMetrics,"metadata",metadata,"rss",emptyCaseRSS(config.samplingIntervalSeconds),"lifecyclePassed",lifecyclePassed,"status",conditional(lifecyclePassed&&relativeError<=1e-12,"complete","failed")); %#ok<AGROW>
        pause(max(0.05,2*config.samplingIntervalSeconds));
    end
    writePhase(phasePath,"module-clear"); clearSeconds = NaN;
    if string(config.implementation) ~= "matlab", clearTimer = tic; eval("clear "+string(config.module)); clearSeconds = toc(clearTimer); end
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds); rss = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    for iCase = 1:numel(caseResults), caseResults(iCase).rss = caseRSS(rss,string(caseResults(iCase).id),config.samplingIntervalSeconds); end
    result = struct("schemaVersion","1.0.0","status",conditional(all(string({caseResults.status})=="complete"),"complete","failed"),"implementation",string(config.implementation),"sourceCommit",string(config.sourceCommit),"repeatIndex",config.repeatIndex,"module",string(config.module),"moduleInfo",moduleInfo,"cases",caseResults,"rss",rss,"moduleClearSeconds",clearSeconds,"failure",emptyFailure());
catch exception
    if ~isempty(handle)
        try
            feval(config.module,'delete',handle);
        catch
        end
    end
    if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
    stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true)); clear temporaryCleanup stateCleanup
end

function [totalSeconds,internalSeconds,outputs] = executeTimed(implementation,module,handle,wvt)
outputs = cell(1,3); timer = tic;
if string(implementation) == "matlab"
    [outputs{:}] = wvt.nonlinearFlux(); internalSeconds = NaN;
else
    [outputs{:},internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
end
totalSeconds = toc(timer);
end

function [ledger,metrics,metadata] = implementationMetadata(config,wvt,handle,moduleInfo)
spectralOutputBytes = 3*16*wvt.Nj*wvt.Nkl;
if string(config.implementation) == "matlab"
    transformLedger = wvt.transformStorageLedger();
    persistentFullHermitianBytes = sum([transformLedger.entries(string({transformLedger.entries.identifier})=="horizontal.fullSpectrumBuffer").bytes]);
    ledger = struct("comparisonScope","shared canonical input excluded; three flux outputs included","knownPersistentBytes",transformLedger.knownPersistentBytes,"backendMaximumLiveBytes",transformLedger.knownMaximumLiveBytes,"fluxOutputBytes",spectralOutputBytes,"comparableMaximumLiveBytes",transformLedger.knownMaximumLiveBytes+spectralOutputBytes,"opaqueMemory","MATLAB FFT workspace reported only through RSS","persistentFullHermitianBytes",persistentFullHermitianBytes);
    metrics = struct(); metadata = struct("activeImplementation","matlab","engine","matlab-builtin","loadedBaseLibrary","MATLAB managed","loadedThreadLibrary","MATLAB managed","fallback",false,"threadCount",NaN);
else
    metrics = feval(config.module,'metrics',handle);
    ledger = struct("comparisonScope","shared canonical input excluded; three flux outputs included","knownPersistentBytes",metrics.persistentBytes,"backendMaximumLiveBytes",metrics.persistentBytes,"fluxOutputBytes",spectralOutputBytes,"comparableMaximumLiveBytes",metrics.persistentBytes+spectralOutputBytes,"opaqueMemory","FFTW plan-owned memory reported only through RSS","persistentFullHermitianBytes",metrics.persistentFullHermitianBytes);
    metadata = struct("activeImplementation",string(config.implementation),"engine",string(metrics.engine),"loadedBaseLibrary",string(moduleInfo.baseLibrary),"loadedThreadLibrary",string(moduleInfo.threadLibrary),"fallback",false,"threadCount",config.threadCount,"schedule",string(metrics.nonlinearFluxSchedule),"contractVersion",metrics.contractVersion);
end
end

function validateModuleInfo(info,config)
if string(info.baseLibrary) ~= string(config.baseLibrary), error("WaveVortexModel:AssemblyBaseLibraryIdentity","%s resolved FFTW to %s.",config.implementation,info.baseLibrary); end
if string(info.threadLibrary) ~= string(config.threadLibrary), error("WaveVortexModel:AssemblyThreadLibraryIdentity","%s resolved FFTW threads to %s.",config.implementation,info.threadLibrary); end
if config.moduleUsesOpenMP, error("WaveVortexModel:AssemblyUnexpectedOpenMP","The %s MEX module links an OpenMP runtime.",config.implementation); end
if startsWith(string(info.baseLibrary),string(matlabroot)), error("WaveVortexModel:AssemblyBundledFFTW","%s resolved MATLAB's bundled FFTW.",config.implementation); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,moduleDirectory)
addpath(repositoryRoot,benchmarkFolder); if string(moduleDirectory) ~= "", addpath(moduleDirectory); end
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function sampler = startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler = emptySampler(interval); if ~(ismac||isunix)||~isfile(samplerPath), sampler.reason="External RSS sampler unavailable."; return, end
command = sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output] = system(command); samplerPid = str2double(strtrim(output)); if status~=0||~isfinite(samplerPid), sampler.reason="Unable to launch RSS sampler."; return, end
sampler.status="running"; sampler.processId=samplerPid; sampler.provider=conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler = stopSampler(sampler,stopPath,interval)
if sampler.status~="running", return, end; writeText(stopPath,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',sampler.processId)); sampler.status="complete";
end

function rss = samplerResult(sampler,samplePath,interval)
rss = struct("status",sampler.status,"provider",sampler.provider,"reason",sampler.reason,"samplingIntervalSeconds",interval,"samples",[]);
if sampler.status~="complete"||~isfile(samplePath), return, end
lines=splitlines(strtrim(string(fileread(samplePath)))); samples=repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine=1:numel(lines), fields=split(lines(iLine),sprintf('\t')); index=str2double(fields(1)); samples(iLine)=struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3))); end
rss.samples=samples;
end

function value = caseRSS(rss,caseId,interval)
value = emptyCaseRSS(interval); value.status=rss.status; value.provider=rss.provider; if rss.status~="complete"||isempty(rss.samples), return, end
phases=string({rss.samples.phase}); bytes=[rss.samples.rssBytes]; baseline=bytes(phases==caseId+"-baseline"); persistentValues=bytes(phases==caseId+"-persistent"); nonlinearValues=bytes(phases==caseId+"-nonlinearFlux");
if isempty(baseline)||isempty(persistentValues)||isempty(nonlinearValues), value.status="unsupported"; return, end
value.baselineBytes=median(baseline); value.persistentBytes=median(persistentValues); value.peakBytes=max(nonlinearValues); value.persistentIncrementBytes=value.persistentBytes-value.baselineBytes; value.peakIncrementBytes=value.peakBytes-value.baselineBytes;
end

function writePhase(pathname,phase)
temporary=pathname+".tmp"; writeText(temporary,phase); movefile(temporary,pathname,"f");
end
function writeText(pathname,contents)
fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end; cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end
function deleteTemporaryFiles(varargin)
for iFile=1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end
function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end
function value=conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end
function value=emptySampler(interval)
value=struct("status","unsupported","provider","","reason","","processId",NaN,"samplingIntervalSeconds",interval);
end
function value=emptyCaseRSS(interval)
value=struct("status","unsupported","provider","","samplingIntervalSeconds",interval,"baselineBytes",NaN,"persistentBytes",NaN,"peakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
end
function value=emptyFailure
value=struct("identifier","","message","","report","");
end
function value=emptyCase
value=struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",NaN,"warmupCount",0,"sampleCount",0,"constructionSeconds",NaN,"planningSeconds",NaN,"firstCall",struct(),"completeMexSamplesSeconds",[],"completeMexMedianSeconds",NaN,"nativeInternalSamplesSeconds",[],"nativeInternalMedianSeconds",NaN,"boundaryResidualMedianSeconds",NaN,"relativeError",NaN,"correctnessPassed",false,"ledger",struct(),"metrics",struct(),"stageMetrics",struct(),"metadata",struct(),"rss",struct(),"lifecyclePassed",false,"status","failed");
end
function value=emptyResult(config)
value=struct("schemaVersion","1.0.0","status","failed","implementation",string(config.implementation),"sourceCommit",string(config.sourceCommit),"repeatIndex",config.repeatIndex,"module",string(config.module),"moduleInfo",struct(),"cases",repmat(emptyCase,0,1),"rss",struct(),"moduleClearSeconds",NaN,"failure",emptyFailure);
end
