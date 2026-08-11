function compiledKernelReadinessWorker(configPath,outputPath)
% Benchmark one implementation and core-v1 case in a fresh MATLAB process.
config=jsondecode(fileread(configPath)); originalDirectory=pwd; originalPath=path; originalRng=rng;
stateCleanup=onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath=string(tempname)+".phase"; stopPath=string(tempname)+".stop"; samplePath=string(tempname)+".rss"; temporaryCleanup=onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler=emptySampler(config.samplingIntervalSeconds); result=emptyResult(config.implementation,config.samplingIntervalSeconds); handle=[]; wvt=[];
try
    path(config.matlabPath); addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,config.buildDirectory);
    writePhase(phasePath,"baseline"); sampler=startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds); pause(config.plateauSeconds);
    writePhase(phasePath,"construction"); constructionTimer=tic; wvt=createWaveVortexBenchmarkTransform(config.benchmarkCase,"builtin"); state=initializeWaveVortexBenchmarkState(wvt,config.benchmarkCase.seed);
    moduleBefore=struct();
    if string(config.implementation)=="compiled", moduleBefore=wv_compiled_transform_mex('moduleMetrics'); handle=wv_compiled_transform_mex('create',kernelConfiguration(wvt),config.threadCount); end
    constructionSeconds=toc(constructionTimer);
    advanceWaveVortexBenchmarkState(wvt,state,0); firstTimer=tic; firstOutputs=executeOperation(config.implementation,wvt,handle); %#ok<NASGU>
    firstCallSeconds=toc(firstTimer); clear firstOutputs
    for iWarmup=1:config.benchmarkCase.warmupCount
        advanceWaveVortexBenchmarkState(wvt,state,iWarmup); outputs=executeOperation(config.implementation,wvt,handle); %#ok<NASGU>
        clear outputs
    end
    if string(config.implementation)=="compiled"
        wv_compiled_transform_mex('setStageInstrumentation',handle,true);
        diagnosticOutputs=executeOperation(config.implementation,wvt,handle); %#ok<NASGU>
        clear diagnosticOutputs
        wv_compiled_transform_mex('setStageInstrumentation',handle,false);
    end
    writePhase(phasePath,"persistent"); [ledger,metrics,metadata]=implementationMetadata(config.implementation,wvt,handle); drawnow; pause(config.plateauSeconds);
    metadata.variantIdentifier=string(config.variantIdentifier); metadata.requestedPhaseImplementation=string(config.phaseImplementation); metadata.requestedModalCoefficientMode=string(config.modalCoefficientMode); metadata.requestedOptimizationLevel=string(config.optimizationLevel); metadata.requestedModalWorkerCount=config.modalWorkerCount;
    rawSeconds=NaN(1,config.benchmarkCase.sampleCount); finalOutputs=[];
    for iSample=1:config.benchmarkCase.sampleCount
        advanceWaveVortexBenchmarkState(wvt,state,config.benchmarkCase.warmupCount+iSample); writePhase(phasePath,"nonlinearFlux"); timer=tic; finalOutputs=executeOperation(config.implementation,wvt,handle); rawSeconds(iSample)=toc(timer);
    end
    if string(config.implementation)=="compiled", expected=cell(1,3); [expected{:}]=wvt.nonlinearFlux(); relativeError=waveVortexBenchmarkRelativeError(expected,finalOutputs); else, relativeError=0; end
    drawnow; pause(max(0.03,3*config.samplingIntervalSeconds)); clear finalOutputs
    writePhase(phasePath,"cleanup"); moduleAfter=struct();
    if ~isempty(handle), wv_compiled_transform_mex('delete',handle); handle=[]; moduleAfter=wv_compiled_transform_mex('moduleMetrics'); end
    delete(wvt); wvt=[]; pause(max(0.05,2*config.samplingIntervalSeconds)); sampler=stopSampler(sampler,stopPath,config.samplingIntervalSeconds); rss=samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    lifecyclePassed=true;
    if string(config.implementation)=="compiled", lifecyclePassed=moduleAfter.kernelCount==moduleBefore.kernelCount&&moduleAfter.activePlans==moduleBefore.activePlans&&moduleAfter.outstandingPlanningBytes==0&&moduleAfter.totalPlansCreated-moduleAfter.totalPlansDestroyed==moduleAfter.activePlans; end
    result=struct("status",conditional(lifecyclePassed&&relativeError<=1e-12,"complete","failed"),"implementation",string(config.implementation),"constructionSeconds",constructionSeconds,"firstCallSeconds",firstCallSeconds,"rawSeconds",rawSeconds,"medianSeconds",median(rawSeconds),"relativeError",relativeError,"correctnessPassed",relativeError<=1e-12,"ledger",ledger,"rss",rss,"metrics",metrics,"metadata",metadata,"lifecyclePassed",lifecyclePassed,"failure",emptyFailure());
catch exception
    if ~isempty(handle)
        try
            wv_compiled_transform_mex('delete',handle);
        catch
        end
    end
    if ~isempty(wvt)&&isvalid(wvt), delete(wvt); end
    stopSampler(sampler,stopPath,config.samplingIntervalSeconds); result.failure=struct("identifier",string(exception.identifier),"message",string(exception.message));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true)); clear temporaryCleanup stateCleanup
end

function outputs=executeOperation(implementation,wvt,handle)
outputs=cell(1,3); if string(implementation)=="compiled", [outputs{:}]=wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); else, [outputs{:}]=wvt.nonlinearFlux(); end
end

function [ledger,metrics,metadata]=implementationMetadata(implementation,wvt,handle)
if string(implementation)=="compiled"
    metrics=wv_compiled_transform_mex('metrics',handle); ledger=struct("knownPersistentBytes",metrics.persistentBytes,"knownMaximumLiveBytes",metrics.knownMaximumLiveOwnedBytes,"descriptorBytes",metrics.descriptorBytes,"halfSpectrumScratchBytes",metrics.halfSpectrumScratchCapacityBytes,"realScratchBytes",metrics.realScratchCapacityBytes,"planWrapperLowerBoundBytes",metrics.planBytes,"opaquePlanMemory","reported through RSS","persistentFullHermitianBytes",metrics.persistentFullHermitianBytes,"gradientMaskBytes",metrics.gradientMaskBytes); metadata=struct("activeImplementation","compiled","engine",string(metrics.engine),"loadedLibrary",string(metrics.loadedLibrary),"schedule",string(metrics.nonlinearFluxSchedule),"phaseImplementation",string(metrics.phaseImplementation),"modalCoefficientMode",string(metrics.modalCoefficientMode),"optimizationImplementation",string(metrics.optimizationImplementation),"modalWorkerCount",metrics.modalWorkerCount,"contractVersion",metrics.contractVersion,"fallback",false);
else
    ledger=wvt.transformStorageLedger(); metrics=struct(); metadata=struct("activeImplementation","builtin","engine","matlab-builtin","loadedLibrary","MATLAB managed","schedule","MATLAB ordinary nonlinearFlux","contractVersion",NaN,"fallback",false);
end
end

function configuration=kernelConfiguration(wvt)
configuration=struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,buildDirectory)
addpath(repositoryRoot,benchmarkFolder,buildDirectory); metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json"))); for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function sampler=startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler=emptySampler(interval); if ~(ismac||isunix)||~isfile(samplerPath), sampler.reason="External RSS sampler unavailable."; return, end
command=sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval); [status,output]=system(command); samplerPid=str2double(strtrim(output)); if status~=0||~isfinite(samplerPid), sampler.reason="Unable to launch RSS sampler."; return, end; sampler.status="running"; sampler.processId=samplerPid; sampler.provider=conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler=stopSampler(sampler,stopPath,interval)
if sampler.status~="running", return, end; writeText(stopPath,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',sampler.processId)); sampler.status="complete";
end

function rss=samplerResult(sampler,samplePath,interval)
rss=emptyRSS(interval); rss.status=sampler.status; rss.provider=sampler.provider; rss.reason=sampler.reason; if sampler.status~="complete"||~isfile(samplePath), return, end
lines=splitlines(strtrim(string(fileread(samplePath)))); samples=repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1); for iLine=1:numel(lines), fields=split(lines(iLine),sprintf('\t')); index=str2double(fields(1)); rssKiB=str2double(fields(3)); samples(iLine)=struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*rssKiB); end
rss.samples=samples; baseline=[samples(string({samples.phase})=="baseline").rssBytes]; persistentValues=[samples(string({samples.phase})=="persistent").rssBytes]; nonlinear=[samples(string({samples.phase})=="nonlinearFlux").rssBytes]; if isempty(baseline)||isempty(persistentValues)||isempty(nonlinear), rss.status="unsupported"; rss.reason="Required RSS phases were not sampled."; return, end; rss.baselineMedianBytes=median(baseline); rss.persistentMedianBytes=median(persistentValues); rss.nonlinearFluxPeakBytes=max(nonlinear); rss.persistentIncrementBytes=rss.persistentMedianBytes-rss.baselineMedianBytes; rss.peakIncrementBytes=rss.nonlinearFluxPeakBytes-rss.baselineMedianBytes;
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
function value=emptyRSS(interval)
value=struct("status","unsupported","provider","","reason","","samplingIntervalSeconds",interval,"samples",[],"baselineMedianBytes",NaN,"persistentMedianBytes",NaN,"nonlinearFluxPeakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
end
function value=emptyFailure()
value=struct("identifier","","message","");
end
function value=emptyResult(implementation,interval)
value=struct("status","failed","implementation",string(implementation),"constructionSeconds",NaN,"firstCallSeconds",NaN,"rawSeconds",[],"medianSeconds",NaN,"relativeError",NaN,"correctnessPassed",false,"ledger",struct(),"rss",emptyRSS(interval),"metrics",struct(),"metadata",struct(),"lifecyclePassed",false,"failure",emptyFailure());
end
