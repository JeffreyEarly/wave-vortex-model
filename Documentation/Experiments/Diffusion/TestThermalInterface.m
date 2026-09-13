classdef TestThermalInterface < matlab.unittest.TestCase
    methods (Test, TestTags="diffusion-research")
        function coefficientsAndCachedFields(testCase)
            w = newFixture();
            a = w.coefficientStateAnnotations();
            testCase.verifyEqual(string({a.name}),"Ath");
            testCase.verifyEqual(w.coefficientState(),struct(Ath=w.Ath));
            testCase.verifySize(w.Ath,[3 2]);
            testCase.verifyFalse(isprop(w,'Ag_q'));
            testCase.verifyFalse(isprop(w,'Ag_0'));
            expected = w.reconstruction*w.Ath;
            testCase.verifyEqual(w.reconstructFields("probeField").probeField,expected);
            testCase.verifyEqual(w.variableWithName('probeField'),expected);
            testCase.verifyEqual(w.reconstructionCount,1);
            map = w.reconstruction;
            w.Ath = 2*w.Ath;
            testCase.verifyEqual(w.probeField,2*expected);
            testCase.verifyEqual(w.reconstructionCount,2);
            testCase.verifyEqual(w.reconstruction,map);
        end
        function prescribedTendencyThroughModel(testCase)
            w = newFixture();
            initial = w.Ath;
            model = WVModel(w);
            model.setupIntegrator(integratorType="fixed",deltaT=.25);
            model.integrateToTime(2);
            testCase.verifyEqual(w.t,2);
            testCase.verifyEqual(w.Ath,initial+4*w.source,AbsTol=2e-14);
        end
        function annotatedRestoreAndContinuation(testCase)
            w = newFixture();
            model = WVModel(w);
            model.setupIntegrator(integratorType="fixed",deltaT=.25);
            model.integrateToTime(1);
            path = [tempname '.nc'];
            cleanup = onCleanup(@()delete(path));
            file = w.writeToFile(path);
            file.close();
            testCase.verifyError(@()ThermalInterfaceFixture.scientificFactory(),'ThermalInterfaceFixture:ScientificConstructionDisabled');
            restored = WVTransform.waveVortexTransformFromFile(path);
            testCase.verifyEqual(restored.coefficientState(),w.coefficientState());
            testCase.verifyEqual(restored.t,w.t);
            testCase.verifyEqual(restored.reconstruction,w.reconstruction);
            testCase.verifyEqual(restored.source,w.source);
            testCase.verifyEqual(restored.probeField,w.probeField);
            resumed = WVModel(restored);
            resumed.setupIntegrator(integratorType="fixed",deltaT=.25);
            resumed.integrateToTime(2);
            model.integrateToTime(2);
            testCase.verifyEqual(restored.Ath,w.Ath,AbsTol=2e-14);
        end
    end
end

function w = newFixture()
map = [1 0 2;0 1 -1;1 1 0;2 -1 1];
source = [1 2;3 4;5 6]*1e-3*(1+2i);
state = [1 2;3 4;5 6]*(1-1i);
w = ThermalInterfaceFixture(reconstruction=map,source=source,Ath=state);
end
