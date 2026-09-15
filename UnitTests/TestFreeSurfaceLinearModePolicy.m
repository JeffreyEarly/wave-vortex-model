classdef TestFreeSurfaceLinearModePolicy < matlab.unittest.TestCase
    properties (SetAccess=private)
        linearTransform
        linearAssessment
        filteredTransform
        filteredAssessment
    end

    methods (TestClassSetup)
        function constructMatchedPolicies(testCase)
            N2=@(z)1e-4+0*z;
            [testCase.linearTransform,testCase.linearAssessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=N2,latitude=30,nEVP=69,shouldAntialias=true,quadraticDealiasing="none");
            [testCase.filteredTransform,testCase.filteredAssessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=N2,latitude=30,nEVP=69,shouldAntialias=true,quadraticDealiasing="fixedFraction");
        end
    end

    methods (Test, TestTags="full")
        function defaultAndNonePoliciesExposeTheirLimits(testCase)
            linear=testCase.linearTransform; filtered=testCase.filteredTransform;
            linearReport=testCase.linearAssessment; filteredReport=testCase.filteredAssessment;
            qgNone=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65], ...
                N2Function=@(z)1e-4+0*z,latitude=30,quadraticDealiasing="none");
            defaultSmall=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30, ...
                waveModeCount=1,inertialModeCount=1,apvModeCount=1,mdaModeCount=1);

            testCase.verifyEqual(linear.quadraticDealiasing,"none")
            testCase.verifyEqual(filtered.quadraticDealiasing,"fixedFraction")
            testCase.verifyEqual(defaultSmall.quadraticDealiasing,"fixedFraction")
            testCase.verifyEqual([filtered.retainedFraction filtered.energyFraction filtered.bandwidthFraction],[2/3 .99 2/3])
            testCase.verifyFalse(defaultSmall.shouldAntialias)
            testCase.verifyEqual(qgNone.quadraticDealiasing,"none")
            testCase.verifyTrue(qgNone.shouldAntialias)
            testCase.verifyEqual([numel(qgNone.apvMode) numel(qgNone.mdaMode)], ...
                [numel(linear.apvMode) numel(linear.mdaMode)])
            testCase.verifyEqual(qgNone.constructionAssessment.apv.selectedCount, ...
                qgNone.constructionAssessment.apv.linearCount)
            testCase.verifyEqual(linear.waveModeCountByKh,38*ones(4,1))
            testCase.verifyEqual(linearReport.pages.linearCount,linearReport.pages.selectedCount)
            testCase.verifyEqual(linearReport.pages.filteringCount,linearReport.pages.linearCount)
            testCase.verifyEqual(linearReport.inertial.filteringCount,linearReport.inertial.linearCount)
            testCase.verifyEqual(filteredReport.pages.filteringCount,floor((2/3)*filteredReport.pages.linearCount))
            testCase.verifyEqual(filteredReport.inertial.filteringCount,floor((2/3)*filteredReport.inertial.linearCount))
            testCase.verifyEqual(filtered.waveModeCountByKh,filteredReport.pages.selectedCount)
            testCase.verifyEqual(numel(filtered.inertialMode),filteredReport.inertial.selectedCount)
            testCase.verifyEqual(numel(filtered.apvMode),filteredReport.apv.dealiasing.selectedCount)
            verifyDealiasingMetadata(testCase,linearReport,"none")
            verifyDealiasingMetadata(testCase,filteredReport,"fixedFraction")
            testCase.verifyEqual(filteredReport.apv.dealiasing.coordinateKind,"wkb-chebyshev-lobatto")
            testCase.verifyEqual(filteredReport.apv.dealiasing.filteringCount, ...
                floor((2/3)*filteredReport.apv.dealiasing.linearCount))
        end

        function noneIgnoresFilteringParametersAndSurvivesPersistence(testCase)
            linear=testCase.linearTransform;
            [changed,assessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30,shouldAntialias=true, ...
                quadraticDealiasing="none",retainedFraction=.4,energyFraction=.9,bandwidthFraction=.5);
            testCase.verifyEqual(changed.waveModeCountByKh,linear.waveModeCountByKh)
            testCase.verifyEqual([numel(changed.inertialMode) numel(changed.apvMode) numel(changed.mdaMode)], ...
                [numel(linear.inertialMode) numel(linear.apvMode) numel(linear.mdaMode)])
            testCase.verifyEqual(assessment.pages.selectedCount,assessment.pages.linearCount)
            testCase.verifyEqual(assessment.inertial.selectedCount,assessment.inertial.linearCount)
            testCase.verifyEqual(assessment.apv.dealiasing.selectedCount,assessment.apv.dealiasing.linearCount)

            state=changed.scientificState(); restored=WVTransformFreeSurfaceBoussinesq(state);
            testCase.verifyEqual(restored.scientificState(),state)
            testCase.verifyEqual(restored.quadraticDealiasing,"none")
            testCase.verifyEqual([restored.retainedFraction restored.energyFraction restored.bandwidthFraction],[.4 .9 .5])
            transferred=changed.waveVortexTransformWithResolution([8 8 65]);
            testCase.verifyEqual(transferred.quadraticDealiasing,"none")
            testCase.verifyEqual([transferred.retainedFraction transferred.energyFraction transferred.bandwidthFraction],[.4 .9 .5])
            testCase.verifyEqual(transferred.waveModeCountByKh,changed.waveModeCountByKh)
        end

        function explicitCountsUseFullLinearFilteringCapacity(testCase)
            filtered=testCase.filteredAssessment;
            keys=testCase.filteredTransform.khUnique;
            requested=min(filtered.pages.filteringCount,[0;2;3;0]);
            [w,assessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,latitude=30,nEVP=69,shouldAntialias=true,quadraticDealiasing="fixedFraction", ...
                waveModeKappa=keys,waveModeCount=requested,inertialModeCount=2,apvModeCount=2,mdaModeCount=2);
            testCase.verifyEqual(w.waveModeCountByKh,requested)
            testCase.verifyEqual(assessment.pages.selectedCount,requested)
            testCase.verifyGreaterThanOrEqual(assessment.pages.filteringCount,requested)
            testCase.verifyGreaterThan(assessment.pages.linearCount(requested>0),requested(requested>0))
            testCase.verifyEqual(assessment.pages.linearCount,filtered.pages.linearCount)
            testCase.verifyEqual(assessment.pages.filteringCount,filtered.pages.filteringCount)
            testCase.verifyEqual(assessment.inertial.selectedCount,2)
            testCase.verifyGreaterThan(assessment.inertial.linearCount,assessment.inertial.selectedCount)
            testCase.verifyEqual(assessment.inertial.linearCount,filtered.inertial.linearCount)
            testCase.verifyEqual(assessment.inertial.filteringCount,filtered.inertial.filteringCount)
            testCase.verifyEqual(assessment.apv.dealiasing.selectedCount,2)
            testCase.verifyGreaterThan(assessment.apv.dealiasing.linearCount,assessment.apv.dealiasing.selectedCount)
            testCase.verifyEqual(assessment.nEVP,filtered.nEVP)
            testCase.verifyEqual(assessment.referenceNEVP,filtered.referenceNEVP)
            testCase.verifyGreaterThan(assessment.nEVP,w.Nz+4)
            testCase.verifyTrue(any(requested==2))
            testCase.verifyNotEqual(requested(requested==2),floor((2/3)*requested(requested==2)))
            testCase.verifyEqual(assessment.pages.status(requested==0),repmat("not-requested",nnz(requested==0),1))
            testCase.verifyTrue(all(cellfun(@isempty,assessment.modeConvergence(requested==0))))
        end

        function filteringRejectsOnlyCountsAboveIndependentLimits(testCase)
            filtered=testCase.filteredAssessment; linear=testCase.linearAssessment;
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,quadraticDealiasing="fixedFraction", ...
                waveModeCount=linear.pages.linearCount(1),inertialModeCount=1,apvModeCount=1,mdaModeCount=1), ...
                'WV:QuadraticDealiasingWaveCountRejected')
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,quadraticDealiasing="fixedFraction", ...
                waveModeCount=0,inertialModeCount=linear.inertial.linearCount,apvModeCount=1,mdaModeCount=1), ...
                'WV:QuadraticDealiasingInertialCountRejected')
            testCase.verifyError(@()WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65], ...
                N2Function=@(z)1e-4+0*z,quadraticDealiasing="fixedFraction", ...
                apvModeCount=linear.apv.dealiasing.linearCount,mdaModeCount=1), ...
                'WV:QuadraticDealiasingAPVCountRejected')
            testCase.verifyLessThan(filtered.pages.filteringCount,linear.pages.linearCount)
            testCase.verifyLessThan(filtered.inertial.filteringCount,linear.inertial.linearCount)
        end

        function effectiveBandwidthUsesCommonWKBShapes(testCase)
            [w,assessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e5 1e5 1000],[8 8 33],N2Function=@(z)1e-4*exp(2*z/700), ...
                quadraticDealiasing="effectiveBandwidth",energyFraction=.97,bandwidthFraction=.6);
            testCase.verifyEqual(w.quadraticDealiasing,"effectiveBandwidth")
            testCase.verifyEqual([w.energyFraction w.bandwidthFraction],[.97 .6])
            testCase.verifyEqual(assessment.dealiasing.coordinateKind,"wkb-chebyshev-lobatto")
            testCase.verifyEqual(assessment.pages.selectedCount,assessment.pages.filteringCount)
            testCase.verifyEqual(assessment.inertial.selectedCount,assessment.inertial.filteringCount)
            testCase.verifyEqual(assessment.apv.dealiasing.selectedCount,assessment.apv.dealiasing.filteringCount)
            testCase.verifySize(w.waveF,[w.Nz numel(w.waveMode) numel(w.khUnique)])
            testCase.verifySize(w.waveG,[w.Nz numel(w.waveMode) numel(w.khUnique)])
            testCase.verifySize(w.apvF,[w.Nz numel(w.apvMode)])
            testCase.verifySize(w.apvG,[w.Nz numel(w.apvMode)])
            for p=1:height(assessment.pages)
                report=assessment.pages.dealiasing{p};
                testCase.verifyEqual(report.coordinateKind,assessment.dealiasing.coordinateKind)
                testCase.verifyEqual(numel(report.effectiveDegreeF),assessment.pages.linearCount(p))
                testCase.verifyEqual(numel(report.effectiveDegreeG),assessment.pages.linearCount(p))
            end
            testCase.verifyEqual(assessment.inertial.dealiasing.coordinateKind,assessment.dealiasing.coordinateKind)
            testCase.verifyEqual(assessment.apv.dealiasing.coordinateKind,assessment.dealiasing.coordinateKind)
        end

        function automaticZeroFilteringHasDistinctStatus(testCase)
            [w,assessment]=WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e3 1e3 1000],[8 8 33],N2Function=@(z)1e-4*exp(2*z/700),g0=Inf,gd=Inf, ...
                shouldAntialias=true,quadraticDealiasing="effectiveBandwidth", ...
                energyFraction=.9,bandwidthFraction=.05);
            filteredOut=assessment.pages.filteringCount==0 & assessment.pages.linearCount>0;
            testCase.verifyTrue(any(filteredOut))
            testCase.verifyEqual(w.waveModeCountByKh(filteredOut),zeros(nnz(filteredOut),1))
            testCase.verifyEqual(assessment.pages.status(filteredOut),repmat("filtered-out",nnz(filteredOut),1))
            testCase.verifyEqual(assessment.pages.limitingMetric(filteredOut), ...
                repmat("quadratic-dealiasing",nnz(filteredOut),1))
            testCase.verifyTrue(all(cellfun(@(report)~isempty(report),assessment.modeConvergence(filteredOut))))
        end

        function explicitAPVHeadSurvivesUnconvergedIndependentTail(testCase)
            qg=WVTransformFreeSurfaceQG([1e9 1e9 1000],[4 4 33], ...
                N2Function=@(z)1e-4*exp(2*z/700),g0=.02,gd=.03,quadraticDealiasing="none", ...
                modeConvergenceTolerance=1e-12,apvModeCount=1);
            assessment=qg.constructionAssessment;
            testCase.verifyEqual(qg.apvModeCount,1)
            testCase.verifyEqual(assessment.apv.selectedCount,1)
            testCase.verifyGreaterThan(assessment.apv.linearCount,assessment.apv.selectedCount)
            testCase.verifyGreaterThan(numel(assessment.apv.convergence.identity.columnLabels), ...
                assessment.apv.linearCount)
        end

        function fixedBoundaryResolutionStillAppliesToNone(testCase)
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification( ...
                [1e4 1e4 1000],[8 8 17],N2Function=@(z)1e-4+0*z,latitude=30,quadraticDealiasing="none", ...
                waveModeCount=0,inertialModeCount=1,apvModeCount=3,mdaModeCount=2),'WV:UnderresolvedBoundaryGrid')
        end
    end
end

function verifyDealiasingMetadata(testCase,assessment,policy)
testCase.verifyEqual(assessment.dealiasing.quadraticDealiasing,policy)
testCase.verifyEqual(assessment.dealiasing.retainedFraction,2/3)
testCase.verifyEqual(assessment.dealiasing.energyFraction,.99)
testCase.verifyEqual(assessment.dealiasing.bandwidthFraction,2/3)
testCase.verifyEqual(assessment.dealiasing.gridDegree,64)
testCase.verifyEqual(assessment.dealiasing.coordinateKind,"wkb-chebyshev-lobatto")
for p=1:height(assessment.pages)
    testCase.verifyEqual(assessment.pages.dealiasing{p}.coordinateKind,assessment.dealiasing.coordinateKind)
end
testCase.verifyEqual(assessment.inertial.dealiasing.coordinateKind,assessment.dealiasing.coordinateKind)
end
