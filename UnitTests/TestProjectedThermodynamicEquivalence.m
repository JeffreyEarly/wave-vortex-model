classdef TestProjectedThermodynamicEquivalence < matlab.unittest.TestCase
    properties
        constantState
        exponentialState
    end
    methods (TestClassSetup)
        function setup(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','thermodynamic-formulation-study')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            for profile=["constant","exponential"]
                if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 65],N2Function=N2,apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,shouldAntialias=false);
                testCase.(profile+"State")=w.scientificState();
            end
        end
    end
    methods (Test, TestTags="full")
        function physicalPullbackAgreesForEveryInputAndOutputFamily(testCase)
            for profile=["constant","exponential"]
                w=WVTransformFreeSurfaceBoussinesq(testCase.(profile+"State"));
                study=manuscriptEvolutionOperators(w,profile,padding=1);
                initial=study.seed("mixed",.1);
                for family=[string(fieldnames(initial)).',"mixed"]
                    state=structfun(@(a)zeros(size(a)),initial,UniformOutput=false);
                    state.Amda=initial.Amda;
                    if family=="mixed", state=initial; else, state.(family)=initial.(family); end
                    for time=[327 901]
                        r=evaluateProjectedThermodynamics(w,profile,state,time);
                        testCase.verifyLessThan(r.scalarPullbackError,2e-14);
                        testCase.verifyLessThan(r.inversePressureError,1e-10);
                        for entry=r.families
                            testCase.verifyLessThan(entry.pulledError,1e-9*entry.referenceMax+1e-18);
                        end
                    end
                end
            end
        end
        function nativeChangeAndPressureChangeAreQuadratic(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.exponentialState);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1);
            large=evaluateProjectedThermodynamics(w,"exponential",study.seed("mixed",.1),327);
            small=evaluateProjectedThermodynamics(w,"exponential",study.seed("mixed",.01),327);
            testCase.verifyEqual(large.hDifference/small.hDifference,100,RelTol=.01);
            testCase.verifyEqual(large.pressureDifference/small.pressureDifference,100,RelTol=.01);
            testCase.verifyGreaterThan(large.pressureDifference,1e6*large.pressureBaselineError);
            testCase.verifyGreaterThan(large.surfacePressureDifference,1e-4);
            % This test identifies a changed closure, not an equivalent replacement.
            for name=["Ag_q","Ag_0","Aw_p","Aw_m","Amda"]
                a=large.families(string({large.families.family})==name);
                b=small.families(string({small.families.family})==name);
                testCase.verifyEqual(a.nativeDifference/b.nativeDifference,100,RelTol=.03);
            end
        end
        function constantProfileIsAnExactControl(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.constantState);
            study=manuscriptEvolutionOperators(w,"constant",padding=1);
            r=evaluateProjectedThermodynamics(w,"constant",study.seed("mixed",.1),327);
            testCase.verifyLessThan(r.hDifference,2e-14);
            testCase.verifyLessThan(r.pressureDifference,1e-10);
            for entry=r.families
                testCase.verifyLessThan(entry.nativeDifference,1e-10*entry.referenceMax+1e-18);
            end
        end
        function referenceClockPreservesPhysicalComparison(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.exponentialState);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1);
            state=study.seed("mixed",.1);
            original=evaluateProjectedThermodynamics(w,"exponential",state,327);
            omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex); omega(~w.activeWaveModes)=0;
            phase=exp(1i*omega*19); inertialPhase=exp(1i*w.f*19);
            state.Aw_p=state.Aw_p.*phase; state.Aw_m=state.Aw_m./phase; state.Aio=state.Aio*inertialPhase;
            w.t0=19;
            changed=evaluateProjectedThermodynamics(w,"exponential",state,327);
            for field=["reference","pulled"]
                actual=changed.(field); expected=original.(field);
                actual.Aw_p=actual.Aw_p./phase; actual.Aw_m=actual.Aw_m.*phase; actual.Aio=actual.Aio/inertialPhase;
                for name=string(fieldnames(expected)).'
                    testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-10*max(abs(expected.(name)),[],'all')+1e-18);
                end
            end
        end
    end
end
