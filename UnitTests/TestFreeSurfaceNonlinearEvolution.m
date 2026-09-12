classdef TestFreeSurfaceNonlinearEvolution < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyOperators(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function explicitActivationUsesDirectRHSAndPreservesLinearDefault(testCase)
            [wvt,study,state] = fixture();
            original = wvt.coefficientState();
            testCase.verifyEmpty(wvt.forcing)
            rate = wvt.coefficientTendency();
            verifyZeroState(testCase,rate)

            expected = study.rhs(wvt.t,state);
            wvt.addForcing(WVNonlinearAdvection(wvt));
            [actual,speed,diagnostics] = wvt.coefficientTendency();
            verifyState(testCase,actual,expected,3e-10)
            fields = wvt.reconstructFields(["u","v"]);
            testCase.verifyEqual(speed,max(hypot(fields.u,fields.v),[],'all'))
            testCase.verifyEqual(diagnostics.totalEnergy,wvt.nonlinearEnergy().totalEnergy,RelTol=2e-13)
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyEqual([wvt.t,wvt.t0],[327,-17])

            flux = wvt.fluxForForcing();
            testCase.verifyEqual(flux{"nonlinear advection"},actual)
            wvt.removeForcing(wvt.forcingWithName("nonlinear advection"));
            verifyZeroState(testCase,wvt.coefficientTendency())
            testCase.verifyEqual(wvt.coefficientState(),original)
        end

        function stableCorrectionsReachEverySourceAndCoefficientFamily(testCase)
            [wvt,study,state] = fixture();
            wvt.addForcing(WVNonlinearAdvection(wvt));
            derivative = struct(x=@(a)wvt.diffX(a),y=@(a)wvt.diffY(a),xi=@(a)wvt.diffZ(a));
            context = WVInternal.freeSurfaceThermodynamics(wvt);
            for amplitude = [1,1e-8,1e-12]
                scaled = structfun(@(a)amplitude*a,state,UniformOutput=false);
                setState(wvt,scaled)
                h = study.sample(wvt.t,scaled,1);
                z = reshape(wvt.z,1,1,[])+reshape(1+wvt.z/wvt.Lz,1,1,[]).*h.ssh;
                thermal = context.evaluateNonlinear(z,h.eta,h.ssh,wvt.N2);
                % Constant-stratification oracle, including bounded label
                % adjustment. It uses no buoyancy quadrature/subtraction.
                adjustment = min(0,max(-wvt.Lz,z-h.eta))-(z-h.eta);
                remainder = -1e-4*(max(z,0)+adjustment);
                expected = evaluateManuscriptNonlinearTerms(h,h.p,wvt.z,wvt.Lz,wvt.f,wvt.rho0,wvt.N2,remainder,derivative);
                [actual.u,actual.v,actual.w,actual.eta] = wvt.nonlinearAdvectionSources();
                for name = ["u","v","w","eta"]
                    testCase.verifyEqual(actual.(name),expected.source.(name),AbsTol=1e-12*max(abs(expected.source.(name)),[],'all')+1e-30)
                end
                rate = wvt.coefficientTendency();
                reference = wvt.projectSources(expected.source);
                testCase.verifyEqual(sort(string(fieldnames(rate))),sort(["Ag_q";"Ag_0";"Aw_p";"Aw_m";"Aio";"Amda"]))
                for family = string(fieldnames(rate)).'
                    testCase.verifyEqual(rate.(family),reference.(family),AbsTol=1e-12*max(abs(reference.(family)),[],'all')+1e-30)
                end
                oldRemainder = -thermal.buoyancy-reshape(wvt.N2,1,1,[]).*h.eta;
                oldPressure = (1./(1+h.ssh/wvt.Lz)-1).*derivative.xi(h.p)/wvt.rho0;
                exactPressure = -h.ssh.*derivative.xi(h.p)./(wvt.rho0*(wvt.Lz+h.ssh));
                oldError = max(abs(oldRemainder+oldPressure-remainder-exactPressure),[],'all');
                newError = max(abs(expected.P.w-remainder-exactPressure),[],'all');
                fprintf('Stable corrections: amplitude=%g, old/new maximum P_w error=%.3g / %.3g m s^-2\n',amplitude,oldError,newError);
                testCase.verifyLessThanOrEqual(newError,oldError+realmin)
            end
        end

        function nonlinearEnergyUsesPhysicalVolumeAndQuadraticSurface(testCase)
            [wvt,~,~] = fixture();
            diagnostics = wvt.nonlinearEnergy();
            fields = wvt.reconstructFields(["u","v","w","eta","ssh","z_physical"]);
            gamma = 1+fields.ssh/wvt.Lz;
            label = fields.z_physical-fields.eta;
            upper = min(fields.z_physical,0);
            N2 = 1e-4;
            ape = -N2*fields.eta.*label-.5*N2*label.^2+.5*N2*upper.^2;
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            expectedKinetic = .5*sum(weights.*gamma.*(fields.u.^2+fields.v.^2+fields.w.^2),'all');
            expectedAPE = sum(weights.*gamma.*ape,'all');
            expectedSurface = .5*wvt.g*mean(fields.ssh.^2,'all');
            testCase.verifyEqual(diagnostics.kineticEnergy,expectedKinetic,RelTol=2e-13)
            testCase.verifyEqual(diagnostics.availablePotentialEnergy,expectedAPE,AbsTol=2e-12)
            testCase.verifyEqual(diagnostics.surfaceEnergy,expectedSurface,RelTol=2e-13)
            testCase.verifyEqual(diagnostics.totalEnergy,expectedKinetic+expectedAPE+expectedSurface,RelTol=2e-13)
            testCase.verifyGreaterThan(min(label,[],'all'),-wvt.Lz)
            testCase.verifyLessThan(max(label,[],'all'),0)
        end

        function reportedEnergyTendencyMatchesStateAndClockDifference(testCase)
            [wvt,~,~] = fixture();
            wvt.addForcing(WVNonlinearAdvection(wvt));
            original = wvt.coefficientState();
            originalTime = wvt.t;
            [rate,~,diagnostics] = wvt.coefficientTendency();
            steps = [1,.3];
            finiteDifference = zeros(size(steps));
            for stepIndex = 1:numel(steps)
                dt = steps(stepIndex);
                energy = zeros(2,1);
                signs = [1,-1];
                for signIndex = 1:2
                    state = original;
                    for family = string(fieldnames(state)).'
                        state.(family) = state.(family)+signs(signIndex)*dt*rate.(family);
                    end
                    setState(wvt,state)
                    wvt.t = originalTime+signs(signIndex)*dt;
                    energy(signIndex) = wvt.nonlinearEnergy().totalEnergy;
                end
                finiteDifference(stepIndex) = (energy(1)-energy(2))/(2*dt);
            end
            setState(wvt,original)
            wvt.t = originalTime;
            error = abs(finiteDifference-diagnostics.energyTendency);
            testCase.verifyGreaterThan(abs(diagnostics.energyTendency),1e-8)
            testCase.verifyEqual(diagnostics.energyTendency,finiteDifference(2),RelTol=1e-5,AbsTol=2e-13)
            testCase.verifyGreaterThan(error(1)/error(2),8)
            testCase.verifyLessThan(error(1)/error(2),15)
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyEqual([wvt.t,wvt.t0],[327,-17])
        end
    end
end

function [wvt,study,state] = fixture()
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
wvt.t0 = -17;
study = manuscriptEvolutionOperators(wvt,"constant",padding=1);
state = study.seed("mixed",1);
setState(wvt,state)
wvt.t = 327;
end

function setState(wvt,state)
for family = string(fieldnames(state)).', wvt.(family)=state.(family); end
end

function verifyZeroState(testCase,state)
for family = string(fieldnames(state)).'
    testCase.verifyEqual(state.(family),zeros(size(state.(family))))
end
end

function verifyState(testCase,actual,expected,tolerance)
for family = string(fieldnames(expected)).'
    scale = max(abs(expected.(family)),[],'all');
    testCase.verifyEqual(actual.(family),expected.(family),AbsTol=tolerance*scale+1e-13)
end
end
