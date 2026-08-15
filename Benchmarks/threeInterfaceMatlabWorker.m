function threeInterfaceMatlabWorker(configPath,outputPath)
% Execute one matched MATLAB-interface benchmark sample in a fresh process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase";
stopPath = string(tempname)+".stop";
samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler;
result = failedResult(config);
model = [];
wvt = [];
try
    path(config.matlabPath);
    addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder);
    writePhase(phasePath,"startup");
    sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds);
    interfaceTimer = tic;
    backend = string(config.backend);
    benchmarkCase = string(config.case.id);
    requestedIntegrator = string(config.case.requestedIntegrator);
    if benchmarkCase == "nonlinear-flux"
        [wvt,reader] = WVTransform.waveVortexTransformFromFile(config.inputPath,iTime=Inf,shouldReadOnly=true,computationalBackend=backend);
        reader.close();
        validateBackend(wvt,backend);
        provider = providerRecord(wvt,backend,config);
        writePhase(phasePath,"steady-retained");
        pause(config.plateauSeconds);
        operationTimer = tic;
        [Fp,Fm,F0] = wvt.nonlinearFlux();
        integrationSeconds = toc(operationTimer);
        writeComplexBinary(config.comparisonPath,Fp,Fm,F0);
        finalState = stateRecord(wvt);
        outputAgreement = struct("kind","flux-binary","path",string(config.comparisonPath));
        actualIntegrator = "none";
    else
        model = benchmarkModelFromFile(config.inputPath,backend);
        wvt = model.wvt;
        validateBackend(wvt,backend);
        provider = providerRecord(wvt,backend,config);
        if requestedIntegrator == "fixed-rk4"
            model.setupIntegrator(integratorType="fixed",deltaT=config.case.deltaT);
        elseif requestedIntegrator == "adaptive-rk23"
            model.setupIntegrator(integratorType="adaptive",integrator=@ode23,relTolerance=config.case.relativeTolerance,absTolerance=config.case.absoluteTolerance,shouldShowIntegrationStats=0);
        else
            error("WaveVortexBenchmark:UnknownIntegrator","Unsupported requested integrator %s.",requestedIntegrator);
        end
        actualIntegrator = activeIntegrator(model);
        writePhase(phasePath,"steady-retained");
        pause(config.plateauSeconds);
        operationTimer = tic;
        model.integrateToTime(config.case.finalTime,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
        integrationSeconds = toc(operationTimer);
        finalState = stateRecord(wvt);
        model.closeNetCDFFile();
        outputAgreement = struct("kind","model-output","path",string(config.inputPath));
    end
    interfaceTotalSeconds = toc(interfaceTimer);
    writePhase(phasePath,"outputs-held");
    pause(config.plateauSeconds);
    if ~isempty(model) && isvalid(model)
        delete(model);
        model = [];
    elseif ~isempty(wvt) && isvalid(wvt)
        delete(wvt);
        wvt = [];
    end
    writePhase(phasePath,"complete");
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    rssSamples = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    rss = phaseRSS(rssSamples);
    result = struct( ...
        "schemaVersion","three-interface-worker-v1", ...
        "status","complete", ...
        "interface",string(config.interface), ...
        "case",config.case, ...
        "sourceCommit",string(config.sourceCommit), ...
        "timing",struct("interfaceTotalSeconds",interfaceTotalSeconds,"integrationSeconds",integrationSeconds), ...
        "memory",rss, ...
        "provider",provider, ...
        "integrator",struct("requested",requestedIntegrator,"actual",actualIntegrator,"matched",requestedIntegrator==actualIntegrator), ...
        "finalState",finalState, ...
        "output",outputAgreement, ...
        "failure",emptyFailure);
catch exception
    if ~isempty(model) && isvalid(model)
        try
            model.closeNetCDFFile();
        catch
        end
        delete(model);
    elseif ~isempty(wvt) && isvalid(wvt)
        delete(wvt);
    end
    stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
end

function identifier = activeIntegrator(model)
if string(model.integratorType) == "fixed"
    identifier = "fixed-rk4";
elseif string(model.integratorType) == "adaptive" && string(func2str(model.odeIntegrator)) == "ode23"
    identifier = "adaptive-rk23";
else
    identifier = string(model.integratorType)+":"+string(func2str(model.odeIntegrator));
end
end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
clear temporaryCleanup stateCleanup
end

function model = benchmarkModelFromFile(pathname,backend)
[wvt,reader] = WVTransform.waveVortexTransformFromFile(pathname,iTime=Inf,shouldReadOnly=true,computationalBackend=backend);
readerCleanup = onCleanup(@()closeReader(reader));
isDynamicsLinear = false;
if isKey(reader.attributes,'WVModelIsDynamicsLinear')
    isDynamicsLinear = logical(reader.attributes('WVModelIsDynamicsLinear'));
end
model = WVModel(wvt,shouldUseLinearDynamics=isDynamicsLinear);
reader.close();
clear readerCleanup
ncfile = NetCDFFile(char(pathname),shouldReadOnly=false);
try
    outputFile = WVModelOutputFile.modelOutputFileFromFile(ncfile,model);
    model.addOutputFile(outputFile);
catch exception
    if ~isempty(ncfile.id)
        ncfile.close();
    end
    rethrow(exception)
end
end

function validateBackend(wvt,backend)
metadata = wvt.computationalBackendMetadata;
if string(metadata.activeBackend) ~= backend
    error("WaveVortexBenchmark:InterfaceFallback","Requested %s but %s executed.",backend,string(metadata.activeBackend));
end
if backend == "compiled" && (string(metadata.provider.id) ~= "native-neon-pthreads" || ~metadata.module.identityValidated || metadata.libraries.openmp.detected || metadata.contract.planCount ~= 17)
    error("WaveVortexBenchmark:InterfaceProvider","The MATLAB compiled interface did not execute the validated native provider.");
end
end

function value = providerRecord(wvt,backend,config)
if backend == "compiled"
    metadata = wvt.computationalBackendMetadata;
    value = struct("id",string(metadata.provider.id),"version",string(metadata.provider.version),"threads",double(config.threadCount),"baseLibrary",string(metadata.libraries.base.path),"threadLibrary",string(metadata.libraries.thread.path),"noFallback",true);
else
    value = struct("id","matlab-builtin","version",string(version),"threads",double(config.threadCount),"baseLibrary","","threadLibrary","","noFallback",true);
end
end

function value = stateRecord(wvt)
value = struct("t",wvt.t,"shape",[wvt.Nj wvt.Nkl],"ApNorm",norm(wvt.Ap(:)),"AmNorm",norm(wvt.Am(:)),"A0Norm",norm(wvt.A0(:)));
end

function writeComplexBinary(pathname,varargin)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:ComparisonWrite","Unable to open %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
for iValue = 1:numel(varargin)
    values = varargin{iValue}(:);
    interleaved = reshape([real(values).'; imag(values).'],[],1);
    fwrite(fileId,interleaved,"double");
end
clear cleanup
end

function sampler = startSampler(samplerPath,phasePath,stopPath,samplePath,interval)
sampler = emptySampler;
if ~(ismac||isunix) || ~isfile(samplerPath)
    sampler.reason = "External RSS sampler unavailable.";
    return
end
command = sprintf('"/bin/sh" "%s" "%d" "%s" "%s" "%s" "%.6f" >/dev/null 2>&1 & echo $!',samplerPath,matlabProcessID,phasePath,stopPath,samplePath,interval);
[status,output] = system(command);
samplerPid = str2double(strtrim(output));
if status ~= 0 || ~isfinite(samplerPid)
    sampler.reason = "Unable to launch RSS sampler.";
    return
end
sampler.status = "running";
sampler.processId = samplerPid;
sampler.provider = conditional(ismac,"macos-ps-rss-external","linux-ps-rss-external");
end

function sampler = stopSampler(sampler,stopPath,interval)
if sampler.status ~= "running"
    return
end
writeText(stopPath,"stop");
pause(max(0.05,2*interval));
system(sprintf('kill %d >/dev/null 2>&1',sampler.processId));
sampler.status = "complete";
end

function rss = samplerResult(sampler,samplePath,interval)
rss = struct("status",sampler.status,"provider",sampler.provider,"reason",sampler.reason,"samplingIntervalSeconds",interval,"samples",[]);
if sampler.status ~= "complete" || ~isfile(samplePath)
    return
end
lines = splitlines(strtrim(string(fileread(samplePath))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    index = str2double(fields(1));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3)));
end
rss.samples = samples;
end

function value = phaseRSS(rss)
value = struct("status",rss.status,"provider",rss.provider,"baselineProcessBytes",NaN,"peakProcessBytes",NaN,"peakIncrementBytes",NaN,"samples",rss.samples);
if rss.status ~= "complete" || isempty(rss.samples)
    return
end
phases = string({rss.samples.phase});
bytes = [rss.samples.rssBytes];
baseline = bytes(phases=="steady-retained");
if isempty(baseline)
    value.status = "unsupported";
    return
end
value.baselineProcessBytes = median(baseline);
value.peakProcessBytes = max(bytes);
value.peakIncrementBytes = max(0,value.peakProcessBytes-value.baselineProcessBytes);
end

function writePhase(pathname,phase)
temporary = pathname+".tmp";
writeText(temporary,phase);
movefile(temporary,pathname,"f");
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder)
        addpath(folder);
    end
end
end

function closeReader(reader)
if ~isempty(reader) && isvalid(reader) && ~isempty(reader.id)
    reader.close();
end
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin)
    if isfile(varargin{iFile})
        delete(varargin{iFile});
    end
end
end

function restoreState(directory,originalPath,originalRng)
cd(directory);
path(originalPath);
rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function value = emptySampler
value = struct("status","unsupported","provider","","reason","","processId",NaN);
end

function value = emptyFailure
value = struct("identifier","","message","","report","");
end

function value = failedResult(config)
value = struct("schemaVersion","three-interface-worker-v1","status","failed","interface",string(config.interface),"case",config.case,"sourceCommit",string(config.sourceCommit),"timing",struct(),"memory",struct(),"provider",struct(),"integrator",struct(),"finalState",struct(),"output",struct(),"failure",emptyFailure);
end
