classdef TestThermodynamicComparison < matlab.unittest.TestCase
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
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],N2Function=N2,apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,nEVP=256,shouldAntialias=false);
                testCase.(profile+"State")=w.scientificState();
            end
        end
    end
    methods (Test, TestTags="full")
        function inverseRecoversPhysicalStatesAcrossAmplitudeAndClock(testCase)
            for profile=["constant","exponential"]
                w=WVTransformFreeSurfaceBoussinesq(testCase.(profile+"State"));
                study=manuscriptEvolutionOperators(w,profile,padding=1);
                op=thermodynamicComparisonOperators(w,profile,"displacement");
                for amplitude=[.0001 .01 .1]
                    a=study.seed("mixed",amplitude);
                    for time=[327 901]
                        b=thermodynamicCoefficientMap(w,profile,a,time);
                        [recovered,assessment]=invertThermodynamicCoefficientMap(w,profile,b,time);
                        testCase.verifyLessThan(assessment.residual,2e-11);
                        testCase.verifyLessThan(assessment.iterations,15);
                        expected=op.fields(time,a); actual=op.fields(time,recovered);
                        for name=["u","v","w","eta","ssh","density"]
                            testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-9*max(abs(expected.(name)),[],'all')+1e-11);
                        end
                    end
                end
            end
        end
        function constantProfileNativeRHSMatchesDisplacement(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.constantState);
            study=manuscriptEvolutionOperators(w,"constant",padding=1); a=study.seed("mixed",.1);
            b=thermodynamicCoefficientMap(w,"constant",a,327);
            displacement=thermodynamicComparisonOperators(w,"constant","displacement");
            density=thermodynamicComparisonOperators(w,"constant","density");
            expected=displacement.rhs(327,a); actual=density.rhs(327,b);
            for name=string(fieldnames(expected)).'
                testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-8*max(abs(expected.(name)),[],'all')+1e-18);
            end
        end
        function endpointRoundoffPreservesTheOriginalLinearVariable(testCase)
            for profile=["constant","exponential"]
                w=WVTransformFreeSurfaceBoussinesq(testCase.(profile+"State"));
                density=thermodynamicComparisonOperators(w,profile,"density");
                context=WVInternal.freeSurfaceThermodynamics(w);
                if profile=="constant", lambda=0; else, lambda=1/650; end
                for side=1:2
                    endpoints=[.1;-.1]; endpoints(side)=(2*side-3)*16*eps(w.Lz);
                    a=w.coefficientState(); a.Amda(1:2)=w.mdaG([end 1],1:2)\endpoints;
                    [~,actual]=density.rhs(327,a);
                    f=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
                    alpha=reshape(1+w.z/w.Lz,1,1,[]); z=reshape(w.z,1,1,[])+alpha.*f.ssh;
                    e=f.eta-alpha.*f.ssh; eta=e;
                    if lambda~=0, eta=-log1p(-lambda*e)/lambda; end
                    eta=eta+alpha.*f.ssh;
                    thermal=context.evaluateNonlinear(z,eta,f.ssh,w.N2);
                    hatted=struct(u=f.u_hat,v=f.v_hat,w=f.w_hat,eta=f.eta,p=f.p,ssh=f.ssh);
                    derivative=struct(x=@(v)w.diffX(v),y=@(v)w.diffY(v),xi=@(v)w.diffZ(v));
                    remainder=thermal.buoyancyRemainder+reshape(w.N2,1,1,[]).*(eta-f.eta);
                    expected=WVInternal.freeSurfaceNonlinearTerms(hatted,f.p,w.z,w.Lz,w.f,w.rho0,w.N2,remainder,derivative);
                    testCase.verifyEqual(actual.w,expected.source.w,AbsTol=2e-18);
                    endpoints(side)=4*endpoints(side); a.Amda(1:2)=w.mdaG([end 1],1:2)\endpoints;
                    testCase.verifyError(@()density.rhs(327,a),'WVStudy:ParcelLabelDomain');
                end
            end
        end
        function analyticInventoryDerivativeMatchesDirectionalDifference(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.exponentialState);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1); a=study.seed("mixed",.1);
            for variant=["displacement","density"]
                state=a; if variant=="density", state=thermodynamicCoefficientMap(w,"exponential",a,327); end
                op=thermodynamicComparisonOperators(w,"exponential",variant); rate=op.rhs(327,state);
                budget=thermodynamicBudgetRate(w,"exponential",variant,state,327,rate);
                plus=state; minus=state; dt=.05;
                for name=string(fieldnames(state)).'
                    plus.(name)=state.(name)+dt*rate.(name); minus.(name)=state.(name)-dt*rate.(name);
                end
                p=op.observe(327+dt,plus); m=op.observe(327-dt,minus);
                difference=[p.energy-m.energy;p.densityMoment-m.densityMoment;p.densitySquaredMoment-m.densitySquaredMoment]/(2*dt);
                testCase.verifyEqual(budget,difference,AbsTol=2e-8);
            end
        end
        function inverseMapTrajectoryMatchesTheSameFiniteEvolution(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.exponentialState);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1); a=study.seed("mixed",.1);
            b=thermodynamicCoefficientMap(w,"exponential",a,327);
            displacement=thermodynamicComparisonOperators(w,"exponential","displacement");
            density=thermodynamicComparisonOperators(w,"exponential","equivalent");
            reference=runThermodynamicTrajectory(displacement,a,327,40,2.5);
            actual=runThermodynamicTrajectory(density,b,327,40,2.5,reference.checkpoints);
            testCase.verifyLessThan(actual.summary.velocityError,1e-8);
            testCase.verifyLessThan(actual.summary.densityError,1e-8);
            testCase.verifyLessThan(actual.summary.sshError,1e-7);
            testCase.verifyEqual(actual.summary.acceptedRHS,64);
            testCase.verifyEqual(actual.summary.rejectedRHS,0);
        end
    end
end
