classdef TestActiveBoundaryBoussinesqExample < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function addExamplePath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'Examples')));
        end
    end

    methods (Test, TestTags="full")
        function mixedFieldsHaveIndependentPhaseAndEnergyChecks(testCase)
            for profile = ["constant","exponential"]
                result = activeBoundaryBoussinesq(profile=profile);
                w = result.transform;
                testCase.verifyEqual(w.quadraticDealiasing,"none");
                testCase.verifyEqual([numel(w.apvMode),numel(w.mdaMode),numel(w.inertialMode),numel(w.waveMode)],[3 2 3 4]);
                testCase.verifyEqual(result.time,600);
                for name = string(fieldnames(result.fields)).'
                    components = result.components;
                    sumFields = components.wave.(name)+components.balanced.(name)+components.inertial.(name);
                    waveSum = components.surfaceGravityWave.(name)+components.internalGravityWave.(name);
                    testCase.verifyEqual(sumFields,result.fields.(name),AbsTol=2e-13);
                    testCase.verifyEqual(waveSum,components.wave.(name),AbsTol=2e-13);
                end
                testCase.verifyGreaterThan(norm(result.components.surfaceGravityWave.ssh,'fro'),0);
                testCase.verifyGreaterThan(norm(result.components.internalGravityWave.ssh,'fro'),0);
                testCase.verifyGreaterThan(norm(result.components.mda.eta(:)),0);

                testCase.verifyEqual(result.energy.totalEnergy,physicalEnergy(w,result.fields,w.verticalQuadratureWeights,w.N2),RelTol=2e-13);
                testCase.verifyEqual(result.energy.totalEnergy,result.initialEnergy.totalEnergy,RelTol=5e-7);
                testCase.verifyEqual(result.energy.totalEnergy,physicalEnergy(w,result.initialFields,w.verticalQuadratureWeights,w.N2),RelTol=5e-7);

                spectral = w.reconstructSpectralState();
                divergence = spectral.u.*(1i*w.k(:).')+spectral.v.*(1i*w.l(:).');
                wZ = w.verticalDerivativeMatrix*spectral.w;
                testCase.verifyLessThan(norm(divergence+wZ,'fro')/(norm(divergence,'fro')+norm(wZ,'fro')),1e-7);
                testCase.verifyLessThan(max(abs(spectral.w(1,:))),1e-13);
                verifyPhases(testCase,result);
            end
        end

        function verticalSamplesAndRetainedWaveBandAreSeparateControls(testCase)
            result = activeBoundaryBoussinesq(profile="exponential");
            w = result.transform;
            [fine,fineAssessment] = w.waveVortexTransformWithResolution([w.Nx w.Ny 97]);
            testCase.verifyEqual(fine.waveModeCountByKh,w.waveModeCountByKh);
            testCase.verifyEqual(fine.apvModeNumber,w.apvModeNumber);
            testCase.verifyEqual(fine.mdaModeNumber,w.mdaModeNumber);
            testCase.verifyEqual([fine.t fine.t0],[w.t w.t0]);
            testCase.verifyEqual(fineAssessment.discardedEnergy,0);
            names = ["u_hat","v_hat","w_hat","eta","ssh"];
            [nodes,weights] = legpts(257);
            z = w.Lz*(nodes-1)/2;
            weights = w.Lz*weights(:)/2;
            native = fieldsAtDepth(w,z,names);
            refined = fieldsAtDepth(fine,z,names);
            difference = subtractFields(refined,native,names);
            referenceEnergy = physicalEnergy(w,native,weights,w.N2Function(z));
            testCase.verifyLessThan(sqrt(physicalEnergy(w,difference,weights,w.N2Function(z))/referenceEnergy),1e-7);

            [shorter,bandAssessment] = w.waveVortexTransformWithResolution([w.Nx w.Ny w.Nz],waveModeCount=2);
            testCase.verifyEqual(shorter.z,w.z);
            testCase.verifyEqual(shorter.waveModeCountByKh,2*ones(size(w.waveModeCountByKh)));
            kept = fieldsAtDepth(shorter,z,names);
            difference = subtractFields(native,kept,names);
            discardedEnergy = physicalEnergy(w,difference,weights,w.N2Function(z));
            testCase.verifyGreaterThan(discardedEnergy,0);
            testCase.verifyEqual(discardedEnergy,bandAssessment.discardedEnergy,RelTol=2e-6);
        end

        function mixedStateRestartsAtTheSavedWaveClock(testCase)
            result = activeBoundaryBoussinesq(finalTime=300);
            w = result.transform;
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path = fullfile(fixture.Folder,'boussinesq.nc');
            file = w.writeToFile(path);
            file.close();
            restored = WVTransform.waveVortexTransformFromFile(path);
            testCase.verifyEqual([restored.t restored.t0],[w.t w.t0]);
            restoredScience = restored.scientificState();
            originalScience = w.scientificState();
            testCase.verifyEqual(restoredScience.verticalGridSnapshot,originalScience.verticalGridSnapshot);
            originalState = w.coefficientState();
            restoredState = restored.coefficientState();
            for name = string(fieldnames(originalState)).'
                testCase.verifyEqual(norm(restoredState.(name)-originalState.(name),'fro'),0);
            end
            resumed = WVModel(restored,shouldUseLinearDynamics=true);
            resumed.integrateToTime(600,shouldShowIntegrationDiagnostics=false);
            uninterrupted = WVModel(w,shouldUseLinearDynamics=true);
            uninterrupted.integrateToTime(600,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(restored.reconstructFields(["u_hat","w_hat","eta","ssh"]), ...
                w.reconstructFields(["u_hat","w_hat","eta","ssh"]),AbsTol=2e-13);
        end
    end
end

function verifyPhases(testCase,result)
w = result.transform;
j = result.waveFourierColumn;
p = w.klNonzeroKhUniqueIndex(j);
elapsed = result.time-w.t0;
for i = 1:4
    mask = false(size(w.Aw_p));
    mask(i,j) = true;
    sign = (-1)^(i-1);
    if sign>0
        component = WVFlowComponent(w,coefficientMasks=struct(Aw_p=mask));
    else
        component = WVFlowComponent(w,coefficientMasks=struct(Aw_m=mask));
    end
    w.t = w.t0;
    initial = w.reconstructSpectralState(flowComponent=component);
    w.t = result.time;
    evolved = w.reconstructSpectralState(flowComponent=component);
    omega = sqrt(w.f^2+w.g*w.waveEquivalentDepth(i,p)*w.khNonzero(j)^2);
    testCase.verifyGreaterThan(norm(initial.w,'fro'),0);
    testCase.verifyEqual(evolved.w,initial.w*exp(1i*sign*omega*elapsed),AbsTol=2e-13);
end
component = w.flowComponentWithName("inertial");
w.t = w.t0;
initial = w.reconstructSpectralState(flowComponent=component);
w.t = result.time;
evolved = w.reconstructSpectralState(flowComponent=component);
testCase.verifyEqual(evolved.u-1i*evolved.v,(initial.u-1i*initial.v)*exp(1i*w.f*elapsed),AbsTol=2e-13);
end

function fields = fieldsAtDepth(w,z,names)
fields = w.reconstructFields(names);
interpolation = w.verticalGrid.calculus.interpolationMatrix(z);
for name = names(names~="ssh")
    values = reshape(fields.(name),[],w.Nz)*interpolation.';
    fields.(name) = reshape(values,w.Nx,w.Ny,numel(z));
end
end

function difference = subtractFields(first,second,names)
for name = names
    difference.(name) = first.(name)-second.(name);
end
end

function energy = physicalEnergy(w,fields,weights,N2)
integrand = fields.u_hat.^2+fields.v_hat.^2+fields.w_hat.^2+reshape(N2,1,1,[]).*fields.eta.^2;
energy = mean(sum(reshape(weights,1,1,[]).*integrand,3)+w.g*fields.ssh.^2,'all')/2;
end
