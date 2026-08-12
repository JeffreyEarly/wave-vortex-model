function compiledKernelIssue130Worker(configPath,outputPath)
% Run one issue #130 variant and case in a fresh MATLAB process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase"; stopPath = string(tempname)+".stop"; samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler(config.samplingIntervalSeconds);
result = emptyResult(config);
handle = []; wvt = [];
try
    path(config.matlabPath);
    addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,config.variant.mexDirectory);
    writePhase(phasePath,"startup");
    sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds);
    pause(config.plateauSeconds);

    module = string(config.variant.module);
    info = feval(module,'moduleInfo');
    validateIdentity(info,config);
    writePhase(phasePath,"provider-load"); pause(config.plateauSeconds);

    definition = config.caseDefinition;
    rng(definition.seed,'twister');
    wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
    state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
    moduleBefore = feval(module,'moduleMetrics');
    writePhase(phasePath,"construction");
    timer = tic; handle = feval(module,'create',kernelConfiguration(wvt),config.threadCount); constructionSeconds = toc(timer);
    moduleAfterCreate = feval(module,'moduleMetrics');

    diagnosticBefore = feval(module,'metrics',handle);
    feval(module,'setStageInstrumentation',handle,true);
    execute(module,handle,wvt);
    diagnosticAfter = feval(module,'metrics',handle);
    diagnosticMetrics = diagnosticRecord(diagnosticBefore,diagnosticAfter);
    feval(module,'setStageInstrumentation',handle,false);
    for iWarmup = 1:definition.warmupCount
        advanceWaveVortexBenchmarkState(wvt,state,iWarmup);
        execute(module,handle,wvt);
    end
    writePhase(phasePath,"persistent"); pause(config.plateauSeconds);

    totalSamples = NaN(1,definition.sampleCount); internalSamples = totalSamples;
    writePhase(phasePath,"operations");
    for iSample = 1:definition.sampleCount
        advanceWaveVortexBenchmarkState(wvt,state,definition.warmupCount+iSample);
        [~,~,~,internalSamples(iSample),totalSamples(iSample)] = execute(module,handle,wvt);
    end
    writePhase(phasePath,"correctness");
    [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
    [actualFp,actualFm,actualF0] = feval(module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
    errors = struct("Fp",relativeError(actualFp,expectedFp),"Fm",relativeError(actualFm,expectedFm),"F0",relativeError(actualF0,expectedF0));
    maximumRelativeError = max(cell2mat(struct2cell(errors)));
    metrics = feval(module,'metrics',handle);

    writePhase(phasePath,"cleanup");
    feval(module,'delete',handle); handle = [];
    moduleAfterDelete = feval(module,'moduleMetrics');
    lifecyclePassed = moduleAfterDelete.kernelCount == moduleBefore.kernelCount && moduleAfterDelete.activePlans == moduleBefore.activePlans && moduleAfterDelete.outstandingPlanningBytes == 0;
    delete(wvt); wvt = [];
    eval("clear "+module);
    writePhase(phasePath,"module-clear"); pause(config.plateauSeconds);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    rss = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);

    result = struct("schemaVersion","1.0.0","status",conditional(maximumRelativeError<=1e-12&&lifecyclePassed,"complete","failed"),"repeatIndex",config.repeatIndex,"variantId",string(config.variant.id),"caseId",string(definition.id),"providerId",string(config.providerId),"threadCount",config.threadCount,"moduleInfo",info,"constructionSeconds",constructionSeconds,"planningSeconds",moduleAfterCreate.totalPlanningSeconds-moduleBefore.totalPlanningSeconds,"totalSamplesSeconds",totalSamples,"totalMedianSeconds",median(totalSamples),"internalSamplesSeconds",internalSamples,"internalMedianSeconds",median(internalSamples),"errors",errors,"maximumRelativeError",maximumRelativeError,"metrics",metrics,"diagnosticMetrics",diagnosticMetrics,"lifecyclePassed",lifecyclePassed,"rss",rss,"failure",emptyFailure());
catch exception
    deleteActive(config,handle,wvt);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds); %#ok<NASGU>
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name}),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
clear temporaryCleanup stateCleanup
end


function record = diagnosticRecord(before,after)
record = after;
for field = ["executionCount" "horizontalExecutionCount" "verticalExecutionCount" "nonlinearFluxCallCount" "nonlinearFluxPhaseEvaluationCount"]
    record.(field) = after.(field)-before.(field);
end
end

function [Fp,Fm,F0,internalSeconds,totalSeconds] = execute(module,handle,wvt)
timer = tic;
[Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
totalSeconds = toc(timer);
end

function validateIdentity(info,config)
if string(info.baseLibrary) ~= string(config.baseLibrary) || string(info.threadLibrary) ~= string(config.threadLibrary)
    error("WaveVortexBenchmark:Issue130LibraryIdentity","The issue #130 module resolved an unexpected FFTW library.");
end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],'omitmissing')/max(max(abs(expected(:)),[],'omitmissing'),realmin);
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
if ~ismac || ~isfile(samplerPath), sampler.reason = "External RSS sampler unavailable."; return, end
command = sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output] = system(command); samplerPid = str2double(strtrim(output));
if status ~= 0 || ~isfinite(samplerPid), sampler.reason = "Unable to launch RSS sampler."; return, end
sampler.status = "running"; sampler.processId = samplerPid; sampler.provider = "macos-ps-rss-external";
end

function sampler = stopSampler(sampler,stopPath,interval)
if sampler.status ~= "running", return, end
writeText(stopPath,"stop"); pause(max(0.05,2*interval)); system(sprintf('kill %d >/dev/null 2>&1',sampler.processId)); sampler.status = "complete";
end

function rss = samplerResult(sampler,samplePath,interval)
rss = struct("status",sampler.status,"provider",sampler.provider,"reason",sampler.reason,"samplingIntervalSeconds",interval,"samples",[],"startupMedianBytes",NaN,"persistentMedianBytes",NaN,"operationPeakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
if sampler.status ~= "complete" || ~isfile(samplePath), return, end
lines = splitlines(strtrim(string(fileread(samplePath))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t')); index = str2double(fields(1));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3)));
end
rss.samples = samples; phases = string({samples.phase}); bytes = [samples.rssBytes];
startup = bytes(phases=="startup"); persistentRSS = bytes(phases=="persistent"); operations = bytes(phases=="operations");
if isempty(startup) || isempty(persistentRSS) || isempty(operations), rss.status = "failed"; rss.reason = "Required RSS phases were not sampled."; return, end
rss.startupMedianBytes = median(startup); rss.persistentMedianBytes = median(persistentRSS); rss.operationPeakBytes = max(operations);
rss.persistentIncrementBytes = rss.persistentMedianBytes-rss.startupMedianBytes; rss.peakIncrementBytes = rss.operationPeakBytes-rss.startupMedianBytes;
end

function writePhase(pathname,phase)
temporary = pathname+".tmp"; writeText(temporary,phase); movefile(temporary,pathname,"f");
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteActive(config,handle,wvt)
if ~isempty(handle)
    try
        feval(config.variant.module,'delete',handle);
    catch
    end
end
if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
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

function value = emptyFailure
value = struct("identifier","","message","","stack",strings(0,1),"report","");
end

function value = emptyResult(config)
value = struct("schemaVersion","1.0.0","status","failed","repeatIndex",config.repeatIndex,"variantId",string(config.variant.id),"caseId",string(config.caseDefinition.id),"providerId",string(config.providerId),"threadCount",config.threadCount,"moduleInfo",struct(),"constructionSeconds",NaN,"planningSeconds",NaN,"totalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalSamplesSeconds",[],"internalMedianSeconds",NaN,"errors",struct(),"maximumRelativeError",NaN,"metrics",struct(),"diagnosticMetrics",struct(),"lifecyclePassed",false,"rss",struct(),"failure",emptyFailure());
end
