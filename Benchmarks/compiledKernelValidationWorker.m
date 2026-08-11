function compiledKernelValidationWorker(configPath,outputPath)
% Measure one compiled-kernel lifecycle in a fresh MATLAB process.
config=jsondecode(fileread(configPath));
originalDirectory=pwd; originalPath=path; originalRng=rng;
stateCleanup=onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath=string(tempname)+".phase"; stopPath=string(tempname)+".stop"; samplePath=string(tempname)+".rss";
temporaryCleanup=onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler=emptySampler(config.samplingIntervalSeconds);
result=emptyResult(config.samplingIntervalSeconds);
handle=[]; wvt=[];
try
    path(config.matlabPath); addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,config.buildDirectory);
    writePhase(phasePath,"baseline"); sampler=startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds); pause(config.plateauSeconds);
    writePhase(phasePath,"construction");
    definition=config.definition; rng(definition.seed,"twister");
    wvt=WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
    wvt.initWithRandomFlow(uvMax=0.01); wvt.t=90;
    moduleBefore=wv_compiled_transform_mex('moduleMetrics');
    handle=wv_compiled_transform_mex('create',kernelConfiguration(wvt),config.threadCount);
    for iWarmup=1:config.warmupCount
        writePhase(phasePath,"warmup");
        [Fp,Fm,F0]=wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); %#ok<ASGLU>
        clear Fp Fm F0
    end
    writePhase(phasePath,"persistent"); metrics=wv_compiled_transform_mex('metrics',handle); drawnow; pause(config.plateauSeconds);
    writePhase(phasePath,"nonlinearFlux");
    [Fp,Fm,F0]=wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); %#ok<ASGLU>
    drawnow; pause(max(0.03,3*config.samplingIntervalSeconds)); clear Fp Fm F0
    writePhase(phasePath,"cleanup"); wv_compiled_transform_mex('delete',handle); handle=[]; delete(wvt); wvt=[];
    moduleAfter=wv_compiled_transform_mex('moduleMetrics'); pause(max(0.05,2*config.samplingIntervalSeconds));
    sampler=stopSampler(sampler,stopPath,config.samplingIntervalSeconds); rss=samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    ledger=storageLedger(metrics);
    lifecyclePassed=moduleAfter.kernelCount==moduleBefore.kernelCount && moduleAfter.activePlans==moduleBefore.activePlans && moduleAfter.outstandingPlanningBytes==0 && moduleAfter.totalPlansCreated-moduleAfter.totalPlansDestroyed==moduleAfter.activePlans;
    result=struct("status",conditional(lifecyclePassed,"complete","failed"),"ledger",ledger,"rss",rss,"moduleBefore",moduleBefore,"moduleAfter",moduleAfter,"lifecyclePassed",lifecyclePassed,"failure",emptyFailure());
catch exception
    if ~isempty(handle)
        try
            wv_compiled_transform_mex('delete',handle);
        catch
        end
    end
    if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
    sampler=stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    result.failure=struct("identifier",string(exception.identifier),"message",string(exception.message));
    if isfile(samplePath)
        try
            result.rss=samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
        catch
        end
    end
end
writeText(outputPath,jsonencode(result,PrettyPrint=true)); clear temporaryCleanup stateCleanup
end

function ledger=storageLedger(metrics)
ledger=struct("knownPersistentBytes",metrics.persistentBytes,"knownMaximumLiveBytes",metrics.knownMaximumLiveOwnedBytes,"descriptorBytes",metrics.descriptorBytes,"halfSpectrumScratchBytes",metrics.halfSpectrumScratchCapacityBytes,"realScratchBytes",metrics.realScratchCapacityBytes,"planWrapperLowerBoundBytes",metrics.planBytes,"opaquePlanMemory","reported separately through process RSS","callerStateInputBytes",metrics.stateInputBytes,"matlabOwnedFluxOutputBytes",metrics.fluxOutputBytes,"persistentFullHermitianBytes",metrics.persistentFullHermitianBytes,"gradientMaskBytes",metrics.gradientMaskBytes);
end

function configuration=kernelConfiguration(wvt)
configuration=struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,buildDirectory)
addpath(repositoryRoot,benchmarkFolder,buildDirectory); metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function sampler=startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler=emptySampler(interval); if ~(ismac||isunix)||~isfile(samplerPath), sampler.reason="External RSS sampler unavailable."; return, end
command=sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output]=system(command); samplerPid=str2double(strtrim(output)); if status~=0||~isfinite(samplerPid), sampler.reason="Unable to launch RSS sampler."; return, end
sampler.status="running"; sampler.processId=samplerPid; sampler.provider=conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler=stopSampler(sampler,stopPath,interval)
if sampler.status~="running", return, end
writeText(stopPath,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',sampler.processId)); sampler.status="complete";
end

function rss=samplerResult(sampler,samplePath,interval)
rss=struct("status",sampler.status,"provider",sampler.provider,"reason",sampler.reason,"samplingIntervalSeconds",interval,"samples",[] ,"baselineMedianBytes",NaN,"persistentMedianBytes",NaN,"nonlinearFluxPeakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
if sampler.status~="complete"||~isfile(samplePath), return, end
lines=splitlines(strtrim(string(fileread(samplePath)))); samples=repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine=1:numel(lines), fields=split(lines(iLine),sprintf('\t')); index=str2double(fields(1)); rssKiB=str2double(fields(3)); samples(iLine)=struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*rssKiB); end
rss.samples=samples; baseline=[samples(string({samples.phase})=="baseline").rssBytes]; persistentValues=[samples(string({samples.phase})=="persistent").rssBytes]; nonlinear=[samples(string({samples.phase})=="nonlinearFlux").rssBytes];
if isempty(baseline)||isempty(persistentValues)||isempty(nonlinear), rss.status="unsupported"; rss.reason="Required RSS phases were not sampled."; return, end
rss.baselineMedianBytes=median(baseline); rss.persistentMedianBytes=median(persistentValues); rss.nonlinearFluxPeakBytes=max(nonlinear); rss.persistentIncrementBytes=rss.persistentMedianBytes-rss.baselineMedianBytes; rss.peakIncrementBytes=rss.nonlinearFluxPeakBytes-rss.baselineMedianBytes;
end

function writePhase(pathname,phase)
temporary=pathname+".tmp"; writeText(temporary,phase); movefile(temporary,pathname,"f");
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

function value=conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end

function value=emptySampler(interval)
value=struct("status","unsupported","provider","","reason","","processId",NaN,"samplingIntervalSeconds",interval);
end

function value=emptyFailure()
value=struct("identifier","","message","");
end

function value=emptyResult(interval)
value=struct("status","failed","ledger",struct(),"rss",struct("status","unsupported","provider","","reason","","samplingIntervalSeconds",interval,"samples",[],"baselineMedianBytes",NaN,"persistentMedianBytes",NaN,"nonlinearFluxPeakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN),"moduleBefore",struct(),"moduleAfter",struct(),"lifecyclePassed",false,"failure",emptyFailure());
end
