function compiledKernelIssue128Worker(configPath,outputPath)
% Run one issue #128 control or FFTW++ candidate in a fresh MATLAB process.
config = jsondecode(fileread(configPath));
phasePath = string(tempname)+".phase"; stopPath = string(tempname)+".stop"; samplePath = string(tempname)+".rss";
cleanup = onCleanup(@()deleteFiles(phasePath,stopPath,samplePath));
result = struct("status","failed","configurationId",string(config.configurationId),"processIndex",config.processIndex,"threadCount",config.threadCount,"moduleInfo",struct(),"cases",struct([]),"rss",struct(),"failure",struct());
handle = []; wvt = [];
try
    path(config.matlabPath); addPaths(config.repositoryRoot,config.mexDirectory);
    writeText(phasePath,"startup"); samplerPid = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds); pause(config.plateauSeconds);
    writeText(phasePath,"provider-load");
    if string(config.runtimeLibrary) == "", info = feval(config.module,'moduleInfo'); else, info = feval(config.module,'moduleInfo',char(config.runtimeLibrary)); end
    result.moduleInfo = info; pause(config.plateauSeconds);
    cases = repmat(emptyCase,0,1);
    for iCase = 1:numel(config.cases)
        definition = config.cases(iCase); prefix = string(definition.id);
        rng(definition.seed,"twister"); writeText(phasePath,prefix+"-construction");
        constructTimer = tic;
        wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=true);
        state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
        moduleBefore = feval(config.module,'moduleMetrics');
        if string(config.creationMode) == "convolution"
            handle = feval(config.module,'createConvolution',kernelConfiguration(wvt),config.threadCount,char(config.variant));
        else
            handle = feval(config.module,'create',kernelConfiguration(wvt),config.threadCount);
        end
        feval(config.module,'setStageInstrumentation',handle,true);
        moduleAfterCreate = feval(config.module,'moduleMetrics'); constructionSeconds = toc(constructTimer);
        [firstTotal,firstInternal] = executeTimed(config.module,handle,wvt);
        for iWarmup = 1:definition.warmupCount
            advanceWaveVortexBenchmarkState(wvt,state,iWarmup); executeTimed(config.module,handle,wvt);
        end
        writeText(phasePath,prefix+"-persistent"); pause(config.plateauSeconds);
        total = NaN(1,definition.sampleCount); internal = total;
        writeText(phasePath,prefix+"-operations");
        for iSample = 1:definition.sampleCount
            advanceWaveVortexBenchmarkState(wvt,state,definition.warmupCount+iSample);
            [total(iSample),internal(iSample)] = executeTimed(config.module,handle,wvt);
        end
        [actualFp,actualFm,actualF0] = feval(config.module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
        [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
        maximumRelativeError = max([relativeError(actualFp,expectedFp) relativeError(actualFm,expectedFm) relativeError(actualF0,expectedF0)]);
        metrics = feval(config.module,'metrics',handle);
        writeText(phasePath,prefix+"-cleanup"); feval(config.module,'delete',handle); handle = []; delete(wvt); wvt = [];
        moduleAfterDelete = feval(config.module,'moduleMetrics');
        lifecyclePassed = moduleAfterDelete.kernelCount == moduleBefore.kernelCount && moduleAfterDelete.activePlans == moduleBefore.activePlans && moduleAfterDelete.outstandingPlanningBytes == 0 && moduleAfterDelete.totalPlansCreated-moduleAfterDelete.totalPlansDestroyed == moduleAfterDelete.activePlans;
        planningSeconds = moduleAfterCreate.totalPlanningSeconds-moduleBefore.totalPlanningSeconds;
        cases(end+1,1) = struct("id",prefix,"Nxyz",definition.Nxyz,"isHydrostatic",logical(definition.isHydrostatic),"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"constructionSeconds",constructionSeconds,"planningSeconds",planningSeconds,"firstTotalSeconds",firstTotal,"firstInternalSeconds",firstInternal,"totalSamplesSeconds",total,"internalSamplesSeconds",internal,"totalMedianSeconds",median(total),"internalMedianSeconds",median(internal),"maximumRelativeError",maximumRelativeError,"lifecyclePassed",lifecyclePassed,"metrics",metrics,"rss",struct()); %#ok<AGROW>
    end
    writeText(phasePath,"module-clear"); eval("clear "+string(config.module)); pause(config.plateauSeconds);
    stopSampler(samplerPid,stopPath,config.samplingIntervalSeconds); rss = readRSS(samplePath,config.samplingIntervalSeconds);
    for iCase = 1:numel(cases), cases(iCase).rss = caseRSS(rss,string(cases(iCase).id)); end
    result.status = conditional(all([cases.lifecyclePassed]) && max([cases.maximumRelativeError]) <= 1e-12,"complete","failed"); result.cases = cases; result.rss = rss;
catch exception
    if ~isempty(handle)
        try
            feval(config.module,'delete',handle);
        catch
        end
    end
    if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true)); clear cleanup
end

function value = emptyCase
value = struct("id","","Nxyz",[],"isHydrostatic",false,"seed",0,"warmupCount",0,"sampleCount",0,"constructionSeconds",NaN,"planningSeconds",NaN,"firstTotalSeconds",NaN,"firstInternalSeconds",NaN,"totalSamplesSeconds",[],"internalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalMedianSeconds",NaN,"maximumRelativeError",NaN,"lifecyclePassed",false,"metrics",struct(),"rss",struct());
end

function [total,internal] = executeTimed(module,handle,wvt)
timer = tic; [Fp,Fm,F0,internal] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); total = toc(timer); %#ok<ASGLU>
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],"omitmissing")/max(max(abs(expected(:)),[],"omitmissing"),realmin);
end

function addPaths(repositoryRoot,mexDirectory)
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"),mexDirectory); metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function pid = startSampler(script,phase,stop,samples,interval)
command = sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',script,matlabProcessID,phase,stop,samples,interval);
[status,output] = system(command); pid = str2double(strtrim(output)); if status ~= 0 || ~isfinite(pid), pid = NaN; end
end

function stopSampler(pid,stop,interval)
if ~isfinite(pid), return, end
writeText(stop,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',pid));
end

function rss = readRSS(pathname,interval)
rss = struct("status","unsupported","samplingIntervalSeconds",interval,"samples",struct([])); if ~isfile(pathname), return, end
lines = splitlines(strtrim(string(fileread(pathname)))); samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines), fields = split(lines(iLine),sprintf('\t')); index = str2double(fields(1)); samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3))); end
rss.status = "complete"; rss.samples = samples;
end

function value = caseRSS(rss,id)
value = struct("status",rss.status,"baselineBytes",NaN,"persistentBytes",NaN,"peakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
if rss.status ~= "complete", return, end
phases = string({rss.samples.phase}); bytes = [rss.samples.rssBytes]; baseline = bytes(phases==id+"-construction"); persistentSamples = bytes(phases==id+"-persistent"); operations = bytes(phases==id+"-operations");
if isempty(baseline) || isempty(persistentSamples) || isempty(operations), value.status = "unsupported"; return, end
value.baselineBytes = min(baseline); value.persistentBytes = median(persistentSamples); value.peakBytes = max(operations); value.persistentIncrementBytes = value.persistentBytes-value.baselineBytes; value.peakIncrementBytes = value.peakBytes-value.baselineBytes;
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:Issue128Artifact","Unable to write %s.",pathname); end
fileCleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear fileCleanup
end

function deleteFiles(varargin)
for value = string(varargin), if isfile(value), delete(value); end, end
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
