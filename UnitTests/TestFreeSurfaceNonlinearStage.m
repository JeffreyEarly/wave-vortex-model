classdef TestFreeSurfaceNonlinearStage < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyHelpers(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function fullC1NonflatStageMatchesIndependentDenseSystem(testCase)
            [wvt,seed,helper,derivatives] = fixture(false);
            context = WVInternal.freeSurfaceNonlinearStage(wvt);
            wvt.t = 327; wvt.t0 = 19;
            original = wvt.coefficientState();
            [rate,diagnostics,stage] = context.evaluate(seed);
            [denseRate,matrix,layout] = denseStage(wvt,stage,derivatives);
            actual = layout.pack(stage.totalRate);
            testCase.verifyLessThan(norm(matrix*(actual-denseRate))/norm(matrix*denseRate),2e-9)
            testCase.verifyEqual(layout.pack(rate),actual-layout.pack(stage.linearRate),AbsTol=1e-15)
            weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
            physical = stage.physical; hatted = stage.hatted;
            expected = sum(weights.*physical.gamma.*(.5*(physical.u.^2+physical.v.^2+physical.w.^2)+.5e-4*hatted.eta.^2),'all')+mean(.5*wvt.g*hatted.ssh.^2-(1e-4/6)*hatted.ssh.^3,'all');
            testCase.verifyEqual(diagnostics.totalEnergy,expected,RelTol=2e-13)
            testCase.verifyEqual(stage.thermodynamics.pressureSurface,wvt.g*hatted.ssh-.5e-4*hatted.ssh.^2,AbsTol=2e-13)
            testCase.verifyEqual(diagnostics.referenceConvention,"constant-surface-N2")
            testCase.verifyLessThan(diagnostics.solver.relativeResidual,5e-10)
            testCase.verifyGreaterThan(diagnostics.minimumLabel,-wvt.Lz)
            testCase.verifyLessThan(diagnostics.maximumLabel,0)
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyEqual([wvt.t,wvt.t0],[327,19])
            % Default input uses canonical state while leaving it unchanged.
            for family = string(fieldnames(seed)).', wvt.(family)=seed.(family); end
            defaultRate = context.evaluate();
            testCase.verifyEqual(defaultRate,rate)
            testCase.verifyEqual(wvt.coefficientState(),seed)
            wvt.t = 827; wvt.t0 = -21;
            reused = context.evaluate();
            fresh = WVInternal.freeSurfaceNonlinearStage(wvt);
            testCase.verifyEqual(reused,fresh.evaluate())
            testCase.verifyEqual([wvt.t,wvt.t0],[827,-21])
            testCase.verifyEqual(wvt.coefficientState(),seed)
            [minimumLabel,maximumLabel] = helper.labelBounds(hatted,helper.buildContext(wvt,1));
            testCase.verifyGreaterThan(minimumLabel,-wvt.Lz)
            testCase.verifyLessThan(maximumLabel,0)
        end

        function validOneSidedLinearLimitIncludesBothWaveSignsAndVariableProfile(testCase)
            for variable = [false,true]
                [wvt,seed] = fixture(variable);
                wvt.t = 1793; wvt.t0 = -31;
                context = WVInternal.freeSurfaceNonlinearStage(wvt);
                layout = WVInternal.freeSurfaceRealCoefficientLayout(wvt);
                amplitudes = [1e-3,5e-4];
                normalized = cell(2,1); nonlinearNorm = zeros(2,1);
                for index = 1:2
                    amplitude = amplitudes(index);
                    state = structfun(@(value)amplitude*value,seed,UniformOutput=false);
                    [rate,diagnostics,stage] = context.evaluate(state);
                    normalized{index} = layout.pack(stage.totalRate)/amplitude;
                    nonlinearNorm(index) = energyNorm(wvt,rate);
                    testCase.verifyGreaterThan(diagnostics.minimumLabel,-wvt.Lz)
                    testCase.verifyLessThan(diagnostics.maximumLabel,0)
                end
                % One-sided extrapolation respects positive mean endpoint
                % offsets; a negative amplitude would violate label bounds.
                extrapolated = layout.unpack(2*normalized{2}-normalized{1});
                expected = linearRate(wvt,seed);
                difference = extrapolated;
                for family = string(fieldnames(expected)).'
                    difference.(family)=difference.(family)-expected.(family);
                end
                testCase.verifyLessThan(energyNorm(wvt,difference)/energyNorm(wvt,expected),2e-7)
                testCase.verifyGreaterThan(nonlinearNorm(1)/nonlinearNorm(2),3.7)
                testCase.verifyLessThan(nonlinearNorm(1)/nonlinearNorm(2),4.3)
                testCase.verifyEqual([wvt.t,wvt.t0],[1793,-31])
            end
        end

        function variableWavePagesPreservePaddingAtChangingClocks(testCase)
            profile = @(z)1e-4*exp(2*z/700);
            options = struct(N2Function=profile,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128,shouldAntialias=true);
            args = namedargs2cell(options);
            uniform = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:});
            counts = mod(3-(0:length(uniform.khUnique)-1).',4);
            options.waveModeCount = counts;
            args = namedargs2cell(options);
            wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},waveModeKappa=uniform.khUnique);
            helper = freeSurfaceWeakStudyHelpers();
            seed = helper.seedState(wvt);
            seed.Aw_m = .4*exp(.63i)*seed.Aw_p;
            for family = ["Aw_p","Aw_m"], seed.(family)(~wvt.activeWaveModes)=0; end
            context = WVInternal.freeSurfaceNonlinearStage(wvt);
            original = wvt.coefficientState();
            testCase.verifyEqual(wvt.activeEndpoint(:),[1;2])
            testCase.verifyTrue(any(counts==0))
            testCase.verifyTrue(any(~wvt.activeWaveModes,'all'))
            frequency = wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
            testCase.verifyTrue(all(isfinite(frequency),'all'))
            testCase.verifyEqual(frequency(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
            clocks = [13,7;1301,-31;-17,17];
            for index = 1:size(clocks,1)
                wvt.t=clocks(index,1); wvt.t0=clocks(index,2);
                [rate,diagnostics,stage] = context.evaluate(seed);
                for family = string(fieldnames(rate)).'
                    testCase.verifyTrue(all(isfinite(rate.(family)),'all'))
                end
                for family = ["Aw_p","Aw_m"]
                    testCase.verifyEqual(rate.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
                    testCase.verifyEqual(stage.totalRate.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
                    testCase.verifyEqual(stage.linearRate.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
                end
                testCase.verifyGreaterThan(diagnostics.minimumLabel,-wvt.Lz)
                testCase.verifyLessThan(diagnostics.maximumLabel,0)
                testCase.verifyLessThan(diagnostics.solver.relativeResidual,5e-10)
                testCase.verifyEqual(wvt.coefficientState(),original)
                testCase.verifyEqual([wvt.t,wvt.t0],clocks(index,:))
            end
        end

        function outOfDomainLabelsFailWithoutChangingState(testCase)
            [wvt,seed] = fixture(false);
            context = WVInternal.freeSurfaceNonlinearStage(wvt);
            original = wvt.coefficientState();
            % Reverse mean offsets while leaving oscillatory endpoint
            % anomalies small: both forbidden parcel-label sides are active.
            invalid = seed; invalid.Amda=-seed.Amda;
            testCase.verifyError(@()context.evaluate(invalid),'WV:ParcelLabelDomain')
            testCase.verifyEqual(wvt.coefficientState(),original)
        end
    end
end

function [wvt,seed,helper,derivatives] = fixture(variable)
profile = @(z)1e-4+0*z;
if variable, profile=@(z)1e-4*exp(2*z/700); end
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=profile,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128);
helper = freeSurfaceWeakStudyHelpers();
seed = helper.seedState(wvt);
xColumn = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
yColumn = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
seed.Aw_p(1,yColumn) = .3*exp(.41i)*seed.Aw_p(1,xColumn);
seed.Aw_m = .4*exp(.63i)*seed.Aw_p;
derivatives = helper.buildContext(wvt,1).derivative;
end

function rate = linearRate(wvt,state)
rate = structfun(@(value)zeros(size(value)),state,UniformOutput=false);
frequency = wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
rate.Aw_p = 1i*frequency.*state.Aw_p;
rate.Aw_m = -1i*frequency.*state.Aw_m;
rate.Aio = 1i*wvt.f*state.Aio;
end

function value = energyNorm(wvt,state)
spectral = wvt.reconstructSpectralState(state=state);
weights = wvt.verticalQuadratureWeights;
factor = 2*ones(1,wvt.Nkl); factor(wvt.k==0 & wvt.l==0)=1;
value = sqrt(sum(factor.*sum(weights.*(abs(spectral.u).^2+abs(spectral.v).^2+abs(spectral.w).^2+wvt.N2.*abs(spectral.eta).^2),1))+wvt.g*sum(factor.*abs(spectral.ssh(end,:)).^2));
end

function [rate,matrix,layout] = denseStage(wvt,stage,derivative)
layout = WVInternal.freeSurfaceRealCoefficientLayout(wvt);
boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
shape = [wvt.Nx,wvt.Ny,wvt.Nz];
matrix = zeros(4*prod(shape)+wvt.Nx*wvt.Ny,layout.dimension);
surfaceW = zeros(wvt.Nx*wvt.Ny,layout.dimension);
K = zeros(boundary.dimension,layout.dimension);
for column = 1:layout.dimension
    unit = zeros(layout.dimension,1); unit(column)=1;
    state = layout.unpack(unit);
    spectral = wvt.reconstructSpectralState(state=state);
    for name = ["u","v","w","eta","ssh"]
        fields.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
    end
    fields.ssh = fields.ssh(:,:,end);
    matrix(:,column) = weightedVector(wvt,fields,stage.metric);
    surfaceW(:,column) = reshape(fields.w(:,:,end),[],1);
    K(:,column) = boundary.apply(state);
end
rhs = WVInternal.freeSurfaceMappedTendency(stage.hatted,zeros(shape),stage.thermodynamics.buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,derivative);
rhs.ssh = stage.hatted.w(:,:,end);
load = matrix'*weightedVector(wvt,rhs,stage.metric)-surfaceW'*stage.thermodynamics.pressureSurface(:)/(wvt.Nx*wvt.Ny);
thetaS = stage.hatted.eta(:,:,end)-stage.hatted.ssh;
thetaB = stage.hatted.eta(:,:,1);
targets = struct(ssh=rhs.ssh,surface=-stage.physical.u(:,:,end).*derivative.x(thetaS)-stage.physical.v(:,:,end).*derivative.y(thetaS),bottom=-stage.physical.u(:,:,1).*derivative.x(thetaB)-stage.physical.v(:,:,1).*derivative.y(thetaB));
target = boundary.projectTarget(targets);
scale = sqrt(sum(matrix.^2,1)).';
normalized = matrix./scale.';
H = normalized'*normalized;
K = K./scale.';
unconstrained = H\(load./scale);
response = H\K';
multiplier = (K*response)\(K*unconstrained-target);
rate = (unconstrained-response*multiplier)./scale;
end

function vector = weightedVector(wvt,fields,metric)
weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
u = sqrt(weights.*metric.gamma).*fields.u./metric.gamma;
v = sqrt(weights.*metric.gamma).*fields.v./metric.gamma;
w = sqrt(weights.*metric.gamma).*(fields.w+metric.betaX.*fields.u+metric.betaY.*fields.v);
eta = sqrt(weights.*metric.displacementWeight).*fields.eta;
ssh = sqrt(wvt.g/(wvt.Nx*wvt.Ny))*fields.ssh;
vector = [u(:);v(:);w(:);eta(:);ssh(:)];
end
