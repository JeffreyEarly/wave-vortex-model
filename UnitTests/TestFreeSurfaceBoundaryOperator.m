classdef TestFreeSurfaceBoundaryOperator < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function physicalTraceDualityHoldsForAllEndpointConfigurations(testCase)
            stream = RandStream('mt19937ar',Seed=8173);
            endpointOptions = [NaN NaN;Inf Inf;NaN Inf;Inf NaN];
            uniform = newTransform();
            counts = mod((0:numel(uniform.khUnique)-1).',4);
            for configuration = 1:size(endpointOptions,1)
                wvt = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=counts,g0=endpointOptions(configuration,1),gd=endpointOptions(configuration,2));
                state = randomState(wvt,stream);
                stored = randomState(wvt,stream);
                for family = string(fieldnames(stored)).', wvt.(family)=stored.(family); end
                boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
                allNames = ["ssh","surface","bottom"];
                names = allNames([1,1+wvt.activeEndpoint(:).']);
                testCase.verifyEqual(boundary.names,names)
                testCase.verifyTrue(any(counts==0))
                testCase.verifyTrue(any(~wvt.activeWaveModes,'all'))
                fields = randomTargets(wvt,stream);
                target = boundary.projectTarget(fields);
                for clocks = [1321 51;13 270]
                    wvt.t = clocks(1);
                    wvt.t0 = clocks(2);
                    traces = spatialTraces(wvt,state);
                    actual = boundary.apply(state);
                    [expected,scale] = physicalPairing(traces,fields,names);
                    testCase.verifySize(actual,[boundary.dimension,1])
                    testCase.verifyTrue(isreal(actual))
                    testCase.verifyEqual(dot(actual,target),expected,AbsTol=5e-12*max(scale,1e-12))
                    [normSquared,~] = physicalPairing(traces,traces,names);
                    testCase.verifyEqual(dot(actual,actual),normSquared,RelTol=5e-12)
                    coordinates = randn(stream,boundary.dimension,1);
                    adjoint = boundary.adjoint(coordinates);
                    [coefficientPair,coefficientScale] = realPairing(state,adjoint);
                    testCase.verifyEqual(coefficientPair,dot(actual,coordinates),AbsTol=5e-12*max(coefficientScale,1e-12))
                    testCase.verifyTrue(isreal(adjoint.Amda))
                    testCase.verifyEqual(adjoint.Aio,zeros(size(adjoint.Aio)))
                    for family = ["Aw_p","Aw_m"]
                        testCase.verifyEqual(adjoint.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
                    end
                    testCase.verifyEqual(wvt.coefficientState(),stored)
                    testCase.verifyEqual([wvt.t;wvt.t0],clocks)
                end
            end
        end

        function discardedRMSMatchesIndependentTrigonometricProjection(testCase)
            stream = RandStream('mt19937ar',Seed=5297);
            for endpoints = [NaN NaN;Inf Inf;NaN Inf;Inf NaN].'
                wvt = newTransform(waveModeCount=0,g0=endpoints(1),gd=endpoints(2));
                boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
                fields = randomTargets(wvt,stream);
                [vector,discardedRMS] = boundary.projectTarget(fields);
                projected = retainedTargets(wvt,fields,boundary.names);
                residualSquared = 0;
                retainedSquared = 0;
                for name = boundary.names
                    residualSquared = residualSquared+mean((fields.(name)-projected.(name)).^2,'all');
                    retainedSquared = retainedSquared+mean(projected.(name).^2,'all');
                end
                testCase.verifyEqual(discardedRMS,sqrt(residualSquared/numel(boundary.names)),AbsTol=5e-14)
                testCase.verifyEqual(dot(vector,vector),retainedSquared,AbsTol=5e-13)
                [projectedVector,projectedDiscarded] = boundary.projectTarget(projected);
                testCase.verifyEqual(projectedVector,vector,AbsTol=5e-14)
                testCase.verifyLessThan(projectedDiscarded,5e-14)
                fields.ssh(:) = 1;
                fields.surface(:) = 0;
                fields.bottom(:) = 0;
                [meanVector,meanDiscarded] = boundary.projectTarget(fields);
                testCase.verifyEqual(meanVector,zeros(boundary.dimension,1),AbsTol=5e-14)
                testCase.verifyEqual(meanDiscarded,1/sqrt(numel(boundary.names)),AbsTol=5e-14)
                % Extra inactive endpoint samples do not enter the target norm.
                for name = setdiff(["surface","bottom"],boundary.names), fields.(name)(:)=1e6; end
                [inactiveVector,inactiveDiscarded] = boundary.projectTarget(fields);
                testCase.verifyEqual(inactiveVector,meanVector)
                testCase.verifyEqual(inactiveDiscarded,meanDiscarded)
            end
        end

        function meanMDAAndInertialDirectionsHaveTheirPhysicalTraces(testCase)
            wvt = newTransform(waveModeCount=0);
            boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
            wvt.t = 917;
            wvt.t0 = -57;
            zero = zeroState(wvt);
            fields = struct(ssh=ones(wvt.Nx,wvt.Ny),surface=2*ones(wvt.Nx,wvt.Ny),bottom=-3*ones(wvt.Nx,wvt.Ny));
            target = boundary.projectTarget(fields);
            for index = 1:numel(zero.Amda)
                direction = zero;
                direction.Amda(index) = 1;
                traces = spatialTraces(wvt,direction);
                actual = boundary.apply(direction);
                [expected,scale] = physicalPairing(traces,fields,boundary.names);
                testCase.verifyEqual(dot(actual,target),expected,AbsTol=5e-12*max(scale,1e-12))
                testCase.verifyEqual(mean(traces.ssh,'all'),0,AbsTol=5e-14)
                [expectedNorm,~] = physicalPairing(traces,traces,boundary.names);
                testCase.verifyEqual(dot(actual,actual),expectedNorm,RelTol=5e-12)
            end
            for phase = [1,1i]
                direction = zero;
                direction.Aio(:) = phase;
                testCase.verifyEqual(boundary.apply(direction),zeros(boundary.dimension,1))
                traces = spatialTraces(wvt,direction);
                for name = boundary.names, testCase.verifyEqual(traces.(name),zeros(wvt.Nx,wvt.Ny)); end
            end
        end
    end
end

function wvt = newTransform(options)
arguments (Input)
    options.waveModeCount (:,1) double = 3
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
end
args = namedargs2cell(options);
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},N2Function=@(z)1e-4*exp(2*z/700),apvModeCount=3,mdaModeCount=2,inertialModeCount=3,shouldAntialias=true);
end

function state = zeroState(wvt)
state = structfun(@(value)zeros(size(value)),wvt.coefficientState(),UniformOutput=false);
end

function state = randomState(wvt,stream)
state = zeroState(wvt);
for family = string(fieldnames(state)).'
    shape = size(state.(family));
    scale = 0.1;
    if ismember(family,["Ag_q","Ag_0"]), scale=1e-8; end
    state.(family) = scale*randn(stream,shape);
    if family~="Amda", state.(family)=state.(family)+1i*scale*randn(stream,shape); end
    if ismember(family,["Aw_p","Aw_m"]), state.(family)(~wvt.activeWaveModes)=0; end
end
end

function fields = randomTargets(wvt,stream)
for name = ["ssh","surface","bottom"]
    fields.(name) = 0.3+randn(stream,wvt.Nx,wvt.Ny);
end
end

function fields = spatialTraces(wvt,state)
spectral = wvt.reconstructSpectralState(state=state);
eta = wvt.transformToSpatialDomainWithFourier(spectral.eta);
ssh = wvt.transformToSpatialDomainWithFourier(spectral.ssh);
fields.ssh = ssh(:,:,end);
fields.surface = eta(:,:,end)-fields.ssh;
fields.bottom = eta(:,:,1);
end

function retained = retainedTargets(wvt,fields,names)
[X,Y] = ndgrid(wvt.x,wvt.y);
for name = names
    samples = fields.(name);
    projected = zeros(size(samples));
    if name~="ssh", projected(:)=mean(samples,'all'); end
    for index = 1:numel(wvt.kNonzero)
        sinusoid = exp(1i*(wvt.kNonzero(index)*X+wvt.lNonzero(index)*Y));
        amplitude = mean(samples.*conj(sinusoid),'all');
        projected = projected+2*real(amplitude*sinusoid);
    end
    retained.(name) = projected;
end
end

function [value,scale] = physicalPairing(first,second,names)
value = 0;
scale = 0;
for name = names
    products = first.(name).*second.(name);
    value = value+mean(products,'all');
    scale = scale+mean(abs(products),'all');
end
end

function [value,scale] = realPairing(first,second)
value = 0;
scale = 0;
for family = string(fieldnames(first)).'
    products = conj(first.(family)).*second.(family);
    value = value+real(sum(products,'all'));
    scale = scale+sum(abs(products),'all');
end
end
