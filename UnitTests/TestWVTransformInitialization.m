classdef TestWVTransformInitialization < matlab.unittest.TestCase
    properties (TestParameter)
        transform = {'constant','hydrostatic','boussinesq','stratified-qg','barotropic-qg'}
        latitude = struct('southOutside',-86,'southUpperBoundary',-85,'southLowerBoundary',-5,'southInsideLowerBoundary',-4,'equator',0,'northInsideLowerBoundary',4,'northLowerBoundary',5,'northUpperBoundary',85,'northOutside',86)
    end

    methods (Test, TestTags = "full")
        function stratifiedQGConvertsKConstantModesToGeostrophicNormalization(testCase)
            N2 = @(z)2e-5*exp(z/4000);
            wvt = WVTransformStratifiedQG([4000 3000 1000],[8 6 5],N2Function=N2,latitude=45,shouldAntialias=false);

            testCase.verifyEqual(wvt.verticalModes.normalization,Normalization.kConstant)
            [F,G,h,~,geostrophicRatio] = wvt.verticalModes.modesAtFrequency(0,"geostrophicNorm");
            nBaroclinic = wvt.Nj-1;
            expectedFinv = [ones(wvt.Nz,1),F(:,1:nBaroclinic).*geostrophicRatio(1:nBaroclinic)];
            expectedGinv = zeros(wvt.Nz,wvt.Nj);
            expectedGinv(2:end-1,2:end) = G(2:end-1,1:nBaroclinic).*geostrophicRatio(1:nBaroclinic);

            testCase.verifyEqual(wvt.FinvMatrix,expectedFinv,RelTol=1e-12,AbsTol=1e-13)
            testCase.verifyEqual(wvt.GinvMatrix,expectedGinv,RelTol=1e-12,AbsTol=1e-13)
            testCase.verifyEqual(wvt.h_0,[1;h(1:nBaroclinic).'],RelTol=1e-12,AbsTol=1e-13)
        end
    end

    methods (Test, TestTags = "full")
        function testInitWithLatitude(testCase,transform,latitude)
            constructor = @()TestWVTransformInitialization.transformAtLatitude(transform,latitude);
            if abs(latitude) < 5
                testCase.verifyError(constructor,'MATLAB:validators:mustBeGreaterThanOrEqual')
            elseif abs(latitude) > 85
                testCase.verifyError(constructor,'MATLAB:validators:mustBeLessThanOrEqual')
            else
                testCase.verifyWarningFree(constructor)
            end
        end
    end

    methods (Static, Access=private)
        function wvt = transformAtLatitude(transform,latitude)
            Lxyz = [15e3 15e3 5000];
            Nxyz = [8 8 5];
            N2 = @(z)(5.2e-3)^2*ones(size(z));
            switch transform
                case 'constant'
                    wvt = WVTransformConstantStratification(Lxyz,Nxyz,latitude=latitude,shouldAntialias=false);
                case 'hydrostatic'
                    wvt = WVTransformHydrostatic(Lxyz,Nxyz,N2=N2,latitude=latitude,shouldAntialias=false);
                case 'boussinesq'
                    wvt = WVTransformBoussinesq(Lxyz,Nxyz,N2=N2,latitude=latitude,shouldAntialias=false);
                case 'stratified-qg'
                    wvt = WVTransformStratifiedQG(Lxyz,Nxyz,N2=N2,latitude=latitude,shouldAntialias=false);
                case 'barotropic-qg'
                    wvt = WVTransformBarotropicQG(Lxyz(1:2),Nxyz(1:2),latitude=latitude,shouldAntialias=false);
                otherwise
                    error("TestWVTransformInitialization:UnknownTransform","Unknown transform parameter %s.",transform)
            end
        end
    end
end
