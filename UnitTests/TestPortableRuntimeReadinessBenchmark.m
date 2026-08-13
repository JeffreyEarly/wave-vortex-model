classdef TestPortableRuntimeReadinessBenchmark < matlab.unittest.TestCase
    properties
        benchmarkFolder
        temporaryFolder
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
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
        function integrationOnlyDecisionIsIndependentOfCommandOverhead(testCase)
            comparison = comparisonFixture;
            decision = portableRuntimeReadinessDecision(comparison);
            testCase.verifyEqual(decision.status,"RUNTIME-PREVIEW-READY")
            testCase.verifyEqual(decision.memoryStatus,"RUNTIME-MEMORY-OPTIMIZED")
            testCase.verifyEqual(decision.timingScope,"eight fixed RK4 integration steps only; construction, preparation, checkpoint I/O, and output writing excluded")

            comparison(1).integrationSpeedup = 1.249;
            decision = portableRuntimeReadinessDecision(comparison);
            testCase.verifyEqual(decision.status,"RUNTIME-PREVIEW-NOT-READY")
            comparison(1).integrationSpeedup = 1.25;
            comparison(2).peakIncrementRSSRatio = 0.801;
            decision = portableRuntimeReadinessDecision(comparison);
            testCase.verifyEqual(decision.status,"RUNTIME-PREVIEW-READY")
            testCase.verifyEqual(decision.memoryStatus,"RUNTIME-MEMORY-NOT-OPTIMIZED")
        end

        function correctnessIdentityAndLivenessAreRequired(testCase)
            comparison = comparisonFixture;
            comparison(1).maximumRelativeError = 1.01e-12;
            testCase.verifyFalse(portableRuntimeReadinessDecision(comparison).previewReady)
            comparison = comparisonFixture;
            comparison(1).noFallback = false;
            testCase.verifyFalse(portableRuntimeReadinessDecision(comparison).previewReady)
            comparison = comparisonFixture;
            comparison(1).persistentFullHermitianBytes = 16;
            testCase.verifyFalse(portableRuntimeReadinessDecision(comparison).previewReady)
        end
    end

    methods (Test,TestTags="optional")
        function reducedRuntimeBenchmarkExecutesBothConsumers(testCase)
            result = runPortableRuntimeReadinessBenchmark(sizes=[8 6 7],hydrostatic=[true false],processRunCount=1,stepCount=1,deltaT=0.01,samplingIntervalSeconds=0.01,plateauSeconds=0.03,shouldWriteArtifacts=false);
            testCase.verifyEqual(result.status,"complete")
            testCase.verifyEqual(numel(result.runs),4)
            testCase.verifyEqual(string({result.comparison.status}),["complete" "complete"])
            testCase.verifyLessThanOrEqual(max([result.comparison.maximumRelativeError]),1e-12)
            testCase.verifyTrue(all([result.comparison.nativeIdentityPassed]))
            testCase.verifyTrue(all([result.comparison.noFallback]))
        end

        function workerFailureProducesPartialArtifacts(testCase)
            outputDirectory = fullfile(testCase.temporaryFolder,"partial");
            testCase.verifyError(@()runPortableRuntimeReadinessBenchmark(sizes=[8 6 7],hydrostatic=true,processRunCount=1,stepCount=1,deltaT=0.01,outputDirectory=outputDirectory,injectWorkerFailure=true),"WaveVortexBenchmark:PortableRuntimeWorkers")
            artifact = jsondecode(fileread(fullfile(outputDirectory,"portable-runtime-readiness.json")));
            testCase.verifyEqual(string(artifact.status),"failed")
            testCase.verifyEqual(string(artifact.failure.stage),"workers")
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")))
        end

        function reducedDenseOutputBenchmarkPreservesTrajectoryAndStorage(testCase)
            result = runPortableDenseOutputBenchmark(sizes=[8 6 7],hydrostatic=[true false],processRunCount=1,warmupStepCount=1,mediumSampleCount=2,largeSampleCount=2,deltaT=0.01,shouldWriteArtifacts=false);
            testCase.verifyEqual(result.status,"complete")
            testCase.verifyEqual(numel(result.runs),8)
            testCase.verifyLessThanOrEqual(max([result.comparisons.maximumRelativeError]),1e-12)
            for comparison = reshape(result.comparisons,1,[])
                stateBytes = comparison.baselineWorkspaceBytes/9;
                testCase.verifyEqual(comparison.candidateNoOutputWorkspaceBytes,9*stateBytes)
                testCase.verifyEqual(comparison.denseMethodWorkspaceBytes,12*stateBytes)
                testCase.verifyEqual(comparison.denseDriverBytes,3*stateBytes)
            end
        end
    end
end

function value = comparisonFixture
record = struct("status","complete","integrationSpeedup",1.5,"maximumRelativeError",1e-15,"nativeIdentityPassed",true,"noFallback",true,"planCount",17,"persistentFullHermitianBytes",0,"peakIncrementRSSRatio",0.75);
value = repmat(record,2,1);
end
