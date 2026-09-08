classdef TestWaveQuadraticAdvisory < matlab.unittest.TestCase
    properties
        prepared
    end
    methods (TestClassSetup)
        function prepareModes(testCase)
            testCase.prepared=prepareSourceStudy(resolveStudyCase("cal-constant-17"));
        end
    end
    methods (Test)
        function matchesFrozenStudyAndPreservesPreparation(testCase)
            data=testCase.prepared; z=data.z; weights=data.w;
            [report,evidence]=assessWaveQuadraticResolution(data,requestedWaveCount=3);
            root=fileparts(mfilename('fullpath'));
            expected=readtable(fullfile(root,'results','calibration-v1','cal-constant-17-scores-v2','prefix-errors.csv'));
            testCase.verifyEqual(report.prefixDiagnostics.quadraticError,expected.fixedError,AbsTol=1e-7)
            testCase.verifyEqual(report.largestSampledCount,3)
            testCase.verifyTrue(report.requestedCountAccepted)
            testCase.verifyEqual(report.status,"assessed")
            testCase.verifyEqual(report.cost.nonzeroProducts,43600)
            testCase.verifyEqual(report.cost.reservedProducts,report.cost.nonzeroProducts+report.cost.structuralZeros)
            testCase.verifyEqual(height(report.coverage.selectedInteractions),numel(unique(evidence.rows.interaction)))
            testCase.verifyEqual(data.z,z); testCase.verifyEqual(data.w,weights)
            limit=report.prefixDiagnostics.limitingInteraction{end};
            testCase.verifyEqual(sum(limit.integerWavevectors(1:2,:),1),limit.integerWavevectors(3,:))
            testCase.verifyNotEmpty(limit.outputModeLabels)
        end
        function rejectsExplicitCountWithoutReplacingRequest(testCase)
            report=assessWaveQuadraticResolution(testCase.prepared,requestedWaveCount=4);
            testCase.verifyEqual(report.status,"rejected")
            testCase.verifyEqual(report.requestedWaveCount,4)
            testCase.verifyFalse(report.requestedCountAccepted)
            testCase.verifyEqual(report.largestSampledCount,3)
            testCase.verifyTrue(any(report.rejectionReasons=="wave-gram"))
        end
        function fixedFamilyFailureCannotProduceAnAcceptedCount(testCase)
            data=testCase.prepared; data.inertialGram=1;
            report=assessWaveQuadraticResolution(data,requestedWaveCount=3);
            testCase.verifyEqual(report.status,"rejected")
            testCase.verifyTrue(isnan(report.largestSampledCount))
            testCase.verifyEqual(report.fixedFamilyCounts.inertial,data.config.inertialCount)
            testCase.verifyFalse(report.requestedCountAccepted)
        end
        function rejectsQuadraticFailureIndependentlyOfGram(testCase)
            data=testCase.prepared; data.waveGram(:)=0;
            report=assessWaveQuadraticResolution(data,quadraticTolerance=.01,requestedWaveCount=8);
            testCase.verifyEqual(report.status,"rejected")
            testCase.verifyEqual(report.requestedWaveCount,8)
            testCase.verifyEqual(report.largestSampledCount,6)
            testCase.verifyTrue(any(report.rejectionReasons=="quadratic-products"))
            testCase.verifyFalse(any(report.rejectionReasons=="wave-gram"))
        end
        function unstableReferenceIsInconclusive(testCase)
            data=testCase.prepared; data.requiredConvergence(1)=1;
            report=assessWaveQuadraticResolution(data,requestedWaveCount=3);
            testCase.verifyEqual(report.status,"reference-inconclusive")
            testCase.verifyTrue(isnan(report.largestSampledCount))
            testCase.verifyFalse(report.requestedCountAccepted)
        end
        function validatesBudgetBeforeProjection(testCase)
            % Removing prepared fields makes any attempted projection fail;
            % the budget rejection must happen before accessing those fields.
            data=testCase.prepared; data.wave={};
            testCase.verifyError(@()assessWaveQuadraticResolution(data,productBudget=1),'WVStudy:ProductBudgetExceeded')
        end
        function validatesRequestedCount(testCase)
            testCase.verifyError(@()assessWaveQuadraticResolution(testCase.prepared,requestedWaveCount=[1 2]),'WVStudy:InvalidRequestedCount')
            testCase.verifyError(@()assessWaveQuadraticResolution(testCase.prepared,requestedWaveCount=9),'WVStudy:InvalidRequestedCount')
            testCase.verifyError(@()assessWaveQuadraticResolution(struct()),'WVStudy:InvalidPreparation')
            testCase.verifyError(@()assessWaveQuadraticResolution(testCase.prepared,quadraticTolerance=.001),'WVStudy:ReferenceAllowanceTooLarge')
        end
    end
end
