classdef TestThermalReadinessConstruction < matlab.unittest.TestCase
    properties
        audit
    end
    methods (TestClassSetup)
        function independentResponse(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.audit=auditThermalReadinessConstruction(string(folder.Folder),sections="response",shouldEvaluateBalanced=false);
        end
    end
    methods (Test,TestTags="full")
        function completePageMatchesIndependentAugmentedExponential(testCase)
            rows=testCase.audit.response;
            testCase.verifyEqual(rows.assemblyCount,[2057;4113]);
            testCase.verifyTrue(all(rows.conjugateInvolution));
            testCase.verifyLessThan(max(rows.inverseResidual),1e-8);
            testCase.verifyLessThan(max(rows.eigenResidual),1e-10);
            testCase.verifyLessThan(max(rows.operatorRelativeError),1e-10);
            testCase.verifyLessThan(max(rows.homogeneousRelativeError),1e-10);
            testCase.verifyLessThan(max(rows.surfaceSourceRelativeError),1e-10);
            testCase.verifyLessThan(max(rows.bottomSourceRelativeError),1e-10);
            testCase.verifyLessThan(max(rows.endpointSourceResidual),1e-2);
            testCase.verifyTrue(all(isfinite(rows.maximumUnitDiffusivityRate)));
        end
        function assemblyRefinementPreservesPhysicalResponses(testCase)
            rows=testCase.audit.refinement;
            testCase.verifyEqual(unique(rows.response),["bottom source";"homogeneous";"surface source"]);
            testCase.verifyEqual(height(rows),21);
            testCase.verifyTrue(all(isfinite(rows.absoluteError)));
            % Use the existing T9 physical-field floors and relative gate.
            % Opposite-endpoint responses can be near zero; their raw
            % relative errors remain recorded in the authoring audit table.
            names=["qgpv";"buoyancy";"speed";"ssh";"surfaceAnomaly";"bottomAnomaly";"physicalEnergy"];
            floors=[1e-13;1e-12;1e-12;1e-10;1e-10;1e-10;1e-12];
            [known,index]=ismember(rows.observable,names);
            testCase.assertTrue(all(known));
            allowance=floors(index)+1e-8*rows.referenceNorm;
            testCase.verifyLessThanOrEqual(rows.absoluteError,allowance);
        end
    end
end
