classdef TestFreeSurfaceWeakMassAction < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function nonflatMassMatchesPhysicalPairingAndIsSymmetric(testCase)
            uniform = newTransform();
            counts = mod((0:numel(uniform.khUnique)-1).',4);
            wvt = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=counts);
            wvt.t = 2718;
            wvt.t0 = 17;
            originalState = wvt.coefficientState();
            metric = nonflatMetric(wvt);
            stream = RandStream('mt19937ar',Seed=24719);
            first = randomState(wvt,stream);
            second = randomState(wvt,stream);
            firstFields = physicalVariation(wvt,first,metric);
            secondFields = physicalVariation(wvt,second,metric);
            firstAction = WVInternal.freeSurfaceWeakMassAction(wvt,first,metric);
            secondAction = WVInternal.freeSurfaceWeakMassAction(wvt,second,metric);
            [expected,scale] = physicalPairing(wvt,firstFields,secondFields,metric);
            testCase.verifyEqual(realPairing(second,firstAction),expected,AbsTol=5e-12*scale)
            testCase.verifyEqual(realPairing(first,secondAction),expected,AbsTol=5e-12*scale)
            [expectedEnergy,~] = physicalPairing(wvt,firstFields,firstFields,metric);
            testCase.verifyGreaterThan(expectedEnergy,0)
            testCase.verifyEqual(realPairing(first,firstAction),expectedEnergy,RelTol=5e-12)
            testCase.verifyTrue(any(counts==0))
            testCase.verifyTrue(any(~wvt.activeWaveModes,'all'))
            for family = ["Aw_p","Aw_m"]
                testCase.verifyEqual(firstAction.(family)(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
            end
            testCase.verifyTrue(isreal(firstAction.Amda))
            testCase.verifyEqual([wvt.t,wvt.t0],[2718,17])
            testCase.verifyEqual(wvt.coefficientState(),originalState)
        end

        function tinyRealDenseGramMatchesTheCompleteAction(testCase)
            wvt = newTransform(Nxyz=[4 4 33],waveModeCount=1,apvModeCount=1,inertialModeCount=1);
            wvt.t = 913;
            wvt.t0 = -31;
            metric = nonflatMetric(wvt);
            zero = zeroState(wvt);
            directionCount = 2*sum(structfun(@numel,zero))-numel(zero.Amda);
            directions = cell(directionCount,1);
            columns = cell(directionCount,1);
            column = 0;
            for family = string(fieldnames(zero)).'
                phases = [1,1i];
                if family=="Amda", phases=1; end
                for index = 1:numel(zero.(family))
                    for phase = phases
                        direction = zero;
                        direction.(family)(index) = phase;
                        column = column+1;
                        directions{column} = direction;
                        columns{column} = weightedPhysicalVector(wvt,physicalVariation(wvt,direction,metric),metric);
                    end
                end
            end
            matrix = horzcat(columns{:});
            denseGram = matrix.'*matrix;
            stream = RandStream('mt19937ar',Seed=923);
            coefficients = randn(stream,numel(directions),1);
            variation = zero;
            for index = 1:numel(directions)
                for family = string(fieldnames(zero)).'
                    variation.(family) = variation.(family)+coefficients(index)*directions{index}.(family);
                end
            end
            action = WVInternal.freeSurfaceWeakMassAction(wvt,variation,metric);
            actual = zeros(size(coefficients));
            for index = 1:numel(directions), actual(index)=realPairing(directions{index},action); end
            expected = denseGram*coefficients;
            testCase.verifyLessThan(norm(actual-expected)/norm(expected),5e-12)
            % Scale out coefficient units before testing full-rank positivity.
            diagonal = sqrt(diag(denseGram));
            [~,notPositive] = chol(denseGram./(diagonal*diagonal.'));
            testCase.verifyEqual(notPositive,0)
        end

        function zeroDisplacementWeightHasTheExpectedMDANullDirection(testCase)
            wvt = newTransform(waveModeCount=0);
            wvt.t = 71;
            wvt.t0 = 5;
            metric = nonflatMetric(wvt);
            metric.displacementWeight(:) = 0;
            variation = zeroState(wvt);
            variation.Amda(1) = 0.3;
            action = WVInternal.freeSurfaceWeakMassAction(wvt,variation,metric);
            for family = string(fieldnames(action)).'
                testCase.verifyEqual(action.(family),zeros(size(action.(family))),AbsTol=0)
            end
            invalid = metric;
            invalid.gamma(1) = 0;
            testCase.verifyError(@()WVInternal.freeSurfaceWeakMassAction(wvt,variation,invalid),'WV:WeakMassMetric')
            invalid = metric;
            invalid.displacementWeight(1) = -1;
            testCase.verifyError(@()WVInternal.freeSurfaceWeakMassAction(wvt,variation,invalid),'WV:WeakMassMetric')
        end
    end
end

function wvt = newTransform(options)
arguments (Input)
    options.Nxyz (1,3) double = [8 8 65]
    options.waveModeCount (:,1) double = 3
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.apvModeCount (1,1) double = 3
    options.inertialModeCount (1,1) double = 3
end
Nxyz = options.Nxyz;
options = rmfield(options,'Nxyz');
args = namedargs2cell(options);
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],Nxyz,args{:},N2Function=@(z)1e-4*exp(2*z/700),mdaModeCount=2,shouldAntialias=true);
end

function metric = nonflatMetric(wvt)
[X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
k = 2*pi/wvt.Lx;
l = 2*pi/wvt.Ly;
metric.gamma = 1+0.15*cos(k*X(:,:,1)).*cos(l*Y(:,:,1));
metric.betaX = -0.15*wvt.Lz*k*(1+Z/wvt.Lz).*sin(k*X).*cos(l*Y)./metric.gamma;
metric.betaY = -0.15*wvt.Lz*l*(1+Z/wvt.Lz).*cos(k*X).*sin(l*Y)./metric.gamma;
metric.displacementWeight = metric.gamma.*1e-4.*(1+0.3*cos(k*X).*sin(l*Y)).*(1+0.5*Z/wvt.Lz);
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

function fields = physicalVariation(wvt,state,metric)
spectral = wvt.reconstructSpectralState(state=state);
for name = ["u","v","w","eta","ssh"]
    hatted.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
end
fields.u = hatted.u./metric.gamma;
fields.v = hatted.v./metric.gamma;
fields.w = hatted.w+metric.betaX.*hatted.u+metric.betaY.*hatted.v;
fields.eta = hatted.eta;
fields.ssh = hatted.ssh(:,:,end);
end

function [value,scale] = physicalPairing(wvt,first,second,metric)
firstVector = weightedPhysicalVector(wvt,first,metric);
secondVector = weightedPhysicalVector(wvt,second,metric);
products = firstVector.*secondVector;
value = sum(products);
scale = sum(abs(products));
end

function vector = weightedPhysicalVector(wvt,fields,metric)
volumeWeights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
kineticWeight = sqrt(volumeWeights.*metric.gamma);
u = kineticWeight.*fields.u;
v = kineticWeight.*fields.v;
w = kineticWeight.*fields.w;
eta = sqrt(volumeWeights.*metric.displacementWeight).*fields.eta;
ssh = sqrt(wvt.g/(wvt.Nx*wvt.Ny))*fields.ssh;
vector = [u(:);v(:);w(:);eta(:);ssh(:)];
end

function value = realPairing(state,covector)
value = 0;
for family = string(fieldnames(state)).'
    value = value+real(sum(conj(state.(family)).*covector.(family),'all'));
end
end
