classdef TestFFTWKBDerivative < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addCandidate(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','vertical-derivative-study')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
        end
    end
    methods (Test, TestTags="full")
        function analyticMappedDerivativesIncludeMetric(testCase)
            % s is affine in exp(z/B). exp(3*z/B) is a cubic in s;
            % constant-metric nth differentiation would incorrectly vanish
            % at order four. Check every sample, including both endpoints.
            Z = 17; B = 4000; D = 1000;
            s = (1-cos(pi*(0:Z-1)'/(Z-1)))/2;
            z = B*log(exp(-D/B)+s*(1-exp(-D/B)));
            metric = 2*exp(z/B)/(B*(1-exp(-D/B)));
            for horizontal = {ones(3,2),[1,2i;3i,4;5,6i]}
                u = horizontal{1}.*reshape(exp(3*z/B),1,1,[]);
                for n = 1:4
                    actual = fftWKBDerivative(u,metric,n);
                    expected = (3/B)^n*u;
                    testCase.verifyEqual(size(actual),size(u))
                    testCase.verifyLessThan(max(abs(actual-expected),[],'all')/max(abs(expected),[],'all'),2e-5)
                    testCase.verifyEqual(isreal(actual),isreal(u))
                end
            end
        end

        function storedOperatorsPreserveAliasesAndBoundaryMode(testCase)
            base = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(z/650),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,nEVP=128,shouldAntialias=true);
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(folder.Folder,'derivative-state.nc');
            nc = base.writeToFile(file); nc.close();
            restored = WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(file);
            testCase.verifyEmpty(restored.verticalModes)
            candidate = DerivativeStudyBoussinesq(restored.scientificState());
            candidate.useFFT = true;
            testCase.verifyEmpty(candidate.verticalModes)
            metric = 2*exp(candidate.z/1300)/(1300*(1-exp(-candidate.Lz/1300)));
            testCase.verifyEqual(candidate.derivativeMetric,metric,RelTol=1e-10)
            u = repmat(reshape(candidate.zeroAPVF(:,1,1),1,1,[]),8,8,1);
            expected = -(candidate.N2/candidate.g).*candidate.zeroAPVG(:,1,1);
            actual = candidate.diffZ(u);
            testCase.verifyLessThan(norm(squeeze(actual(1,1,:))-expected)/norm(expected),1e-5)
            for n = 1:4
                actual = candidate.diffZ(u,n=n);
                testCase.verifyEqual(candidate.diffZF(u,n=n),actual)
                testCase.verifyEqual(candidate.diffZG(u,n=n),actual)
            end
            study = manuscriptEvolutionOperators(candidate,"exponential",padding=1);
            state = study.seed("mixed",1);
            for family = string(fieldnames(state)).', candidate.(family)=state.(family); end
            for time = [327 901]
                candidate.t = time;
                candidate.useFFT = false;
                [dense.u,dense.v,dense.w,dense.eta] = candidate.nonlinearAdvectionSources();
                candidate.useFFT = true;
                [fast.u,fast.v,fast.w,fast.eta] = candidate.nonlinearAdvectionSources();
                for name = ["u","v","w","eta"]
                    difference = fast.(name)-dense.(name);
                    testCase.verifyLessThan(norm(difference(:))/norm(dense.(name)(:)),1e-9)
                end
            end
        end

        function constantsAndHighestPolynomialMode(testCase)
            Z = 33; degree = Z-1;
            x = -cos(pi*(0:degree)'/degree);
            metric = ones(Z,1);
            testCase.verifyEqual(fftWKBDerivative(ones(2,3,Z),metric),zeros(2,3,Z))
            % T_degree at the nodes; endpoint derivatives have exact limits.
            values = cos(degree*acos(x));
            expected = zeros(Z,1);
            expected(2:end-1) = degree*sin(degree*acos(x(2:end-1)))./sqrt(1-x(2:end-1).^2);
            expected(1) = (-1)^(degree-1)*degree^2; expected(end) = degree^2;
            actual = fftWKBDerivative(repmat(reshape(values,1,1,[]),2,3,1),metric);
            testCase.verifyEqual(squeeze(actual(1,1,:)),expected,AbsTol=1e-9)
        end

        function boundaryLocalizedFunctionConvergesIndependently(testCase)
            errors = zeros(2,4);
            for index = 1:2
                counts = [17 33]; Z = counts(index);
                x = -cos(pi*(0:Z-1)'/(Z-1));
                u = repmat(reshape(exp(12*(x-1)),1,1,[]),2,3,1);
                for n = 1:4
                    actual = fftWKBDerivative(u,ones(Z,1),n);
                    errors(index,n) = max(abs(actual-12^n*u),[],'all')/12^n;
                end
            end
            testCase.verifyLessThan(errors(2,:),errors(1,:)/100)
            testCase.verifyLessThan(errors(2,:),1e-5*ones(1,4))
        end
    end
end
