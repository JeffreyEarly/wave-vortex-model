classdef TestFreeSurfaceJointResolution < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function boussinesqCouplesBothWaveSignsAndRealMean(testCase)
            L = [1e5 1e5 1000];
            N = [4 4 33];
            options = struct(N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=3,mdaModeCount=2,inertialModeCount=2);
            args = namedargs2cell(options);
            [w,report] = WVTransformFreeSurfaceBoussinesq.fromStratification(L,N,args{:},waveModeCount=2);
            joint = report.joint;
            p = joint.pages(1);
            testCase.verifyEqual(joint.status,"measured")
            testCase.verifyEqual(p.kappa,w.khUnique(1))
            testCase.verifyEqual(p.columnCount,3+w.activeEndpointCount+4)
            testCase.verifyEqual(nnz(startsWith(p.columnLabels,"Aw_p:")),2)
            testCase.verifyEqual(nnz(startsWith(p.columnLabels,"Aw_m:")),2)
            testCase.verifyEqual(p.recovery.observation.rank,p.columnCount)
            testCase.verifyTrue(isfinite(p.recovery.observationNoiseGain))
            testCase.verifyEqual(p.productionInversion.status,"not-applicable")
            testCase.verifyEqual(p.reference.status,"measured")
            testCase.verifyLessThan(p.reference.retainedFieldError,1e-2)
            testCase.verifyLessThan(p.reference.sourceError,1e-2)
            testCase.verifyEqual(joint.mean.columnCount,2*numel(w.inertialMode)+numel(w.mdaMode))
            testCase.verifyEqual(joint.mean.recovery.observation.rank,joint.mean.columnCount)
            testCase.verifyTrue(any(startsWith(joint.mean.columnLabels,"Aio.imag:")))

            [w,report] = WVTransformFreeSurfaceBoussinesq.fromStratification(L,N,args{:},waveModeCount=0);
            testCase.verifyTrue(all(arrayfun(@(p)~any(startsWith(p.columnLabels,"Aw_")),report.joint.pages)))
            testCase.verifyEqual([report.joint.pages.columnCount], ...
                repmat(numel(w.apvMode)+w.activeEndpointCount,1,numel(w.khUnique)))
            testCase.verifyTrue(all(arrayfun(@(p)p.reference.status=="measured",report.joint.pages)))
        end

        function qgDistinguishesPhysicalProjectionAndSampledInversion(testCase)
            w = WVTransformFreeSurfaceQG([1e5 1e5 1000],[4 4 33],N2Function=@(z)1e-4*exp(z/700), ...
                latitude=30,apvModeCount=3,mdaModeCount=2);
            report = w.constructionAssessment.joint;
            p = report.pages(1);
            testCase.verifyEqual(report.status,"measured")
            testCase.verifyEqual(p.columnCount,3+w.activeEndpointCount)
            testCase.verifyEqual(p.recovery.observation.rank,p.columnCount)
            testCase.verifyEqual(p.productionInversion.status,"measured")
            testCase.verifyLessThan(p.productionInversion.roundTripError,1e-10)
            testCase.verifyGreaterThan(p.physicalProjectionOverlapError,p.productionInversion.roundTripError)
            testCase.verifyEqual(p.reference.status,"measured")
            testCase.verifyLessThan(p.reference.sourceError,1e-2)
            testCase.verifyEqual(report.mean.reference.sourceStatus,"not-applicable")
            testCase.verifyEqual(report.mean.columnCount,w.mdaModeCount)
        end

        function deficientJointSynthesisHasNoNoiseMeasurement(testCase)
            w = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[4 4 33], ...
                N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=0);
            state = w.scientificState();
            state.inertialF(:,2) = state.inertialF(:,1);
            unresolved = WVTransformFreeSurfaceBoussinesq(state);
            report = WVInternal.assessFreeSurfaceJointResolution(unresolved);
            testCase.verifyEqual(report.status,"rank-deficient")
            testCase.verifyEqual(report.limitingKappa,0)
            testCase.verifyLessThan(report.mean.recovery.observation.rank,report.mean.columnCount)
            testCase.verifyEqual(report.mean.recovery.observationNoiseGainStatus,"unavailable")
            testCase.verifyTrue(isnan(report.mean.recovery.observationNoiseGain))
            testCase.verifyEqual(report.mean.reference.status,"unassessed")
            testCase.verifyError(@()WVInternal.assessFreeSurfaceJointResolution(unresolved,failureMode="error"), ...
                "WV:UnresolvedJointSynthesis")
        end
    end
end
