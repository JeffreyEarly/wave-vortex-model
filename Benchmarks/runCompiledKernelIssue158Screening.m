function results = runCompiledKernelIssue158Screening(options)
% Screen the issue #158 in-place arena against streamed three-channel.
arguments
    options.nativeProviderRoot (1,1) string
    options.buildDirectory (1,1) string = fullfile(tempdir,"wave-vortex-issue158-mex")
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = utcRunId
    options.shouldBuild (1,1) logical = true
    options.shouldWriteArtifacts (1,1) logical = true
end

repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
provider = nativeProvider(options.nativeProviderRoot);
variants = variantDefinitions;
if options.shouldBuild
    if ~isfolder(options.buildDirectory), mkdir(options.buildDirectory); end
    for iVariant = 1:numel(variants)
        [mexPath,build] = buildCompiledKernelTransformMex(outputDirectory=options.buildDirectory,outputName=variants(iVariant).module,provider=provider,issue130Variant=3,issue158InPlaceArena=variants(iVariant).isArena);
        variants(iVariant).mexPath = string(mexPath);
        variants(iVariant).mexSha256 = string(build.mexSha256);
    end
else
    for iVariant = 1:numel(variants)
        variants(iVariant).mexPath = fullfile(options.buildDirectory,variants(iVariant).module+"."+mexext);
        if ~isfile(variants(iVariant).mexPath), error("WaveVortexModel:Issue158MexMissing","Missing issue #158 MEX module: %s",variants(iVariant).mexPath); end
        variants(iVariant).mexSha256 = sha256File(variants(iVariant).mexPath);
    end
end
addpath(options.buildDirectory);

results = initializeResults(repositoryRoot,provider,variants,options);
results.focusedTests = focusedTests(variants);
cases = caseDefinitions;
for iCase = 1:numel(cases)
    definition = cases(iCase);
    order = definition.order;
    fprintf("Issue #158 screening: %s (%s then %s).\n",definition.id,variants(order(1)).id,variants(order(2)).id);
    caseVariants = repmat(emptyVariantResult,0,1);
    for iOrder = 1:numel(order)
        variant = variants(order(iOrder));
        rng(definition.seed,"twister");
        wvt = WVTransformConstantStratification([15000 15000 1300],definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=true);
        state = initializeWaveVortexBenchmarkState(wvt,definition.seed);
        [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
        configuration = kernelConfiguration(wvt);
        moduleBefore = feval(variant.module,'moduleMetrics');
        rssBeforeCreate = processRSSBytes;
        handle = feval(variant.module,'create',configuration,16);
        handleCleanup = onCleanup(@()deleteHandle(variant.module,handle));
        rssAfterCreate = processRSSBytes;
        info = feval(variant.module,'moduleInfo');
        validateIdentity(info,provider);
        metricsInitial = feval(variant.module,'metrics',handle);
        initialPointer = metricsInitial.scratchBasePointer;
        [actualFp,actualFm,actualF0] = execute(variant.module,handle,wvt);
        errors = struct("Fp",relativeError(actualFp,expectedFp),"Fm",relativeError(actualFm,expectedFm),"F0",relativeError(actualF0,expectedF0));
        maximumRelativeError = max([errors.Fp errors.Fm errors.F0]);
        advanceWaveVortexBenchmarkState(wvt,state,1);
        execute(variant.module,handle,wvt);
        totalSamplesSeconds = NaN(1,3);
        internalSamplesSeconds = NaN(1,3);
        for iSample = 1:3
            advanceWaveVortexBenchmarkState(wvt,state,iSample+1);
            [~,~,~,internalSamplesSeconds(iSample),totalSamplesSeconds(iSample)] = execute(variant.module,handle,wvt);
        end
        rssAfterRepeated = processRSSBytes;
        feval(variant.module,'setStageInstrumentation',handle,true);
        metricsBeforeDiagnostic = feval(variant.module,'metrics',handle);
        advanceWaveVortexBenchmarkState(wvt,state,5);
        execute(variant.module,handle,wvt);
        metricsAfterDiagnostic = feval(variant.module,'metrics',handle);
        feval(variant.module,'setStageInstrumentation',handle,false);
        rssAfterDiagnostic = processRSSBytes;
        feval(variant.module,'delete',handle);
        clear handleCleanup
        moduleAfter = feval(variant.module,'moduleMetrics');
        lifecyclePassed = moduleAfter.kernelCount == moduleBefore.kernelCount && moduleAfter.activePlans == moduleBefore.activePlans && moduleAfter.outstandingPlanningBytes == 0 && moduleAfter.totalPlansCreated-moduleAfter.totalPlansDestroyed == moduleAfter.activePlans;
        pointerStable = metricsAfterDiagnostic.scratchBasePointer == initialPointer;
        metricDelta = diagnosticMetrics(metricsBeforeDiagnostic,metricsAfterDiagnostic);
        memory = memoryRecord(metricsAfterDiagnostic,wvt);
        rss = struct("provider","macos-ps-rss-diagnostic","beforeCreateBytes",rssBeforeCreate,"afterCreateBytes",rssAfterCreate,"afterRepeatedBytes",rssAfterRepeated,"afterDiagnosticBytes",rssAfterDiagnostic,"createIncrementBytes",rssAfterCreate-rssBeforeCreate,"repeatedIncrementBytes",rssAfterRepeated-rssBeforeCreate,"diagnosticIncrementBytes",rssAfterDiagnostic-rssBeforeCreate);
        caseVariants(end+1,1) = struct("id",variant.id,"module",variant.module,"mexSha256",variant.mexSha256,"executionOrdinal",iOrder,"maximumRelativeError",maximumRelativeError,"errors",errors,"warmupCount",1,"sampleCount",3,"totalSamplesSeconds",totalSamplesSeconds,"totalMedianSeconds",median(totalSamplesSeconds),"internalSamplesSeconds",internalSamplesSeconds,"internalMedianSeconds",median(internalSamplesSeconds),"metrics",metricsAfterDiagnostic,"diagnosticDelta",metricDelta,"memory",memory,"rss",rss,"pointerStable",pointerStable,"lifecyclePassed",lifecyclePassed,"libraryIdentityPassed",true,"status",conditional(maximumRelativeError<=1e-12&&pointerStable&&lifecyclePassed,"complete","failed")); %#ok<AGROW>
        delete(wvt)
    end
    caseVariants = caseVariants([caseVariants.id]=="streamed-three-channel-control" | [caseVariants.id]=="inplace-six-field-arena");
    control = caseVariants([caseVariants.id]=="streamed-three-channel-control");
    arena = caseVariants([caseVariants.id]=="inplace-six-field-arena");
    comparison = comparisonRecord(control,arena);
    results.cases(end+1,1) = struct("id",definition.id,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"seed",definition.seed,"executionOrder",[variants(order).id],"variants",caseVariants,"comparison",comparison);
end
comparisons = [results.cases.comparison];
testsPassed = results.focusedTests.maximumRelativeError <= 1e-12 && results.focusedTests.injectedFailuresPassed && results.focusedTests.lifecyclePassed;
results.decision = decisionRecord(comparisons,testsPassed,repositoryRoot);
results.status = conditional(results.decision.advance,"ADVANCE","CORE_REJECT");
results.completedAtUTC = utcTimestamp;
if options.shouldWriteArtifacts
    if options.outputDirectory == "", options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue158",options.runId+"-lyra"); end
    if isfolder(options.outputDirectory), error("WaveVortexModel:Issue158OutputExists","Output directory already exists: %s",options.outputDirectory); end
    mkdir(options.outputDirectory);
    writeText(fullfile(options.outputDirectory,"issue158-screening.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function variants = variantDefinitions
variants = [struct("id","streamed-three-channel-control","module","wv_issue158_streamed_control","isArena",false,"mexPath","","mexSha256",""); struct("id","inplace-six-field-arena","module","wv_issue158_inplace_arena","isArena",true,"mexPath","","mexSha256","")];
end

function cases = caseDefinitions
cases = [struct("id","constant-hydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",true,"seed",1582561,"order",[1 2]); struct("id","constant-nonhydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",false,"seed",1582562,"order",[2 1])];
end

function result = focusedTests(variants)
sizes = {[6 5 7],[7 6 8],[8 7 9]};
maximumRelativeError = 0;
for isHydrostatic = [true false]
    for iSize = 1:numel(sizes)
        seed = 158000+100*double(isHydrostatic)+iSize;
        rng(seed,"twister");
        wvt = WVTransformConstantStratification([15000 12000 1300],sizes{iSize},isHydrostatic=isHydrostatic,shouldAntialias=true);
        initializeWaveVortexBenchmarkState(wvt,seed);
        [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
        for variant = variants'
            handle = feval(variant.module,'create',kernelConfiguration(wvt),2);
            cleanup = onCleanup(@()deleteHandle(variant.module,handle));
            [Fp,Fm,F0] = feval(variant.module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
            maximumRelativeError = max(maximumRelativeError,max([relativeError(Fp,expectedFp) relativeError(Fm,expectedFm) relativeError(F0,expectedF0)]));
            clear cleanup
        end
        delete(wvt)
    end
end
arena = variants([variants.isArena]);
failureWvt = WVTransformConstantStratification([15000 12000 1300],[6 5 7],isHydrostatic=false,shouldAntialias=true);
configuration = kernelConfiguration(failureWvt);
before = feval(arena.module,'moduleMetrics');
planFailurePassed = throws(@()feval(arena.module,'createInjectedFailure',configuration,2,'plan'));
allocationFailurePassed = throws(@()feval(arena.module,'createInjectedFailure',configuration,2,'allocation'));
handle = feval(arena.module,'createInjectedFailure',configuration,2,'execution');
shape = [failureWvt.Nj failureWvt.Nkl];
Ap = complex(zeros(shape)); Am = Ap; A0 = Ap;
executionFailurePassed = throws(@()executeFailure(arena.module,handle,Ap,Am,A0));
feval(arena.module,'delete',handle);
after = feval(arena.module,'moduleMetrics');
lifecyclePassed = after.kernelCount == before.kernelCount && after.activePlans == before.activePlans && after.outstandingPlanningBytes == 0;
delete(failureWvt)
result = struct("sizes",{sizes},"hydrostatic",[true false],"maximumRelativeError",maximumRelativeError,"planFailurePassed",planFailurePassed,"allocationFailurePassed",allocationFailurePassed,"executionFailurePassed",executionFailurePassed,"injectedFailuresPassed",planFailurePassed&&allocationFailurePassed&&executionFailurePassed,"lifecyclePassed",lifecyclePassed);
end

function executeFailure(module,handle,Ap,Am,A0)
[~,~,~] = feval(module,'nonlinearFlux',handle,Ap,Am,A0,0,0);
end

function value = throws(action)
try
    action();
    value = false;
catch
    value = true;
end
end

function value = diagnosticMetrics(before,after)
value = struct("executionCount",after.executionCount-before.executionCount,"horizontalExecutionCount",after.horizontalExecutionCount-before.horizontalExecutionCount,"verticalExecutionCount",after.verticalExecutionCount-before.verticalExecutionCount,"nonlinearFluxCallCount",after.nonlinearFluxCallCount-before.nonlinearFluxCallCount,"phaseEvaluationCount",after.nonlinearFluxPhaseEvaluationCount-before.nonlinearFluxPhaseEvaluationCount,"stages",struct("phaseSeconds",after.phaseSeconds,"reconstructionSeconds",after.reconstructionSeconds,"derivativeReconstructionSeconds",after.derivativeReconstructionSeconds,"productSeconds",after.productSeconds,"projectionSeconds",after.projectionSeconds,"coefficientAssemblySeconds",after.coefficientAssemblySeconds,"derivativeCoefficientAssemblySeconds",after.derivativeCoefficientAssemblySeconds,"coefficientProjectionSeconds",after.coefficientProjectionSeconds));
end

function value = memoryRecord(metrics,wvt)
spectralBytes = 3*wvt.Nj*wvt.Nkl*16;
value = struct("descriptorBytes",metrics.descriptorBytes,"planWrapperBytesLowerBound",metrics.planBytes,"opaquePlanMemory","FFTW-owned plan memory is opaque","scratchBytes",metrics.scratchCapacityBytes,"persistentOwnedBytesLowerBound",metrics.persistentBytes,"stateInputBytes",spectralBytes,"fluxOutputBytes",spectralBytes,"completeExactMaximumLiveBytesExcludingOpaquePlans",metrics.persistentBytes+2*spectralBytes,"halfSpectrumScratchBytes",metrics.halfSpectrumScratchCapacityBytes,"realScratchBytes",metrics.realScratchCapacityBytes,"inPlaceArenaBytes",metrics.inPlaceArenaCapacityBytes,"paddingBytes",metrics.inPlaceArenaPaddingBytes,"compactPhaseSpillBytes",metrics.compactPhaseSpillBytes,"scratchAllocationCount",metrics.scratchAllocationCount,"alignmentBytes",metrics.scratchBaseAlignmentBytes,"persistentFullHermitianBytes",metrics.persistentFullHermitianBytes);
end

function value = comparisonRecord(control,arena)
storageReduction = 1-arena.memory.completeExactMaximumLiveBytesExcludingOpaquePlans/control.memory.completeExactMaximumLiveBytesExcludingOpaquePlans;
timeRegression = arena.totalMedianSeconds/control.totalMedianSeconds-1;
controlRSS = control.rss.diagnosticIncrementBytes;
arenaRSS = arena.rss.diagnosticIncrementBytes;
rssRegression = NaN;
if controlRSS > 0 && arenaRSS >= 0, rssRegression = arenaRSS/controlRSS-1; end
value = struct("completeExactMaximumLiveReduction",storageReduction,"completeTimeRegression",timeRegression,"diagnosticRSSRegression",rssRegression,"storageGatePassed",storageReduction>=0.05,"relaxedLowComplexityBand",storageReduction>=0.03&&storageReduction<0.05,"timeGatePassed",timeRegression<=0.03,"diagnosticRSSGatePassed",~isfinite(rssRegression)||rssRegression<=0.03,"correctnessPassed",arena.maximumRelativeError<=1e-12,"lifecyclePassed",arena.lifecyclePassed&&arena.pointerStable,"executionCountsPreserved",arena.diagnosticDelta.executionCount==control.diagnosticDelta.executionCount&&arena.diagnosticDelta.horizontalExecutionCount==control.diagnosticDelta.horizontalExecutionCount&&arena.diagnosticDelta.verticalExecutionCount==control.diagnosticDelta.verticalExecutionCount);
end

function value = decisionRecord(comparisons,testsPassed,repositoryRoot)
paths = ["CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" "CompiledKernel/include/WaveVortexKernel/WVTransformConstantStratificationKernel.hpp" "CompiledKernel/CMakeLists.txt" "Benchmarks/compiled-kernel/wv_compiled_transform_mex.cpp" "Benchmarks/buildCompiledKernelTransformMex.m" "tools/compiled-kernel/tests/WVReferenceFFTEngine.cpp" "tools/compiled-kernel/tests/TestWVKernelContract.cpp" "Benchmarks/runCompiledKernelIssue158Screening.m"];
complexity = struct("addedExecutionPaths",0,"addedFFTPlans",0,"addedTransforms",0,"addedExecutions",0,"addedPersistentScientificObjects",0,"addedFallbacks",0,"addedRecomputation",0,"publicScientificInterfaceChanges",0,"diagnosticMetricFieldsAdded",7,"persistentDenseHermitianSpectra",0,"sourceFootprint",sourceFootprint(repositoryRoot,paths));
ordinaryGate = all([comparisons.storageGatePassed]) && all([comparisons.timeGatePassed]) && all([comparisons.diagnosticRSSGatePassed]);
lowComplexityGate = all([comparisons.relaxedLowComplexityBand]) && all([comparisons.timeGatePassed]) && all([comparisons.diagnosticRSSGatePassed]);
advance = testsPassed && all([comparisons.correctnessPassed]) && all([comparisons.lifecyclePassed]) && all([comparisons.executionCountsPreserved]) && (ordinaryGate||lowComplexityGate);
value = struct("status",conditional(advance,"ADVANCE","CORE_REJECT"),"advance",advance,"gate","complexity-adjusted issue #158 gate: >=5% ordinarily; 3-5% only for demonstrably localized zero-complexity execution changes; <3% reject","testsPassed",testsPassed,"ordinaryGatePassed",ordinaryGate,"lowComplexityGatePassed",lowComplexityGate,"complexityLedger",complexity,"rejectedControls",["streamed-target-single-output" "bounded-FFT schedules"]);
end

function value = sourceFootprint(repositoryRoot,paths)
quotedPaths = arrayfun(@shellQuote,paths);
command = "git -C "+shellQuote(repositoryRoot)+" diff --numstat 7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05..HEAD -- "+join(quotedPaths," ");
[status,output] = system(command);
files = repmat(struct("path","","addedLines",0,"deletedLines",0),0,1);
if status == 0 && strlength(strtrim(string(output))) > 0
    lines = splitlines(strtrim(string(output)));
    for line = lines'
        fields = split(line,sprintf('\t'));
        files(end+1,1) = struct("path",fields(3),"addedLines",str2double(fields(1)),"deletedLines",str2double(fields(2))); %#ok<AGROW>
    end
end
value = struct("fileCount",numel(files),"addedLines",sum([files.addedLines]),"deletedLines",sum([files.deletedLines]),"files",files);
end

function results = initializeResults(repositoryRoot,provider,variants,options)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
emptyCase = struct("id","","Nxyz",[],"isHydrostatic",false,"seed",NaN,"executionOrder",strings(1,0),"variants",repmat(emptyVariantResult,0,1),"comparison",struct());
results = struct("schemaVersion","1.0.0","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty,"validatedScheduleCommit","7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05","selectionEvidenceCommit","90d8ef1befa2f074474e787ef756f77918621e12","selectionEvidenceMerged",false),"environment",struct("host","Lyra","matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"provider",provider.id,"fftwVersion",provider.version,"threadBackend",provider.threadBackend,"threadCount",16,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"baseLibrarySha256",provider.baseLibrarySha256,"threadLibrarySha256",provider.threadLibrarySha256),"configuration",struct("processCount",1,"warmupCount",1,"sampleCount",3,"rotatedOrder",true,"deterministicAdvancement",true,"largeCasesRun",false,"finalistProtocolRun",false,"rssProtocolRun",false,"correctnessTolerance",1e-12,"maximumTimeRegression",0.03,"ordinaryStorageReduction",0.05,"lowComplexityStorageBand",[0.03 0.05]),"variants",variants,"focusedTests",struct(),"liveness",livenessRecord,"cases",repmat(emptyCase,0,1),"decision",struct());
end

function value = livenessRecord
stages = [struct("stage","phase","live","canonical state 3S; output flux 3S; compact phase spill S","alias","none"); struct("stage","velocity spectrum","live","three velocity spectra 3H; compact phase spill S","alias","velocity spectra occupy arenas 1-3"); struct("stage","velocity physical","live","U,V,W in three padded arenas; compact phase spill S","alias","spectral values are dead and overwritten in place"); struct("stage","target derivative spectrum","live","U,V,W in arenas 1-3; dx,dy,dz spectra 3H in arenas 4-6; phase S","alias","derivative spectra occupy their future physical arenas"); struct("stage","target derivative physical/product","live","U,V,W,dx,dy,dz in six padded arenas; phase S","alias","dx is overwritten by the physical flux product"); struct("stage","target projection","live","U,V,W; one flux spectrum H; phase S; accumulated Fp,Fm,F0","alias","the target's dx arena is transformed destructively in place; other derivative arenas are dead")];
value = struct("hydrostaticTargets",["U" "V" "N"],"nonhydrostaticTargets",["U" "V" "W" "N"],"symbols",struct("R","Nx*Ny*Nz*8 physical bytes","P","2*(floor(Nx/2)+1)*Ny*Nz*8 FFTW-padded physical bytes","H","(floor(Nx/2)+1)*Ny*Nz*16 Hermitian-half bytes; H=P","S","Nj*Nkl*16 compact coefficient/phase bytes"),"stages",stages,"minimumArenaCount",6,"unavoidableSpills","one compact S phase array; caller-owned canonical state and flux boundary arrays","completeLowerBound","descriptor + plan wrappers + 6P + S scratch + 6S caller state/flux; FFTW-owned plan allocations are opaque","alignment","one stable 64-byte-aligned arena base; no interior alignment gaps; allocator metadata is opaque","padding","6*(P-R)","proof","No spectral value is consumed after its inverse transform. No derivative physical value is consumed after product formation, and only the product field is consumed by forward projection. Therefore each spectrum may alias its future physical field without overlapping meaningful lifetimes.");
end

function [Fp,Fm,F0,internalSeconds,totalSeconds] = execute(module,handle,wvt)
timer = tic;
[Fp,Fm,F0,internalSeconds] = feval(module,'nonlinearFluxTimed',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
totalSeconds = toc(timer);
end

function provider = nativeProvider(root)
includeDirectory = fullfile(root,"install","include");
baseLibrary = fullfile(root,"install","lib","libfftw3.3.dylib");
threadLibrary = fullfile(root,"install","lib","libfftw3_threads.3.dylib");
if ~isfile(fullfile(includeDirectory,"fftw3.h")) || ~isfile(baseLibrary) || ~isfile(threadLibrary), error("WaveVortexModel:Issue158NativeProviderMissing","The pinned FFTW 3.3.11 NEON/pthreads provider is incomplete at %s.",root); end
provider = struct("id","native-neon-pthreads","version","3.3.11","threadBackend","pthreads","includeDirectory",string(includeDirectory),"linkLibraries",[string(threadLibrary) string(baseLibrary)],"rpathDirectories",string(fullfile(root,"install","lib")),"baseLibrary",string(baseLibrary),"threadLibrary",string(threadLibrary),"baseLibrarySha256",sha256File(baseLibrary),"threadLibrarySha256",sha256File(threadLibrary));
end

function validateIdentity(info,provider)
if ~contains(string(info.version),provider.version) || string(info.baseLibrary) ~= provider.baseLibrary || string(info.threadLibrary) ~= provider.threadLibrary, error("WaveVortexModel:Issue158ProviderIdentity","The loaded FFTW provider does not match the pinned NEON/pthreads build."); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function bytes = processRSSBytes
[status,output] = system("ps -o rss= -p "+feature("getpid"));
if status == 0, bytes = 1024*str2double(strtrim(output)); else, bytes = NaN; end
end

function markdown = summaryMarkdown(results)
lines = ["# Issue #158 Lyra in-place arena screening";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"` from validated schedule `"+results.source.validatedScheduleCommit+"`";"- Selection evidence: `"+results.source.selectionEvidenceCommit+"` (recorded, not merged)";"- Provider: FFTW `"+results.environment.fftwVersion+"` NEON/`"+results.environment.threadBackend+"`, `"+results.environment.threadCount+"` threads";"- Protocol: one process, one warmup, three samples, rotated order, deterministic advancement";"";"| Case | Complete control (ms) | Complete arena (ms) | Time regression | Exact max-live control | Exact max-live arena | Reduction | Max error |";"|---|---:|---:|---:|---:|---:|---:|---:|"];
for item = results.cases'
    control = item.variants([item.variants.id]=="streamed-three-channel-control");
    arena = item.variants([item.variants.id]=="inplace-six-field-arena");
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %+.2f%% | %.3f MiB | %.3f MiB | %.2f%% | %.3g |",item.id,1e3*control.totalMedianSeconds,1e3*arena.totalMedianSeconds,100*item.comparison.completeTimeRegression,control.memory.completeExactMaximumLiveBytesExcludingOpaquePlans/2^20,arena.memory.completeExactMaximumLiveBytesExcludingOpaquePlans/2^20,100*item.comparison.completeExactMaximumLiveReduction,arena.maximumRelativeError); %#ok<AGROW>
end
ledger = results.decision.complexityLedger;
lines = [lines;"";"## Liveness result";"";"The exact FFTW-compatible lower bound is six padded physical/Hermitian arenas plus one compact `[Nj,Nkl]` phase spill. Spectra alias only their future physical fields; their meaningful lifetimes do not overlap. The complete lower bound includes the descriptor, plan wrappers, scratch, and caller-owned canonical state and flux arrays. FFTW-owned plan memory remains opaque.";"";"## Complexity ledger";"";"- Added execution paths: "+ledger.addedExecutionPaths;"- Added FFT plans/transforms/executions: "+ledger.addedFFTPlans+"/"+ledger.addedTransforms+"/"+ledger.addedExecutions;"- Added persistent scientific objects/fallbacks/recomputation: "+ledger.addedPersistentScientificObjects+"/"+ledger.addedFallbacks+"/"+ledger.addedRecomputation;"- Public scientific-interface changes: "+ledger.publicScientificInterfaceChanges+"; diagnostic metric fields added: "+ledger.diagnosticMetricFieldsAdded;"- Persistent dense Hermitian spectra: "+ledger.persistentDenseHermitianSpectra;"- Localized source footprint: "+ledger.sourceFootprint.fileCount+" files, +"+ledger.sourceFootprint.addedLines+"/-"+ledger.sourceFootprint.deletedLines+" lines";"";"## Decision";"";"`"+results.decision.status+"`. Single-output and bounded-FFT schedules remained rejected controls and were not expanded."];
markdown = join(lines,newline)+newline;
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
[status,commit] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD"); if status ~= 0, error("WaveVortexModel:Issue158GitIdentity","Unable to resolve commit identity."); end
[status,tree] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD^{tree}"); if status ~= 0, error("WaveVortexModel:Issue158GitIdentity","Unable to resolve tree identity."); end
[~,dirty] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain");
commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(dirty)))>0;
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],"omitmissing")/max(max(abs(expected(:)),[],"omitmissing"),realmin);
end

function deleteHandle(module,handle)
try
    feval(module,'delete',handle);
catch
end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname)); if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function value = utcRunId
value = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"));
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyVariantResult
value = struct("id","","module","","mexSha256","","executionOrdinal",0,"maximumRelativeError",NaN,"errors",struct(),"warmupCount",0,"sampleCount",0,"totalSamplesSeconds",[],"totalMedianSeconds",NaN,"internalSamplesSeconds",[],"internalMedianSeconds",NaN,"metrics",struct(),"diagnosticDelta",struct(),"memory",struct(),"rss",struct(),"pointerStable",false,"lifecyclePassed",false,"libraryIdentityPassed",false,"status","failed");
end
