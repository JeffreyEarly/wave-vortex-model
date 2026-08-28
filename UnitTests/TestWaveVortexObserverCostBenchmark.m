classdef TestWaveVortexObserverCostBenchmark < matlab.unittest.TestCase
    properties
        RepositoryRoot (1,1) string
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            testCase.RepositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.RepositoryRoot,"Benchmarks")));
        end
    end

    methods (Test,TestTags="smoke")
        function definitionsFormMatchedTwoByTwoDecomposition(testCase)
            definitions = waveVortexObserverCostBenchmarkCases;
            testCase.verifyEqual(string({definitions.id}),["coefficient-endpoint" "coefficient-dense-output" "integrated-observer-endpoint" "composite-dense-output"])
            testCase.verifyEqual([definitions.integratesObserverState],[false false true true])
            testCase.verifyEqual([definitions.usesDenseOutput],[false true false true])
            testCase.verifyEqual(string({definitions.integrationLabel}),["coefficients only" "coefficients only" "coefficients plus tracer and particles" "coefficients plus tracer and particles"])
            testCase.verifyEqual(string({definitions.outputLabel}),["endpoint output" "first-step dense coefficient output" "endpoint output" "first-step composite dense-output graph"])
            testCase.verifyEqual([definitions.scheduledInteriorOutputCount],[0 3 0 3])
            testCase.verifyEqual([definitions.finalTime],8*128*ones(1,4))
        end

        function caseSelectionIsValidatedAndOrdered(testCase)
            definitions = waveVortexObserverCostBenchmarkCases(caseIds=["composite-dense-output" "coefficient-endpoint"],deltaT=2,integrationStepCount=4,denseOutputPointsPerStep=2);
            testCase.verifyEqual(string({definitions.id}),["composite-dense-output" "coefficient-endpoint"])
            testCase.verifyEqual([definitions.finalTime],[8 8])
            testCase.verifyEqual(definitions(1).expectedOutputRecordCounts.dense,4)
            testCase.verifyError(@()waveVortexObserverCostBenchmarkCases(caseIds="unknown"),"WaveVortexBenchmark:UnknownObserverCostCase")
            testCase.verifyError(@()waveVortexObserverCostBenchmarkCases(caseIds=["coefficient-endpoint" "coefficient-endpoint"]),"WaveVortexBenchmark:DuplicateObserverCostCase")
        end

    end

    methods (Test,TestTags="full")
        function reducedCasesDeliverConfiguredGraphsAndWork(testCase)
            definitions = waveVortexObserverCostBenchmarkCases(deltaT=1/1024,integrationStepCount=2,denseOutputPointsPerStep=1);
            results = cell(1,numel(definitions));
            for iCase = 1:numel(definitions)
                results{iCase} = runWaveVortexObserverCostBenchmarkCase(definitions(iCase).id,Nxyz=[8 6 5],deltaT=1/1024,integrationStepCount=2,denseOutputPointsPerStep=1);
                testCase.verifyEqual(results{iCase}.status,"complete")
                testCase.verifyEqual(results{iCase}.work.acceptedStepCount,2)
                testCase.verifyEqual(results{iCase}.work.rhsEvaluationCount,9)
                testCase.verifyEqual(orderfields(results{iCase}.work.outputRecordCounts),orderfields(definitions(iCase).expectedOutputRecordCounts))
            end
            testCase.verifyLessThan(results{1}.work.integratedState.elementCount,results{3}.work.integratedState.elementCount)
            testCase.verifyEqual(results{1}.finalState,results{2}.finalState)
            testCase.verifyEqual(results{3}.finalState,results{4}.finalState)
        end
    end
end
