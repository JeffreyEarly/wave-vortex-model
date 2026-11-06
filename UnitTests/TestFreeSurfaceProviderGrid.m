classdef TestFreeSurfaceProviderGrid < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function smoothedQGPreservesBoundaryResponsesAndTransfersAcrossMaps(testCase)
            Lxyz = [220e3 175e3 1000];
            Nxyz = [8 6 49];
            N2 = @(z) 1e-5+6e-5*exp(z/200);
            options = struct(N2Function=N2,latitude=-35,rotationRate=6.8e-5,g0=.02,gd=.03,apvModeCount=2,mdaModeCount=2,quadraticDealiasing="none",shouldAntialias=true);
            args = namedargs2cell(options);
            smoothed = WVTransformFreeSurfaceQG(Lxyz,Nxyz,args{:},verticalGridRule="smoothedBandwidth");
            wkb = WVTransformFreeSurfaceQG(Lxyz,Nxyz,args{:});
            testCase.verifyEqual(smoothed.verticalGrid.kind,"smoothedBandwidth");
            testCase.verifyEqual(wkb.verticalGrid.kind,"wkb");
            testCase.verifyGreaterThan(norm(smoothed.z-wkb.z,inf),1);
            expectedLogDerivative = (6e-5/200)*exp(smoothed.z/200)./N2(smoothed.z);
            testCase.verifyEqual(smoothed.dLnN2,expectedLogDerivative,AbsTol=2e-10);

            testCase.assertEqual(smoothed.activeEndpointCount,2);
            F = smoothed.zeroAPVF(:,:,1);
            G = smoothed.zeroAPVG(:,:,1);
            testCase.verifyEqual([G(end,:)-F(end,:);G(1,:)],eye(2),AbsTol=1e-11);
            expectedDerivative = -(smoothed.N2/smoothed.g).*G;
            for endpoint = 1:2
                field = repmat(reshape(F(:,endpoint),1,1,[]),smoothed.Nx,smoothed.Ny,1);
                derivative = smoothed.diffZ(field);
                expected = expectedDerivative(:,endpoint);
                testCase.verifyLessThan(norm(squeeze(derivative(1,1,:))-expected)/norm(expected),2e-6);
            end

            [X,Y] = ndgrid(smoothed.x,smoothed.y);
            horizontal = cos(2*pi*X/smoothed.Lx)+0.5*sin(2*pi*Y/smoothed.Ly);
            vertical = @(z) exp(z/220)+0.15*cos(pi*z/smoothed.Lz);
            field = horizontal.*reshape(vertical(smoothed.z),1,1,[]);
            [transferred,relativeError] = WVInternal.freeSurfaceSpatialTransfer(smoothed,wkb,field);
            expected = horizontal.*reshape(vertical(wkb.z),1,1,[]);
            testCase.verifyEqual(transferred,expected,AbsTol=3e-9);
            testCase.verifyLessThan(relativeError,3e-9);

            smoothed.Ag_q(1,1) = .025+.03i;
            smoothed.Amda(1) = .01;
            [~,assessment] = WVInternal.freeSurfaceCoefficientTransfer(smoothed,wkb);
            testCase.verifyLessThan(assessment.relativeFieldError,2e-7);
            testCase.verifyLessThan(assessment.maximumModeShapeError,2e-7);
        end

        function smoothedBoussinesqRestoresDirectOffGridReconstruction(testCase)
            Lxyz = [200e3 180e3 1000];
            Nxyz = [8 6 33];
            N2 = @(z) 1e-4*exp(z/800);
            wvt = WVTransformFreeSurfaceBoussinesq.fromStratification(Lxyz,Nxyz,N2Function=N2,g0=.02,gd=.03, ...
                apvModeCount=2,mdaModeCount=2,waveModeCount=3,inertialModeCount=2,nEVP=96, ...
                shouldAntialias=true,quadraticDealiasing="none",verticalGridRule="smoothedBandwidth");
            testCase.verifyEqual(wvt.verticalGrid.kind,"smoothedBandwidth");
            testCase.verifyEqual(wvt.z,wvt.verticalGrid.z);
            testCase.verifyEqual(wvt.verticalQuadratureWeights,wvt.verticalGrid.weights);
            wvt.Aw_p(1,1) = .025+.03i;
            wvt.Ag_0(1,1) = .04-.01i;
            wvt.t0 = 4;
            wvt.t = 81;

            zQuery = [-977;-643;-327;-71];
            P = wvt.verticalGrid.calculus.interpolationMatrix(zQuery);
            nativeFields = wvt.reconstructSpectralState();
            expected = P*nativeFields.u;
            testCase.verifyGreaterThan(norm(expected,"fro"),0);

            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            filePath = fullfile(fixture.Folder,'mapped-boussinesq.nc');
            file = wvt.writeToFile(filePath);
            file.close();
            restored = WVTransform.waveVortexTransformFromFile(filePath);
            testCase.verifyEmpty(restored.verticalModes);
            testCase.verifyEqual(restored.coefficientState(),wvt.coefficientState());
            testCase.verifyEqual(restored.verticalGrid.kind,wvt.verticalGrid.kind);
            testCase.verifyEqual(restored.verticalGrid.calculus.snapshot(),wvt.verticalGrid.calculus.snapshot());
            testCase.verifyEqual(restored.verticalDerivativeMatrix,wvt.verticalDerivativeMatrix);
            restoredP = restored.verticalGrid.calculus.interpolationMatrix(zQuery);
            restoredFields = restored.reconstructSpectralState();
            testCase.verifyEqual(restoredP,P);
            testCase.verifyEqual(restoredP*restoredFields.u,expected);
        end
    end
end
