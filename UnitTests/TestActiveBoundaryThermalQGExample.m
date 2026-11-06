classdef TestActiveBoundaryThermalQGExample < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function addExampleAndReferencePaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'Examples')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'UnitTests','Fixtures')));
        end
    end

    methods (Test, TestTags="full")
        function unforcedFieldsMatchIndependentSpatialAndMeanSolutions(testCase)
            for profile = ["constant","exponential"]
                result = activeBoundaryThermalQG(profile=profile);
                w = result.transform;
                testCase.verifyEmpty(w.forcingNames());
                testCase.verifyEqual(result.time,86400);
                testCase.verifyGreaterThan(norm(w.Ath,'fro'),0);
                testCase.verifyGreaterThan(norm(w.Amda),0);
                testCase.verifyGreaterThan(result.energy.totalEnergy,0);
                testCase.verifyLessThan(result.energy.totalEnergy,result.initialEnergy.totalEnergy);
                for name = string(fieldnames(result.fields)).'
                    testCase.verifyEqual(result.components.ath.(name)+result.components.amda.(name),result.fields.(name),AbsTol=1e-13);
                end
                testCase.verifyLessThan(result.initialProjection.qgpvRMS,1e-11);
                testCase.verifyLessThan(result.meanBuoyancyRmsError,1e-8);
                [coarseReference,~] = homogeneousReference(w,36,257);
                [refinedReference,weights] = homogeneousReference(w,48,513);
                testCase.verifyLessThan(max(fieldErrors(coarseReference,refinedReference,weights)),1e-5);
                errors = fieldErrors(thermalFields(result),refinedReference,weights);
                testCase.verifyLessThan(max(errors),2e-3);
            end
        end

        function thermalDimensionSamplingAndAssemblyRefineIndependently(testCase)
            configurations = [17 65 257; 25 65 257; 33 65 257; 17 97 257; 17 65 513];
            errors = zeros(size(configurations,1),4);
            for i = 1:size(configurations,1)
                configuration = configurations(i,:);
                result = activeBoundaryThermalQG(profile="exponential",thermalModeCount=configuration(1), ...
                    Nz=configuration(2),assemblyQuadratureCount=configuration(3));
                w = result.transform;
                testCase.verifyEqual([w.thermalModeCount,w.Nz,w.assemblyQuadratureCount],configuration);
                if i==1, [reference,weights] = homogeneousReference(w,48,513); end
                errors(i,:) = fieldErrors(thermalFields(result),reference,weights);
            end
            % The three axis controls share the same manufactured initial
            % streamfunction, mean profile, elapsed time, diffusivity and
            % independent reference error budget.
            testCase.verifyLessThan(max(errors,[],'all'),1e-8);
        end

        function exponentialSteppingRestartAndTransferPreserveTheState(testCase)
            result = activeBoundaryThermalQG(finalTime=0);
            w = result.transform;
            state = w.coefficientState();
            [fine,assessment] = w.waveVortexTransformWithResolution([w.Nx w.Ny 97]);
            testCase.verifyEqual(fine.thermalModeCount,w.thermalModeCount);
            testCase.verifyEqual(fine.assemblyQuadratureCount,w.assemblyQuadratureCount);
            testCase.verifyLessThan(assessment.relativeFieldError,1e-7);
            data = w.linearEvolutionData();
            finalTime = 86400;
            expected = data.fromModes(exp(finalTime*data.rates).*data.toModes(state));
            for step = [10800 5400]
                evolved = activeBoundaryThermalQG(finalTime=finalTime,timeStep=step);
                testCase.verifyEqual(evolved.transform.Ath,expected.Ath,AbsTol=2e-13);
                testCase.verifyEqual(evolved.transform.Amda,expected.Amda,AbsTol=2e-13);
            end

            model = diffusionModel(w,10800);
            model.integrateToTime(finalTime/2,shouldShowIntegrationDiagnostics=false);
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path = fullfile(fixture.Folder,'thermal.nc');
            file = w.writeToFile(path);
            file.close();
            restored = WVTransform.waveVortexTransformFromFile(path);
            testCase.verifyEqual(restored.coefficientState(),w.coefficientState());
            testCase.verifyEqual([restored.t restored.t0],[w.t w.t0]);
            continuation = diffusionModel(restored,10800);
            continuation.integrateToTime(finalTime,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(restored.Ath,expected.Ath,AbsTol=2e-13);
            testCase.verifyEqual(restored.Amda,expected.Amda,AbsTol=2e-13);
        end
    end
end

function model = diffusionModel(w,step)
model = WVModel(w);
model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true, ...
    exponentialAdaptive=false,initialStep=step,maximumStep=step);
end

function [fields,weights] = homogeneousReference(w,dimension,quadratureCount)
[nodes,weights] = legpts(385);
z = w.Lz*(nodes-1)/2;
weights = w.Lz*weights(:)/2;
N2 = @(points) w.N20*exp(2*w.inverseScale*points);
dLnN2 = @(points) 2*w.inverseScale+zeros(size(points));
reference = balancedDensityDiffusionReference(N2,dLnN2,w.Lz,2*pi/w.Lx,w.f,w.g, ...
    w.kappa_z,dimension,quadratureCount,z);
xi = 1+z/w.Lz;
initial = reference.streamfunction\(10*(xi.^3/6-xi.^4/12-1/12));
state = expm(w.t*reference.generator)*initial;
fields = struct(buoyancy=reference.buoyancy*state,qgpv=reference.qgpv*state, ...
    ssh=reference.ssh*state,endpointAnomalies=reference.endpoints*state);
end

function fields = thermalFields(result)
w = result.transform;
fields = result.components.ath;
[nodes,~] = legpts(385);
query = (nodes+1)/2;
if w.inverseScale~=0
    % The native Chebyshev interpolant lives in the WKB coordinate.
    z = w.Lz*(query-1);
    query = 1+expm1(w.inverseScale*z)/(-expm1(-w.Lz*w.inverseScale));
end
for name = ["buoyancy","qgpv"]
    values = squeeze(fields.(name)(1,1,:));
    fields.(name) = bary(2*query-1,values);
end
fields.ssh = fields.ssh(1,1);
fields.endpointAnomalies = squeeze(fields.endpointAnomalies(1,1,:));
end

function errors = fieldErrors(actual,reference,weights)
errors = zeros(1,4);
names = ["buoyancy","qgpv","ssh","endpointAnomalies"];
metrics = {sqrt(weights),sqrt(weights),1,ones(2,1)};
for i = 1:numel(names)
    name = names(i);
    scale = metrics{i};
    errors(i) = norm(scale.*(actual.(name)-reference.(name)))/norm(scale.*reference.(name));
end
end
