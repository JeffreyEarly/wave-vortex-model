classdef TestAutomaticFreeSurfaceModeSelection < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function automaticFamiliesShareBalancedPolicyAndExposeEvidence(testCase)
            N2=@(z)1e-4*ones(size(z));
            qg=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 33],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=N2,latitude=30);
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=N2,latitude=30);
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
            testCase.verifyTrue(a.quadratic.requestedCountAccepted)
            testCase.verifyEmpty(a.quadratic.coverage.missingOutputKappa)
            testCase.verifyEqual(a.quadratic.cost.newEigensolves,0)
            testCase.verifyEqual(a.quadratic.cost.newProductEvaluations,0)
            testCase.verifyLessThanOrEqual(a.cost.selectionTrials,128)
            testCase.verifyLessThanOrEqual(a.quadratic.cost.reservedProducts,500000)
            testCase.verifyEqual(w.constructionAssessment,a)
            testCase.verifyEqual(unique(a.boundary.pages.endpoint),["bottom";"surface"])
            state=w.scientificState(); restored=WVTransformFreeSurfaceBoussinesq(state);
            testCase.verifyEqual(restored.scientificState(),state)
            testCase.verifyEmpty(fieldnames(restored.constructionAssessment))
        end

        function finerGridSupportsANonuniformAutomaticMap(testCase)
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@(z)1e-4+0*z,latitude=30);
            testCase.verifyGreaterThan(numel(unique(w.waveModeCountByKh)),1)
            testCase.verifyGreaterThan(min(w.waveModeCountByKh),4)
            testCase.verifyGreaterThan(a.nEVP,64)
            testCase.verifyTrue(a.quadratic.requestedCountAccepted)
            testCase.verifyEmpty(a.quadratic.coverage.unmeasuredOutputPrefixKappa)
            amplitudes=w.Aw_p;
            amplitudes(w.activeWaveModes)=1e-3*exp(1i*(1:nnz(w.activeWaveModes)));
            w.Aw_p=amplitudes; w.Aw_m=.5*conj(amplitudes);
            first=w.physicalEnergy(); modal=w.totalEnergy;
            w.t=1234; second=w.physicalEnergy();
            testCase.verifyEqual(w.totalEnergy,modal,RelTol=1e-13)
            testCase.verifyLessThan(abs(second.totalEnergy-first.totalEnergy)/first.totalEnergy,1e-5)
        end

        function explicitCountsAreStrictAndIndependent(testCase)
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@(z)1e-4+0*z,waveModeCount=3,inertialModeCount=2,apvModeCount=3,mdaModeCount=2);
            testCase.verifyEqual(w.waveModeCountByKh,3*ones(size(w.khUnique)))
            testCase.verifyEqual([numel(w.apvMode),numel(w.mdaMode),numel(w.inertialMode)],[3 2 2])
            testCase.verifyEqual(a.pages.requestedCount,a.pages.selectedCount)
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@(z)1e-4+0*z,waveModeCount=32,inertialModeCount=2,apvModeCount=3,mdaModeCount=2),'WV:StrictWaveModeCountRejected')
        end

        function fixedBoundariesCannotBeHiddenBySmallWaveCounts(testCase)
            testCase.verifyError(@()WVTransformFreeSurfaceQG([1e4 1e4 1000],[8 8 17],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@(z)1e-4+0*z,latitude=30,apvModeCount=3,mdaModeCount=2),'WV:UnderresolvedBoundaryGrid')
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification([1e4 1e4 1000],[8 8 17],shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@(z)1e-4+0*z,latitude=30,waveModeCount=0,inertialModeCount=1,apvModeCount=3,mdaModeCount=2),'WV:UnderresolvedBoundaryGrid')
        end

        function productBudgetPrecedesReferenceFieldEvaluation(testCase)
            geometry=WVGeometryDoublyPeriodic([1e5 1e5],[64 64],shouldAntialias=true,Nz=65,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            k=geometry.k(:); l=geometry.l(:); nonzero=hypot(k,l)>0;
            k=k(nonzero); l=l(nonzero); kh=uniquetol(hypot(k,l),64*eps,DataScale=max(hypot(k,l)));
            state=struct(Lxyz=[1e5 1e5 1000],Nxyz=[64 64 65],kNonzero=k,lNonzero=l,khUnique=kh,shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@unavailableProfile,rotationRate=1e-4,latitude=30,activeEndpointCount=2,apvMode=(1:8).',mdaMode=(1:3).');
            counts=8*ones(numel(kh),1);
            testCase.verifyError(@()WVInternal.prepareConstructionProducts(state,[],[],[],counts,3,struct(),struct()),'WV:QuadraticConstructionBudget')
            function value=unavailableProfile(~) %#ok<STOUT>
                error('WVTest:UnexpectedProfileEvaluation','Budget admission must precede reference-field evaluation.')
            end
        end

        function requestingAReportDoesNotChangeConstruction(testCase)
            args=namedargs2cell(struct(shouldCheckQuadraticAliasing=true,shouldAntialias=true,N2Function=@(z)1e-4*exp(2*z/700),waveModeCount=3,inertialModeCount=2,apvModeCount=3,mdaModeCount=2));
            first=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],args{:});
            [second,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],args{:});
            A=first.scientificState(); B=second.scientificState();
            testCase.verifyEqual(rmfield(A,{'N2Function','rhoFunction'}),rmfield(B,{'N2Function','rhoFunction'}))
            testCase.verifyEqual(first.waveModeCountByKh,a.pages.selectedCount)
            testCase.verifyNotEmpty(a.referenceNEVP)
        end
    end
end
