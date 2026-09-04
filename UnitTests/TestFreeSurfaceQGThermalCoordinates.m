classdef TestFreeSurfaceQGThermalCoordinates < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function completeOperatorsMatchExistingTendency(testCase)
            for endpointWeights=[-.1 .1;-.1 Inf;Inf .1;Inf Inf].'
                w=WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),g0=endpointWeights(1),gd=endpointWeights(2),mdaGramTolerance=.1);
                n=w.apvModeCount+w.activeEndpointCount;
                a=reshape(sin(1:n*length(w.klNonzero))+1i*cos(1:n*length(w.klNonzero)),n,[])*1e-7;
                w.Ag_q=a(1:w.apvModeCount,:); w.Ag_0=a(w.apvModeCount+1:end,:);
                w.Amda=sin((1:w.mdaModeCount).');
                [L,M]=w.thermalDiffusionOperators(1e-5);
                testCase.verifySize(L,[n n length(w.khUnique)])
                testCase.verifySize(M,[w.mdaModeCount w.mdaModeCount])
                expected=reshape(pagemtimes(L(:,:,w.klNonzeroKhUniqueIndex),reshape(a,n,1,[])),n,[]);
                actual=w.thermalCoefficientTendency(1e-5);
                testCase.verifyEqual([actual.Ag_q;actual.Ag_0],expected,RelTol=5e-13,AbsTol=1e-24)
                testCase.verifyEqual(actual.Amda,M*w.Amda,RelTol=5e-13,AbsTol=1e-22)
                [zeroL,zeroM]=w.thermalDiffusionOperators(0);
                testCase.verifyEqual(zeroL,zeros(size(L)))
                testCase.verifyEqual(zeroM,zeros(size(M)))
                % Returned arrays cannot mutate the cache; state is unrelated.
                saved=L; L(:)=0; w.Ag_q(:)=0;
                testCase.verifyEqual(L,zeros(size(saved)))
                testCase.verifyEqual(w.thermalDiffusionOperators(1e-5),saved)
            end
        end

        function directRestorationRebuildsIdenticalOperators(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300));
            [L,M]=w.thermalDiffusionOperators(1e-5);
            file=fullfile(fixture.Folder,'state.nc'); nc=w.writeToFile(file); nc.close();
            restored=WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
            [restoredL,restoredM]=restored.thermalDiffusionOperators(1e-5);
            testCase.verifyEqual(restoredL,L)
            testCase.verifyEqual(restoredM,M)
            testCase.verifyEqual(restored.Ag_q,w.Ag_q)
            testCase.verifyEqual(restored.Ag_0,w.Ag_0)
            testCase.verifyEqual(restored.Amda,w.Amda)
        end
    end
end
