classdef TestFreeSurfaceQGInteriorDisplacement < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function interiorDisplacementMatchesActiveEndpointAnomalies(testCase)
            endpointValues = [Inf Inf; -0.1 Inf; Inf 0.1; -0.1 0.1];
            for profile = ["constant","exponential"]
                for endpoints = endpointValues.'
                    wvt = newTransform(profile,endpoints);
                    fields = wvt.reconstructFields(["eta","eta_i","ssh"]);
                    lift = reshape(1+wvt.z/wvt.Lz,1,1,[]);
                    expected = fields.eta-lift.*fields.ssh;
                    testCase.verifyEqual(fields.eta_i,expected,AbsTol=2e-12)
                    testCase.verifyEqual(wvt.eta_i,expected,AbsTol=2e-12)
                    testCase.verifyEqual(fields.eta_i(:,:,1),fields.eta(:,:,1),AbsTol=2e-12)
                    testCase.verifyEqual(mean(fields.eta_i,[1 2]),mean(fields.eta,[1 2]),AbsTol=2e-12)
                    [~,~,~,anomalies] = wvt.quasigeostrophicSpatialState();
                    for endpoint = 1:wvt.activeEndpointCount
                        index = 1;
                        if wvt.activeEndpoint(endpoint)==1, index=wvt.Nz; end
                        testCase.verifyEqual(fields.eta_i(:,:,index),anomalies(:,:,endpoint),AbsTol=2e-9)
                    end
                    for endpoint = setdiff([1 2],wvt.activeEndpoint.')
                        index = 1;
                        if endpoint==1, index=wvt.Nz; end
                        testCase.verifyEqual(fields.eta_i(:,:,index),zeros(wvt.Nx,wvt.Ny),AbsTol=2e-9)
                    end
                end
            end
        end

        function componentFieldsRemainAdditiveAndRegisterForCustomComponents(testCase)
            wvt = newTransform("exponential",[-0.1;0.1]);
            originalState = wvt.coefficientState();
            sumComponents = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
            for name = ["apv","zeroapv","mda"]
                component = wvt.flowComponentWithName(name);
                fields = wvt.reconstructFields(["eta","eta_i","ssh"],flowComponent=component);
                expected = fields.eta-reshape(1+wvt.z/wvt.Lz,1,1,[]).*fields.ssh;
                testCase.verifyEqual(fields.eta_i,expected,AbsTol=2e-12)
                testCase.verifyEqual(wvt.variableWithName(char("eta_i_"+name)),expected,AbsTol=2e-12)
                sumComponents = sumComponents+fields.eta_i;
            end
            testCase.verifyEqual(sumComponents,wvt.eta_i,AbsTol=2e-12)
            component = WVFlowComponent(wvt,coefficientMasks=struct(Ag_q=true,Ag_0=true));
            component.name = "balanced anomalies";
            component.shortName = "anomalies";
            component.abbreviatedName = "anomalies";
            wvt.addFlowComponent(component);
            fields = wvt.reconstructFields("eta_i",flowComponent=component);
            testCase.verifyEqual(wvt.variableWithName('eta_i_anomalies'),fields.eta_i,AbsTol=0)
            testCase.verifyEqual(wvt.coefficientState(),originalState)
            operation = wvt.operationForKnownVariable('eta_i');
            testCase.verifyEqual(operation.outputVariables.units,'m')
            testCase.verifyEqual(operation.outputVariables.dimensions,{'x','y','z'})
        end

        function everyCoefficientFamilyInvalidatesInteriorDisplacement(testCase)
            wvt = newTransform("exponential",[-0.1;0.1]);
            for family = ["Ag_q","Ag_0","Amda"]
                before = wvt.eta_i;
                beforeComponent = wvt.variableWithName('eta_i_apv');
                testCase.verifyNotEmpty(wvt.fetchFromVariableCache('eta_i'))
                testCase.verifyNotEmpty(wvt.fetchFromVariableCache('eta_i_apv'))
                wvt.(family) = 2*wvt.(family);
                testCase.verifyEmpty(wvt.fetchFromVariableCache('eta_i'))
                testCase.verifyEmpty(wvt.fetchFromVariableCache('eta_i_apv'))
                fields = wvt.reconstructFields("eta_i");
                testCase.verifyEqual(wvt.eta_i,fields.eta_i,AbsTol=0)
                testCase.verifyGreaterThan(norm(wvt.eta_i(:)-before(:)),0)
                component = wvt.flowComponentWithName('apv');
                fields = wvt.reconstructFields("eta_i",flowComponent=component);
                testCase.verifyEqual(wvt.variableWithName('eta_i_apv'),fields.eta_i,AbsTol=0)
                if family=="Ag_q"
                    testCase.verifyEqual(fields.eta_i,2*beforeComponent,AbsTol=0)
                else
                    testCase.verifyEqual(fields.eta_i,beforeComponent,AbsTol=0)
                end
            end
        end
    end
end

function wvt = newTransform(profile,endpoints)
N2 = @(z)1e-4*ones(size(z));
if profile=="exponential", N2=@(z)1e-4*exp(2*z/1000); end
wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 65],N2Function=N2,latitude=30,g0=endpoints(1),gd=endpoints(2),apvModeCount=3,mdaModeCount=3);
wvt.Ag_q(1,1) = 1e-7*(1+0.2i);
if ~isempty(wvt.Ag_0), wvt.Ag_0(:,2)=1e-7*(1:height(wvt.Ag_0)).'; end
wvt.Amda(1) = 0.02;
end
