classdef TestWaveVortexFFTWReadinessBenchmark < matlab.unittest.TestCase
    properties
        benchmarkFolder (1,1) string
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.benchmarkFolder));
        end
    end

    methods (Test,TestTags="full")
        function allFixedGatesProduceReady(testCase)
            [core,storage,capabilities] = testCase.completeEvidence();
            decision = waveVortexFFTWReadinessDecision(core,storage,capabilities);
            testCase.verifyEqual(decision.outcome,"READY");
            testCase.verifyTrue(all(arrayfun(@(value)all(cell2mat(struct2cell(value.gates))),decision.cases)));
            testCase.verifyFalse(decision.thresholdsChanged);
        end

        function thresholdsAreInclusive(testCase)
            [core,storage,capabilities] = testCase.completeEvidence();
            for iCase = 1:numel(core.cases)
                core.cases(iCase).backends(1).medianSeconds = 1.10;
                core.cases(iCase).backends(2).medianSeconds = 1;
                core.cases(iCase).backends(2).relativeError = 1e-12;
            end
            decision = waveVortexFFTWReadinessDecision(core,storage,capabilities);
            testCase.verifyEqual(decision.outcome,"READY");
            testCase.verifyEqual([decision.cases.speedup],1.10*ones(1,4),AbsTol=1e-14);
        end

        function oneFailedRSSGateProducesNotReady(testCase)
            [core,storage,capabilities] = testCase.completeEvidence();
            storage.cases(1).comparison.gates.persistentRSSPassed = false;
            decision = waveVortexFFTWReadinessDecision(core,storage,capabilities);
            testCase.verifyEqual(decision.outcome,"NOT READY");
            testCase.verifyTrue(ismember("persistentRSSPassed",decision.cases(1).failedCriteria));
            testCase.verifyEqual(decision.failedCaseIds,decision.cases(1).id);
        end

        function fallbackOrMissingEvidenceProducesIncomplete(testCase)
            [core,storage,capabilities] = testCase.completeEvidence();
            core.cases(2).status = "failed";
            decision = waveVortexFFTWReadinessDecision(core,storage,capabilities);
            testCase.verifyEqual(decision.outcome,"INCOMPLETE");
            testCase.verifyFalse(decision.cases(2).gates.evidenceComplete);
        end

        function invalidProviderFailsEveryCaseWithoutChangingEvidenceStatus(testCase)
            [core,storage,capabilities] = testCase.completeEvidence();
            capabilities.provider.id = "native";
            decision = waveVortexFFTWReadinessDecision(core,storage,capabilities);
            testCase.verifyEqual(decision.outcome,"NOT READY");
            testCase.verifyTrue(all(arrayfun(@(value)ismember("libraryIdentityPassed",value.failedCriteria),decision.cases)));
        end

        function markdownContainsEveryDecisionTable(testCase)
            [core,storage,capabilities] = testCase.completeEvidence();
            decision = waveVortexFFTWReadinessDecision(core,storage,capabilities);
            results = struct("runId","test","environment",struct("matlabRelease","2026a","architecture","maca64"),"source",struct("commit",string(repmat('a',1,40)),"requiredTag","v4.2.1"),"capabilities",struct("providerId","matlab-bundled","libraryVersion","fftw-3.3.8","libraryPath","/MATLAB/libmwfftw3.3.dylib"),"core",core,"decision",decision);
            summary = waveVortexFFTWReadinessSummary(results);
            testCase.verifySubstring(summary,"## End-to-end timing and correctness");
            testCase.verifySubstring(summary,"## Storage and lifecycle gates");
            testCase.verifySubstring(summary,"## Dispatch and configuration");
            testCase.verifySubstring(summary,"## Failed criteria");
            testCase.verifySubstring(summary,"**READY**");
        end

        function issue75ArtifactRetainsFixedHashes(testCase)
            artifact = fullfile(testCase.benchmarkFolder,"results","reference","transform-storage-v1-m5-max-r2026a-fftw");
            testCase.verifyEqual(testCase.sha256(fullfile(artifact,"benchmark.json")),"0210a3c0a8e54c891c0cd2935a812c3e2d598f35162e3f73d7aab979c4e76690");
            testCase.verifyEqual(testCase.sha256(fullfile(artifact,"summary.md")),"f61efd9cdd5c75d6ae666743e24dbbffc78e059bf089e70662ff440bf544f18c");
        end
    end

    methods (Static,Access=private)
        function [core,storage,capabilities] = completeEvidence()
            ids = ["constant-nonhydrostatic-256x256x65" "constant-hydrostatic-256x256x65" "constant-nonhydrostatic-512x512x129" "constant-hydrostatic-512x512x129"];
            coreCases = repmat(struct("id","","status","complete","backends",struct([])),1,4);
            storageCases = repmat(struct("id","","status","complete","comparison",struct()),1,4);
            for iCase = 1:4
                coreCases(iCase).id = ids(iCase);
                builtinMetadata = TestWaveVortexFFTWReadinessBenchmark.metadata("builtin","full-complex",[]);
                fftwMetadata = TestWaveVortexFFTWReadinessBenchmark.metadata("fftw","hermitian-half",1);
                coreCases(iCase).backends = [struct("id","builtin","medianSeconds",1.2,"relativeError",0,"metadata",builtinMetadata) struct("id","fftw","medianSeconds",1,"relativeError",1e-13,"metadata",fftwMetadata)];
                gates = struct("exactStorageSavingsPassed",true,"noPersistentFullSpectrumPassed",true,"noPreservingScratchPassed",true,"lifecyclePassed",true,"rssSupported",true,"persistentRSSPassed",true,"peakRSSPassed",true);
                storageCases(iCase).id = ids(iCase);
                storageCases(iCase).comparison = struct("exactKnownPersistentSavingsMiB",65,"medianPersistentRSSImprovementMiB",20,"medianPeakRSSImprovementMiB",20,"gates",gates);
            end
            core = struct("cases",coreCases);
            storage = struct("cases",storageCases);
            capabilities = struct("provider",struct("id","matlab-bundled","identityValidated",true),"library",struct("identityValidated",true),"modules",struct("r2c",struct("identityValidated",true)),"features",struct("r2c",struct("isAvailable",true),"c2r",struct("isAvailable",true)));
        end

        function value = metadata(backend,storageType,compressedDimension)
            derivative = struct("operation","diffX","derivativeOrder",1,"implementation","matlab-1d");
            value = struct("activeBackend",backend,"fourierStorageType",storageType,"compressedDimension",compressedDimension,"mappingMethod","two-dimensional-rows","mappingMemoryBytes",128,"verticalTransformDispatch",struct([]),"spatialDerivativeDispatch",derivative);
        end

        function digest = sha256(pathname)
            engine = java.security.MessageDigest.getInstance("SHA-256");
            engine.update(uint8(fileread(pathname)));
            digest = lower(join(compose("%02x",typecast(engine.digest(),"uint8")),""));
        end
    end
end
