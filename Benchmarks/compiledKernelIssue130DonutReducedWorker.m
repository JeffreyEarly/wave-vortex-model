function compiledKernelIssue130DonutReducedWorker(configPath,outputPath)
% Run one reduced issue #130 MATLAB path in a fresh process.
config = jsondecode(fileread(configPath));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
result = emptyResult(config);
handle = [];
wvt = [];
try
    addRepositoryPaths(config.repositoryRoot,config.benchmarkFolder,string(config.mexDirectory));
    definition = config.caseDefinition;
    rng(definition.seed,"twister");
    wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=true);
    state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
    mode = string(config.mode);
    info = struct;
    moduleBefore = struct;
    moduleAfterCreate = struct;
    constructionSeconds = NaN;
    diagnostic = struct;
    metrics = struct;
    if mode == "mex"
        module = string(config.module);
        info = feval(module,'moduleInfo');
        validateIdentity(info,config);
        moduleBefore = feval(module,'moduleMetrics');
        timer = tic;
        handle = feval(module,'create',kernelConfiguration(wvt),config.threadCount);
        constructionSeconds = toc(timer);
        moduleAfterCreate = feval(module,'moduleMetrics');
        before = normalizedMetrics(feval(module,'metrics',handle),config);
        feval(module,'setStageInstrumentation',handle,true);
        [~,~,~,diagnosticInternal,diagnosticTotal] = executeMex(module,handle,wvt);
        after = normalizedMetrics(feval(module,'metrics',handle),config);
        feval(module,'setStageInstrumentation',handle,false);
        diagnostic = diagnosticRecord(before,after,diagnosticTotal,diagnosticInternal);
    end

    for iWarmup = 1:config.warmupCount
        advanceWaveVortexBenchmarkState(wvt,state,iWarmup);
        executePath(mode,string(config.module),handle,wvt);
    end
    totalSamples = NaN(1,config.sampleCount);
    internalSamples = NaN(1,config.sampleCount);
    for iSample = 1:config.sampleCount
        advanceWaveVortexBenchmarkState(wvt,state,config.warmupCount+iSample);
        [totalSamples(iSample),internalSamples(iSample)] = executePath(mode,string(config.module),handle,wvt);
    end

    errors = struct("Fp",0,"Fm",0,"F0",0);
    if mode == "mex"
        module = string(config.module);
        [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
        [actualFp,actualFm,actualF0] = feval(module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
        errors = struct("Fp",relativeError(actualFp,expectedFp),"Fm",relativeError(actualFm,expectedFm),"F0",relativeError(actualF0,expectedF0));
        metrics = normalizedMetrics(feval(module,'metrics',handle),config);
        feval(module,'delete',handle);
        handle = [];
        moduleAfterDelete = feval(module,'moduleMetrics');
        lifecyclePassed = moduleAfterDelete.kernelCount == moduleBefore.kernelCount && moduleAfterDelete.activePlans == moduleBefore.activePlans && moduleAfterDelete.outstandingPlanningBytes == 0 && moduleAfterDelete.totalPlansCreated-moduleBefore.totalPlansCreated == moduleAfterDelete.totalPlansDestroyed-moduleBefore.totalPlansDestroyed;
        eval("clear "+module);
    else
        moduleAfterDelete = struct;
        lifecyclePassed = true;
    end
    maximumRelativeError = max(cell2mat(struct2cell(errors)));
    result = struct("schemaVersion","1.0.0","status",conditional(maximumRelativeError<=1e-12&&lifecyclePassed,"complete","failed"),"mode",mode,"variantId",string(config.variantId),"caseId",string(definition.id),"Nxyz",definition.Nxyz,"isHydrostatic",logical(definition.isHydrostatic),"seed",definition.seed,"threadCountRequested",config.threadCount,"threadCountEffective",config.threadCount,"threadBehavior",threadBehavior(mode),"warmupCount",config.warmupCount,"sampleCount",config.sampleCount,"module",string(config.module),"mexSha256",fileHash(config),"moduleInfo",info,"constructionSeconds",constructionSeconds,"planningSeconds",planningSeconds(moduleBefore,moduleAfterCreate),"totalSamplesSeconds",totalSamples,"totalMedianSeconds",median(totalSamples),"internalSamplesSeconds",internalSamples,"internalMedianSeconds",median(internalSamples),"mexBoundaryConversionSamplesSeconds",totalSamples-internalSamples,"mexBoundaryConversionMedianSeconds",median(totalSamples-internalSamples),"boundaryConversionBehavior",boundaryBehavior(mode),"errors",errors,"maximumRelativeInfinityError",maximumRelativeError,"metrics",metrics,"diagnostic",diagnostic,"lifecycle",struct("passed",lifecyclePassed,"before",moduleBefore,"afterDelete",moduleAfterDelete),"fallbackOccurred",false,"failure",emptyFailure());
catch exception
    deleteActive(config,handle,wvt);
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name}),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
clear stateCleanup
end

function [totalSeconds,internalSeconds] = executePath(mode,module,handle,wvt)
if mode == "mex"
    [~,~,~,internalSeconds,totalSeconds] = executeMex(module,handle,wvt);
else
    timer = tic;
    wvt.nonlinearFlux();
    totalSeconds = toc(timer);
    internalSeconds = totalSeconds;
end
end

function [Fp,Fm,F0,internalSeconds,totalSeconds] = executeMex(module,handle,wvt)
timer = tic;
[Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
totalSeconds = toc(timer);
end

function value = normalizedMetrics(value,config)
if ~isfield(value,"screeningVariant"), value.screeningVariant = string(config.variantId); end
if ~isfield(value,"phaseReservationBytes"), value.phaseReservationBytes = 0; end
value.exactPersistentArrayBytesExcludingOpaquePlans = value.descriptorBytes+value.scratchCapacityBytes;
value.exactMaximumLiveArrayBytesExcludingOpaquePlans = value.descriptorBytes+value.scratchCapacityBytes+value.stateInputBytes+value.fluxOutputBytes;
value.planMemoryAccounting = "wrapper lower bound; FFTW-owned plan memory is opaque";
value.fallbackOccurred = false;
end

function record = diagnosticRecord(before,after,totalSeconds,internalSeconds)
record = struct("totalSeconds",totalSeconds,"internalSeconds",internalSeconds,"mexBoundaryConversionSeconds",totalSeconds-internalSeconds,"phaseSeconds",after.phaseSeconds,"reconstructionSeconds",after.reconstructionSeconds,"derivativeReconstructionSeconds",after.derivativeReconstructionSeconds,"productSeconds",after.productSeconds,"projectionSeconds",after.projectionSeconds,"coefficientAssemblySeconds",after.coefficientAssemblySeconds,"derivativeCoefficientAssemblySeconds",after.derivativeCoefficientAssemblySeconds,"coefficientProjectionSeconds",after.coefficientProjectionSeconds,"executionCount",after.executionCount-before.executionCount,"horizontalExecutionCount",after.horizontalExecutionCount-before.horizontalExecutionCount,"verticalExecutionCount",after.verticalExecutionCount-before.verticalExecutionCount,"nonlinearFluxCallCount",after.nonlinearFluxCallCount-before.nonlinearFluxCallCount,"phaseEvaluationCount",after.nonlinearFluxPhaseEvaluationCount-before.nonlinearFluxPhaseEvaluationCount);
end

function validateIdentity(info,config)
if ~contains(string(info.version),"3.3.11") || string(info.baseLibrary) ~= string(config.provider.baseLibrary) || string(info.threadLibrary) ~= string(config.provider.threadLibrary)
    error("WaveVortexModel:Issue130DonutProviderIdentity","The reduced worker did not resolve the pinned FFTW 3.3.11 NEON/pthreads provider.");
end
openMPRuntime = string(info.openMPRuntimeLibrary);
if openMPRuntime ~= "" && ~startsWith(openMPRuntime,string(matlabroot)+filesep)
    error("WaveVortexModel:Issue130DonutOpenMP","The reduced worker unexpectedly loaded an isolated OpenMP runtime: %s",info.openMPRuntimeLibrary);
end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder,mexDirectory)
addpath(repositoryRoot,benchmarkFolder);
if mexDirectory ~= "", addpath(mexDirectory); end
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],"omitmissing")/max(max(abs(expected(:)),[],"omitmissing"),realmin);
end

function value = planningSeconds(before,after)
if isempty(fieldnames(before)), value = NaN; else, value = after.totalPlanningSeconds-before.totalPlanningSeconds; end
end

function value = fileHash(config)
if string(config.mode) ~= "mex", value = ""; return, end
pathname = fullfile(config.mexDirectory,string(config.module)+"."+mexext);
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
value = extractBefore(string(strtrim(output))," ");
end

function value = threadBehavior(mode)
if mode == "mex", value = "FFTW plans requested 18 pthreads; two joined coefficient workers run outside FFTW execution regions; MATLAB's bundled libomp may be resident but is not used as the FFTW backend; no nested threading or isolated LLVM libomp"; else, value = "MATLAB maxNumCompThreads=18; production nonlinearFlux path"; end
end

function value = boundaryBehavior(mode)
if mode == "mex", value = "interleaved-complex inputs are passed by pointer; three complex outputs are allocated at the MEX boundary; reported boundary is complete call minus C++ entry timing"; else, value = "not applicable to production MATLAB"; end
end

function deleteActive(config,handle,wvt)
if ~isempty(handle)
    try
        feval(config.module,'delete',handle);
    catch
    end
end
if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
end

function restoreState(directory,originalPath,originalRng)
cd(directory);
path(originalPath);
rng(originalRng);
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function writeText(pathname,value)
fileId = fopen(pathname,"w");
if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",value);
clear cleanup
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyFailure
value = struct("identifier","","message","","stack",strings(0,1),"report","");
end

function value = emptyResult(config)
value = struct("schemaVersion","1.0.0","status","failed","mode",string(config.mode),"variantId",string(config.variantId),"caseId",string(config.caseDefinition.id),"failure",emptyFailure());
end
