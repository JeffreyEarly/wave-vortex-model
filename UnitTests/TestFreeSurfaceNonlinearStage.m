classdef TestFreeSurfaceNonlinearStage < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyOperators(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function nonlinearSourcesMatchAppendixCAtCurrentClocks(testCase)
            for profile = ["constant","exponential"]
                [wvt,study,state] = fixture(profile);
                original = wvt.coefficientState();
                [~,terms,hatted] = study.rhs(wvt.t,state);
                [actual.u,actual.v,actual.w,actual.eta] = wvt.nonlinearAdvectionSources();
                for name = ["u","v","w","eta"]
                    scale = max(abs(terms.source.(name)),[],'all');
                    testCase.verifyEqual(actual.(name),terms.source.(name),AbsTol=3e-12*scale+3e-14)
                    testCase.verifyEqual(terms.source.(name),-terms.N.(name)-terms.P.(name),AbsTol=2e-15)
                end
                expectedHu = -terms.N.u+wvt.f*hatted.v-wvt.diffX(hatted.p)/wvt.rho0-terms.P.u;
                expectedHv = -terms.N.v-wvt.f*hatted.u-wvt.diffY(hatted.p)/wvt.rho0-terms.P.v;
                testCase.verifyEqual(terms.H.u,expectedHu,AbsTol=3e-14)
                testCase.verifyEqual(terms.H.v,expectedHv,AbsTol=3e-14)
                testCase.verifyEqual(wvt.coefficientState(),original)
                testCase.verifyEqual([wvt.t,wvt.t0],[327,-17])
            end
        end

        function nonlinearTendencyMatchesDirectStudyProjection(testCase)
            [wvt,study,state] = fixture("constant");
            expected = study.rhs(wvt.t,state);
            wvt.addForcing(WVNonlinearAdvection(wvt));
            original = wvt.coefficientState();
            [actual,~,diagnostics] = wvt.coefficientTendency();
            verifyState(testCase,actual,expected,3e-10)
            testCase.verifyFalse(isfield(diagnostics,'solver'))
            testCase.verifyFalse(isfield(diagnostics,'constraintReactionWork'))
            testCase.verifyFalse(isfield(diagnostics,'p_full'))
            testCase.verifyEqual(diagnostics.referenceConvention,"upper-constant-density")
            testCase.verifyGreaterThan(diagnostics.minimumLabel,-wvt.Lz)
            testCase.verifyLessThan(diagnostics.maximumLabel,0)
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyEqual([wvt.t,wvt.t0],[327,-17])

            % The finite modal projection need not satisfy the nonlinear
            % material boundary laws exactly. Its retained residuals must
            % remain finite and are reported without a constraint repair.
            observed = study.observe(wvt.t,state,actual);
            residuals = [observed.sshResidual,observed.surfaceResidual,observed.bottomResidual];
            testCase.verifyTrue(all(isfinite(residuals)))
        end

        function validOneSidedLinearLimitIsQuadratic(testCase)
            for profile = ["constant","exponential"]
                [wvt,~,seed] = fixture(profile);
                wvt.addForcing(WVNonlinearAdvection(wvt));
                amplitudes = [1e-3,5e-4];
                magnitudes = zeros(size(amplitudes));
                for index = 1:numel(amplitudes)
                    state = structfun(@(value)amplitudes(index)*value,seed,UniformOutput=false);
                    setState(wvt,state)
                    rate = wvt.coefficientTendency();
                    magnitudes(index) = stateNorm(rate);
                end
                ratio = magnitudes(1)/magnitudes(2);
                testCase.verifyGreaterThan(ratio,3.7)
                testCase.verifyLessThan(ratio,4.3)
            end
        end

        function variableWavePagesRemainFiniteAtChangingClocks(testCase)
            profileFunction = @(z)1e-4*exp(z/650);
            options = struct(N2Function=profileFunction,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
            args = namedargs2cell(options);
            uniform = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:});
            counts = mod(3-(0:length(uniform.khUnique)-1).',4);
            options.waveModeCount = counts;
            args = namedargs2cell(options);
            wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},waveModeKappa=uniform.khUnique);
            wvt.t0 = -17;
            study = manuscriptEvolutionOperators(wvt,"exponential",padding=1);
            state = study.seed("mixed",1);
            setState(wvt,state)
            wvt.addForcing(WVNonlinearAdvection(wvt));
            original = wvt.coefficientState();
            testCase.verifyTrue(any(counts==0))
            testCase.verifyTrue(any(~wvt.activeWaveModes,'all'))
            clocks = [13,7;1301,-31;-17,17];
            for index = 1:size(clocks,1)
                wvt.t = clocks(index,1); wvt.t0 = clocks(index,2);
                rate = wvt.coefficientTendency();
                for family = string(fieldnames(rate)).'
                    testCase.verifyTrue(all(isfinite(rate.(family)),'all'))
                end
                for family = ["Aw_p","Aw_m"]
                    testCase.verifyEqual(rate.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
                end
                testCase.verifyEqual(wvt.coefficientState(),original)
                testCase.verifyEqual([wvt.t,wvt.t0],clocks(index,:))
            end
        end
    end
end

function [wvt,study,state] = fixture(profile)
N2Function = @(z)1e-4+zeros(size(z));
if profile=="exponential", N2Function=@(z)1e-4*exp(z/650); end
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2Function,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
wvt.t0 = -17;
study = manuscriptEvolutionOperators(wvt,profile,padding=1);
state = study.seed("mixed",1);
setState(wvt,state)
wvt.t = 327;
end

function setState(wvt,state)
for family = string(fieldnames(state)).', wvt.(family)=state.(family); end
end

function verifyState(testCase,actual,expected,tolerance)
for family = string(fieldnames(expected)).'
    scale = max(abs(expected.(family)),[],'all');
    testCase.verifyEqual(actual.(family),expected.(family),AbsTol=tolerance*scale+1e-13)
end
end

function value = stateNorm(state)
value = 0;
for family = string(fieldnames(state)).', value=value+sum(abs(state.(family)).^2,'all'); end
value = sqrt(value);
end
