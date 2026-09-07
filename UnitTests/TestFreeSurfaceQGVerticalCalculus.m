classdef TestFreeSurfaceQGVerticalCalculus < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function zeroAPVModesDifferentiateWithoutAPVProjection(testCase)
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),g0=.02,gd=.03,mdaGramTolerance=.1);
            for endpoint = 1:w.activeEndpointCount
                F = w.zeroAPVF(:,endpoint,1);
                expected = -(w.N2/w.g).*w.zeroAPVG(:,endpoint,1);
                values = repmat(reshape(F,1,1,[]),w.Nx,w.Ny,1);
                actual = w.diffZF(values);
                testCase.verifyLessThan(norm(squeeze(actual(1,1,:))-expected)/norm(expected),1e-10)
                actual = w.diffZG(values);
                testCase.verifyLessThan(norm(squeeze(actual(1,1,:))-expected)/norm(expected),1e-10)
            end
        end

        function allFamiliesAndMixedFieldsSatisfyModeIdentities(testCase)
            for variableN = [false true]
                if variableN
                    N2 = @(z) 1e-4*exp(z/4000);
                else
                    N2 = @(z) 1e-4*ones(size(z));
                end
                w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 6 33],N2Function=N2,g0=.02,gd=.03,mdaGramTolerance=.1);
                apv = 3;
                mda = 3;
                profiles = [w.apvF(:,apv),w.apvG(:,apv),w.zeroAPVF(:,1,1),w.zeroAPVG(:,1,1),w.mdaG(:,mda)];
                derivatives = [-(w.N2/w.g).*w.apvG(:,apv),w.apvF(:,apv)/w.apvEquivalentDepth(apv),-(w.N2/w.g).*w.zeroAPVG(:,1,1),-(w.g*w.khUnique(1)^2/w.f^2)*w.zeroAPVF(:,1,1),(w.mdaF(:,mda)+(w.g0/w.g)*w.mdaG(end,mda))/w.mdaEquivalentDepth(mda)];
                % Normalize before mixing so each family's contribution matters.
                scale = vecnorm(profiles);
                profiles = profiles./scale;
                derivatives = derivatives./scale;
                fieldProfiles = [profiles,profiles*(1:5).'];
                fieldDerivatives = [derivatives,derivatives*(1:5).'];
                [X,Y] = ndgrid(w.x,w.y);
                horizontal = cos(2*pi*X/w.Lx)+1i*sin(2*pi*Y/w.Ly);
                for column = 1:size(fieldProfiles,2)
                    values = horizontal.*reshape(fieldProfiles(:,column),1,1,[]);
                    expected = horizontal.*reshape(fieldDerivatives(:,column),1,1,[]);
                    actual = w.diffZ(values);
                    testCase.verifyLessThan(norm(actual(:)-expected(:))/norm(expected(:)),1e-5)
                    testCase.verifyEqual(w.diffZF(values),actual)
                    testCase.verifyEqual(w.diffZG(values),actual)
                end
            end
        end

        function mappedHigherDerivativesIncludeVariableMetric(testCase)
            % N grows exponentially, so the WKB metric is not constant.
            % exp(3*z/B) is a cubic polynomial in the exact native coordinate,
            % yet all its physical derivatives, including the fourth, are nonzero.
            B = 4000;
            w = WVTransformFreeSurfaceQG([500e3 500e3 1000],[8 6 9],N2Function=@(z)1e-4*exp(2*z/B),g0=.02,gd=.03,mdaGramTolerance=.1);
            [X,Y] = ndgrid(w.x,w.y);
            horizontal = cos(2*pi*X/w.Lx)+1i*sin(2*pi*Y/w.Ly);
            values = horizontal.*reshape(exp(3*w.z/B),1,1,[]);
            for n = 1:4
                expected = (3/B)^n*values;
                actual = w.diffZ(values,n=n);
                testCase.verifyLessThan(norm(actual(:)-expected(:))/norm(expected(:)),1e-4,sprintf('Physical derivative order %d',n))
                testCase.verifyEqual(w.diffZF(values,n=n),actual)
                testCase.verifyEqual(w.diffZG(values,n=n),actual)
            end
        end

        function constantStratificationPolynomialsHavePhysicalDerivatives(testCase)
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 6 17],N2Function=@(z)1e-4*ones(size(z)),g0=.02,gd=.03,mdaGramTolerance=.1);
            [X,Y] = ndgrid(w.x,w.y);
            horizontal = cos(2*pi*X/w.Lx)+1i*sin(2*pi*Y/w.Ly);
            s = (w.z+w.Lz)/w.Lz;
            values = horizontal.*reshape(s.^5,1,1,[]);
            for n = 1:4
                expected = horizontal.*reshape(factorial(5)/factorial(5-n)*s.^(5-n)/w.Lz^n,1,1,[]);
                actual = w.diffZ(values,n=n);
                testCase.verifyLessThan(norm(actual(:)-expected(:))/norm(expected(:)),1e-7)
            end
            constant = ones(w.Nx,w.Ny,w.Nz);
            testCase.verifyLessThan(max(abs(w.diffZ(constant)),[],'all')*w.Lz,1e-10)
        end

        function gaussianInitializationMatchesAnalyticQGPVProjection(testCase)
            errors = zeros(2,1);
            for iGrid = 1:2
                nz = [13 33];
                B = 4000;
                w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 nz(iGrid)],N2Function=@(z)1e-4*exp(2*z/B),g0=.02,gd=.03,mdaGramTolerance=.1);
                U = .05; Le = 20e3; He = 250; zc = 75;
                center = [.35*w.Lx .65*w.Ly];
                w.initWithGaussianEddy(maximumSpeed=U,horizontalRadius=Le,verticalScale=He,zCenter=zc,center=center);
                k = reshape(w.k,1,[]); l = reshape(w.l,1,[]); kh2 = k.^2+l.^2;
                horizontal = pi*Le^2/(w.Lx*w.Ly)*exp(-Le^2*kh2/4).*exp(-1i*(k*center(1)+l*center(2)));
                profile = exp(-(w.z-zc).^2/(2*He^2));
                first = -(w.z-zc)/He^2.*profile;
                second = ((w.z-zc).^2/He^4-1/He^2).*profile;
                amplitude = U*Le*exp(.5)/sqrt(2);
                psi = amplitude*profile*horizontal;
                eta = -(w.f./w.N2).*(amplitude*first*horizontal);
                q = -kh2.*psi+(w.f^2./w.N2).*(amplitude*(second-(2/B)*first)*horizontal);
                endpoints = [eta(end,:)-(w.f/w.g)*psi(end,:);eta(1,:)];
                [expectedQ,expected0] = w.transformStateForward(q(:,w.klNonzero),endpoints(:,w.klNonzero));
                errors(iGrid) = norm(w.Ag_q-expectedQ,'fro')/norm(expectedQ,'fro');
                testCase.verifyLessThan(norm(w.Ag_0-expected0,'fro')/norm(expected0,'fro'),1e-4)
                [~,actualEndpoints] = w.transformStateBack(w.Ag_q,w.Ag_0);
                testCase.verifyLessThan(norm(actualEndpoints-endpoints(:,w.klNonzero),'fro')/norm(endpoints(:,w.klNonzero),'fro'),1e-10)
            end
            testCase.verifyLessThan(errors(1),1e-4)
            testCase.verifyLessThan(errors(2),1e-6)
            testCase.verifyLessThan(errors(2),errors(1))
        end

        function restoredRuleDifferentiatesWithoutModeConstruction(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 6 17],N2Function=@(z)1e-4*exp(z/4000),g0=.02,gd=.03,mdaGramTolerance=.1);
            file = fullfile(fixture.Folder,'vertical-calculus.nc');
            nc = w.writeToFile(file); nc.close();
            restored = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
            testCase.verifyEmpty(restored.verticalModes)
            testCase.verifyEqual(restored.verticalDerivativeMatrix,w.verticalDerivativeMatrix)
            values = repmat(reshape(exp(w.z/w.Lz),1,1,[]),w.Nx,w.Ny,1);
            for n = 1:4
                testCase.verifyEqual(restored.diffZ(values,n=n),w.diffZ(values,n=n))
                testCase.verifyEqual(restored.diffZF(values,n=n),w.diffZF(values,n=n))
                testCase.verifyEqual(restored.diffZG(values,n=n),w.diffZG(values,n=n))
            end
        end

        function validationPreservesGridAndOrderContract(testCase)
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 6 17],N2Function=@(z)1e-4*ones(size(z)),g0=.02,gd=.03,mdaGramTolerance=.1);
            values = zeros(w.Nx,w.Ny,w.Nz);
            testCase.verifyError(@()w.diffZ(values,n=0),'MATLAB:validators:mustBeMember')
            testCase.verifyError(@()w.diffZF(values,n=5),'MATLAB:validators:mustBeMember')
            testCase.verifyError(@()w.diffZG(values,n=1.5),'MATLAB:validators:mustBeMember')
            testCase.verifyError(@()w.diffZ(zeros(w.Nx,w.Ny)),'MATLAB:validators:mustBeMember')
            testCase.verifyError(@()w.diffZF(zeros(w.Nx+1,w.Ny,w.Nz)),'MATLAB:validators:mustBeMember')
            testCase.verifyError(@()w.diffZG(zeros(w.Nx,w.Ny,w.Nz+1)),'MATLAB:validators:mustBeMember')
        end
    end
end
