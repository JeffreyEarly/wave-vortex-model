classdef TestFreeSurfaceNonlinearAdvectionGuard < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function constructionAndRegistrationRejectWithoutChangingForcing(testCase)
            wvt = TestFreeSurfaceNonlinearAdvectionGuard.freeSurfaceTransform();
            source = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*ones(wvt.spatialMatrixSize));
            wvt.addForcing(source);
            expected = wvt.forcing;
            testCase.verifyError(@()WVNonlinearAdvection(wvt),'WVNonlinearAdvection:UnsupportedTransform')
            testCase.verifyError(@()wvt.addForcing(WVNonlinearAdvection(wvt)),'WVNonlinearAdvection:UnsupportedTransform')
            testCase.verifyError(@()wvt.setForcing(WVNonlinearAdvection(wvt)),'WVNonlinearAdvection:UnsupportedTransform')
            testCase.verifyEqual(wvt.forcing,expected)
            testCase.verifyTrue(wvt.forcingWithName(source.name) == source)
            testCase.verifyFalse(wvt.hasForcingWithName("nonlinear advection"))
        end

        function conversionAndRestorationRejectUnsupportedOwner(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            supported = WVTransformConstantStratification([40e3 30e3 2e3],[8 6 5],N0=5.2e-3,latitude=45,shouldAntialias=false);
            force = WVNonlinearAdvection(supported);
            wvt = TestFreeSurfaceNonlinearAdvectionGuard.freeSurfaceTransform();
            testCase.verifyError(@()force.forcingWithResolutionOfTransform(wvt),'WVNonlinearAdvection:UnsupportedTransform')
            ncfile = force.writeToFile(fullfile(fixture.Folder,"nonlinear-forcing.nc"));
            cleanup = onCleanup(@()ncfile.close());
            restored = WVForcing.forcingFromGroup(ncfile,supported);
            testCase.verifyClass(restored,'WVNonlinearAdvection')
            testCase.verifyError(@()WVForcing.forcingFromGroup(ncfile,wvt),'WVNonlinearAdvection:UnsupportedTransform')
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
