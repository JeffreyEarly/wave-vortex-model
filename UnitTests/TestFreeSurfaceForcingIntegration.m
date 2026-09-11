classdef TestFreeSurfaceForcingIntegration < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyOperators(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function effectiveNamedInventoryIsValidatedAtomically(testCase)
            wvt = newTransform();
            advection = WVNonlinearAdvection(wvt);
            reference = WVPrescribedBoussinesqSource(wvt);
            physical = WVPrescribedBoussinesqSource(wvt,sourceCoordinates="physical");
            testCase.verifyEmpty(wvt.forcing)
            wvt.addForcing([physical reference]);
            testCase.verifyEqual(wvt.forcing,reference)
            testCase.verifyError(@()wvt.setForcing([reference physical]),'WVTransformFreeSurfaceBoussinesq:PhysicalSourceRequiresAdvection')
            testCase.verifyEqual(wvt.forcing,reference)
            unsupported = WVForcing(wvt,'unqualified closure',WVForcingType('NonhydrostaticSpatial'));
            testCase.verifyError(@()wvt.addForcing([advection unsupported]),'WVTransformFreeSurfaceBoussinesq:UnsupportedForcing')
            testCase.verifyEqual(wvt.forcing,reference)
            inventory = wvt.scientificState();
            wvt.setForcing([physical advection]);
            testCase.verifyEqual(wvt.scientificState(),inventory)
            expected = wvt.forcing;
            testCase.verifyError(@()wvt.removeForcing(advection),'WVTransformFreeSurfaceBoussinesq:PhysicalSourceRequiresAdvection')
            testCase.verifyEqual(wvt.forcing,expected)
            wvt.addForcing(reference);
            wvt.removeForcing(advection);
            testCase.verifyEqual(wvt.forcing,reference)
            wvt.setForcing([physical advection]);
            wvt.removeAllForcing();
            testCase.verifyEmpty(wvt.forcing)
        end

        function referenceSourcesRemainUnmappedInLinearEvolution(testCase)
            wvt = newTransform();
            [X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
            source = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*cos(2*pi*X/wvt.Lx),vRate=2e-7*sin(2*pi*Y/wvt.Ly),wRate=3e-8*(1+Z/wvt.Lz),etaRate=1e-6*(1+Z/(2*wvt.Lz)),frequency=.003,referenceTime=29,phase=.4);
            wvt.t = 327; wvt.t0 = -17;
            wvt.addForcing(source);
            scale = cos(source.frequency*(wvt.t-source.referenceTime)+source.phase);
            [actual.u,actual.v,actual.w,actual.eta] = wvt.spatialFluxForForcingWithName(source.name);
            expected = struct(u=scale*source.uRate,v=scale*source.vRate,w=scale*source.wRate,eta=scale*source.etaRate);
            for name = ["u","v","w","eta"], testCase.verifyEqual(actual.(name),expected.(name)); end
            [rate,~,diagnostics] = wvt.coefficientTendency();
            testCase.verifyEqual(rate,wvt.projectSources(expected))
            testCase.verifyEmpty(fieldnames(diagnostics))
            testCase.verifyEqual([wvt.t,wvt.t0],[327,-17])
        end

        function physicalAccelerationsUseTheAppendixCMapOnce(testCase)
            [wvt,~,~] = seededTransform();
            [X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
            source = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*(1+Z/wvt.Lz).*cos(2*pi*X/wvt.Lx),vRate=2e-7*(Z/wvt.Lz).^2.*sin(2*pi*Y/wvt.Ly),wRate=3e-8*(1+Z/wvt.Lz).^2,etaRate=1e-6*(1+.1*cos(2*pi*X/wvt.Lx)).*(1+Z/(2*wvt.Lz)),sourceCoordinates="physical",frequency=.003,referenceTime=29,phase=.4);
            wvt.setForcing([source WVNonlinearAdvection(wvt)]);
            scale = cos(source.frequency*(wvt.t-source.referenceTime)+source.phase);
            Su = scale*source.uRate; Sv = scale*source.vRate;
            Sw = scale*source.wRate; Seta = scale*source.etaRate;
            ssh = wvt.ssh; gamma = 1+ssh/wvt.Lz;
            alpha = reshape(1+wvt.z/wvt.Lz,1,1,[]);
            expected = struct(u=gamma.*Su,v=gamma.*Sv,w=Sw-alpha.*wvt.diffX(ssh).*Su-alpha.*wvt.diffY(ssh).*Sv,eta=Seta);
            [actual.u,actual.v,actual.w,actual.eta] = wvt.spatialFluxForForcingWithName(source.name);
            for name = ["u","v","w","eta"], testCase.verifyEqual(actual.(name),expected.(name),AbsTol=2e-20); end

            wvt.addOperation(SpatialForcingOperation(wvt));
            testCase.verifyEqual(wvt.Fu_prescribed_Boussinesq_source,expected.u,AbsTol=2e-20)
            testCase.verifyEqual(wvt.Fv_prescribed_Boussinesq_source,expected.v,AbsTol=2e-20)
            testCase.verifyEqual(wvt.Fw_prescribed_Boussinesq_source,expected.w,AbsTol=2e-20)
            testCase.verifyEqual(wvt.Feta_prescribed_Boussinesq_source,expected.eta,AbsTol=2e-20)
        end

        function forcingDecompositionSumsToTheSingleProjectedTendency(testCase)
            [wvt,~,~] = seededTransform();
            [X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
            source = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*(1+Z/wvt.Lz).*cos(2*pi*X/wvt.Lx),vRate=2e-7*(Z/wvt.Lz).^2.*sin(2*pi*Y/wvt.Ly),wRate=3e-8*(1+Z/wvt.Lz).^2,etaRate=1e-6*(1+.1*cos(2*pi*X/wvt.Lx)).*(1+Z/(2*wvt.Lz)),sourceCoordinates="physical",frequency=.003,referenceTime=29,phase=.4);
            wvt.setForcing([source WVNonlinearAdvection(wvt)]);
            [advection.u,advection.v,advection.w,advection.eta] = wvt.spatialFluxForForcingWithName("nonlinear advection");
            [prescribed.u,prescribed.v,prescribed.w,prescribed.eta] = wvt.spatialFluxForForcingWithName(source.name);
            totalSource = advection;
            for name = ["u","v","w","eta"], totalSource.(name)=totalSource.(name)+prescribed.(name); end
            expected = wvt.projectSources(totalSource);
            [actual,~,diagnostics] = wvt.coefficientTendency();
            verifyState(testCase,actual,expected,2e-13)

            flux = wvt.fluxForForcing();
            sumFlux = flux{"nonlinear advection"};
            prescribedFlux = flux{string(source.name)};
            for family = string(fieldnames(sumFlux)).'
                sumFlux.(family) = sumFlux.(family)+prescribedFlux.(family);
            end
            verifyState(testCase,sumFlux,actual,2e-13)
            verifyState(testCase,prescribedFlux,wvt.projectSources(prescribed),2e-13)

            fields = wvt.reconstructFields(["u","v","w","eta","ssh"]);
            scale = cos(source.frequency*(wvt.t-source.referenceTime)+source.phase);
            gamma = 1+fields.ssh/wvt.Lz;
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            expectedWork = sum(weights.*gamma.*scale.*(fields.u.*source.uRate+fields.v.*source.vRate+fields.w.*source.wRate+1e-4*fields.eta.*source.etaRate),'all');
            testCase.verifyEqual(diagnostics.prescribedWork,expectedWork,AbsTol=2e-16)
            testCase.verifyTrue(isfinite(diagnostics.energyTendency))
            testCase.verifyFalse(isfield(diagnostics,'constraintReactionWork'))
            testCase.verifyEqual([wvt.t,wvt.t0],[327,-17])
        end
    end
end

function wvt = newTransform()
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+zeros(size(z)),shouldAntialias=true,shouldCheckQuadraticAliasing=true,apvModeCount=2,mdaModeCount=2,waveModeCount=3,inertialModeCount=2,nEVP=128);
end

function [wvt,study,state] = seededTransform()
wvt = newTransform();
wvt.t0 = -17;
study = manuscriptEvolutionOperators(wvt,"constant",padding=1);
state = study.seed("mixed",1);
for family = string(fieldnames(state)).', wvt.(family)=state.(family); end
wvt.t = 327;
end

function verifyState(testCase,actual,expected,tolerance)
for family = string(fieldnames(expected)).'
    scale = max(abs(expected.(family)),[],'all');
    testCase.verifyEqual(actual.(family),expected.(family),AbsTol=tolerance*scale+1e-13)
end
end
