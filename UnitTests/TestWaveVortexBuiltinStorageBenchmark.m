classdef TestWaveVortexBuiltinStorageBenchmark < matlab.unittest.TestCase
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
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test,TestTags="full")
        function ledgerAccountsForKnownBuiltinStorage(testCase)
            transform = WVTransformConstantStratification([15e3 15e3 1300],[16 16 9]);
            transform.initWithRandomFlow;
            transform.nonlinearFlux;
            ledger = transform.transformStorageLedger();
            testCase.verifyEqual(ledger.schema,"transform-storage-ledger-v1");
            testCase.verifyEqual(ledger.implementation,"builtin");
            testCase.verifyEqual(ledger.fourierStorageType,"full-complex");
            testCase.verifyTrue(ledger.hasPersistentFullSpectrum);
            testCase.verifyGreaterThanOrEqual(ledger.opaqueEntryCount,1);
            entries = ledger.entries;
            exactPersistent = string({entries.byteStatus}) == "exact" & string({entries.persistence}) == "persistent" & string({entries.allocationState}) == "allocated";
            exactTransient = string({entries.byteStatus}) == "exact" & string({entries.persistence}) == "transient" & string({entries.allocationState}) == "allocated";
            testCase.verifyEqual(ledger.knownPersistentBytes,sum([entries(exactPersistent).bytes]));
            testCase.verifyEqual(ledger.knownTransientBytes,sum([entries(exactTransient).bytes]));
            testCase.verifyEqual(ledger.maximumKnownTransientBytes,max([entries(exactTransient).bytes]));
            testCase.verifyEqual(ledger.knownMaximumLiveBytes,ledger.knownPersistentBytes+ledger.maximumKnownTransientBytes);
            fullBuffer = entries(string({entries.identifier}) == "horizontal.fullSpectrumBuffer");
            testCase.verifyEqual(fullBuffer.bytes,16*prod([16 16 9]));
            testCase.verifyEqual(nnz(startsWith(string({entries.identifier}),"vertical.matrix.")),4);
        end

        function oneCommandBenchmarkWritesJSONAndMarkdown(testCase)
            outputDirectory = fullfile(testCase.temporaryFolder,"storage-result");
            results = runWaveVortexBuiltinStorageBenchmark(suiteId="smoke-v1",caseIds="smoke-constant-nonhydrostatic",processRunCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.08,outputDirectory=outputDirectory);
            testCase.verifyEqual(results.status,"complete");
            testCase.verifyEqual(results.cases.implementation,"builtin");
            testCase.verifyEqual(string(results.cases.runs.metadata.fourierStorageType),"full-complex");
            testCase.verifyEqual(results.cases.rss.status,"complete");
            phases = string({results.cases.runs.rss.samples.phase});
            testCase.verifyTrue(all(ismember(["baseline" "persistent" "nonlinearFlux"],phases)));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"builtin-storage.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"builtin-storage.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            summary = string(fileread(fullfile(outputDirectory,"summary.md")));
            testCase.verifySubstring(summary,"Known persistent (MiB)");
            testCase.verifySubstring(summary,"Maximum known live (MiB)");
            testCase.verifySubstring(summary,"Peak RSS (MiB)");
        end

        function retirementBenchmarkComparesCleanSourceRoots(testCase)
            outputDirectory = fullfile(testCase.temporaryFolder,"retirement-result");
            result = runWaveVortexRetirementBenchmark( ...
                baselineRoot=testCase.repositoryRoot, ...
                candidateRoot=testCase.repositoryRoot, ...
                caseIds="constant-nonhydrostatic-256x256x65", ...
                processRunCount=1, ...
                shouldRunStorageBenchmark=false, ...
                shouldWriteArtifacts=true, ...
                outputDirectory=outputDirectory, ...
                runId="retirement-smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(result.decision,"RETIRE");
            testCase.verifyEqual(result.cases.maximumRelativeError,0);
            testCase.verifyTrue(result.cases.builtinExecutionPassed);
            testCase.verifyTrue(result.cases.performancePassed);
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"retirement-benchmark.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
        end
    end
end
