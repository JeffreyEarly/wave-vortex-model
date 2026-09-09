classdef TestFreeSurfaceVariableWaveCounts < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function explicitMapPreservesModesAndUniformBehavior(testCase)
            uniform = newTransform();
            counts = mod(2*(0:numel(uniform.khUnique)-1).',5);
            w = newTransform(waveModeKappa=flipud(uniform.khUnique),waveModeCount=flipud(counts));
            testCase.verifyEqual(w.waveModeCountByKh,counts)
            testCase.verifySize(w.Aw_p,size(uniform.Aw_p))
            testCase.verifyEqual(w.inertialF,uniform.inertialF)
            for p = 1:numel(counts)
                modes = 1:counts(p);
                testCase.verifyEqual(w.waveF(:,modes,p),uniform.waveF(:,modes,p),AbsTol=1e-10)
                testCase.verifyEqual(w.waveG(:,modes,p),uniform.waveG(:,modes,p),AbsTol=1e-10)
                testCase.verifyEqual(w.waveEquivalentDepth(modes,p),uniform.waveEquivalentDepth(modes,p))
                testCase.verifyEqual(w.waveF(:,counts(p)+1:end,p),zeros(w.Nz,4-counts(p)))
            end
            explicit = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=4);
            explicitState = explicit.scientificState(); uniformState = uniform.scientificState();
            testCase.verifyEqual(rmfield(explicitState,{'N2Function','rhoFunction'}),rmfield(uniformState,{'N2Function','rhoFunction'}))
            testCase.verifyEqual(explicit.N2Function(explicit.z),uniform.N2Function(uniform.z))
            historical = rmfield(uniform.scientificState(),'waveModeCountByKh');
            restored = WVTransformFreeSurfaceBoussinesq(historical);
            testCase.verifyEqual(restored.scientificState(),uniform.scientificState())
        end

        function maskedStatesReconstructProjectAndConserve(testCase)
            uniform = newTransform();
            counts = mod(2*(0:numel(uniform.khUnique)-1).',5);
            w = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=counts);
            initial = initialState(w);
            assignState(w,initial); assignState(uniform,initial);
            energy = w.totalEnergy;
            for time = [0 1234 1e5]
                w.t = time; uniform.t = time;
                actual = w.reconstructFields(["u","v","w","eta","ssh"]);
                expected = uniform.reconstructFields(["u","v","w","eta","ssh"]);
                for name = string(fieldnames(actual)).'
                    testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-10)
                end
                [projected,assessment] = w.projectFields(actual);
                testCase.verifyLessThan(assessment.relativeFieldEnergyError,1e-6)
                testCase.verifyEqual(projected.Aw_p(~w.activeWaveModes),zeros(sum(~w.activeWaveModes,'all'),1))
                testCase.verifyEqual(projected.Aw_m(~w.activeWaveModes),zeros(sum(~w.activeWaveModes,'all'),1))
                testCase.verifyEqual(w.totalEnergy,energy,RelTol=1e-7)
                testCase.verifyTrue(all(isfinite(w.p),'all'))
            end
            invalid = w.Aw_p; invalid(find(~w.activeWaveModes,1)) = 1;
            testCase.verifyError(@()assignWave(w,invalid),'WVTransformFreeSurfaceBoussinesq:InactiveWaveCoefficient')
            state = w.scientificState(); state.waveEquivalentDepth(find(state.waveEquivalentDepth==0,1)) = 1;
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq(state),'WVTransformFreeSurfaceBoussinesq:InvalidScientificState')
            state = w.scientificState(); state.waveModeCountByKh = state.waveModeCountByKh+1i;
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq(state),'WVTransformFreeSurfaceBoussinesq:InvalidScientificState')
        end

        function sourceProjectionAndFixedEvolutionKeepPaddingInert(testCase)
            uniform = newTransform();
            counts = mod(2*(0:numel(uniform.khUnique)-1).',5);
            w = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=counts);
            [X,Y,Z] = ndgrid(w.x,w.y,w.z);
            sources = struct(u=1e-7*cos(2*pi*X/w.Lx).*(1+Z/w.Lz),v=2e-7*sin(2*pi*Y/w.Ly).*(Z/w.Lz).^2,w=3e-8*cos(2*pi*(X/w.Lx+Y/w.Ly)).*(1+Z/w.Lz),eta=1e-6*(1+.2*cos(2*pi*X/w.Lx)).*(1+Z/(2*w.Lz)));
            actual = w.projectSources(sources); expected = uniform.projectSources(sources);
            for name = ["Aw_p","Aw_m"]
                testCase.verifyEqual(actual.(name)(w.activeWaveModes),expected.(name)(w.activeWaveModes),AbsTol=1e-16)
                testCase.verifyEqual(actual.(name)(~w.activeWaveModes),zeros(sum(~w.activeWaveModes,'all'),1))
            end
            assignState(w,initialState(w));
            before = w.coefficientState();
            model = WVModel(w); model.setupIntegrator(integratorType="fixed",deltaT=10);
            model.integrateToTime(100,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(w.coefficientState(),before)
            forcing = WVPrescribedBoussinesqSource(w,uRate=sources.u,vRate=sources.v,wRate=sources.w,etaRate=sources.eta);
            w.addForcing(forcing);
            initialTendency = w.projectSources(sources);
            expected = before;
            omega = w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
            active = w.activeWaveModes;
            for name = ["Aw_p","Aw_m"]
                sign = -1; if name=="Aw_m", sign=1; end
                expected.(name)(active) = before.(name)(active)+initialTendency.(name)(active).*(exp(sign*1i*omega(active)*100)-1)./(sign*1i*omega(active));
            end
            model.integrateToTime(200,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(w.Aw_p,expected.Aw_p,RelTol=2e-7,AbsTol=1e-15)
            testCase.verifyEqual(w.Aw_m,expected.Aw_m,RelTol=2e-7,AbsTol=1e-15)
            testCase.verifyEqual(w.Aw_p(~active),zeros(sum(~active,'all'),1))
            testCase.verifyTrue(all(isfinite(w.u),'all'))
        end

        function zeroWavePagesKeepIndependentFamilies(testCase)
            w = newTransform(waveModeCount=0);
            testCase.verifySize(w.Aw_p,[0 numel(w.klNonzero)])
            testCase.verifyEqual(w.waveModeCountByKh,zeros(numel(w.khUnique),1))
            testCase.verifySize(w.Aio,[3 1])
            assignState(w,initialState(w));
            fields = w.reconstructFields(["u","v","w","eta","ssh"]);
            [projected,assessment] = w.projectFields(fields);
            testCase.verifyEmpty(projected.Aw_p)
            testCase.verifyLessThan(assessment.relativeFieldEnergyError,1e-6)
            zero = zeros(w.Nx,w.Ny,w.Nz);
            tendency = w.projectSources(struct(u=zero,v=zero,w=zero,eta=zero));
            testCase.verifyEmpty(tendency.Aw_p)
            testCase.verifyTrue(isfinite(w.totalEnergy))
        end

        function explicitKeysRejectAmbiguousOrIncompleteMaps(testCase)
            base = newTransform(); kappa = base.khUnique;
            counts = 2*ones(size(kappa));
            repeated = newTransform(waveModeKappa=[flipud(kappa);kappa(1)],waveModeCount=[flipud(counts);counts(1)]);
            testCase.verifyEqual(repeated.waveModeCountByKh,counts)
            testCase.verifyError(@()newTransform(waveModeCount=[2;3]),'WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap')
            testCase.verifyError(@()newTransform(waveModeKappa=kappa(1:end-1),waveModeCount=2),'WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap')
            testCase.verifyError(@()newTransform(waveModeKappa=[kappa;kappa(1)],waveModeCount=[counts;3]),'WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap')
            testCase.verifyError(@()newTransform(waveModeKappa=[kappa;2*max(kappa)],waveModeCount=2),'WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap')
        end
    end
end

function w = newTransform(options)
arguments (Input)
    options.waveModeCount (:,1) double = 4
    options.waveModeKappa (:,1) double = zeros(0,1)
end
args = namedargs2cell(options);
w = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},N2Function=@(z)1e-4*exp(2*z/700),apvModeCount=3,mdaModeCount=2,inertialModeCount=3);
end

function state = initialState(w)
state = w.coefficientState();
for name = string(fieldnames(state)).'
    value = state.(name); ordinal = reshape(1:numel(value),size(value));
    if ismember(name,["Ag_q","Ag_0"]), scale=1e-8; else, scale=.002; end
    if name=="Amda", value=scale*cos(ordinal); else, value=scale*exp(1i*ordinal)./(1+ordinal); end
    if ismember(name,["Aw_p","Aw_m"]), value(~w.activeWaveModes)=0; end
    state.(name)=value;
end
end

function assignState(w,state)
for name = string(fieldnames(state)).', w.(name)=state.(name); end
end

function assignWave(w,value), w.Aw_p=value; end
