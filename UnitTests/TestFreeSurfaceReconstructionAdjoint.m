classdef TestFreeSurfaceReconstructionAdjoint < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function mixedPairingHoldsForEveryFieldAndVariableWaveCounts(testCase)
            stream = RandStream('mt19937ar',Seed=83017);
            for profile = ["constant","exponential"]
                uniform = newTransform(profile);
                counts = mod((0:numel(uniform.khUnique)-1).',4);
                wvt = newTransform(profile,waveModeKappa=uniform.khUnique,waveModeCount=counts);
                testCase.verifyTrue(any(counts==0))
                testCase.verifyTrue(any(~wvt.activeWaveModes,'all'))
                testCase.verifyGreaterThan(numel(unique(counts)),2)
                state = randomState(wvt,stream);
                for name = string(fieldnames(state)).', wvt.(name)=state.(name); end
                fields = randomFields(wvt,stream);
                for clocks = [1234 17;31 211]
                    wvt.t = clocks(1);
                    wvt.t0 = clocks(2);
                    reconstructed = spatialState(wvt,state);
                    for channel = ["u","v","w","eta","ssh","mixed"]
                        selected = fields;
                        if channel~="mixed"
                            for name = string(fieldnames(selected)).'
                                if name~=channel, selected.(name)(:)=0; end
                            end
                        end
                        adjoint = WVInternal.freeSurfaceReconstructionAdjoint(wvt,selected);
                        verifyPairing(testCase,wvt,reconstructed,selected,state,adjoint);
                        verifyFamilyContract(testCase,wvt,adjoint);
                    end
                    testCase.verifyEqual(wvt.coefficientState(),state)
                    testCase.verifyEqual([wvt.t;wvt.t0],clocks)
                end
            end
        end

        function coefficientDirectionsMatchIndependentReconstruction(testCase)
            wvt = newTransform("exponential");
            wvt.t = 345.25;
            wvt.t0 = -18.5;
            stream = RandStream('mt19937ar',Seed=71403);
            fields = randomFields(wvt,stream);
            adjoint = WVInternal.freeSurfaceReconstructionAdjoint(wvt,fields);
            zero = wvt.coefficientState();
            for family = string(fieldnames(zero)).'
                entries = unique([1,numel(zero.(family))]);
                phases = [1,1i];
                if family=="Amda", phases=1; end
                for entry = entries
                    for phase = phases
                        direction = zero;
                        direction.(family)(entry) = phase;
                        reconstructed = spatialState(wvt,direction);
                        [actual,scale] = spatialPairing(wvt,reconstructed,fields);
                        expected = real(conj(phase)*adjoint.(family)(entry));
                        testCase.verifyEqual(actual,expected,AbsTol=5e-12*scale)
                    end
                end
            end
        end

        function omittedWaveAndBoundaryFamiliesPreserveTheAdjointContract(testCase)
            wvt = newTransform("constant",waveModeCount=0,g0=Inf,gd=Inf);
            wvt.t = 901;
            wvt.t0 = 71;
            stream = RandStream('mt19937ar',Seed=6517);
            state = randomState(wvt,stream);
            fields = randomFields(wvt,stream);
            adjoint = WVInternal.freeSurfaceReconstructionAdjoint(wvt,fields);
            verifyPairing(testCase,wvt,spatialState(wvt,state),fields,state,adjoint);
            verifyFamilyContract(testCase,wvt,adjoint);
            testCase.verifyEmpty(adjoint.Aw_p)
            testCase.verifyEmpty(adjoint.Aw_m)
            testCase.verifyEmpty(adjoint.Ag_0)
            testCase.verifyGreaterThan(norm(adjoint.Aio),0)
            testCase.verifyGreaterThan(norm(adjoint.Amda),0)
        end
    end
end

function wvt = newTransform(profile,options)
arguments (Input)
    profile (1,1) string
    options.waveModeCount (:,1) double = 3
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
end
N2 = @(z)1e-4*ones(size(z));
if profile=="exponential", N2=@(z)1e-4*exp(2*z/700); end
args = namedargs2cell(options);
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},N2Function=N2,apvModeCount=3,mdaModeCount=2,inertialModeCount=3,shouldAntialias=true);
end

function state = randomState(wvt,stream)
state = wvt.coefficientState();
for family = string(fieldnames(state)).'
    shape = size(state.(family));
    scale = 0.1;
    if ismember(family,["Ag_q","Ag_0"]), scale=1e-8; end
    state.(family) = scale*randn(stream,shape);
    if family~="Amda", state.(family)=state.(family)+1i*scale*randn(stream,shape); end
    if ismember(family,["Aw_p","Aw_m"]), state.(family)(~wvt.activeWaveModes)=0; end
end
end

function fields = randomFields(wvt,stream)
for name = ["u","v","w","eta"]
    fields.(name) = 0.2+randn(stream,wvt.Nx,wvt.Ny,wvt.Nz);
end
fields.ssh = -0.3+randn(stream,wvt.Nx,wvt.Ny);
end

function fields = spatialState(wvt,state)
spectral = wvt.reconstructSpectralState(state=state);
for name = ["u","v","w","eta","ssh"]
    fields.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
end
fields.ssh = fields.ssh(:,:,end);
end

function verifyPairing(testCase,wvt,reconstructed,fields,state,adjoint)
[physicalPair,physicalScale] = spatialPairing(wvt,reconstructed,fields);
coefficientPair = 0;
coefficientScale = 0;
for family = string(fieldnames(state)).'
    products = conj(state.(family)).*adjoint.(family);
    coefficientPair = coefficientPair+real(sum(products,'all'));
    coefficientScale = coefficientScale+sum(abs(products),'all');
end
testCase.verifyEqual(coefficientPair,physicalPair,AbsTol=5e-12*max(physicalScale,coefficientScale))
end

function [value,scale] = spatialPairing(wvt,reconstructed,fields)
weights = reshape(wvt.verticalQuadratureWeights,1,1,[]);
value = 0;
scale = 0;
for name = ["u","v","w","eta"]
    products = weights.*reconstructed.(name).*fields.(name);
    value = value+sum(products,'all')/(wvt.Nx*wvt.Ny);
    scale = scale+sum(abs(products),'all')/(wvt.Nx*wvt.Ny);
end
products = reconstructed.ssh.*fields.ssh;
value = value+mean(products,'all');
scale = scale+mean(abs(products),'all');
end

function verifyFamilyContract(testCase,wvt,adjoint)
state = wvt.coefficientState();
testCase.verifyEqual(sort(string(fieldnames(adjoint))),sort(string(fieldnames(state))))
for family = string(fieldnames(state)).'
    testCase.verifySize(adjoint.(family),size(state.(family)))
    testCase.verifyTrue(all(isfinite(adjoint.(family)),'all'))
end
testCase.verifyTrue(isreal(adjoint.Amda))
for family = ["Aw_p","Aw_m"]
    testCase.verifyEqual(adjoint.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
end
end
