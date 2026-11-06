classdef TestFreeSurfaceResolutionContract < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function strictWaveMapReportsCeilingsAndSkipsEmptyPages(testCase)
            Lxyz = [1e5 1e5 1000];
            Nxyz = [8 8 33];
            N2 = @(z) 1e-4 + zeros(size(z));
            qg = WVTransformFreeSurfaceQG(Lxyz,Nxyz,N2Function=N2,latitude=30, ...
                apvModeCount=3,mdaModeCount=2,quadraticDealiasing="none");
            kappa = qg.khUnique;
            requested = 2*ones(size(kappa));
            requested(1) = 1;
            requested(end) = 0;
            [w,report] = WVTransformFreeSurfaceBoussinesq.fromStratification(Lxyz,Nxyz, ...
                N2Function=N2,latitude=30,shouldAntialias=qg.shouldAntialias,apvModeCount=3,mdaModeCount=2, ...
                inertialModeCount=3,waveModeKappa=kappa,waveModeCount=requested,quadraticDealiasing="none", ...
                nEVP=24,referenceNEVP=36);

            testCase.verifyEqual(report.grid,qg.constructionAssessment.grid)
            testCase.verifyEqual(report.grid.rule,"smoothedBandwidth")
            testCase.verifyEqual(report.grid.Nz,w.Nz)
            testCase.verifyEqual(report.waveEVP.candidateNEVP,24)
            testCase.verifyEqual(report.waveEVP.referenceNEVP,36)
            testCase.verifyEqual(report.grid.maximumRetainedKh,max(kappa))
            testCase.verifyEqual(report.pages.candidateCount,requested)
            testCase.verifyEqual(report.pages.selectedCount,requested)
            testCase.verifyTrue(all(report.pages.candidateLimitReached(requested>0)))
            testCase.verifyFalse(report.pages.candidateLimitReached(end))
            testCase.verifyEqual(report.pages.status(end),"not-requested")
            testCase.verifyEmpty(report.modeConvergence{end})
            testCase.verifyEqual(report.inertial.candidateCount,3)
            testCase.verifyEqual(report.apv.selectedCount,3)
            testCase.verifyEqual(report.mda.selectedCount,2)
            testCase.verifyEqual(unique(string({report.verticalProducts.probes.family})),["APV","inertial","wave"])
            testCase.verifyEqual(report.verticalProducts.fullNonlinearInteractions,"unassessed")
            testCase.verifyLessThan(max([report.verticalProducts.probes.referenceQuadratureError]),1e-9)
        end

        function thermalReportsIndependentSamplingAndQuadratureCounts(testCase)
            w = WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[4 4 65], ...
                N2Function=@(z) 1e-4 + zeros(size(z)),thermalModeCount=17,mdaModeCount=4, ...
                assemblyQuadratureCount=101,nonlinearQuadratureCount=77,shouldCheckQuadraticAliasing=true);
            report = w.constructionAssessment;
            testCase.verifyEqual(report.grid.rule,"wkb")
            testCase.verifyEqual(report.grid.Nz,65)
            testCase.verifyEqual(report.thermalModeCount,17)
            testCase.verifyEqual(report.mdaCount,4)
            testCase.verifyEqual(report.assemblyQuadratureCount,101)
            testCase.verifyEqual(report.nonlinearQuadratureCount,77)
            testCase.verifyEqual(report.polynomialDegree,(0:16).')
        end
    end
end
