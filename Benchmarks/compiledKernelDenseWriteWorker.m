function compiledKernelDenseWriteWorker(configPath,outputPath)
% Run paired issue #127 variants in one fresh MATLAB process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
phasePath = string(tempname)+".phase"; stopPath = string(tempname)+".stop"; samplePath = string(tempname)+".rss";
temporaryCleanup = onCleanup(@()deleteTemporaryFiles(phasePath,stopPath,samplePath));
sampler = emptySampler(config.samplingIntervalSeconds);
result = emptyResult(config);
activeHandles = []; activeTransform = [];
try
    path(config.matlabPath);
    addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,string({config.variants.mexDirectory}));
    writePhase(phasePath,"startup");
    sampler = startSampler(config.samplerPath,phasePath,stopPath,samplePath,config.samplingIntervalSeconds);
    pause(config.plateauSeconds);
    moduleInfo = cell(numel(config.variants),1);
    for iVariant = 1:numel(config.variants)
        moduleInfo{iVariant} = feval(config.variants(iVariant).module,'moduleInfo');
        validateIdentity(moduleInfo{iVariant},config);
    end
    writePhase(phasePath,"provider-load"); pause(config.plateauSeconds);

    caseResults = repmat(emptyCase(),numel(config.cases),1);
    for iCase = 1:numel(config.cases)
        definition = config.cases(iCase); prefix = string(definition.id);
        rng(definition.seed,'twister');
        activeTransform = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
        state = initializeWaveVortexBenchmarkState(activeTransform,definition.seed);
        inputs = operationInputs(activeTransform);
        activeHandles = zeros(numel(config.variants),1,'uint64');
        moduleBefore = cell(numel(config.variants),1);
        moduleAfterCreate = cell(numel(config.variants),1);
        constructionSeconds = zeros(numel(config.variants),1);
        writePhase(phasePath,prefix+"-construction");
        for iVariant = 1:numel(config.variants)
            module = string(config.variants(iVariant).module);
            moduleBefore{iVariant} = feval(module,'moduleMetrics'); timer = tic;
            activeHandles(iVariant) = feval(module,'create',kernelConfiguration(activeTransform),config.threadCount);
            constructionSeconds(iVariant) = toc(timer); moduleAfterCreate{iVariant} = feval(module,'moduleMetrics');
        end

        diagnostics = cell(numel(config.variants),1);
        for iVariant = 1:numel(config.variants)
            module = string(config.variants(iVariant).module); handle = activeHandles(iVariant);
            feval(module,'setStageInstrumentation',handle,true);
            executeOperation(module,"nonlinearFlux",handle,inputs,activeTransform);
            diagnostics{iVariant} = feval(module,'metrics',handle);
            feval(module,'setStageInstrumentation',handle,false);
        end
        for iWarmup = 1:definition.warmupCount
            advanceWaveVortexBenchmarkState(activeTransform,state,iWarmup);
            for iVariant = 1:numel(config.variants)
                module = string(config.variants(iVariant).module); handle = activeHandles(iVariant);
                executeOperation(module,"inverse",handle,inputs,activeTransform);
                executeOperation(module,"nonlinearFlux",handle,inputs,activeTransform);
            end
        end
        writePhase(phasePath,prefix+"-persistent"); pause(config.plateauSeconds);
        operations = ["inverse" "nonlinearFlux"];
        totalSamples = NaN(definition.sampleCount,numel(operations),numel(config.variants));
        internalSamples = totalSamples;
        executionOrder = zeros(definition.sampleCount,numel(config.variants));
        writePhase(phasePath,prefix+"-operations");
        for iSample = 1:definition.sampleCount
            advanceWaveVortexBenchmarkState(activeTransform,state,definition.warmupCount+iSample);
            variantOrder = mod((0:numel(config.variants)-1)+(iSample+config.repeatIndex-2),numel(config.variants))+1;
            executionOrder(iSample,:) = variantOrder;
            for iVariant = variantOrder
                operationOrder = mod((0:numel(operations)-1)+(iSample+iVariant-2),numel(operations))+1;
                for iOperation = operationOrder
                    [totalSamples(iSample,iOperation,iVariant),internalSamples(iSample,iOperation,iVariant)] = executeOperation(string(config.variants(iVariant).module),operations(iOperation),activeHandles(iVariant),inputs,activeTransform);
                end
            end
        end

        variants = repmat(emptyVariantCase(),numel(config.variants),1);
        for iVariant = 1:numel(config.variants)
            module = string(config.variants(iVariant).module); handle = activeHandles(iVariant);
            errors = correctnessErrors(module,handle,inputs,activeTransform);
            metrics = feval(module,'metrics',handle);
            variants(iVariant) = struct("id",string(config.variants(iVariant).id),"constructionSeconds",constructionSeconds(iVariant),"planningSeconds",moduleAfterCreate{iVariant}.totalPlanningSeconds-moduleBefore{iVariant}.totalPlanningSeconds,"timings",timingRecords(totalSamples(:,:,iVariant),internalSamples(:,:,iVariant),operations),"errors",errors,"maximumRelativeError",max(cell2mat(struct2cell(errors))),"metrics",metrics,"diagnosticMetrics",diagnostics{iVariant},"lifecyclePassed",false);
        end

        writePhase(phasePath,prefix+"-cleanup");
        for iVariant = 1:numel(config.variants)
            module = string(config.variants(iVariant).module);
            feval(module,'delete',activeHandles(iVariant));
            afterDelete = feval(module,'moduleMetrics');
            variants(iVariant).lifecyclePassed = afterDelete.kernelCount == moduleBefore{iVariant}.kernelCount && afterDelete.activePlans == moduleBefore{iVariant}.activePlans && afterDelete.outstandingPlanningBytes == 0;
        end
        activeHandles = [];
        delete(activeTransform); activeTransform = [];
        caseResults(iCase) = struct("id",prefix,"Nxyz",definition.Nxyz,"isHydrostatic",logical(definition.isHydrostatic),"shouldAntialias",logical(definition.shouldAntialias),"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"executionOrder",executionOrder,"variants",variants,"rss",emptyCaseRSS(config.samplingIntervalSeconds),"status",conditional(all([variants.lifecyclePassed]) && max([variants.maximumRelativeError])<=1e-12,"complete","failed"));
    end

    for iVariant = 1:numel(config.variants), eval("clear "+string(config.variants(iVariant).module)); end
    writePhase(phasePath,"module-clear"); pause(config.plateauSeconds);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds);
    rss = samplerResult(sampler,samplePath,config.samplingIntervalSeconds);
    for iCase = 1:numel(caseResults), caseResults(iCase).rss = caseRSS(rss,string(caseResults(iCase).id)); end
    result = struct("schemaVersion","1.0.0","status",conditional(all(string({caseResults.status})=="complete"),"complete","failed"),"repeatIndex",config.repeatIndex,"providerId",string(config.providerId),"threadCount",config.threadCount,"moduleInfo",vertcat(moduleInfo{:}),"cases",caseResults,"rss",rss,"failure",emptyFailure());
catch exception
    deleteActive(config,activeHandles,activeTransform);
    sampler = stopSampler(sampler,stopPath,config.samplingIntervalSeconds); %#ok<NASGU>
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name}),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
clear temporaryCleanup stateCleanup
end

function inputs = operationInputs(wvt)
inputs = struct("Ap",wvt.Ap,"Am",wvt.Am,"A0",wvt.A0);
end

function [totalSeconds,internalSeconds] = executeOperation(module,operation,handle,inputs,wvt)
timer = tic;
if operation == "inverse"
    [fields,internalSeconds] = feval(module,'inverseTimed',handle,inputs.Ap,inputs.Am,inputs.A0,wvt.t,wvt.t0); %#ok<ASGLU>
else
    [Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0); %#ok<ASGLU>
end
totalSeconds = toc(timer);
end

function errors = correctnessErrors(module,handle,inputs,wvt)
actualInverse = feval(module,'inverse',handle,inputs.Ap,inputs.Am,inputs.A0,wvt.t,wvt.t0);
[U,V,W,N] = wvt.transformWaveVortexToUVWEta(inputs.Ap,inputs.Am,inputs.A0,wvt.t);
[actualFp,actualFm,actualF0] = feval(module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
[expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
errors = struct("inverse",relativeError(actualInverse,cat(4,U,V,W,N)),"nonlinearFlux",max([relativeError(actualFp,expectedFp) relativeError(actualFm,expectedFm) relativeError(actualF0,expectedF0)]));
end

function records = timingRecords(total,internal,operations)
records = repmat(struct("operation","","totalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalSamplesSeconds",[],"internalMedianSeconds",NaN,"boundaryMedianSeconds",NaN),numel(operations),1);
for iOperation = 1:numel(operations)
    records(iOperation) = struct("operation",operations(iOperation),"totalSamplesSeconds",total(:,iOperation)',"totalMedianSeconds",median(total(:,iOperation)),"internalSamplesSeconds",internal(:,iOperation)',"internalMedianSeconds",median(internal(:,iOperation)),"boundaryMedianSeconds",median(total(:,iOperation)-internal(:,iOperation)));
end
end

function validateIdentity(info,config)
if string(info.baseLibrary) ~= string(config.baseLibrary) || string(info.threadLibrary) ~= string(config.threadLibrary), error("WaveVortexModel:NativeFFTWIdentity","An issue #127 module resolved an unexpected FFTW library."); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],'omitmissing')/max(max(abs(expected(:)),[],'omitmissing'),realmin);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,mexDirectories)
directories = cellstr(mexDirectories);
addpath(repositoryRoot,benchmarkFolder,directories{:});
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
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
rss = emptyRSS(interval); rss.status = sampler.status; rss.provider = sampler.provider; rss.reason = sampler.reason;
if sampler.status ~= "complete" || ~isfile(samplePath), return, end
lines = splitlines(strtrim(string(fileread(samplePath)))); samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines), fields = split(lines(iLine),sprintf('\t')); index = str2double(fields(1)); samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3))); end
rss.samples = samples;
end

function value = caseRSS(rss,caseId)
value = emptyCaseRSS(rss.samplingIntervalSeconds);
if rss.status ~= "complete" || isempty(rss.samples), return, end
phases = string({rss.samples.phase}); bytes = [rss.samples.rssBytes]; baseline = bytes(phases==caseId+"-construction"); persistentSamples = bytes(phases==caseId+"-persistent"); operations = bytes(phases==caseId+"-operations");
if isempty(baseline) || isempty(persistentSamples) || isempty(operations), return, end
value.status = "complete"; value.provider = rss.provider; value.baselineBytes = min(baseline); value.persistentBytes = median(persistentSamples); value.peakBytes = max(operations); value.persistentIncrementBytes = value.persistentBytes-value.baselineBytes; value.peakIncrementBytes = value.peakBytes-value.baselineBytes;
end

function writePhase(pathname,phase)
temporary = pathname+".tmp"; writeText(temporary,phase); movefile(temporary,pathname,"f");
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname); end; cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteActive(config,handles,transform)
for iVariant = 1:min(numel(handles),numel(config.variants)), try, feval(config.variants(iVariant).module,'delete',handles(iVariant)); catch, end, end
if ~isempty(transform) && isvalid(transform), delete(transform); end
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
value = struct("status","unsupported","provider","","reason","","samplingIntervalSeconds",interval,"samples",[]);
end

function value = emptyCaseRSS(interval)
value = struct("status","unsupported","provider","","samplingIntervalSeconds",interval,"baselineBytes",NaN,"persistentBytes",NaN,"peakBytes",NaN,"persistentIncrementBytes",NaN,"peakIncrementBytes",NaN);
end

function value = emptyFailure
value = struct("identifier","","message","","stack",strings(0,1),"report","");
end

function value = emptyVariantCase
value = struct("id","","constructionSeconds",NaN,"planningSeconds",NaN,"timings",struct([]),"errors",struct(),"maximumRelativeError",NaN,"metrics",struct(),"diagnosticMetrics",struct(),"lifecyclePassed",false);
end

function value = emptyCase
value = struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",NaN,"warmupCount",0,"sampleCount",0,"executionOrder",[],"variants",repmat(emptyVariantCase(),0,1),"rss",emptyCaseRSS(0.02),"status","failed");
end

function value = emptyResult(config)
value = struct("schemaVersion","1.0.0","status","failed","repeatIndex",config.repeatIndex,"providerId",string(config.providerId),"threadCount",config.threadCount,"moduleInfo",struct([]),"cases",repmat(emptyCase(),0,1),"rss",emptyRSS(config.samplingIntervalSeconds),"failure",emptyFailure());
end
