classdef TestBalancedResolutionEvidence < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function balancedReferenceUsesScientificLabels(testCase)
            inputs=balancedInputs();
            problem=IMInternalModes.geostrophicAPVModes(inputs.background,g0=inputs.g0,gd=inputs.gd);
            candidate=IMSolverSpectral(nEVP=96).solveEVP(problem,nModes=4);
            reference=IMSolverSpectral(nEVP=144).solveEVP(problem,nModes=4);
            reference=reference.selectColumns([4 2 1]);

            [report,errors]=WVInternal.compareResolvedModes(candidate,reference,289,4);
            testCase.verifyEqual(report.matches.referenceColumn,[3;2;NaN;1])
            testCase.verifyEqual(report.matches.status,["matched";"matched";"inconclusive";"matched"])
            testCase.verifyLessThan(max(errors([1 2 4])),1e-6)
            testCase.verifyEqual(errors(3),Inf)
        end

        function missingMeasurementsDoNotQualifyPrefix(testCase)
            inputs=balancedInputs();
            problem=IMInternalModes.geostrophicAPVModes(inputs.background,g0=inputs.g0,gd=inputs.gd);
            basis=IMSolverSpectral(nEVP=96).solveEVP(problem,nModes=3);
            report=WVInternal.compareResolvedModes(basis,basis,193,3);
            rows=report.measurements.columnLabel==report.identity.columnLabels(2) & report.measurements.quantity=="h1";
            duplicate=report.measurements(find(rows,1),:);
            report.measurements(rows,:)=[];
            verifyIncomplete(testCase,report)
            report.measurements=[report.measurements;duplicate;duplicate];
            verifyIncomplete(testCase,report)
        end

        function strictMDAReportsTestedCeiling(testCase)
            inputs=balancedInputs();
            options=balancedOptions(inputs);
            options.mdaModeCount=2;
            vertical=WVInternal.buildFreeSurfaceBalancedModes(inputs.background,33,options);
            mda=vertical.mda;
            testCase.verifyEqual(mda.requestKind,"strict")
            testCase.verifyEqual(mda.requestedCount,2)
            testCase.verifyEqual(mda.candidateCount,2)
            testCase.verifyEqual(mda.convergedCount,2)
            testCase.verifyEqual(mda.fixedGridCount,2)
            testCase.verifyEqual(mda.linearCoverage,"candidate-ceiling")
            testCase.verifyTrue(isnan(mda.filteringCount))
            testCase.verifyEqual(mda.selectedLabels,vertical.mdaTransform.modeNumber(:))
        end

        function inconclusiveBoundaryDoesNotSetRejectedWavenumber(testCase)
            inputs=balancedInputs();
            options=balancedOptions(inputs);
            vertical=WVInternal.buildFreeSurfaceBalancedModes(inputs.background,33,options);
            limit=WVInternal.supportedFreeSurfaceBoundaryWavenumber(["surface","bottom"], ...
                vertical.nEVP,1e-2,vertical,inputs,seedKh=1e-4,modeConvergenceTolerance=1e-16);
            testCase.verifyEqual(limit.status,"reference-inconclusive")
            testCase.verifyEqual(limit.firstInconclusiveKh,1e-4)
            testCase.verifyTrue(isnan(limit.firstRejectedKh))
        end
    end
end

function inputs=balancedInputs()
options=struct(N2Function=@(z)1e-4*exp(2*z/700),rhoFunction=@isempty,g0=.02,gd=.03,latitude=30,rotationRate=7.2921e-5,g=9.81);
inputs=WVInternal.resolveFreeSurfaceInputs(1000,options);
end

function verifyIncomplete(testCase,report)
summary=WVInternal.summarizeModeConvergence(report,3,1e-6);
testCase.verifyEqual(summary.measured,[true;false;true])
testCase.verifyEqual(summary.acceptedCount,1)
testCase.verifyFalse(summary.complete)
end

function options=balancedOptions(inputs)
options=struct(g0=inputs.g0,gd=inputs.gd,gramTolerance=1e-2,modeConvergenceTolerance=1e-6, ...
    quadraticDealiasing="none",retainedFraction=2/3,energyFraction=.99,bandwidthFraction=2/3);
end
