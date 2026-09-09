classdef TestFreeSurfaceLinearModePolicy < matlab.unittest.TestCase
    properties (SetAccess=private)
        linearTransform
        linearAssessment
        nonlinearTransform
        nonlinearAssessment
    end

    methods (TestClassSetup)
        function constructMatchedPolicies(testCase)
            N2=@(z)1e-4+0*z;
            [testCase.linearTransform,testCase.linearAssessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=N2,latitude=30,shouldAntialias=true);
            [testCase.nonlinearTransform,testCase.nonlinearAssessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=N2,latitude=30,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
        end
    end

    methods (Test, TestTags="full")
        function defaultsAndMatchedHorizontalPoliciesAreExplicit(testCase)
            linear=testCase.linearTransform; nonlinear=testCase.nonlinearTransform;
            linearReport=testCase.linearAssessment; nonlinearReport=testCase.nonlinearAssessment;
            qg=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65], ...
                N2Function=@(z)1e-4+0*z,latitude=30,apvModeCount=3,mdaModeCount=2);

            testCase.verifyFalse(linear.shouldCheckQuadraticAliasing)
            defaultLinear=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30, ...
                waveModeCount=1,inertialModeCount=1,apvModeCount=1,mdaModeCount=1);
            testCase.verifyFalse(defaultLinear.shouldAntialias)
            testCase.verifyTrue(qg.shouldCheckQuadraticAliasing)
            testCase.verifyTrue(qg.shouldAntialias)
            testCase.verifyEqual(linear.waveModeCountByKh,38*ones(4,1))
            testCase.verifyEqual(nonlinear.waveModeCountByKh,[10;19;19;10])
            testCase.verifyEqual(linearReport.pages.selectedCount, ...
                min(linearReport.pages.convergedCount,linearReport.pages.gridSupportedCount))
            testCase.verifyEqual(linearReport.pages.selectedCount,linearReport.pages.usableCount)
            testCase.verifyEqual(linearReport.inertial.selectedCount, ...
                min(linearReport.inertial.convergedCount,linearReport.inertial.gridSupportedCount))
            testCase.verifyEqual([linearReport.inertial.selectedCount nonlinearReport.inertial.selectedCount],[38 38])
            testCase.verifyGreaterThan(nonlinearReport.inertial.selectedCount,min(nonlinear.waveModeCountByKh))
        end

        function linearBypassHasNoQuadraticPreparation(testCase)
            linear=testCase.linearTransform; nonlinear=testCase.nonlinearTransform;
            assessment=testCase.linearAssessment;
            testCase.verifyEqual(assessment.quadratic.status,"not-requested")
            testCase.verifyFalse(assessment.shouldCheckQuadraticAliasing)
            testCase.verifyEqual(assessment.cost.selectionTrials,0)
            testCase.verifyFalse(isfield(assessment.cost,'quadratic'))
            testCase.verifyFalse(isfield(assessment.quadratic,'pages'))
            testCase.verifyGreaterThanOrEqual(numel(linear.apvMode),numel(nonlinear.apvMode))

            [changed,changedAssessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30, ...
                shouldAntialias=true,quadraticAliasingTolerance=1e-12);
            testCase.verifyEqual(changed.waveModeCountByKh,linear.waveModeCountByKh)
            testCase.verifyEqual([numel(changed.inertialMode) numel(changed.apvMode) numel(changed.mdaMode)], ...
                [numel(linear.inertialMode) numel(linear.apvMode) numel(linear.mdaMode)])
            testCase.verifyEqual(changedAssessment.quadratic.status,"not-requested")

            propagated=WVTransformFreeSurfaceBoussinesq(linear.scientificState());
            propagated.Aw_p(end,1)=2e-3+1e-3i;
            modalEnergy=propagated.totalEnergy;
            physicalAtZero=propagated.physicalEnergy();
            propagated.t=1234;
            physicalLater=propagated.physicalEnergy();
            testCase.verifyLessThan(abs(physicalAtZero.totalEnergy-modalEnergy)/modalEnergy,2*propagated.gramTolerance)
            testCase.verifyLessThan(abs(physicalLater.totalEnergy-physicalAtZero.totalEnergy)/physicalAtZero.totalEnergy,1e-5)
        end

        function strictLinearPrefixesSurvivePersistenceAndTransfer(testCase)
            linear=testCase.linearTransform;
            state=linear.scientificState();
            restored=WVTransformFreeSurfaceBoussinesq(state);
            testCase.verifyFalse(restored.shouldCheckQuadraticAliasing)
            testCase.verifyEqual(restored.scientificState(),state)

            transferred=linear.waveVortexTransformWithResolution([8 8 65]);
            testCase.verifyFalse(transferred.shouldCheckQuadraticAliasing)
            testCase.verifyEqual(transferred.waveModeCountByKh,linear.waveModeCountByKh)
            testCase.verifyEqual(numel(transferred.inertialMode),numel(linear.inertialMode))

            nonlinear=testCase.nonlinearTransform;
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30,shouldAntialias=true, ...
                shouldCheckQuadraticAliasing=true,waveModeCount=38,inertialModeCount=38, ...
                apvModeCount=numel(nonlinear.apvMode),mdaModeCount=numel(nonlinear.mdaMode)), ...
                'WV:QuadraticModeCountRejected')
        end

        function balancedEndpointsDoNotChangeWavePolarization(testCase)
            free=testCase.linearTransform;
            withoutEndpoints=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30,shouldAntialias=true, ...
                g0=Inf,gd=Inf,nEVP=free.nEVP,waveModeCount=1,inertialModeCount=1,apvModeCount=3,mdaModeCount=2);
            testCase.verifyEqual(withoutEndpoints.waveFrequency,free.waveFrequency(1,:),RelTol=1e-13)
            testCase.verifyEqual(withoutEndpoints.waveEquivalentDepth,free.waveEquivalentDepth(1,:),RelTol=1e-13)
            testCase.verifyEqual(withoutEndpoints.waveF,free.waveF(:,1,:),AbsTol=1e-12)
            testCase.verifyEqual(withoutEndpoints.waveG,free.waveG(:,1,:),AbsTol=1e-12)
            testCase.verifyEqual(withoutEndpoints.waveGForward,free.waveGForward(1,:,:),AbsTol=1e-12)
        end

        function fixedBoundaryResolutionStillAppliesToLinearPolicy(testCase)
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e4 1e4 1000],[8 8 17],N2Function=@(z)1e-4+0*z,latitude=30, ...
                shouldCheckQuadraticAliasing=false,waveModeCount=0,inertialModeCount=1, ...
                apvModeCount=3,mdaModeCount=2),'WV:UnderresolvedBoundaryGrid')
        end

        function qgLinearPolicyBypassesProductsButRetainsBoundaryLimit(testCase)
            qg=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65], ...
                N2Function=@(z)1e-4+0*z,latitude=30,shouldCheckQuadraticAliasing=false);
            report=qg.constructionAssessment;
            testCase.verifyFalse(qg.shouldCheckQuadraticAliasing)
            testCase.verifyEqual([numel(qg.apvMode) numel(qg.mdaMode)], ...
                [numel(testCase.linearTransform.apvMode) numel(testCase.linearTransform.mdaMode)])
            testCase.verifyEqual(report.quadratic.status,"not-requested")
            testCase.verifyTrue(isnan(qg.quadraticAliasingError))
            testCase.verifyTrue(isnan(qg.apvZeroAPVQuadraticError))
            testCase.verifyEqual(numel(qg.activeEndpoint),2)
            testCase.verifySize(qg.Ag_0,[2 length(qg.klNonzero)])

            limit=WVTransformFreeSurfaceQG.assessVerticalResolution(1000,33, ...
                N2Function=@(z)1e-4+0*z,latitude=30,shouldCheckQuadraticAliasing=false);
            testCase.verifyFalse(limit.shouldCheckQuadraticAliasing)
            testCase.verifyTrue(limit.isHorizontalLimitApplicable)
            testCase.verifyTrue(isnan(limit.quadraticAliasingError))
            testCase.verifyTrue(isnan(limit.maximumSupportedError))
            testCase.verifyTrue(isnan(limit.firstRejectedError))
            testCase.verifyTrue(all(isfinite([limit.maximumSupportedBoundaryError limit.firstRejectedBoundaryError])))
            testCase.verifyEqual(limit.limitingMetric,"boundary-resolution")
            testCase.verifyNotEmpty(limit.limitingEndpoint)
        end

        function boundedQuadraticAPVSearchMatchesFullCandidateSelection(testCase)
            w=testCase.nonlinearTransform;
            report=testCase.nonlinearAssessment.apv.candidateConstruction;
            fullCandidateCount=w.Nz+4;
            problem=IMInternalModes.geostrophicAPVModes(N2=w.N2Function,zDomain=[-w.Lz 0], ...
                g=w.g,g0=w.g0,gd=w.gd,surfaceBoundary="freeSurface");
            basis=IMSolverSpectral(nEVP=w.balancedNEVP).solveEVP(problem,nModes=fullCandidateCount);
            [direct,directAssessment]=basis.discreteTransform(z=w.z,weights=w.verticalQuadratureWeights, ...
                variables=["F","G"],gramTolerance=w.gramTolerance, ...
                quadraticAliasingTolerance=w.quadraticAliasingTolerance);

            testCase.verifyEqual(numel(direct.h),numel(w.apvMode))
            testCase.verifyEqual(report.attemptedCounts(1),min(32,fullCandidateCount))
            testCase.verifyEqual(report.candidateCount,report.attemptedCounts(end))
            testCase.verifyLessThan(report.candidateCount,fullCandidateCount)
            testCase.verifyEqual(report.attemptedCounts(2:end), ...
                min(2*report.attemptedCounts(1:end-1),fullCandidateCount))
            selected=numel(w.apvMode);
            testCase.verifyEqual(testCase.nonlinearAssessment.apv.prefixDiagnostics(selected,:), ...
                directAssessment.prefixDiagnostics(selected,:),AbsTol=64*eps)
        end
    end
end
