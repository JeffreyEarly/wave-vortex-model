classdef TestFreeSurfaceQGCoefficientStorageBenchmark < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,"Benchmarks")));
        end
    end

    methods (Test,TestTags="smoke")
        function selectionIsValidated(testCase)
            testCase.verifyError( ...
                @()runFreeSurfaceQGCoefficientStorageBenchmark(gridIds="missing"), ...
                "WaveVortexBenchmark:UnknownCoefficientStorageCase")
            testCase.verifyError( ...
                @()runFreeSurfaceQGCoefficientStorageBenchmark(strategyIds=["separate" "separate"]), ...
                "WaveVortexBenchmark:DuplicateCoefficientStorageCase")
        end

        function preferenceRequiresStatisticalAndPracticalSeparation(testCase)
            tied = freeSurfaceQGCoefficientStoragePreference( ...
                [1 1 1 1 1],[1 1 1 1 1],bootstrapCount=100,seed=1);
            testCase.verifyEqual(tied.ratioConfidenceInterval95,[1 1],AbsTol=0)
            testCase.verifyFalse(tied.packedMeaningfullyFaster)

            faster = freeSurfaceQGCoefficientStoragePreference( ...
                [1 1 1 1 1],0.9*ones(1,5),bootstrapCount=100,seed=1);
            testCase.verifyEqual(faster.ratioConfidenceInterval95,[0.9 0.9],AbsTol=eps)
            testCase.verifyTrue(faster.packedMeaningfullyFaster)
        end
    end

    methods (Test,TestTags="full")
        function canonicalArtifactRetainsSeparateBacking(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            artifactPath = fullfile(root,"Benchmarks","results","reference", ...
                "free-surface-qg-coefficient-storage-v1-m5-max-r2026a","benchmark.json");
            artifact = jsondecode(fileread(artifactPath));
            testCase.verifyEqual(string(artifact.studyId),"free-surface-qg-coefficient-storage-v1")
            testCase.verifyEqual(string(artifact.decision.selectedStrategy),"separate")
            testCase.verifyEqual(numel(artifact.cases),6)
            testCase.verifyEqual([artifact.cases.activeEndpointCount],[0 1 2 0 1 2])
            testCase.verifyTrue(all(arrayfun( ...
                @(benchmarkCase)benchmarkCase.comparison.allCorrectnessPassed,artifact.cases)))
            testCase.verifyFalse(any(arrayfun( ...
                @(benchmarkCase)benchmarkCase.comparison.packedRK4MeaningfullyFaster,artifact.cases)))
        end

        function reducedMatrixIsCorrectAndAccountsForStorage(testCase)
            results = runFreeSurfaceQGCoefficientStorageBenchmark( ...
                gridIds="small",endpointIds=["zero" "one" "two"], ...
                smallNxyz=[8 8 33],Lxyz=[100e3 100e3 1000], ...
                warmupCount=0,sampleCount=1,bootstrapCount=20, ...
                shouldUseFreshProcess=false);
            testCase.verifyEqual(string({results.cases.id}), ...
                ["small-zero-endpoint" "small-one-endpoint" "small-two-endpoint"])
            testCase.verifyEqual([results.cases.activeEndpointCount],[0 1 2])
            testCase.verifyEqual(results.decision.status,"complete")
            testCase.verifyTrue(ismember(results.decision.selectedStrategy,["separate" "packed"]))
            for benchmarkCase = reshape(results.cases,1,[])
                strategies = benchmarkCase.strategies;
                testCase.verifyEqual(string({strategies.id}),["separate" "packed"])
                testCase.verifyTrue(all(arrayfun(@(strategy)strategy.correctness.passed,strategies)))
                testCase.verifyEqual(string({strategies(1).operations.id}), ...
                    ["reconstruction" "projection" "complete-rhs" "integrator-copy-update" "fixed-rk4-step"])
                testCase.verifyEqual(strategies(1).stateStorage.componentCount,3)
                testCase.verifyEqual(strategies(2).stateStorage.componentCount,1)
                testCase.verifyGreaterThanOrEqual( ...
                    strategies(2).stateStorage.totalIntegratorBytes, ...
                    strategies(1).stateStorage.totalIntegratorBytes)
                testCase.verifyEqual(benchmarkCase.comparison.allCorrectnessPassed,true)
            end
        end
    end
end
