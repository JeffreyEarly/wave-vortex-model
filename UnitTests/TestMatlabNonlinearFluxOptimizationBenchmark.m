classdef TestMatlabNonlinearFluxOptimizationBenchmark < matlab.unittest.TestCase
    properties
        repositoryRoot
        benchmarkFolder
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(testCase.repositoryRoot,"Benchmarks");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.benchmarkFolder));
        end
    end

    methods (Test,TestTags="full")
        function everyVariantMatchesProductionForBothModelTypes(testCase)
            suite = waveVortexBenchmarkSuites("smoke-v1");
            caseIds = ["smoke-constant-hydrostatic" "smoke-constant-nonhydrostatic"];
            for caseId = caseIds
                benchmarkCase = suite.cases(string({suite.cases.id}) == caseId);
                wvt = createWaveVortexBenchmarkTransform(benchmarkCase,"builtin");
                transformCleanup = onCleanup(@()delete(wvt));
                state = initializeWaveVortexBenchmarkState(wvt,benchmarkCase.seed);
                advanceWaveVortexBenchmarkState(wvt,state,1);
                [Fp,Fm,F0] = wvt.nonlinearFlux();
                reference = {Fp,Fm,F0};
                for variant = WVMatlabNonlinearFluxExperiment.variantIdentifiers()
                    advanceWaveVortexBenchmarkState(wvt,state,1);
                    experiment = WVMatlabNonlinearFluxExperiment(wvt,variant);
                    experimentCleanup = onCleanup(@()delete(experiment));
                    [candidateFp,candidateFm,candidateF0] = experiment.execute();
                    error = waveVortexBenchmarkRelativeError(reference,{candidateFp,candidateFm,candidateF0});
                    testCase.verifyLessThanOrEqual(error,1e-12,sprintf("%s failed for %s.",variant,caseId));
                    metadata = experiment.executionMetadata();
                    testCase.verifyEqual(metadata.variant,variant);
                    clear experimentCleanup
                end
                clear transformCleanup
            end
        end

        function persistentWorkspaceLedgersAreExact(testCase)
            suite = waveVortexBenchmarkSuites("smoke-v1");
            for caseId = ["smoke-constant-hydrostatic" "smoke-constant-nonhydrostatic"]
                benchmarkCase = suite.cases(string({suite.cases.id}) == caseId);
                wvt = createWaveVortexBenchmarkTransform(benchmarkCase,"builtin");
                transformCleanup = onCleanup(@()delete(wvt));
                spatialBytes = 8*prod(wvt.spatialMatrixSize);
                fieldCount = 3 + double(~wvt.isHydrostatic);

                reset = WVMatlabNonlinearFluxExperiment(wvt,"reusable-reset");
                resetCleanup = onCleanup(@()delete(reset));
                testCase.verifyEqual(reset.storageLedger().knownPersistentBytes,fieldCount*spatialBytes);
                clear resetCleanup

                forward = WVMatlabNonlinearFluxExperiment(wvt,"forward-batch-preallocated");
                forwardCleanup = onCleanup(@()delete(forward));
                testCase.verifyEqual(forward.storageLedger().knownPersistentBytes,fieldCount*spatialBytes);
                clear forwardCleanup

                full = WVMatlabNonlinearFluxExperiment(wvt,"full-batch-preallocated");
                fullCleanup = onCleanup(@()delete(full));
                expectedInverseBytes = 16*4*prod(wvt.spatialMatrixSize);
                testCase.verifyEqual(full.storageLedger().knownPersistentBytes,fieldCount*spatialBytes+expectedInverseBytes);
                clear fullCleanup transformCleanup
            end
        end

        function reducedBenchmarkWritesCompleteArtifacts(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            outputDirectory = fullfile(fixture.Folder,"issue125");
            originalDirectory = pwd;
            originalPath = path;
            originalRng = rng;
            results = runMatlabNonlinearFluxOptimizationBenchmark( ...
                suiteId="smoke-v1", ...
                caseIds="smoke-constant-hydrostatic", ...
                variants=["current" "scalar-zero" "full-batch-cat"], ...
                processRunCount=1, ...
                shouldMeasureRSS=false, ...
                outputDirectory=outputDirectory, ...
                runId="issue125-test");
            testCase.verifyEqual(results.status,"complete");
            testCase.verifyEqual(string({results.cases.variants.variant}),["current" "scalar-zero" "full-batch-cat"]);
            testCase.verifyEqual(arrayfun(@(item)numel(item.rawSeconds),results.cases.variants),repmat(results.cases.sampleCount,3,1));
            testCase.verifyTrue(all(isfinite([results.cases.variants.medianSeconds])));
            testCase.verifyLessThanOrEqual(max([results.cases.variants.relativeError]),1e-12);
            testCase.verifyEqual(results.cases.allocationControls.bytes,3*8*prod([16 16 9]));
            testCase.verifyTrue(all(isfinite(results.cases.allocationControls.allocationSeconds)));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"matlab-optimization-benchmark.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"matlab-optimization-benchmark.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"issue125-v1");
            summary = string(fileread(fullfile(outputDirectory,"summary.md")));
            testCase.verifyTrue(contains(summary,"## Complete nonlinearFlux timing and memory"));
            testCase.verifyTrue(contains(summary,"## Issue #125 adoption decisions"));
            testCase.verifyTrue(contains(summary,"## Diagnostic component medians"));
            testCase.verifyTrue(contains(summary,"## Allocation controls"));
            testCase.verifyTrue(all(strlength(string({results.source.files.sha256})) == 64));
            testCase.verifyTrue(results.decisions(1).productionEligible);
            testCase.verifyFalse(results.decisions(2).productionEligible);
            testCase.verifyEqual(pwd,originalDirectory);
            testCase.verifyEqual(path,originalPath);
            testCase.verifyEqual(rng,originalRng);
        end

        function invalidSelectionsAreRejectedWithoutChangingState(testCase)
            originalDirectory = pwd;
            originalPath = path;
            originalRng = rng;
            testCase.verifyError(@()runMatlabNonlinearFluxOptimizationBenchmark(variants="missing",shouldWriteArtifacts=false),"WaveVortexBenchmark:UnknownMATLABOptimizationVariant");
            testCase.verifyError(@()runMatlabNonlinearFluxOptimizationBenchmark(caseIds="missing",shouldWriteArtifacts=false),"WaveVortexBenchmark:UnknownCase");
            testCase.verifyEqual(pwd,originalDirectory);
            testCase.verifyEqual(path,originalPath);
            testCase.verifyEqual(rng,originalRng);
        end
    end
end
