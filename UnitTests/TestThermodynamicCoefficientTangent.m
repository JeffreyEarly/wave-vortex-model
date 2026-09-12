classdef TestThermodynamicCoefficientTangent < matlab.unittest.TestCase
    properties
        constantState
        exponentialState
        constantResult
        exponentialResult
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
                study=manuscriptEvolutionOperators(w,profile,padding=1);
                testCase.(profile+"Result")=evaluateThermodynamicCoefficientTangent(w,profile,study.seed("mixed",.1),327);
            end
        end
    end
    methods (Test, TestTags="full")
        function centeredDifferencesVerifyAnalyticTangent(testCase)
            r=testCase.exponentialResult;
            for family=["Aw_p","Aw_m","Ag_q","Ag_0","Amda"]
                rows=r.finiteDifferences(string({r.finiteDifferences.family})==family);
                testCase.verifyEqual(rows(1).error/rows(2).error,4,RelTol=.02);
                testCase.verifyLessThan(min([rows.error]),1e-8*rows(1).rateMax+1e-19);
                testCase.verifyGreaterThan(rows(end).omittedTimeError,1000*min([rows.error]));
            end
            rows=r.finiteDifferences(string({r.finiteDifferences.family})=="Aio");
            testCase.verifyLessThan(min([rows.error]),1e-10*rows(1).rateMax);
        end
        function constantProfileRecoversExistingCoefficientEvolution(testCase)
            r=testCase.constantResult;
            for name=string(fieldnames(r.reference)).'
                testCase.verifyEqual(r.tangent.(name),r.reference.(name),AbsTol=1e-8*max(abs(r.reference.(name)),[],'all')+1e-18);
            end
            for row=r.comparison
                testCase.verifyLessThan(row.candidateDifference,1e-8*row.rateMax+1e-18);
            end
        end
        function discrepancyIsAtLeastQuadraticInThisFixture(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.exponentialState);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1);
            small=evaluateThermodynamicCoefficientTangent(w,"exponential",study.seed("mixed",.01),327,1);
            large=testCase.exponentialResult;
            for family=["Aw_p","Aw_m","Ag_q","Ag_0","Aio","Amda"]
                a=large.comparison(string({large.comparison.family})==family);
                b=small.comparison(string({small.comparison.family})==family);
                ratio=a.candidateDifference/b.candidateDifference;
                if any(family==["Aw_p","Aw_m","Ag_0"])
                    testCase.verifyEqual(ratio,100,RelTol=.05);
                else
                    % Leading terms cancel in these families for this fixture.
                    testCase.verifyGreaterThan(ratio,95);
                end
            end
        end
        function changingReferenceClockPreservesTheTangent(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.exponentialState);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1);
            state=study.seed("mixed",.1); r=testCase.exponentialResult;
            omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex); omega(~w.activeWaveModes)=0;
            phase=exp(1i*omega*19); inertialPhase=exp(1i*w.f*19);
            state.Aw_p=state.Aw_p.*phase; state.Aw_m=state.Aw_m./phase; state.Aio=state.Aio*inertialPhase;
            rate=r.reference;
            rate.Aw_p=rate.Aw_p.*phase; rate.Aw_m=rate.Aw_m./phase; rate.Aio=rate.Aio*inertialPhase;
            w.t0=19;
            [~,actual]=thermodynamicCoefficientMap(w,"exponential",state,327,rate);
            actual.Aw_p=actual.Aw_p./phase; actual.Aw_m=actual.Aw_m.*phase; actual.Aio=actual.Aio/inertialPhase;
            for name=string(fieldnames(actual)).'
                testCase.verifyEqual(actual.(name),r.tangent.(name),AbsTol=1e-9*max(abs(r.tangent.(name)),[],'all')+1e-18);
            end
        end
    end
end
