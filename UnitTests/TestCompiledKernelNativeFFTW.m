classdef TestCompiledKernelNativeFFTW < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
            addpath(benchmarkFolder);
            testCase.addTeardown(@()rmpath(benchmarkFolder));
        end
    end

    methods (Test,TestTags="full")
        function providerMatrixIsPinnedAndDistinct(testCase)
            providers = compiledKernelNativeFFTWProviders;
            testCase.verifyEqual(string({providers.id}),["native-plain-pthreads" "native-neon-pthreads" "native-simd128-pthreads" "native-neon-openmp"]);
            testCase.verifyEqual(unique(string({providers.version})),"3.3.11");
            testCase.verifyEqual(unique(string({providers.sourceSHA256})),"5630c24cdeb33b131612f7eb4b1a9934234754f9f388ff8617458d0be6f239a1");
            testCase.verifyTrue(contains(providers(2).configureFlags,"--enable-neon"));
            testCase.verifyTrue(contains(providers(3).configureFlags,"--enable-generic-simd128"));
            testCase.verifyEqual(providers(4).threadBackend,"openmp");
            testCase.verifyTrue(providers(4).requiresOpenMP);
            testCase.verifyEqual([providers.simplicityRank],[1 1 2 3]);
        end

        function finalistSelectionIncludesBuildWinnersNeighborsAndHistoricalControl(testCase)
            providers = compiledKernelNativeFFTWProviders;
            threads = [1 2 4 6 8 12 18];
            screening = repmat(screeningRecord("",0,1),0,1);
            for iProvider = 1:numel(providers)
                for thread = threads
                    score = 1+0.03*abs(thread-(2*iProvider));
                    screening(end+1,1) = screeningRecord(providers(iProvider).id,thread,score); %#ok<AGROW>
                end
            end
            finalists = compiledKernelNativeFFTWFinalists(screening,providers,threads);
            keys = string({finalists.providerId})+"|"+string([finalists.threadCount]);
            for provider = string({providers.id})
                testCase.verifyTrue(any(startsWith(keys,provider+"|")));
                testCase.verifyTrue(any(keys==provider+"|18"));
            end
            best = finalists(string({finalists.providerId})==providers(1).id & [finalists.threadCount]==2);
            testCase.verifyTrue(any(best.reasons=="best-global-nonlinearFlux-for-build"));
        end

        function unknownProviderAndMissingArchiveFailClearly(testCase)
            testCase.verifyError(@()buildCompiledKernelNativeFFTWProviders(providerIds="unknown",cacheRoot=tempname,shouldBuildMex=false),"WaveVortexModel:NativeFFTWUnknownProvider");
            cacheRoot = string(tempname); mkdir(cacheRoot); cleanup = onCleanup(@()rmdir(cacheRoot,"s"));
            testCase.verifyError(@()buildCompiledKernelNativeFFTWProviders(providerIds="native-plain-pthreads",cacheRoot=cacheRoot,shouldBuildMex=false),"WaveVortexModel:NativeFFTWArchiveMissing");
            clear cleanup
        end

        function coefficientAssemblyConfirmationRequiresCommonPhysicalCases(testCase)
            cases = [confirmationCase([256 256 65],true,1.08,0.12); confirmationCase([256 256 65],false,1.06,0.11); confirmationCase([512 512 129],true,1.02,0.12); confirmationCase([512 512 129],false,1.01,0.11)];
            decision = compiledKernelCoefficientAssemblyConfirmationDecision(cases);
            testCase.verifyTrue(decision.confirmed);
            testCase.verifyEqual(decision.qualifyingSizes,"256x256x65");
            cases(2).descriptorReduction = 0.09;
            decision = compiledKernelCoefficientAssemblyConfirmationDecision(cases);
            testCase.verifyFalse(decision.confirmed);
            testCase.verifyEqual(decision.status,"CORE-ADOPT-NOT-CONFIRMED");
        end

        function assemblyDecisionAppliesFixedIntegrationBoundaries(testCase)
            cases = repmat(assemblyCase(1.25,1.03,1.03),4,1);
            decision = compiledKernelAssemblyDecision(cases);
            testCase.verifyEqual(decision.coreStatus,"CORE-COMPLETE");
            testCase.verifyEqual(decision.integrationStatus,"INTEGRATION-READY");
            cases(1).compiledSpeedup = 1.2499;
            decision = compiledKernelAssemblyDecision(cases);
            testCase.verifyEqual(decision.integrationStatus,"INTEGRATION-NOT-READY");
            cases = repmat(assemblyCase(1/1.03,0.80,0.80),4,1);
            decision = compiledKernelAssemblyDecision(cases);
            testCase.verifyEqual(decision.integrationStatus,"MEMORY-ONLY");
            cases(1).peakRSSRatio = 0.8001;
            decision = compiledKernelAssemblyDecision(cases);
            testCase.verifyEqual(decision.integrationStatus,"INTEGRATION-NOT-READY");
        end

        function assemblyDecisionRejectsFallbackAndPersistentFullSpectrum(testCase)
            cases = repmat(assemblyCase(1.5,0.7,0.7),4,1);
            cases(2).noFallback = false;
            decision = compiledKernelAssemblyDecision(cases);
            testCase.verifyEqual(decision.coreStatus,"CORE-INCOMPLETE");
            testCase.verifyEqual(decision.integrationStatus,"INTEGRATION-NOT-READY");
            cases(2).noFallback = true; cases(3).persistentFullHermitianBytes = 16;
            decision = compiledKernelAssemblyDecision(cases);
            testCase.verifyEqual(decision.coreStatus,"CORE-INCOMPLETE");
        end

        function correctedMemoryDecisionAppliesThreePercentGate(testCase)
            cases = repmat(memoryCase(1.03,1.03),4,1);
            speed = frozenSpeedCases(1.25);
            decision = compiledKernelMemoryReassessmentDecision(cases,speed);
            testCase.verifyEqual(decision.memoryStatus,"MEMORY-NONREGRESSION");
            testCase.verifyEqual(decision.integrationStatus,"INTEGRATION-READY");
            cases(2).operationPeakRSSRatio = 1.0301;
            decision = compiledKernelMemoryReassessmentDecision(cases,speed);
            testCase.verifyEqual(decision.memoryStatus,"MEMORY-REGRESSION");
            testCase.verifyEqual(decision.integrationStatus,"INTEGRATION-NOT-READY");
        end

        function matlabRetainedLedgerCountsCacheAndOutputs(testCase)
            wvt = WVTransformConstantStratification([15000 12000 1300],[8 6 7],isHydrostatic=false,shouldAntialias=true);
            cleanup = onCleanup(@()delete(wvt));
            outputs = cell(1,3); [outputs{:}] = wvt.nonlinearFlux();
            ledger = compiledKernelMatlabRetainedLedger(wvt,outputs);
            cacheBytes = 0; names = string(wvt.variableCache.keys);
            for iName = 1:numel(names), value = wvt.variableCache{names(iName)}; info = whos("value"); cacheBytes = cacheBytes+info.bytes; end %#ok<NASGU>
            testCase.verifyEqual(ledger.cacheRetainedBytes,double(cacheBytes));
            testCase.verifyEqual(ledger.exactRetainedApplicationBytes,ledger.transformRetainedBytes+ledger.cacheRetainedBytes+ledger.outputRetainedBytes);
            testCase.verifyTrue(all(ismember(["phase" "Apt" "Amt" "u" "v" "w" "eta"],names)));
            clear cleanup
        end
    end

    methods (Test,TestTags="optional")
        function allNativeModulesResolveExactLibraries(testCase)
            result = buildCompiledKernelNativeFFTWProviders;
            for provider = result.providers'
                addpath(fileparts(provider.mexPath));
                pathCleanup = onCleanup(@()rmpath(fileparts(provider.mexPath)));
                if provider.runtimeLibrary == ""
                    info = feval(provider.module,'moduleInfo');
                else
                    info = feval(provider.module,'moduleInfo',char(provider.runtimeLibrary));
                end
                testCase.verifyEqual(string(info.baseLibrary),provider.baseLibrary);
                testCase.verifyEqual(string(info.threadLibrary),provider.threadLibrary);
                if provider.runtimeLibrary ~= "", testCase.verifyEqual(string(info.openMPRuntimeLibrary),provider.runtimeLibrary); end
                testCase.verifyFalse(startsWith(string(info.baseLibrary),string(matlabroot)));
                testCase.verifyTrue(provider.cycleCounterPassed);
                testCase.verifyTrue(provider.checkPassed);
                clear pathCleanup
            end
        end

        function reducedBenchmarkExercisesBothStagesAndBundledControl(testCase)
            outputDirectory = string(tempname); cleanup = onCleanup(@()removeDirectory(outputDirectory));
            result = runCompiledKernelNativeFFTWBenchmark(sizes=[8 6 7],hydrostatic=[true false],threadCounts=1,providerIds="native-plain-pthreads",screeningWarmupCount=0,screeningMediumSampleCount=1,screeningLargeSampleCount=1,finalWarmupCount=0,finalMediumSampleCount=1,finalLargeSampleCount=1,finalProcessRunCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.02,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(numel(result.screening),1);
            testCase.verifyEqual(numel(result.finalConfigurations),2);
            testCase.verifyTrue(result.selection.valid);
            testCase.verifyEqual(result.selection.providerId,"native-plain-pthreads");
            testCase.verifyLessThanOrEqual(max([result.finalConfigurations.maximumRelativeError]),1e-12);
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"native-fftw-baseline.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"native-fftw-baseline.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            clear cleanup
        end

        function assemblyDecisionHarnessBuildsIsolatedSnapshots(testCase)
            outputDirectory = string(tempname); cleanup = onCleanup(@()removeDirectory(outputDirectory));
            result = runCompiledKernelAssemblyDecisionBenchmark(references=["52de161" "be0f789" "3af6b83" "9ceb932a"],sizes=[8 6 7],hydrostatic=true,processRunCount=1,warmupCount=0,mediumSampleCount=1,largeSampleCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.02,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(numel(result.snapshots),4);
            testCase.verifyEqual(numel(unique(string({result.snapshots.module}))),4);
            testCase.verifyFalse(any([result.snapshots.moduleUsesOpenMP]));
            testCase.verifyEqual(result.decision.coreStatus,"CORE-COMPLETE");
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"compiled-kernel-assembly-decision.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            clear cleanup
        end

        function assemblyDecisionHarnessWritesPartialFailure(testCase)
            outputDirectory = string(tempname); cleanup = onCleanup(@()removeDirectory(outputDirectory));
            action = @()runCompiledKernelAssemblyDecisionBenchmark(references=["missing-issue131-ref" "be0f789" "3af6b83" "HEAD"],sizes=[8 6 7],hydrostatic=true,processRunCount=1,warmupCount=0,mediumSampleCount=1,largeSampleCount=1,outputDirectory=outputDirectory,runId="failure");
            testCase.verifyError(action,"WaveVortexModel:AssemblyGit");
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"compiled-kernel-assembly-decision.json")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"compiled-kernel-assembly-decision.json")));
            testCase.verifyEqual(string(decoded.status),"failed");
            testCase.verifyEqual(string(decoded.failure.stage),"snapshots");
            clear cleanup
        end


        function memoryReassessmentSeparatesSampledBackends(testCase)
            outputDirectory = string(tempname); cleanup = onCleanup(@()removeDirectory(outputDirectory));
            originalDirectory = pwd; originalPath = path; originalRng = rng;
            result = runCompiledKernelMemoryReassessmentBenchmark(sizes=[8 6 7],hydrostatic=true,processRunCount=1,warmupCount=0,mediumSampleCount=1,largeSampleCount=1,threadCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.03,outputHoldSeconds=0.03,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(numel(result.runs),2);
            testCase.verifyEqual(sort(string({result.runs.sampledOperation})),sort(["compiled nonlinearFlux only" "MATLAB nonlinearFlux only"]));
            testCase.verifyEqual([result.runs.referenceCallCount],[0 0]);
            testCase.verifyTrue(all(arrayfun(@(item)isfinite(item.ledger.exactRetainedApplicationBytes),result.runs)));
            testCase.verifyTrue(all(arrayfun(@(item)isfinite(item.rss.operationPeakIncrementBytes),result.runs)));
            testCase.verifyTrue(all(arrayfun(@(item)item.rss.outputsClearedBytes>0 && item.rss.backendDestroyedBytes>0,result.runs)));
            testCase.verifyEqual(pwd,originalDirectory);
            testCase.verifyEqual(path,originalPath);
            testCase.verifyEqual(rng,originalRng);
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"memory-reassessment.json")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"memory-reassessment.json")));
            testCase.verifyEqual(string(decoded.priorEvidence.artifactCommit),"d023626b6182e382f842595e044c2b87143e0eaa");
            clear cleanup
        end

        function memoryReassessmentWritesPartialFailure(testCase)
            outputDirectory = string(tempname); cleanup = onCleanup(@()removeDirectory(outputDirectory));
            action = @()runCompiledKernelMemoryReassessmentBenchmark(sizes=[8 6 7],hydrostatic=true,processRunCount=1,warmupCount=0,mediumSampleCount=1,largeSampleCount=1,threadCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.02,outputHoldSeconds=0.02,outputDirectory=outputDirectory,runId="failure",injectWorkerFailure=true);
            testCase.verifyError(action,"WaveVortexModel:MemoryWorkerResults");
            decoded = jsondecode(fileread(fullfile(outputDirectory,"memory-reassessment.json")));
            testCase.verifyEqual(string(decoded.status),"failed");
            testCase.verifyEqual(string(decoded.failure.stage),"workers");
            clear cleanup
        end
    end
end

function result = screeningRecord(providerId,threadCount,score)
operations = ["forward" "inverse" "fAll" "gAll" "nonlinearFlux"];
timings = repmat(struct("operation","","internalMedianSeconds",score),numel(operations),1);
for iOperation = 1:numel(operations), timings(iOperation).operation = operations(iOperation); end
caseResult = struct("status","complete","maximumRelativeError",0,"lifecyclePassed",true,"timings",timings);
result = struct("status","complete","providerId",string(providerId),"threadCount",threadCount,"cases",repmat(caseResult,4,1));
end

function value = confirmationCase(Nxyz,isHydrostatic,speedup,descriptorReduction)
value = struct("Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"completeCallSpeedup",speedup,"descriptorReduction",descriptorReduction,"maximumRelativeError",1e-14,"lifecyclePassed",true);
end

function value = assemblyCase(speedup,exactRatio,rssRatio)
value = struct("status","complete","compiledSpeedup",speedup,"exactMemoryRatio",exactRatio,"peakRSSRatio",rssRatio,"maximumRelativeError",1e-14,"lifecyclePassed",true,"libraryIdentityPassed",true,"nativeExecutionPassed",true,"noFallback",true,"persistentFullHermitianBytes",0);
end

function value = memoryCase(exactRatio,rssRatio)
value = struct("id","case","status","complete","exactRetainedRatio",exactRatio,"operationPeakRSSRatio",rssRatio,"libraryIdentityPassed",true,"nativeExecutionPassed",true,"noFallback",true,"planCount",17,"persistentFullHermitianBytes",0);
end

function values = frozenSpeedCases(speedup)
values = repmat(struct("id","case","compiledSpeedup",speedup,"maximumRelativeError",1e-14),4,1);
end

function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end
