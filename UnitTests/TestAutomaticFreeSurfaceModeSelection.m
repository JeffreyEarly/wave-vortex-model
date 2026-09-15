classdef TestAutomaticFreeSurfaceModeSelection < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function automaticFamiliesShareBalancedPolicyAndExposeEvidence(testCase)
            N2=@(z)1e-4*ones(size(z));
            qg=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 33],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=N2,latitude=30);
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=N2,latitude=30);
            testCase.verifyEqual(w.apvMode,qg.apvMode)
            testCase.verifyEqual(w.mdaMode,qg.mdaMode)
            testCase.verifyEqual(w.apvF,qg.apvF)
            testCase.verifyEqual(w.mdaG,qg.mdaG)
            testCase.verifyEqual(w.gramTolerance,1e-2)
            testCase.verifyEqual(a.pages.selectedCount,w.waveModeCountByKh)
            for page=1:height(a.pages)
                report=a.modeConvergence{page};
                rows=ismember(report.measurements.columnLabel,report.identity.columnLabels(1:a.pages.selectedCount(page))) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
                testCase.verifyEqual(a.pages.modeConvergenceError(page),max(report.measurements.value(rows)))
            end
            testCase.verifyTrue(all(isnan(a.pages.requestedCount)))
            testCase.verifyEqual(a.inertial.selectedCount,numel(w.inertialMode))
            testCase.verifyLessThanOrEqual(max(a.pages.gramError),w.gramTolerance)
            testCase.verifyLessThanOrEqual(a.inertial.gramError,w.gramTolerance)
            testCase.verifyTrue(all(a.pages.status=="accepted"))
            testCase.verifyEqual(a.dealiasing.quadraticDealiasing,"fixedFraction")
            testCase.verifyEqual(a.pages.filteringCount,floor(a.dealiasing.retainedFraction*a.pages.linearCount))
            testCase.verifyEqual(a.inertial.filteringCount,floor(a.dealiasing.retainedFraction*a.inertial.linearCount))
            testCase.verifyEqual(a.apv.dealiasing.filteringCount,floor(a.dealiasing.retainedFraction*a.apv.dealiasing.linearCount))
            testCase.verifyEqual(a.apv.dealiasing.coordinateKind,a.dealiasing.coordinateKind)
            testCase.verifyEqual(string(cellfun(@(report)report.coordinateKind,a.pages.dealiasing,UniformOutput=false)), ...
                repmat(a.dealiasing.coordinateKind,height(a.pages),1))
            testCase.verifyGreaterThanOrEqual(a.cost.quadraticDealiasingSeconds,0)
            testCase.verifyEqual(w.constructionAssessment,a)
            testCase.verifyEqual(unique(a.boundary.pages.endpoint),["bottom";"surface"])
            state=w.scientificState(); restored=WVTransformFreeSurfaceBoussinesq(state);
            testCase.verifyEqual(restored.scientificState(),state)
            testCase.verifyEmpty(fieldnames(restored.constructionAssessment))
        end

        function finerGridUsesTheFixedFractionOfEachLinearPrefix(testCase)
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=@(z)1e-4+0*z,latitude=30);
            testCase.verifyGreaterThan(min(w.waveModeCountByKh),4)
            testCase.verifyGreaterThan(a.nEVP,64)
            testCase.verifyEqual(w.waveModeCountByKh,a.pages.filteringCount)
            testCase.verifyEqual(a.pages.filteringCount,floor((2/3)*a.pages.linearCount))
            testCase.verifyEqual(a.pages.selectedCount,a.pages.filteringCount)
            amplitudes=w.Aw_p;
            amplitudes(w.activeWaveModes)=1e-3*exp(1i*(1:nnz(w.activeWaveModes)));
            w.Aw_p=amplitudes; w.Aw_m=.5*conj(amplitudes);
            first=w.physicalEnergy();
            w.t=1234; second=w.physicalEnergy();
            testCase.verifyLessThan(abs(second.totalEnergy-first.totalEnergy)/first.totalEnergy,1e-5)
        end

        function explicitCountsAreStrictAndIndependent(testCase)
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=@(z)1e-4+0*z,waveModeCount=3,inertialModeCount=2,apvModeCount=3,mdaModeCount=2);
            testCase.verifyEqual(w.waveModeCountByKh,3*ones(size(w.khUnique)))
            testCase.verifyEqual([numel(w.apvMode),numel(w.mdaMode),numel(w.inertialMode)],[3 2 2])
            testCase.verifyEqual(a.pages.requestedCount,a.pages.selectedCount)
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=@(z)1e-4+0*z,waveModeCount=32,inertialModeCount=2,apvModeCount=3,mdaModeCount=2),'WV:StrictWaveModeCountRejected')
        end

        function fixedBoundariesCannotBeHiddenBySmallWaveCounts(testCase)
            testCase.verifyError(@()WVTransformFreeSurfaceQG([1e4 1e4 1000],[8 8 17],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=@(z)1e-4+0*z,latitude=30,apvModeCount=3,mdaModeCount=2),'WV:UnderresolvedBoundaryGrid')
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification([1e4 1e4 1000],[8 8 17],quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=@(z)1e-4+0*z,latitude=30,waveModeCount=0,inertialModeCount=1,apvModeCount=3,mdaModeCount=2),'WV:UnderresolvedBoundaryGrid')
        end

        function requestingAReportDoesNotChangeConstruction(testCase)
            args=namedargs2cell(struct(quadraticDealiasing="fixedFraction",shouldAntialias=true,N2Function=@(z)1e-4*exp(2*z/700),waveModeCount=3,inertialModeCount=2,apvModeCount=3,mdaModeCount=2));
            first=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],args{:});
            [second,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],args{:});
            A=first.scientificState(); B=second.scientificState();
            testCase.verifyEqual(rmfield(A,{'N2Function','rhoFunction'}),rmfield(B,{'N2Function','rhoFunction'}))
            testCase.verifyEqual(first.waveModeCountByKh,a.pages.selectedCount)
            testCase.verifyNotEmpty(a.referenceNEVP)
        end
    end
end
