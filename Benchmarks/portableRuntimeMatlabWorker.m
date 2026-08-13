function portableRuntimeMatlabWorker(configPath,outputPath)
% Run the compiled MATLAB preview through a fixed RK4 interval in one process.
config = jsondecode(fileread(configPath));
totalTimer = tic;
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase";
stopPath = string(tempname)+".stop";
samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler(config.samplingIntervalSeconds);
wvt = [];
reader = [];
result = emptyResult(config);
try
    path(config.matlabPath);
    addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder);
    writePhase(phasePath,"startup");
    sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds);

    writePhase(phasePath,"construct");
    constructionTimer = tic;
    [wvt,reader] = WVTransform.waveVortexTransformFromFile(char(config.inputPath),iTime=Inf,shouldReadOnly=true,computationalBackend="compiled");
    reader.close();
    reader = [];
    metadata = wvt.computationalBackendMetadata;
    validateActiveBackend(metadata,string(config.expectedModuleHash));
    constructionSeconds = toc(constructionTimer);
    writePhase(phasePath,"steady-retained");
    drawnow;
    pause(config.plateauSeconds);

    writePhase(phasePath,"integrate");
    timer = tic;
    for iStep = 1:config.stepCount
        advanceOneStep(wvt,config.deltaT);
    end
    integrationSeconds = toc(timer);
    writePhase(phasePath,"outputs-held");
    drawnow;
    pause(config.plateauSeconds);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    rssSamples = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    rss = phaseRSS(rssSamples,config.samplingIntervalSeconds);

    writePhase(phasePath,"write");
    writeTimer = tic;
    outputFile = wvt.writeToFile(char(config.outputCheckpoint),shouldOverwriteExisting=true);
    outputFile.close();
    writeSeconds = toc(writeTimer);
    delete(wvt);
    wvt = [];
    lifecycle = lifecycleRecord;
    result = struct( ...
        "schemaVersion","portable-runtime-worker-v1", ...
        "status",conditional(rss.status == "complete" && lifecycle.passed,"complete","failed"), ...
        "implementation","compiled-matlab-preview", ...
        "repeatIndex",config.repeatIndex, ...
        "case",config.caseDefinition, ...
        "constructionSeconds",constructionSeconds, ...
        "integrationSeconds",integrationSeconds, ...
        "writeSeconds",writeSeconds, ...
        "totalSeconds",toc(totalTimer), ...
        "finalTime",config.initialTime+config.stepCount*config.deltaT, ...
        "metadata",metadata, ...
        "rss",rss, ...
        "rssSamples",rssSamples, ...
        "lifecycle",lifecycle, ...
        "failure",emptyFailure);
catch exception
    if ~isempty(reader) && isvalid(reader), reader.close(); end
    if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
    stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
clear temporaryCleanup stateCleanup
end

function advanceOneStep(wvt,h)
Ap0 = wvt.Ap;
Am0 = wvt.Am;
A00 = wvt.A0;
t0 = wvt.t;
[k1p,k1m,k10] = wvt.nonlinearFlux();
wvt.Ap = Ap0+0.5*h*k1p; wvt.Am = Am0+0.5*h*k1m; wvt.A0 = A00+0.5*h*k10; wvt.t = t0+0.5*h;
[k2p,k2m,k20] = wvt.nonlinearFlux();
wvt.Ap = Ap0+0.5*h*k2p; wvt.Am = Am0+0.5*h*k2m; wvt.A0 = A00+0.5*h*k20;
[k3p,k3m,k30] = wvt.nonlinearFlux();
wvt.Ap = Ap0+h*k3p; wvt.Am = Am0+h*k3m; wvt.A0 = A00+h*k30; wvt.t = t0+h;
[k4p,k4m,k40] = wvt.nonlinearFlux();
wvt.Ap = Ap0+(h/6)*(k1p+2*k2p+2*k3p+k4p);
wvt.Am = Am0+(h/6)*(k1m+2*k2m+2*k3m+k4m);
wvt.A0 = A00+(h/6)*(k10+2*k20+2*k30+k40);
wvt.t = t0+h;
end

function validateActiveBackend(metadata,expectedModuleHash)
if string(metadata.activeBackend) ~= "compiled" || string(metadata.provider.id) ~= "native-neon-pthreads" || ~metadata.module.identityValidated || string(metadata.module.sha256) ~= expectedModuleHash || metadata.contract.planCount ~= 17 || metadata.libraries.openmp.detected
    error("WaveVortexBenchmark:PortableRuntimeIdentity","The MATLAB control did not execute the validated compiled preview.")
end
end

function value = lifecycleRecord
metrics = wv_compiled_backend_mex('moduleMetrics');
value = struct("passed",metrics.kernelCount == 0 && metrics.activePlans == 0 && metrics.outstandingPlanningBytes == 0 && ~metrics.moduleLocked,"kernelCount",metrics.kernelCount,"activePlans",metrics.activePlans,"outstandingPlanningBytes",metrics.outstandingPlanningBytes,"moduleLocked",metrics.moduleLocked);
end

function value = phaseRSS(rss,interval)
value = struct("status",rss.status,"provider",rss.provider,"samplingIntervalSeconds",interval,"steadyRetainedBytes",NaN,"operationPeakBytes",NaN,"operationPeakIncrementBytes",NaN);
if rss.status ~= "complete" || isempty(rss.samples), return, end
phases = string({rss.samples.phase});
bytes = [rss.samples.rssBytes];
retained = bytes(phases=="steady-retained");
operation = bytes(phases=="integrate" | phases=="outputs-held");
if isempty(retained) || isempty(operation), value.status = "unsupported"; return, end
value.steadyRetainedBytes = median(retained);
value.operationPeakBytes = max(operation);
value.operationPeakIncrementBytes = max(0,value.operationPeakBytes-value.steadyRetainedBytes);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function sampler = startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler = emptySampler(interval);
if ~(ismac||isunix) || ~isfile(samplerPath), sampler.reason = "External RSS sampler unavailable."; return, end
command = sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output] = system(command);
samplerPid = str2double(strtrim(output));
if status ~= 0 || ~isfinite(samplerPid), sampler.reason = "Unable to launch RSS sampler."; return, end
sampler.status = "running";
sampler.processId = samplerPid;
sampler.provider = conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler = stopSampler(sampler,stopPath,interval)
if sampler.status ~= "running", return, end
writeText(stopPath,"stop");
pause(max(0.05,2*interval));
system(sprintf('kill %d >/dev/null 2>&1',sampler.processId));
sampler.status = "complete";
end

function rss = samplerResult(sampler,samplePath,interval)
rss = struct("status",sampler.status,"provider",sampler.provider,"reason",sampler.reason,"samplingIntervalSeconds",interval,"samples",[]);
if sampler.status ~= "complete" || ~isfile(samplePath), return, end
lines = splitlines(strtrim(string(fileread(samplePath))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    index = str2double(fields(1));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3)));
end
rss.samples = samples;
end

function writePhase(pathname,phase)
temporary = pathname+".tmp";
writeText(temporary,phase);
movefile(temporary,pathname,"f");
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname), end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin)
    if isfile(varargin{iFile}), delete(varargin{iFile}); end
end
end

function restoreState(directory,originalPath,originalRng)
cd(directory);
path(originalPath);
rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptySampler(interval)
value = struct("status","unsupported","provider","","reason","","processId",NaN,"samplingIntervalSeconds",interval);
end

function value = emptyFailure
value = struct("identifier","","message","","report","");
end

function value = emptyResult(config)
value = struct("schemaVersion","portable-runtime-worker-v1","status","failed","implementation","compiled-matlab-preview","repeatIndex",config.repeatIndex,"case",config.caseDefinition,"constructionSeconds",NaN,"integrationSeconds",NaN,"writeSeconds",NaN,"totalSeconds",NaN,"finalTime",NaN,"metadata",struct(),"rss",struct(),"rssSamples",struct(),"lifecycle",struct(),"failure",emptyFailure);
end
