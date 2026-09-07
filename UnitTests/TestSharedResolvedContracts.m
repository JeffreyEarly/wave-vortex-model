classdef TestSharedResolvedContracts < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function qgPureAndMixedFieldsUseOrdinaryOperations(testCase)
            w = newQG(.02,.03);
            setMixedQG(w);
            original = w.coefficientState();
            components = [w.flowComponentWithName('apv') w.flowComponentWithName('zeroapv') w.flowComponentWithName('mda')];
            names = ["psi" "u" "v" "eta" "qgpv" "ssh" "ssu" "ssv"];
            full = w.reconstructFields(names);
            sums = structfun(@(v)zeros(size(v)),full,UniformOutput=false);
            for component = components
                selected = w.reconstructFields(names,flowComponent=component);
                state = w.coefficientState(flowComponent=component);
                testCase.verifyEqual(w.coefficientState(),original)
                for name = names
                    registered = w.variableWithName(char(name+"_"+component.abbreviatedName));
                    testCase.verifyEqual(registered,selected.(name))
                    sums.(name) = sums.(name)+selected.(name);
                end
                assignState(w,state);
                for name = names, testCase.verifyEqual(w.(name),selected.(name)); end
                assignState(w,original);
            end
            for name = names
                testCase.verifyEqual(w.(name),full.(name))
                testCase.verifyEqual(sums.(name),full.(name),AbsTol=2e-12)
            end
            union = components(1)+components(2)+components(3);
            testCase.verifyTrue(union.contains(components(1)))
            testCase.verifyFalse(components(1).contains(components(2)))
            testCase.verifyEqual(w.coefficientState(flowComponent=union),original)
            [psiHat,etaHat,qHat] = w.reconstructSpectralState();
            testCase.verifyEqual(full.psi,w.transformToSpatialDomainWithFourier(psiHat))
            testCase.verifyEqual(full.eta,w.transformToSpatialDomainWithFourier(etaHat))
            testCase.verifyEqual(full.qgpv,w.transformToSpatialDomainWithFourier(qHat))
        end

        function masksRespectIndependentAndAbsentFamilies(testCase)
            for endpoints = [.02 Inf;Inf Inf].'
                w = newQG(endpoints(1),endpoints(2));
                setMixedQG(w);
                state = w.coefficientState();
                testCase.verifyEqual(string(fieldnames(state)).',["Ag_q" "Ag_0" "Amda"])
                testCase.verifyTrue(isreal(state.Amda))
                if isfinite(w.g0), testCase.verifyNotEqual(w.apvModeCount,w.mdaModeCount); end
                mask = false(size(w.Amda)); mask(1) = true;
                c = WVFlowComponent(w,coefficientMasks=struct(Amda=mask,Ag_0=true));
                selected = w.coefficientState(flowComponent=c);
                testCase.verifyEqual(selected.Amda,state.Amda.*mask)
                testCase.verifyEqual(selected.Ag_q,zeros(size(state.Ag_q)))
                testCase.verifyEqual(selected.Ag_0,state.Ag_0)
                testCase.verifyEqual(size(selected.Ag_0),size(state.Ag_0))
                testCase.verifyError(@()WVFlowComponent(w,coefficientMasks=struct(Amda=mask.')),'WVFlowComponent:InvalidMask')
                testCase.verifyError(@()WVFlowComponent(w,coefficientMasks=struct(Amda=.5)),'WVFlowComponent:InvalidMask')
                testCase.verifyError(@()WVFlowComponent(w,coefficientMasks=struct(Ap=true)),'WVFlowComponent:UnknownFamily')
                if w.activeEndpointCount == 0
                    testCase.verifyEmpty(state.Ag_0)
                    apv = w.flowComponentWithName('apv');
                    empty = w.flowComponentWithName('zeroapv');
                    testCase.verifyTrue(apv.contains(empty))
                    testCase.verifyError(@()empty.randomAmplitudes(),'WVFlowComponent:UnsupportedAnalyticalModes')
                    testCase.verifyEqual(w.u_zeroapv,zeros(w.spatialMatrixSize))
                end
            end
            other = newQG(.02,Inf);
            testCase.verifyError(@()w.coefficientState(flowComponent=other.flowComponentWithName('mda')),'WVTransform:InvalidComponent')
        end

        function physicalEnergyRetainsComponentCrossTerms(testCase)
            w = newQG(.02,.03);
            setMixedQG(w);
            components = [w.flowComponentWithName('apv') w.flowComponentWithName('zeroapv') w.flowComponentWithName('mda')];
            total = 0;
            for c = components
                fields = w.reconstructFields(["u" "v" "eta" "ssh"],flowComponent=c);
                direct = sum(w.verticalQuadratureWeights.*squeeze(mean(fields.u.^2+fields.v.^2+reshape(w.N2,1,1,[]).*fields.eta.^2,[1 2])))/2;
                direct = direct+w.g*mean(fields.ssh.^2,'all')/2;
                e = w.totalEnergyOfFlowComponent(c);
                testCase.verifyEqual(e,direct,RelTol=1e-7,AbsTol=1e-20)
                total = total+e;
            end
            cross = 0;
            for i = 1:3
                for j = i+1:3
                    cross = cross+w.totalEnergyOfFlowComponent(components(i)+components(j))-w.totalEnergyOfFlowComponent(components(i))-w.totalEnergyOfFlowComponent(components(j));
                end
            end
            testCase.verifyGreaterThan(abs(cross),1e-8*total)
            testCase.verifyEqual(total+cross,w.totalEnergy,RelTol=1e-13)
        end

        function qgCachesInvalidateAndRHSReconstructsOnce(testCase)
            w = WVCountingFreeSurfaceQG([1e5 1e5 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=.02,gd=.03,mdaGramTolerance=.1);
            setMixedQG(w);
            metric = w.physicalMetricOperators();
            [u,eta,q] = w.variableWithName('u','eta','qgpv');
            testCase.verifyEqual(w.reconstructionCount,1)
            testCase.verifyEqual(w.u,u)
            testCase.verifyEqual(w.eta,eta)
            testCase.verifyEqual(w.qgpv,q)
            testCase.verifyEqual(w.reconstructionCount,1)
            for name = ["Ag_q" "Ag_0" "Amda"]
                before = w.reconstructionCount;
                w.(name) = 2*w.(name);
                testCase.verifyFalse(isKey(w.variableCache,'eta'))
                w.variableWithName('u','eta','qgpv');
                testCase.verifyEqual(w.reconstructionCount,before+1)
                testCase.verifyEqual(w.physicalMetricOperators(),metric)
            end
            before = w.reconstructionCount;
            w.coefficientTendency();
            testCase.verifyEqual(w.reconstructionCount,before+1)
            before = w.reconstructionCount;
            eta = w.eta;
            w.t = 100;
            testCase.verifyEqual(w.eta,eta)
            testCase.verifyEqual(w.reconstructionCount,before)
        end

        function boussinesqRetainsPhysicalFamiliesAndPhaseEvolution(testCase)
            w = WVTransformBoussinesq([1e5 1e5 1000],[8 8 17],N2Function=@(z)1e-4*exp(z/1000),latitude=30);
            seedRandomNumberGenerator(testCase,355);
            w.initWithRandomFlow(uvMax=.001);
            original = w.coefficientState();
            components = [w.geostrophicComponent w.waveComponent w.inertialComponent w.mdaComponent];
            names = ["u" "v" "w" "eta" "ssh"];
            full = w.reconstructFields(names);
            sums = structfun(@(v)zeros(size(v)),full,UniformOutput=false);
            energy = 0;
            for component = components
                selected = w.reconstructFields(names,flowComponent=component);
                selectedState = w.coefficientState(flowComponent=component);
                testCase.verifyEqual(w.coefficientState(),original)
                for name = names
                    testCase.verifyEqual(w.variableWithName(char(name+"_"+component.abbreviatedName)),selected.(name))
                    sums.(name) = sums.(name)+selected.(name);
                end
                energy = energy+w.totalEnergyOfFlowComponent(component);
                assignState(w,selectedState);
                for name = names, testCase.verifyEqual(w.(name),selected.(name),AbsTol=1e-12); end
                assignState(w,original);
            end
            for name = names, testCase.verifyEqual(sums.(name),full.(name),AbsTol=1e-12); end
            testCase.verifyEqual(energy,w.totalEnergy,RelTol=1e-12)
            wave = w.reconstructFields("u",flowComponent=w.waveComponent);
            w.t = 1234;
            evolved = w.reconstructFields("u",flowComponent=w.waveComponent);
            testCase.verifyGreaterThan(norm(evolved.u(:)-wave.u(:)),1e-7)
            testCase.verifyEqual(w.variableWithName(char("u_"+w.waveComponent.abbreviatedName)),evolved.u)
            testCase.verifyEqual(w.coefficientState(),original)
            positive = WVFlowComponent(w,coefficientMasks=struct(Ap=true));
            negative = WVFlowComponent(w,coefficientMasks=struct(Am=true));
            testCase.verifyFalse(negative.contains(positive))
            union = positive+negative;
            testCase.verifyTrue(union.contains(positive))
        end
    end
end

function w = newQG(g0,gd)
w = WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=g0,gd=gd,mdaGramTolerance=.1);
end

function setMixedQG(w)
w.Ag_q(1:3,1) = 1e-8*[1;2i;-1];
w.Ag_0(:,1) = 1e-8*(1:w.activeEndpointCount).';
w.Amda(1:3) = [.01;-.02;.03];
end

function assignState(w,state)
for name = string(fieldnames(state)).', w.(name) = state.(name); end
end
