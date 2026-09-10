classdef TestFreeSurfaceForcingIntegration < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyHelpers(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function effectiveNamedInventoryIsValidatedAtomically(testCase)
            wvt = newTransform(true,true);
            advection = WVNonlinearAdvection(wvt);
            reference = WVPrescribedBoussinesqSource(wvt);
            physical = WVPrescribedBoussinesqSource(wvt,sourceCoordinates="physical");
            testCase.verifyEmpty(wvt.forcing)
            % Both sources have the same registry name. Validate the final
            % effective object, not the physical source replaced in-batch.
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
            % Replacing the physical source permits return to linear mode.
            wvt.addForcing(reference);
            wvt.removeForcing(advection);
            testCase.verifyEqual(wvt.forcing,reference)
            wvt.setForcing([physical advection]);
            wvt.removeAllForcing();
            testCase.verifyEmpty(wvt.forcing)
        end

        function activationRequiresTheExistingQualifiedInventory(testCase)
            for flags = {[true false],[false true]}
                value = flags{1};
                wvt = newTransform(value(1),value(2));
                source = WVPrescribedBoussinesqSource(wvt);
                wvt.addForcing(source);
                inventory = wvt.scientificState();
                testCase.verifyError(@()wvt.addForcing(WVNonlinearAdvection(wvt)),'WVTransformFreeSurfaceBoussinesq:NonlinearInventoryUnqualified')
                testCase.verifyEqual(wvt.forcing,source)
                testCase.verifyEqual(wvt.scientificState(),inventory)
            end
            legacy = WVTransformConstantStratification([40e3 30e3 2e3],[8 6 5],N0=5.2e-3,latitude=45,shouldAntialias=false);
            control = WVNonlinearAdvection(legacy);
            legacy.setForcing(control);
            contract = control.portableImplementationContract();
            testCase.verifyEqual(contract.capabilityStatus,"supported")
            qualified = newTransform(true,true);
            mapped = WVNonlinearAdvection(qualified);
            contract = mapped.portableImplementationContract();
            testCase.verifyEqual(contract.capabilityStatus,"unavailable")
            testCase.verifyNotEmpty(contract.reason)
        end

        function sharedCallbackMatchesIndependentMappedMeanFlow(testCase)
            wvt = newTransform(true,true);
            force = WVNonlinearAdvection(wvt);
            [X,Y,S] = ndgrid(wvt.x,wvt.y,1+wvt.z/wvt.Lz);
            k = 2*pi/wvt.Lx;
            l = 2*pi/wvt.Ly;
            ssh = cos(k*X(:,:,1))+.7*sin(l*Y(:,:,1));
            sx = -k*sin(k*X(:,:,1));
            sy = .7*l*cos(l*Y(:,:,1));
            sxx = -k^2*cos(k*X(:,:,1));
            syy = -.7*l^2*sin(l*Y(:,:,1));
            U = .03; V = .02;
            zero = zeros(size(X));
            hatted = struct(u=U+zero,v=V+zero,w=zero,eta=S.*ssh+2*(2*S-1),ssh=ssh);
            physical = WVInternal.freeSurfacePhysicalFields(hatted,wvt.z,wvt.Lz,sx,sy);
            thermodynamics = WVInternal.freeSurfaceThermodynamics(wvt);
            stage = struct(hatted=hatted,physical=physical,thermodynamics=thermodynamics.evaluate(physical.z,hatted.eta,ssh));
            gamma = physical.gamma;
            Q = U*sx+V*sy;
            expected.u = U*Q./(wvt.Lz*gamma.^2)+zero;
            expected.v = V*Q./(wvt.Lz*gamma.^2)+zero;
            expected.w = -S.*(U^2*sxx+V^2*syy)./gamma.^2-S.*wvt.f.*(V*sx-U*sy)./gamma;
            expected.eta = zero;
            base = 1e-8+zero;
            [actual.u,actual.v,actual.w,actual.eta] = force.addNonhydrostaticSpatialForcing(wvt,base,base,base,base,stage);
            % Analytic derivatives versus full-grid FFT product derivatives;
            % the small rational metric tail is below the absolute bound.
            for name = ["u","v","w","eta"]
                testCase.verifyEqual(actual.(name),base+expected.(name),AbsTol=2e-14)
            end
            testCase.verifyGreaterThan(max(abs(expected.u),[],'all'),1e-12)
            testCase.verifyGreaterThan(max(abs(expected.w),[],'all'),1e-11)
        end

        function standaloneCallbackUsesCurrentHattedFieldsWithoutSolving(testCase)
            wvt = newTransform(true,true);
            helper = freeSurfaceWeakStudyHelpers();
            state = helper.seedState(wvt);
            for name = string(fieldnames(state)).', wvt.(name)=state.(name); end
            wvt.t = 37; wvt.t0 = -17;
            spectral = wvt.reconstructSpectralState();
            for name = ["u","v","w","eta","ssh"]
                hatted.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
            end
            hatted.ssh = hatted.ssh(:,:,end);
            physical = WVInternal.freeSurfacePhysicalFields(hatted,wvt.z,wvt.Lz,wvt.diffX(hatted.ssh),wvt.diffY(hatted.ssh));
            thermo = WVInternal.freeSurfaceThermodynamics(wvt);
            stage = struct(hatted=hatted,physical=physical,thermodynamics=thermo.evaluate(physical.z,hatted.eta,hatted.ssh));
            force = WVNonlinearAdvection(wvt);
            zero = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
            [direct.u,direct.v,direct.w,direct.eta] = force.addNonhydrostaticSpatialForcing(wvt,zero,zero,zero,zero);
            [shared.u,shared.v,shared.w,shared.eta] = force.addNonhydrostaticSpatialForcing(wvt,zero,zero,zero,zero,stage);
            for name = ["u","v","w","eta"]
                testCase.verifyEqual(direct.(name),shared.(name),AbsTol=1e-15)
            end
            testCase.verifyEqual(wvt.coefficientState(),state)
            testCase.verifyEqual([wvt.t,wvt.t0],[37,-17])
            testCase.verifyEmpty(wvt.forcing)
        end
    end
end

function wvt = newTransform(antialias,quadratic)
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,shouldAntialias=antialias,shouldCheckQuadraticAliasing=quadratic,apvModeCount=2,mdaModeCount=2,waveModeCount=3,inertialModeCount=2,nEVP=128);
end
