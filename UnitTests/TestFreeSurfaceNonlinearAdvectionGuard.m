classdef TestFreeSurfaceNonlinearAdvectionGuard < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function unqualifiedActivationRejectsWithoutChangingForcing(testCase)
            wvt = TestFreeSurfaceNonlinearAdvectionGuard.freeSurfaceTransform();
            source = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*ones(wvt.spatialMatrixSize));
            wvt.addForcing(source);
            expected = wvt.forcing;
            force = WVNonlinearAdvection(wvt);
            testCase.verifyClass(force,'WVNonlinearAdvection')
            testCase.verifyError(@()wvt.addForcing(force),'WVTransformFreeSurfaceBoussinesq:NonlinearInventoryUnqualified')
            testCase.verifyError(@()wvt.setForcing(force),'WVTransformFreeSurfaceBoussinesq:NonlinearInventoryUnqualified')
            testCase.verifyEqual(wvt.forcing,expected)
            testCase.verifyTrue(wvt.forcingWithName(source.name) == source)
            testCase.verifyFalse(wvt.hasForcingWithName("nonlinear advection"))
        end

        function conversionAndRestorationStillRequireQualifiedActivation(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            supported = WVTransformConstantStratification([40e3 30e3 2e3],[8 6 5],N0=5.2e-3,latitude=45,shouldAntialias=false);
            force = WVNonlinearAdvection(supported);
            wvt = TestFreeSurfaceNonlinearAdvectionGuard.freeSurfaceTransform();
            converted = force.forcingWithResolutionOfTransform(wvt);
            testCase.verifyClass(converted,'WVNonlinearAdvection')
            testCase.verifyError(@()wvt.addForcing(converted),'WVTransformFreeSurfaceBoussinesq:NonlinearInventoryUnqualified')
            ncfile = force.writeToFile(fullfile(fixture.Folder,"nonlinear-forcing.nc"));
            cleanup = onCleanup(@()ncfile.close());
            restored = WVForcing.forcingFromGroup(ncfile,supported);
            testCase.verifyClass(restored,'WVNonlinearAdvection')
            mapped = WVForcing.forcingFromGroup(ncfile,wvt);
            testCase.verifyClass(mapped,'WVNonlinearAdvection')
            testCase.verifyError(@()wvt.addForcing(mapped),'WVTransformFreeSurfaceBoussinesq:NonlinearInventoryUnqualified')
            testCase.verifyEmpty(wvt.forcing)
        end

        function quasigeostrophicTransformsRetainNonlinearAdvection(testCase)
            barotropic = WVTransformBarotropicQG([40e3 30e3],[8 6],latitude=45,shouldAntialias=false);
            freeSurface = WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 33],N2Function=@(z)1e-4+0*z,apvModeCount=3,mdaModeCount=2);
            for wvt = {barotropic,freeSurface}
                force = WVNonlinearAdvection(wvt{1});
                wvt{1}.setForcing(force);
                testCase.verifyTrue(wvt{1}.forcingWithName("nonlinear advection") == force)
            end
        end
    end

    methods (Static, Access=private)
        function wvt = freeSurfaceTransform()
            wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],N2Function=@(z)1e-4+0*z,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
        end
    end
end
