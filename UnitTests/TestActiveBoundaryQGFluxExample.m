classdef TestActiveBoundaryQGFluxExample < matlab.unittest.TestCase
    properties (TestParameter)
        profile = {"constant","exponential"}
    end
    methods (TestMethodSetup)
        function exposeExamples(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,"Examples")));
        end
    end
    methods (Test, TestTags="full")
        function exampleAdvancesColumnInputAndReconstructsComponents(testCase,profile)
            example = activeBoundaryQGBuoyancyFlux(profile=profile);
            q = example.transform;
            testCase.verifyEqual(q.t,example.period/4)
            testCase.verifyEqual(example.penetrationDepth,52.4423246684,AbsTol=1e-9)
            testCase.verifyEqual(example.columnBuoyancy,example.expectedColumnBuoyancy,RelTol=2e-6)
            testCase.verifyGreaterThan(norm(q.Ag_q,"fro"),0)
            testCase.verifyGreaterThan(norm(q.Ag_0,"fro"),0)
            testCase.verifyGreaterThan(norm(q.Amda),0)
            testCase.verifyGreaterThan(example.energy.totalEnergy,0)
            for name = string(fieldnames(example.fields)).'
                reconstructed = example.components.apv.(name)+example.components.zeroapv.(name)+example.components.mda.(name);
                scale = max(abs(example.fields.(name)),[],"all");
                testCase.verifyEqual(reconstructed,example.fields.(name),AbsTol=5e-13*scale)
            end
        end

        function persistedPhysicalFluxContinuesWithItsAbsoluteClock(testCase)
            example = activeBoundaryQGBuoyancyFlux();
            q = example.transform;
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path = fullfile(folder.Folder,"physical-flux.nc");
            file = q.writeToFile(path);
            file.close();
            restored = WVTransform.waveVortexTransformFromFile(path,iTime=Inf);
            testCase.verifyEqual(restored.t,q.t)
            testCase.verifyEqual(restored.coefficientState(),q.coefficientState())
            savedForce = q.forcingWithName("seasonal surface buoyancy flux");
            restoredForce = restored.forcingWithName("seasonal surface buoyancy flux");
            for name = ["pattern","amplitude","period","phase"]
                testCase.verifyEqual(restoredForce.(name),savedForce.(name))
            end
            advance(q,example.period/2,example.step);
            advance(restored,example.period/2,example.step);
            for name = ["Ag_q","Ag_0","Amda"]
                testCase.verifyEqual(restored.(name),q.(name),AbsTol=2e-13*norm(q.(name),"fro"))
            end
        end
    end
end

function advance(q,time,step)
model = WVModel(q);
model.setupIntegrator(integratorType="exponential",initialStep=step,maximumStep=step,exponentialAdaptive=false);
model.integrateToTime(time,shouldShowIntegrationDiagnostics=false);
end
