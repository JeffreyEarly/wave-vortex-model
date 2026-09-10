classdef TestFreeSurfacePhysicalContract < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyHelpers(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function physicalMappingAndInverseProjectionAreExplicit(testCase)
            wvt = fixture();
            fields = wvt.reconstructFields(["u","v","w","u_hat","v_hat","w_hat","eta","eta_i","ssh","w_i","z_physical","p_linear"]);
            spectral = wvt.reconstructSpectralState();
            for name = ["u","v","w"]
                testCase.verifyEqual(fields.(name+"_hat"),wvt.transformToSpatialDomainWithFourier(spectral.(name)))
            end
            alpha = reshape(1+wvt.z/wvt.Lz,1,1,[]);
            gamma = 1+fields.ssh/wvt.Lz;
            expectedU = fields.u_hat./gamma;
            expectedV = fields.v_hat./gamma;
            expectedW = fields.w_hat+alpha.*(expectedU.*wvt.diffX(fields.ssh)+expectedV.*wvt.diffY(fields.ssh));
            testCase.verifyEqual(fields.u,expectedU,AbsTol=2e-14)
            testCase.verifyEqual(fields.v,expectedV,AbsTol=2e-14)
            testCase.verifyEqual(fields.w,expectedW,AbsTol=2e-14)
            testCase.verifyEqual(fields.z_physical,reshape(wvt.z,1,1,[])+alpha.*fields.ssh,AbsTol=2e-13)
            testCase.verifyEqual(fields.eta_i,fields.eta-alpha.*fields.ssh,AbsTol=2e-14)
            testCase.verifyEqual(fields.w_i,(fields.w_hat-alpha.*fields.w_hat(:,:,end))./gamma,AbsTol=2e-14)
            testCase.verifyEqual(fields.p_linear,wvt.transformToSpatialDomainWithFourier(spectral.p))
            testCase.verifyError(@()wvt.reconstructFields("p"),'WVTransform:UnknownVariable')
            testCase.verifyError(@()wvt.p,'WVTransform:UnknownVariable')
            physical = struct(u=expectedU,v=expectedV,w=expectedW,eta=fields.eta,ssh=fields.ssh);
            original = wvt.coefficientState();
            [recovered,assessment] = wvt.projectFields(physical);
            testCase.verifyLessThan(coefficientEnergyError(wvt,recovered,original),2e-7)
            testCase.verifyLessThan(assessment.relativeFieldEnergyError,2e-7)
            testCase.verifyEqual(wvt.coefficientState(),original)
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            quadratic = .5*sum(weights.*(fields.u_hat.^2+fields.v_hat.^2+fields.w_hat.^2+1e-4*fields.eta.^2),'all')+.5*wvt.g*mean(fields.ssh.^2,'all');
            testCase.verifyEqual(wvt.totalEnergy,quadratic,RelTol=2e-13)
        end

        function componentVelocitiesAddAndBalancedCachesFollowBothClocks(testCase)
            wvt = fixture();
            names = ["u","v","w","u_hat","v_hat","w_hat","eta","eta_i","ssh","w_i","p_linear"];
            total = wvt.reconstructFields(names);
            summed = structfun(@(value)zeros(size(value)),total,UniformOutput=false);
            for label = ["wave","balanced","inertial"]
                component = wvt.flowComponentWithName(label);
                fields = wvt.reconstructFields(names,flowComponent=component);
                for name = names, summed.(name)=summed.(name)+fields.(name); end
            end
            for name = names, testCase.verifyEqual(summed.(name),total.(name),AbsTol=2e-11); end
            balanced = wvt.flowComponentWithName("balanced");
            testCase.verifyError(@()wvt.reconstructFields("p_full",flowComponent=balanced),'WVTransform:TotalStateVariable')
            testCase.verifyError(@()wvt.reconstructFields("z_physical",flowComponent=balanced),'WVTransform:TotalStateVariable')
            warm = wvt.v_balanced;
            hat = wvt.v_hat_balanced;
            wvt.t = wvt.t+917;
            expected = wvt.reconstructFields(["u","v","w"],flowComponent=balanced);
            testCase.verifyEqual(wvt.u_balanced,expected.u)
            testCase.verifyEqual(wvt.v_balanced,expected.v)
            testCase.verifyEqual(wvt.w_balanced,expected.w)
            testCase.verifyGreaterThan(norm(wvt.v_balanced(:)-warm(:)),1e-8)
            testCase.verifyEqual(wvt.v_hat_balanced,hat)
            warm = wvt.v_balanced;
            wvt.t0 = wvt.t0-631;
            expected = wvt.reconstructFields(["u","v","w"],flowComponent=balanced);
            testCase.verifyEqual(wvt.u_balanced,expected.u)
            testCase.verifyEqual(wvt.v_balanced,expected.v)
            testCase.verifyEqual(wvt.w_balanced,expected.w)
            testCase.verifyGreaterThan(norm(wvt.v_balanced(:)-warm(:)),1e-8)
            testCase.verifyEqual(wvt.v_hat_balanced,hat)
        end

        function fullPressureAndEnergyIncludeExactSurfaceTermsAndSourceCoordinates(testCase)
            wvt = fixture();
            fields = wvt.reconstructFields(["u","v","w","eta","ssh"]);
            [pressure,report] = wvt.fullPressure();
            testCase.verifyEqual(pressure(:,:,end)/wvt.rho0,wvt.g*fields.ssh-.5e-4*fields.ssh.^2,AbsTol=2e-10)
            testCase.verifyLessThan(report.bottomAcceleration,2e-10)
            testCase.verifyEqual(wvt.p_full,pressure,AbsTol=2e-8)
            gamma = 1+fields.ssh/wvt.Lz;
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            expectedEnergy = .5*sum(weights.*gamma.*(fields.u.^2+fields.v.^2+fields.w.^2+1e-4*fields.eta.^2),'all')+mean(.5*wvt.g*fields.ssh.^2-(1e-4/6)*fields.ssh.^3,'all');
            energy = wvt.nonlinearEnergy();
            testCase.verifyEqual(energy.totalEnergy,expectedEnergy,RelTol=2e-13)
            testCase.verifyGreaterThan(abs(energy.totalEnergy-wvt.totalEnergy),1e-6)

            % A manufactured physical pressure gradient with zero top trace
            % changes the full pressure by rho0*chi in either source frame.
            [X,Y,A] = ndgrid(wvt.x,wvt.y,1+wvt.z/wvt.Lz);
            k = 2*pi/wvt.Lx; l = 2*pi/wvt.Ly;
            chi = .02*A.*(1-A).*cos(k*X).*cos(l*Y);
            chiX = -.02*k*A.*(1-A).*sin(k*X).*cos(l*Y);
            chiY = -.02*l*A.*(1-A).*cos(k*X).*sin(l*Y);
            chiXi = (.02/wvt.Lz)*(1-2*A).*cos(k*X).*cos(l*Y);
            sshX = wvt.diffX(fields.ssh); sshY = wvt.diffY(fields.ssh);
            physicalU = chiX-A.*sshX.*chiXi./gamma;
            physicalV = chiY-A.*sshY.*chiXi./gamma;
            physicalW = chiXi./gamma;
            physicalSource = WVPrescribedBoussinesqSource(wvt,uRate=physicalU,vRate=physicalV,wRate=physicalW,sourceCoordinates="physical");
            wvt.addForcing([WVNonlinearAdvection(wvt),physicalSource]);
            testCase.verifyEqual(wvt.p_full-pressure,wvt.rho0*chi,AbsTol=3e-7)
            wvt.removeForcing(physicalSource);
            testCase.verifyEqual(wvt.p_full,pressure,AbsTol=2e-8)
            referenceSource = WVPrescribedBoussinesqSource(wvt,uRate=gamma.*physicalU,vRate=gamma.*physicalV,wRate=physicalW-A.*(physicalU.*sshX+physicalV.*sshY),sourceCoordinates="reference");
            wvt.addForcing(referenceSource);
            testCase.verifyEqual(wvt.p_full-pressure,wvt.rho0*chi,AbsTol=3e-7)
            warm = wvt.p_full;
            wvt.Aw_p = 1.05*wvt.Aw_p;
            changed = wvt.fullPressure();
            testCase.verifyEqual(wvt.p_full,changed,AbsTol=2e-8)
            testCase.verifyGreaterThan(norm(changed(:)-warm(:)),1e-4)
        end

        function nativeFileRetainsFieldConventionAndStoredModes(testCase)
            wvt = fixture();
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path = fullfile(folder.Folder,'physical-contract.nc');
            file = wvt.writeToFile(path);
            convention = CAAnnotatedClass.propertyValuesFromGroup(file,{'fieldConvention'});
            testCase.verifyEqual(string(convention.fieldConvention),"physical-velocity-full-c1")
            file.close();
            restored = WVTransform.waveVortexTransformFromFile(path);
            testCase.verifyEqual(restored.fieldConvention,wvt.fieldConvention)
            testCase.verifyEqual(restored.coefficientState(),wvt.coefficientState())
            testCase.verifyEqual([restored.t,restored.t0],[wvt.t,wvt.t0])
            testCase.verifyEmpty(restored.verticalModes)
            for name = ["apvF","waveF","waveG","waveFrequency","verticalDerivativeMatrix"]
                testCase.verifyEqual(restored.(name),wvt.(name))
            end
            names = ["u","v","w","u_hat","v_hat","w_hat","eta","ssh","p_linear","w_i","z_physical"];
            testCase.verifyEqual(restored.reconstructFields(names),wvt.reconstructFields(names))
            testCase.verifyEqual(restored.nonlinearEnergy().totalEnergy,wvt.nonlinearEnergy().totalEnergy,RelTol=2e-13)
            testCase.verifyEqual(restored.p_full,wvt.p_full,AbsTol=2e-8)
        end
    end
end

function wvt = fixture()
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
helper = freeSurfaceWeakStudyHelpers();
state = helper.seedState(wvt);
xColumn = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
yColumn = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
state.Aw_p(1,yColumn) = .3*exp(.41i)*state.Aw_p(1,xColumn);
state.Aw_m = .4*exp(.63i)*state.Aw_p;
for family = string(fieldnames(state)).', wvt.(family)=state.(family); end
wvt.t = 327; wvt.t0 = 19;
end

function value = coefficientEnergyError(wvt,actual,expected)
for family = string(fieldnames(expected)).'
    actual.(family) = actual.(family)-expected.(family);
end
value = quadraticNorm(wvt,actual)/quadraticNorm(wvt,expected);
end

function value = quadraticNorm(wvt,state)
fields = wvt.reconstructSpectralState(state=state);
factor = 2*ones(1,wvt.Nkl); factor(wvt.k==0 & wvt.l==0)=1;
value = sqrt(sum(factor.*sum(wvt.verticalQuadratureWeights.*(abs(fields.u).^2+abs(fields.v).^2+abs(fields.w).^2+wvt.N2.*abs(fields.eta).^2),1))+wvt.g*sum(factor.*abs(fields.ssh(end,:)).^2));
end
