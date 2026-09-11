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
            fields = wvt.reconstructFields(["u","v","w","u_hat","v_hat","w_hat","eta","eta_i","ssh","w_i","z_physical","p"]);
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
            testCase.verifyEqual(fields.p,wvt.transformToSpatialDomainWithFourier(spectral.p))
            testCase.verifyEqual(wvt.p,fields.p)
            testCase.verifyFalse(any(ismember(["p_linear","p_full"],string(wvt.namesOfTransformVariables()))))
            testCase.verifyError(@()wvt.reconstructFields("p_linear"),'WVTransform:UnknownVariable')
            testCase.verifyError(@()wvt.reconstructFields("p_full"),'WVTransform:UnknownVariable')
            testCase.verifyFalse(ismethod(wvt,"fullPressure"))
            physical = struct(u=expectedU,v=expectedV,w=expectedW,eta=fields.eta,ssh=fields.ssh);
            original = wvt.coefficientState();
            [recovered,assessment] = wvt.projectFields(physical);
            testCase.verifyLessThan(coefficientEnergyError(wvt,recovered,original),2e-7)
            testCase.verifyLessThan(assessment.relativeFieldEnergyError,2e-7)
            testCase.verifyEqual(wvt.coefficientState(),original)
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            quadratic = .5*sum(weights.*(fields.u_hat.^2+fields.v_hat.^2+fields.w_hat.^2+1e-4*fields.eta.^2),'all')+.5*wvt.g*mean(fields.ssh.^2,'all');
            testCase.verifyEqual(wvt.totalEnergy,quadratic,RelTol=2e-13)
            testCase.verifyEqual(wvt.physicalEnergy().totalEnergy,quadratic,RelTol=2e-13)
            label = fields.z_physical-fields.eta;
            testCase.verifyEqual(mean(fields.eta(:,:,end)-fields.ssh,'all'),2,AbsTol=2e-12)
            testCase.verifyEqual(mean(fields.eta(:,:,1),'all'),-2,AbsTol=2e-12)
            testCase.verifyGreaterThan(min(label,[],'all'),-wvt.Lz)
            testCase.verifyLessThan(max(label,[],'all'),0)
        end

        function componentFieldsAddAndCachesFollowClocksCoefficientsAndGeometry(testCase)
            wvt = fixture();
            names = ["u","v","w","u_hat","v_hat","w_hat","eta","eta_i","ssh","w_i","p"];
            total = wvt.reconstructFields(names);
            summed = structfun(@(value)zeros(size(value)),total,UniformOutput=false);
            for label = ["wave","balanced","inertial"]
                component = wvt.flowComponentWithName(label);
                fields = wvt.reconstructFields(names,flowComponent=component);
                for name = names, summed.(name)=summed.(name)+fields.(name); end
            end
            for name = names, testCase.verifyEqual(summed.(name),total.(name),AbsTol=2e-11); end
            balanced = wvt.flowComponentWithName("balanced");
            testCase.verifyError(@()wvt.reconstructFields("z_physical",flowComponent=balanced),'WVTransform:TotalStateVariable')
            warm = wvt.v_balanced;
            hat = wvt.v_hat_balanced;
            pressure = wvt.p;
            physicalZ = wvt.z_physical;
            wvt.t = wvt.t+917;
            expected = wvt.reconstructFields(["u","v","w","p"],flowComponent=balanced);
            testCase.verifyEqual(wvt.u_balanced,expected.u)
            testCase.verifyEqual(wvt.v_balanced,expected.v)
            testCase.verifyEqual(wvt.w_balanced,expected.w)
            testCase.verifyEqual(wvt.p_balanced,expected.p)
            testCase.verifyGreaterThan(norm(wvt.v_balanced(:)-warm(:)),1e-8)
            testCase.verifyEqual(wvt.v_hat_balanced,hat)
            testCase.verifyEqual(wvt.p,wvt.reconstructFields("p").p)
            testCase.verifyEqual(wvt.z_physical,wvt.reconstructFields("z_physical").z_physical)
            testCase.verifyGreaterThan(norm(wvt.p(:)-pressure(:)),1e-7)
            testCase.verifyGreaterThan(norm(wvt.z_physical(:)-physicalZ(:)),1e-7)
            warm = wvt.v_balanced;
            pressure = wvt.p;
            wvt.t0 = wvt.t0-631;
            expected = wvt.reconstructFields(["u","v","w","p"],flowComponent=balanced);
            testCase.verifyEqual(wvt.u_balanced,expected.u)
            testCase.verifyEqual(wvt.v_balanced,expected.v)
            testCase.verifyEqual(wvt.w_balanced,expected.w)
            testCase.verifyEqual(wvt.p_balanced,expected.p)
            testCase.verifyGreaterThan(norm(wvt.v_balanced(:)-warm(:)),1e-8)
            testCase.verifyEqual(wvt.v_hat_balanced,hat)
            testCase.verifyGreaterThan(norm(wvt.p(:)-pressure(:)),1e-7)

            x = [12000 53000]; y = [23000 71000]; z = [-250 -650];
            [warmU,warmP] = wvt.variableAtPositionWithName(x,y,z,'u','p');
            wvt.Aw_p = 1.03*wvt.Aw_p;
            expected = wvt.reconstructFields(["u","p","z_physical"]);
            testCase.verifyEqual(wvt.u,expected.u)
            testCase.verifyEqual(wvt.p,expected.p)
            testCase.verifyEqual(wvt.z_physical,expected.z_physical)
            [changedU,changedP] = wvt.variableAtPositionWithName(x,y,z,'u','p');
            testCase.verifyGreaterThan(norm(changedU-warmU),1e-10)
            testCase.verifyGreaterThan(norm(changedP-warmP),1e-5)
        end

        function modalPressureIgnoresForcingAndNonlinearEnergyUsesPhysicalVolume(testCase)
            wvt = fixture();
            fields = wvt.reconstructFields(["u","v","w","eta","ssh","p","z_physical"]);
            gamma = 1+fields.ssh/wvt.Lz;
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            expectedKinetic = .5*sum(weights.*gamma.*(fields.u.^2+fields.v.^2+fields.w.^2),'all');
            crest = max(fields.z_physical,0);
            expectedAPE = .5e-4*sum(weights.*gamma.*(fields.eta.^2-crest.^2),'all');
            expectedSurface = .5*wvt.g*mean(fields.ssh.^2,'all');
            energy = wvt.nonlinearEnergy();
            testCase.verifyEqual(energy.kineticEnergy,expectedKinetic,RelTol=2e-13)
            testCase.verifyEqual(energy.availablePotentialEnergy,expectedAPE,RelTol=2e-13)
            testCase.verifyEqual(energy.surfaceEnergy,expectedSurface,RelTol=2e-13)
            testCase.verifyEqual(energy.totalEnergy,expectedKinetic+expectedAPE+expectedSurface,RelTol=2e-13)
            testCase.verifyGreaterThan(abs(energy.totalEnergy-wvt.totalEnergy),1e-6)

            [X,Y,A] = ndgrid(wvt.x,wvt.y,1+wvt.z/wvt.Lz);
            physicalU = 1e-8*A.*cos(2*pi*X/wvt.Lx);
            physicalV = -2e-8*A.^2.*sin(2*pi*Y/wvt.Ly);
            physicalW = 3e-9*A.*cos(2*pi*(X/wvt.Lx+Y/wvt.Ly));
            physicalSource = WVPrescribedBoussinesqSource(wvt,uRate=physicalU,vRate=physicalV,wRate=physicalW,sourceCoordinates="physical");
            pressure = wvt.p;
            nonlinear = WVNonlinearAdvection(wvt);
            wvt.addForcing([nonlinear,physicalSource]);
            testCase.verifyEqual(wvt.p,pressure)
            testCase.verifyEqual(wvt.reconstructFields("p").p,pressure)
            wvt.removeForcing(physicalSource);
            testCase.verifyEqual(wvt.p,pressure)
            referenceSource = WVPrescribedBoussinesqSource(wvt,uRate=physicalU,vRate=physicalV,wRate=physicalW,sourceCoordinates="reference");
            wvt.addForcing(referenceSource);
            testCase.verifyEqual(wvt.p,pressure)
            testCase.verifyEqual(wvt.reconstructFields("p").p,pressure)
            wvt.removeForcing(referenceSource);
            wvt.removeForcing(nonlinear);
            % Modal pressure changes only after the prognostic state changes.
            wvt.Aw_p = 1.05*wvt.Aw_p;
            testCase.verifyGreaterThan(norm(wvt.p(:)-pressure(:)),1e-4)
        end

        function nativeFileRetainsFieldConventionAndStoredModes(testCase)
            wvt = fixture();
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path = fullfile(folder.Folder,'physical-contract.nc');
            file = wvt.writeToFile(path);
            convention = CAAnnotatedClass.propertyValuesFromGroup(file,{'fieldConvention'});
            testCase.verifyEqual(string(convention.fieldConvention),"physical-velocity-upper-constant")
            file.close();
            restored = WVTransform.waveVortexTransformFromFile(path);
            testCase.verifyEqual(restored.fieldConvention,wvt.fieldConvention)
            testCase.verifyEqual(restored.coefficientState(),wvt.coefficientState())
            testCase.verifyEqual([restored.t,restored.t0],[wvt.t,wvt.t0])
            testCase.verifyEmpty(restored.verticalModes)
            for name = ["apvF","waveF","waveG","waveFrequency","verticalDerivativeMatrix"]
                testCase.verifyEqual(restored.(name),wvt.(name))
            end
            names = ["u","v","w","u_hat","v_hat","w_hat","eta","ssh","p","w_i","z_physical"];
            testCase.verifyEqual(restored.reconstructFields(names),wvt.reconstructFields(names))
            testCase.verifyEqual(restored.nonlinearEnergy().totalEnergy,wvt.nonlinearEnergy().totalEnergy,RelTol=2e-13)
            testCase.verifyEqual(restored.p,wvt.p)
            legacy = NetCDFFile(path,shouldReadOnly=false);
            legacy.addAttribute('fieldConvention','physical-velocity-full-c1');
            legacy.close();
            testCase.verifyError(@()WVTransform.waveVortexTransformFromFile(path),'WVTransform:UnsupportedFieldConvention')
        end
    end
end

function wvt = fixture()
persistent scientific
if isempty(scientific)
    base = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    choices = [3;2;0];
    counts = choices(1+mod((0:numel(base.khUnique)-1).',3));
    wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,waveModeCount=counts,waveModeKappa=base.khUnique,mdaModeCount=2,inertialModeCount=2,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    scientific = wvt.scientificState();
else
    wvt = WVTransformFreeSurfaceBoussinesq(scientific);
end
study = manuscriptEvolutionOperators(wvt,"constant");
state = study.seed("mixed",1);
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
