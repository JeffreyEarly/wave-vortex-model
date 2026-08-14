classdef TestPortableObservingSystemReadinessBenchmark < matlab.unittest.TestCase
    properties
        temporaryFolder
    end
    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repositoryRoot,"Benchmarks")));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test,TestTags="full")
        function decisionRequiresEveryObserverDirectionAndRegression(testCase)
            compatibility = compatibilityFixture;
            comparison = comparisonFixture;
            decision = portableObservingSystemReadinessDecision(compatibility,comparison);
            testCase.verifyEqual(decision.status,"FULL-OUTPUT-COMPATIBLE")

            compatibility(1).passed = false;
            decision = portableObservingSystemReadinessDecision(compatibility,comparison);
            testCase.verifyEqual(decision.status,"PARTIAL")
            testCase.verifyFalse(decision.allBuiltinsPassed)

            compatibility = compatibilityFixture;
            comparison(1).candidateNoOutputRatio = 1.030001;
            decision = portableObservingSystemReadinessDecision(compatibility,comparison);
            testCase.verifyEqual(decision.status,"PARTIAL")
            comparison(1).candidateNoOutputRatio = 1.03;
            testCase.verifyEqual(portableObservingSystemReadinessDecision(compatibility,comparison).status,"FULL-OUTPUT-COMPATIBLE")
        end

        function noPassingObserverIsNotReady(testCase)
            compatibility = compatibilityFixture;
            [compatibility.passed] = deal(false);
            decision = portableObservingSystemReadinessDecision(compatibility,comparisonFixture);
            testCase.verifyEqual(decision.status,"NOT-READY")
        end
    end

    methods (Test,TestTags="optional")
        function compactCompatibilityMatrixExecutes(testCase)
            result = runPortableObservingSystemReadinessBenchmark(shouldRunPerformance=false,shouldWriteArtifacts=false);
            testCase.verifyEqual(result.status,"complete")
            testCase.verifyEqual(numel(result.scenarios),4)
            testCase.verifyEqual(numel(result.compatibility),10)
            testCase.verifyEqual(result.decision.status,"FULL-OUTPUT-COMPATIBLE")
            testCase.verifyTrue(all([result.scenarios.sharedObserverIdentityPassed]))
        end

        function compatibilityFailureWritesPartialArtifact(testCase)
            outputDirectory = fullfile(testCase.temporaryFolder,"partial");
            testCase.verifyError(@()runPortableObservingSystemReadinessBenchmark(shouldRunPerformance=false,outputDirectory=outputDirectory,injectCompatibilityFailure=true),"WaveVortexBenchmark:PortableObservingSystemsCompatibility")
            artifact = jsondecode(fileread(fullfile(outputDirectory,"portable-observing-systems-readiness.json")));
            testCase.verifyEqual(string(artifact.status),"failed")
            testCase.verifyEqual(string(artifact.failure.stage),"compatibility")
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")))
        end
    end
end

function value = compatibilityFixture
observers = ["WVCoefficients" "WVEulerianFields" "WVMooring" "WVLagrangianParticles" "WVTracer"];
directions = ["runtime-to-matlab" "matlab-to-runtime"];
value = repmat(struct("observer","","direction","","passed",true),0,1);
for observer = observers
    for direction = directions
        value(end+1,1) = struct("observer",observer,"direction",direction,"passed",true); %#ok<AGROW>
    end
end
end

function value = comparisonFixture
value = struct("candidateNoOutputRatio",1.02,"correctnessPassed",true);
end
