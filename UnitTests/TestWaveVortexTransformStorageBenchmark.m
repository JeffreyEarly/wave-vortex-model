classdef TestWaveVortexTransformStorageBenchmark < matlab.unittest.TestCase
    properties
        repositoryRoot (1,1) string
        benchmarkFolder (1,1) string
        temporaryFolder (1,1) string
    end

    methods (TestClassSetup)
        function addAuthoringPaths(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(testCase.repositoryRoot,"Benchmarks");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.benchmarkFolder));
            workspaceRoot = string(fileparts(testCase.repositoryRoot));
            candidates = [fullfile(workspaceRoot,"fftw-transforms") fullfile(workspaceRoot,"OceanKit","FFTWTransforms-1.0.2")];
            selected = candidates(arrayfun(@(candidate)isfile(fullfile(candidate,"RealToComplexTransform.m")),candidates));
            if ~isempty(selected)
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture(selected(1)));
            end
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test,TestTags="full")
        function registryDefinesFourCoreMemoryCases(testCase)
            suite = waveVortexBenchmarkSuites("transform-storage-v1");
            core = waveVortexBenchmarkSuites("core-v1");
            testCase.verifyEqual(suite.kind,"transform-storage");
            testCase.verifyFalse(suite.isScored);
            testCase.verifyEqual(suite.operation,"nonlinearAdvection");
            testCase.verifyEqual(string({suite.cases.id}),string({core.cases.id}));
            testCase.verifyEqual(reshape([suite.cases.Nxyz],3,[]).',[256 256 65;256 256 65;512 512 129;512 512 129]);
        end

        function builtinLedgerAccountsForExactOwnedArrays(testCase)
            transform = testCase.createSmallTransform("builtin");
            cleanup = onCleanup(@()testCase.deleteTransform(transform));
            transform.initWithRandomFlow;
            transform.nonlinearFlux;
            ledger = transform.transformStorageLedger();
            testCase.verifyEqual(ledger.schema,"transform-storage-ledger-v1");
            testCase.verifyEqual(ledger.backendIdentifier,"builtin");
            testCase.verifyEqual(ledger.fourierStorageType,"full-complex");
            testCase.verifyTrue(ledger.hasPersistentFullSpectrum);
            testCase.verifyEqual(ledger.preservingScratchAllocatedBytes,0);
            entries = ledger.entries;
            exactPersistent = string({entries.byteStatus}) == "exact" & string({entries.persistence}) == "persistent" & string({entries.allocationState}) == "allocated";
            testCase.verifyEqual(ledger.knownPersistentBytes,sum([entries(exactPersistent).bytes]));
            fullBuffer = entries(string({entries.identifier}) == "horizontal.fullSpectrumBuffer");
            testCase.verifyEqual(fullBuffer.bytes,16*prod([16 16 9]));
            testCase.verifyEqual(nnz(startsWith(string({entries.identifier}),"vertical.matrix.")),4);
            testCase.verifyEqual(ledger.opaquePlanCount,0);
            clear cleanup
        end

        function repeatedSamplerCapturesRequiredBuiltinPhases(testCase)
            result = testCase.runWorker("builtin");
            testCase.assertEqual(string(result.status),"complete",testCase.failureMessage(result));
            testCase.verifyEqual(string(result.activeBackend),"builtin");
            testCase.verifyEqual(string(result.rss.status),"complete");
            phases = string({result.rss.samples.phase});
            testCase.verifyTrue(all(ismember(["baseline" "persistent" "nonlinearFlux"],phases)));
            testCase.verifyTrue(all(isfinite([result.rss.persistentIncrementBytes result.rss.peakIncrementBytes])));
            testCase.verifyTrue(result.lifecycle.isBalanced);
            testCase.verifyTrue(result.ledger.hasPersistentFullSpectrum);
        end

        function comparisonAppliesExactThresholdsAndUnsupportedState(testCase)
            MiB = 2^20;
            builtin = syntheticBackend("builtin",200*MiB,100*MiB,120*MiB,"complete",true,false,0);
            fftw = syntheticBackend("fftw",150*MiB,(100-16.125)*MiB,(120-16.125)*MiB,"complete",true,false,0);
            comparison = waveVortexTransformStorageComparison([256 256 65],[builtin fftw]);
            testCase.verifyEqual(comparison.thresholdMiB,16.125,AbsTol=eps(16.125));
            testCase.verifyTrue(comparison.gates.exactStorageSavingsPassed);
            testCase.verifyTrue(comparison.gates.persistentRSSPassed);
            testCase.verifyTrue(comparison.gates.peakRSSPassed);
            testCase.verifyTrue(comparison.gates.lifecyclePassed);

            fftw.rss.medianPersistentIncrementBytes = (100-16.124)*MiB;
            comparison = waveVortexTransformStorageComparison([256 256 65],[builtin fftw]);
            testCase.verifyFalse(comparison.gates.persistentRSSPassed);
            fftw.rss.status = "unsupported";
            comparison = waveVortexTransformStorageComparison([256 256 65],[builtin fftw]);
            testCase.verifyFalse(comparison.gates.rssSupported);
            testCase.verifyTrue(isnan(comparison.medianPersistentRSSImprovementBytes));
            testCase.verifyError(@()waveVortexTransformStorageComparison([16 16 9],[builtin fftw]),"WaveVortexBenchmark:UnknownTransformStorageThreshold");
        end

        function summaryAndJSONExposeStorageAndRSSGates(testCase)
            MiB = 2^20;
            builtin = syntheticBackend("builtin",200*MiB,100*MiB,120*MiB,"complete",true,true,0);
            fftw = syntheticBackend("fftw",120*MiB,70*MiB,80*MiB,"complete",true,false,0);
            comparison = waveVortexTransformStorageComparison([256 256 65],[builtin fftw]);
            benchmarkCase = struct("id","memory-case","status","complete","backends",[builtin fftw],"comparison",comparison);
            suite = struct("id","transform-storage-v1","kind","transform-storage","cases",benchmarkCase,"suiteScores",struct([]),"familyScores",struct([]));
            results = struct("status","complete","runId","test","environment",struct("matlabRelease",string(version("-release")),"architecture",computer("arch")),"suites",suite);
            summary = waveVortexBenchmarkSummary(results);
            testCase.verifySubstring(summary,"## Transform-storage diagnostic");
            testCase.verifySubstring(summary,"### Exact persistent storage");
            testCase.verifySubstring(summary,"### Repeated process RSS");
            testCase.verifySubstring(summary,"### Memory gates");
            decoded = jsondecode(jsonencode(results));
            testCase.verifyEqual(string(decoded.suites.kind),"transform-storage");
            testCase.verifyEqual(decoded.suites.cases.comparison.thresholdMiB,16.125,AbsTol=eps(16.125));

            partialFFTW = fftw;
            partialFFTW.status = "partial";
            partialFFTW.ledger = struct();
            partialComparison = waveVortexTransformStorageComparison([256 256 65],[builtin partialFFTW]);
            partialCase = struct("id","partial-memory-case","status","partial","backends",[builtin partialFFTW],"comparison",partialComparison);
            results.status = "partial";
            results.suites.cases = partialCase;
            testCase.verifySubstring(waveVortexBenchmarkSummary(results),"| partial-memory-case | fftw | NaN | NaN | 0 | unavailable | NaN |");
        end
    end

    methods (Test,TestTags="optional")
        function FFTWLedgerAndSamplerRetainNoFullSpectrumOrScratch(testCase)
            testCase.assertEqual(exist("fftw_r2c","file"),3,"Build FFTWTransforms through FFTWBackend.build() before running the optional suite.");
            transform = testCase.createSmallTransform("fftw");
            cleanup = onCleanup(@()testCase.deleteTransform(transform));
            transform.initWithRandomFlow;
            transform.nonlinearFlux;
            ledger = transform.transformStorageLedger();
            testCase.verifyEqual(ledger.backendIdentifier,"fftw");
            testCase.verifyEqual(ledger.fourierStorageType,"hermitian-half");
            testCase.verifyFalse(ledger.hasPersistentFullSpectrum);
            testCase.verifyEqual(ledger.preservingScratchAllocatedBytes,0);
            testCase.verifyGreaterThanOrEqual(ledger.opaquePlanCount,1);
            persistentSpectrum = ledger.entries(string({ledger.entries.identifier}) == "horizontal.persistentSpectrumBuffer");
            scratch = ledger.entries(string({ledger.entries.identifier}) == "horizontal.preservingInverseScratch");
            testCase.verifyEqual(persistentSpectrum.allocationState,"unallocated");
            testCase.verifyEqual(scratch.allocationState,"unallocated");
            clear cleanup

            result = testCase.runWorker("fftw");
            testCase.assertEqual(string(result.status),"complete",testCase.failureMessage(result));
            testCase.verifyEqual(string(result.activeBackend),"fftw");
            testCase.verifyEqual(string(result.rss.status),"complete");
            testCase.verifyFalse(result.ledger.hasPersistentFullSpectrum);
            testCase.verifyEqual(result.ledger.preservingScratchAllocatedBytes,0);
            testCase.verifyTrue(result.lifecycle.isBalanced);
        end
    end

    methods (Access=private)
        function transform = createSmallTransform(~,backend)
            transform = WVTransformConstantStratification([15e3 15e3 1300],[16 16 9],fastTransform=backend);
        end

        function result = runWorker(testCase,backend)
            suite = waveVortexBenchmarkSuites("smoke-v1");
            benchmarkCase = suite.cases(1);
            outputPath = fullfile(testCase.temporaryFolder,"worker-" + backend + ".json");
            configPath = fullfile(testCase.temporaryFolder,"worker-" + backend + "-config.json");
            config = struct( ...
                "benchmarkCase",benchmarkCase, ...
                "backendId",backend, ...
                "repeatIndex",1, ...
                "repositoryRoot",testCase.repositoryRoot, ...
                "benchmarkFolder",testCase.benchmarkFolder, ...
                "matlabPath",path, ...
                "samplerPath",fullfile(testCase.benchmarkFolder,"sampleProcessRSS.sh"), ...
                "samplingIntervalSeconds",0.01, ...
                "plateauSeconds",0.08);
            writelines(jsonencode(config),configPath);
            waveVortexTransformStorageWorker(configPath,outputPath);
            result = jsondecode(fileread(outputPath));
        end

        function deleteTransform(~,transform)
            if isempty(transform) || ~isvalid(transform)
                return
            end
            if ~isempty(transform.verticalTransform) && isvalid(transform.verticalTransform)
                delete(transform.verticalTransform);
            end
            if ~isempty(transform.fastTransform) && isvalid(transform.fastTransform)
                delete(transform.fastTransform);
            end
            delete(transform);
        end

        function message = failureMessage(~,result)
            message = "Worker did not report a structured failure.";
            if isfield(result,"failure") && isstruct(result.failure) && isfield(result.failure,"message")
                message = string(result.failure.message);
                if isfield(result.failure,"stack") && isstruct(result.failure.stack) && ~isempty(result.failure.stack)
                    message = message + " at " + string(result.failure.stack(1).name) + ":" + string(result.failure.stack(1).line);
                end
            end
        end
    end
end

function backend = syntheticBackend(identifier,knownBytes,persistentBytes,peakBytes,rssStatus,isBalanced,hasFullSpectrum,scratchBytes)
ledger = struct("knownPersistentBytes",knownBytes,"knownTransientBytes",0,"opaquePlanCount",0,"hasPersistentFullSpectrum",hasFullSpectrum,"preservingScratchAllocatedBytes",scratchBytes);
rss = struct("status",rssStatus,"persistentIncrementBytes",persistentBytes,"peakIncrementBytes",peakBytes,"medianPersistentIncrementBytes",persistentBytes,"medianPeakIncrementBytes",peakBytes);
run = struct("status","complete","lifecycle",struct("isBalanced",isBalanced));
backend = struct("id",identifier,"status","complete","runs",run,"ledger",ledger,"rss",rss);
end
