function compiledKernelMemoryReassessmentWorker(configPath,outputPath)
% Run one corrected issue #131 memory path in a fresh MATLAB process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase"; stopPath = string(tempname)+".stop"; samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler(config.samplingIntervalSeconds); handle = []; wvt = [];
result = emptyResult(config);
try
    path(config.matlabPath); addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,config.moduleDirectory);
    writePhase(phasePath,"startup");
    sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds);
    pause(config.plateauSeconds);

    definition = config.caseDefinition; rng(definition.seed,"twister");
    writePhase(phasePath,"common-model-construction");
    wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
    state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
    advanceWaveVortexBenchmarkState(wvt,state,0);
    writePhase(phasePath,"common-model-baseline"); drawnow; pause(config.plateauSeconds);

    moduleInfo = struct(); moduleBefore = struct(); planningSeconds = NaN;
    writePhase(phasePath,"backend-construction");
    if string(config.implementation) == "compiled"
        moduleInfo = feval(config.module,'moduleInfo'); validateModuleInfo(moduleInfo,config);
        moduleBefore = feval(config.module,'moduleMetrics'); timer = tic;
        handle = feval(config.module,'create',kernelConfiguration(wvt),config.threadCount);
        planningSeconds = toc(timer);
    end
    writePhase(phasePath,"backend-created"); drawnow; pause(config.plateauSeconds);

    for iWarmup = 1:definition.warmupCount
        advanceWaveVortexBenchmarkState(wvt,state,iWarmup);
        writePhase(phasePath,"warmup"); execute(config,wvt,handle);
    end
    writePhase(phasePath,"steady-retained"); drawnow; pause(config.plateauSeconds);

    outputs = cell(1,3);
    for iSample = 1:definition.sampleCount
        advanceWaveVortexBenchmarkState(wvt,state,definition.warmupCount+iSample);
        writePhase(phasePath,"operation"); outputs = execute(config,wvt,handle);
        writePhase(phasePath,"outputs-held"); drawnow; pause(config.outputHoldSeconds);
        if iSample < definition.sampleCount
            clear outputs; writePhase(phasePath,"outputs-cleared"); drawnow; pause(config.samplingIntervalSeconds);
        end
    end
    ledger = retainedLedger(config,wvt,handle,outputs);
    metrics = struct(); metadata = struct("activeImplementation","matlab","engine","matlab-builtin","fallback",false,"threadCount",NaN);
    if string(config.implementation) == "compiled"
        metrics = feval(config.module,'metrics',handle);
        metadata = struct("activeImplementation","compiled","engine",string(metrics.engine),"loadedBaseLibrary",string(moduleInfo.baseLibrary),"loadedThreadLibrary",string(moduleInfo.threadLibrary),"fallback",false,"threadCount",config.threadCount,"schedule",string(metrics.nonlinearFluxSchedule),"contractVersion",metrics.contractVersion);
    end
    clear outputs
    writePhase(phasePath,"outputs-cleared"); drawnow; pause(config.plateauSeconds);

    lifecyclePassed = true; moduleAfterDelete = struct();
    writePhase(phasePath,"backend-destruction");
    if ~isempty(handle)
        feval(config.module,'delete',handle); handle = [];
        moduleAfterDelete = feval(config.module,'moduleMetrics');
        lifecyclePassed = moduleAfterDelete.kernelCount == moduleBefore.kernelCount && moduleAfterDelete.activePlans == moduleBefore.activePlans && moduleAfterDelete.outstandingPlanningBytes == 0 && moduleAfterDelete.totalPlansCreated-moduleAfterDelete.totalPlansDestroyed == moduleAfterDelete.activePlans;
    end
    writePhase(phasePath,"backend-destroyed"); drawnow; pause(config.plateauSeconds);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    rssSamples = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    rss = phaseRSS(rssSamples,config.samplingIntervalSeconds);
    result = struct("schemaVersion","1.0.0","status",conditional(lifecyclePassed&&rss.status=="complete","complete","failed"),"implementation",string(config.implementation),"sourceCommit",string(config.sourceCommit),"repeatIndex",config.repeatIndex,"case",definition,"module",string(config.module),"moduleInfo",moduleInfo,"planningSeconds",planningSeconds,"referenceCallCount",0,"sampledOperation",conditional(string(config.implementation)=="compiled","compiled nonlinearFlux only","MATLAB nonlinearFlux only"),"ledger",ledger,"metrics",metrics,"metadata",metadata,"rss",rss,"rssSamples",rssSamples,"lifecyclePassed",lifecyclePassed,"moduleAfterDelete",moduleAfterDelete,"failure",emptyFailure);
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

function outputs = execute(config,wvt,handle)
outputs = cell(1,3);
if string(config.implementation) == "matlab"
    [outputs{:}] = wvt.nonlinearFlux();
else
    [outputs{:}] = feval(config.module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
end
end

function ledger = retainedLedger(config,wvt,handle,outputs)
if string(config.implementation) == "matlab"
    ledger = compiledKernelMatlabRetainedLedger(wvt,outputs);
    return
end
metrics = feval(config.module,'metrics',handle); outputBytes = 0; outputEntries = repmat(struct("name","","className","","shape",[],"bytes",0),3,1); names = ["Fp" "Fm" "F0"];
for iOutput = 1:3
    value = outputs{iOutput}; info = whos("value"); outputBytes = outputBytes+info.bytes;
    outputEntries(iOutput) = struct("name",names(iOutput),"className",string(class(value)),"shape",double(size(value)),"bytes",double(info.bytes));
end
ledger = struct("schemaVersion","issue131-retained-memory-v1","scope","C++ descriptor, bounded scratch, plan-wrapper lower bound, and three returned flux arrays; shared canonical state and inactive MATLAB transform storage excluded","descriptorBytes",metrics.descriptorBytes,"scratchBytes",metrics.scratchCapacityBytes,"planWrapperLowerBoundBytes",metrics.planBytes,"outputRetainedBytes",double(outputBytes),"exactRetainedApplicationBytes",double(metrics.persistentBytes+outputBytes),"outputEntries",outputEntries,"opaqueMemory","FFTW plan-owned allocations and MATLAB allocator behavior are represented only by isolated RSS");
end

function validateModuleInfo(info,config)
if string(info.baseLibrary) ~= string(config.baseLibrary), error("WaveVortexModel:MemoryBaseLibraryIdentity","Compiled memory worker resolved FFTW to %s.",info.baseLibrary); end
if string(info.threadLibrary) ~= string(config.threadLibrary), error("WaveVortexModel:MemoryThreadLibraryIdentity","Compiled memory worker resolved FFTW threads to %s.",info.threadLibrary); end
if config.moduleUsesOpenMP, error("WaveVortexModel:MemoryUnexpectedOpenMP","The corrected memory MEX module links an OpenMP runtime."); end
if startsWith(string(info.baseLibrary),string(matlabroot)), error("WaveVortexModel:MemoryBundledFFTW","The corrected memory worker resolved MATLAB's bundled FFTW."); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = phaseRSS(rss,interval)
value = struct("status",rss.status,"provider",rss.provider,"samplingIntervalSeconds",interval,"commonModelBaselineBytes",NaN,"backendCreatedBytes",NaN,"steadyRetainedBytes",NaN,"operationPeakBytes",NaN,"operationPeakIncrementBytes",NaN,"outputsClearedBytes",NaN,"backendDestroyedBytes",NaN,"constructionPeakBytes",NaN);
if rss.status ~= "complete" || isempty(rss.samples), return, end
phases = string({rss.samples.phase}); bytes = [rss.samples.rssBytes];
baseline = bytes(phases=="common-model-baseline"); backend = bytes(phases=="backend-created"); retained = bytes(phases=="steady-retained"); operation = bytes(phases=="operation" | phases=="outputs-held"); cleared = bytes(phases=="outputs-cleared"); destroyed = bytes(phases=="backend-destroyed"); construction = bytes(phases=="backend-construction");
if isempty(baseline)||isempty(backend)||isempty(retained)||isempty(operation)||isempty(cleared)||isempty(destroyed), value.status="unsupported"; return, end
value.commonModelBaselineBytes=median(baseline); value.backendCreatedBytes=median(backend); value.steadyRetainedBytes=median(retained); value.operationPeakBytes=max(operation); value.operationPeakIncrementBytes=max(0,value.operationPeakBytes-value.commonModelBaselineBytes); value.outputsClearedBytes=median(cleared); value.backendDestroyedBytes=median(destroyed); if ~isempty(construction), value.constructionPeakBytes=max(construction); end
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,moduleDirectory)
addpath(repositoryRoot,benchmarkFolder); if string(moduleDirectory) ~= "", addpath(moduleDirectory); end
metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function sampler = startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler=emptySampler(interval); if ~(ismac||isunix)||~isfile(samplerPath), sampler.reason="External RSS sampler unavailable."; return, end
command=sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output]=system(command); samplerPid=str2double(strtrim(output)); if status~=0||~isfinite(samplerPid), sampler.reason="Unable to launch RSS sampler."; return, end
sampler.status="running"; sampler.processId=samplerPid; sampler.provider=conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler = stopSampler(sampler,stopPath,interval)
if sampler.status~="running", return, end; writeText(stopPath,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',sampler.processId)); sampler.status="complete";
end

function rss = samplerResult(sampler,samplePath,interval)
rss=struct("status",sampler.status,"provider",sampler.provider,"reason",sampler.reason,"samplingIntervalSeconds",interval,"samples",[]); if sampler.status~="complete"||~isfile(samplePath), return, end
lines=splitlines(strtrim(string(fileread(samplePath)))); samples=repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine=1:numel(lines), fields=split(lines(iLine),sprintf('\t')); index=str2double(fields(1)); samples(iLine)=struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3))); end
rss.samples=samples;
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
function value=emptyFailure
value=struct("identifier","","message","","report","");
end
function value=emptyResult(config)
value=struct("schemaVersion","1.0.0","status","failed","implementation",string(config.implementation),"sourceCommit",string(config.sourceCommit),"repeatIndex",config.repeatIndex,"case",config.caseDefinition,"module",string(config.module),"moduleInfo",struct(),"planningSeconds",NaN,"referenceCallCount",0,"sampledOperation","","ledger",struct(),"metrics",struct(),"metadata",struct(),"rss",struct(),"rssSamples",struct(),"lifecyclePassed",false,"moduleAfterDelete",struct(),"failure",emptyFailure);
end
