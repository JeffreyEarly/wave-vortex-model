classdef TestFreeSurfaceQGBuoyancyFlux < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function weakBoundaryLoadsMatchIndependentEnergy(testCase)
            for accelerations = [.02 .03; .02 Inf; Inf .03].'
                [q,N2] = fluxTransform(700,65,24,accelerations);
                [z,weights] = depthQuadrature(193,q.Lz);
                [index,page,kh] = testWavenumber(q);
                sample = q.verticalGrid.calculus.interpolationMatrix(z);
                mu = q.apvMu(:,page).';
                phi = [-q.apvF./mu,-q.zeroAPVF(:,:,page)/kh^2];
                eta = -(q.f/q.g)*[q.apvG./mu,q.zeroAPVG(:,:,page)/kh^2];
                weightedFields = [sqrt(weights)*kh.*(sample*phi); ...
                    sqrt(weights.*N2(z)).*(sample*eta); q.f/sqrt(q.g)*phi(end,:)];
                [~,R] = qr(weightedFields,0);
                mass = weightedFields'*weightedFields;
                etaTrace = eta([end 1],:);
                [X,~] = ndgrid(q.x,q.y);
                angle = 2*pi*X/q.Lx;
                for endpoint = reshape(q.activeEndpoint,1,[])
                    if endpoint==1
                        actual = q.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=cos(angle));
                        fourierAmplitude = .5;
                    else
                        actual = q.boundaryBuoyancyFluxTendency(bottomBuoyancyFlux=sin(angle));
                        fourierAmplitude = -.5i*sign(q.kNonzero(index));
                    end
                    load = -etaTrace(endpoint,:)'*fourierAmplitude;
                    response = [actual.Ag_q(:,index);actual.Ag_0(:,index)];
                    residual = (R'\(mass*response-load));
                    scale = norm(R'\load);
                    testCase.verifyLessThan(norm(residual)/scale,1e-8, ...
                        sprintf('Independent weak-load residual at endpoint %d.',endpoint))
                end
            end
        end

        function meanFluxMatchesColumnBudget(testCase)
            for scale = [Inf 700]
                [q,N2] = fluxTransform(scale,65,24,[.02 .03]);
                [z,weights] = depthQuadrature(193,q.Lz);
                sample = q.verticalGrid.calculus.interpolationMatrix(z);
                buoyancy = -N2(z).*(sample*q.mdaG);
                [X,~] = ndgrid(q.x,q.y);
                anomaly = .5*cos(2*pi*X/q.Lx);
                Q0 = 1e-8*(1+anomaly);
                Qd = 2e-8*(1-anomaly);
                surface = q.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=Q0);
                bottom = q.boundaryBuoyancyFluxTendency(bottomBuoyancyFlux=Qd);
                both = q.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=Q0,bottomBuoyancyFlux=Qd);
                actual = weights.'*buoyancy*[surface.Amda,bottom.Amda,both.Amda];
                expected = [1e-8 2e-8 3e-8];
                testCase.verifyEqual(actual,expected,RelTol=1e-10)
            end
        end

        function seasonalFluxMatchesIndependentEvolution(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            kappaZ = 1e-2;
            period = 10*86400;
            Qstar = 1e-8;
            omega = 2*pi/period;
            times = period*[.25 .5 1];
            for scale = [Inf 700]
                [q,N2] = fluxTransform(scale,65,24,[.02 .03]);
                [z,weights] = depthQuadrature(257,q.Lz);
                sample = q.verticalGrid.calculus.interpolationMatrix(z);
                [index,~,kh] = testWavenumber(q);
                meanIndex = find(q.k==0 & q.l==0,1);
                model = attachSeasonalFlux(q,kappaZ,period,Qstar,period/96);

                % Compare the wavenumber forced by a real cosine of amplitude Qstar/2.
                reference = independentlyRefinedResponse(testCase,q,N2,scale,kh,kappaZ,Qstar/4,omega,times,z,weights);
                meanReference = neumannSurfaceFlux([z;0;-q.Lz],q.Lz,kappaZ,Qstar,omega,times);
                expectedColumn = Qstar*(1-cos(omega*times))/omega;
                actual = struct(buoyancy=zeros(numel(z),numel(times)),qgpv=zeros(numel(z),numel(times)), ...
                    ssh=zeros(1,numel(times)),endpoints=zeros(2,numel(times)));
                meanBuoyancy = zeros(numel(z)+2,numel(times));
                for iTime = 1:numel(times)
                    model.integrateToTime(times(iTime),shouldShowIntegrationDiagnostics=false);
                    [snapshot,eta] = balancedObservations(q,N2,z,sample,index);
                    for name = ["buoyancy","qgpv","ssh","endpoints"]
                        actual.(name)(:,iTime) = snapshot.(name);
                    end
                    meanEta = [sample*eta(:,meanIndex);eta([end 1],meanIndex)];
                    meanBuoyancy(:,iTime) = -N2([z;0;-q.Lz]).*real(meanEta);
                end
                testCase.verifyEqual(weights.'*meanBuoyancy(1:end-2,:),expectedColumn,AbsTol=3e-8*max(expectedColumn))
                testCase.verifyLessThan(relativeError(meanBuoyancy(1:end-2,:),meanReference(1:end-2,:),weights),2e-4)
                testCase.verifyLessThan(relativeError(meanBuoyancy(end-1,:),meanReference(end-1,:),1),2e-4)
                testCase.verifyLessThan(relativeError(meanBuoyancy(end,:),meanReference(end,:),1),2e-4)
                verifyBalancedResponse(testCase,actual,reference,weights);
            end
        end

        function samplingAndRetainedBandHaveSeparateControls(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            kappaZ = 1e-2;
            period = 10*86400;
            Qstar = 1e-8;
            omega = 2*pi/period;
            time = period/4;
            scale = 700;
            [z,weights] = depthQuadrature(257,100);
            meanReference = neumannSurfaceFlux(z,100,kappaZ,Qstar,omega,time);
            configurations = [65 12;65 18;65 24;97 24];
            errors = zeros(size(configurations,1),3);
            for j = 1:size(configurations,1)
                [q,N2] = fluxTransform(scale,configurations(j,1),configurations(j,2),[.02 .03]);
                [index,~,kh] = testWavenumber(q);
                if j==1
                    reference = independentlyRefinedResponse(testCase,q,N2,scale,kh,kappaZ,Qstar/4,omega,time,z,weights);
                end
                sample = q.verticalGrid.calculus.interpolationMatrix(z);
                [wavePage,meanPage,waveSource,meanSource] = seasonalCoefficientSystem(q,kappaZ,Qstar);
                wave = wavePage.fromEnergy*sinusoidalResponse(wavePage.energyGenerator,waveSource,omega,time);
                q.Ag_q(:,index) = wave(1:q.apvModeCount);
                q.Ag_0(:,index) = wave(q.apvModeCount+1:end);
                q.Amda = meanPage.fromEnergy*sinusoidalResponse(meanPage.energyGenerator,meanSource,omega,time);
                observed = balancedObservations(q,N2,z,sample,index);
                meanBuoyancy = -N2(z).*(sample*q.mdaG*q.Amda);
                errors(j,:) = [relativeError(observed.buoyancy,reference.buoyancy,weights), ...
                    relativeError(observed.qgpv,reference.qgpv,weights), ...
                    relativeError(meanBuoyancy,meanReference,weights)];
            end
            testCase.verifyLessThan(errors(2:3,:),errors(1:2,:))
            testCase.verifyEqual(errors(4,:),errors(3,:),AbsTol=1e-7)
        end

        function timestepRefinementConvergesAtFixedDiscreteState(testCase)
            kappaZ = 1e-2;
            period = 10*86400;
            Qstar = 1e-8;
            omega = 2*pi/period;
            time = period/4;
            q = fluxTransform(700,65,24,[.02 .03]);
            index = testWavenumber(q);
            [wavePage,meanPage,waveSource,meanSource] = seasonalCoefficientSystem(q,kappaZ,Qstar);
            waveReference = sinusoidalResponse(wavePage.energyGenerator,waveSource,omega,time);
            meanReference = sinusoidalResponse(meanPage.energyGenerator,meanSource,omega,time);
            [X,~] = ndgrid(q.x,q.y);
            pattern = 1+.5*cos(2*pi*X/q.Lx);
            q.addForcing(WVVerticalDiffusivity(q,kappa_z=kappaZ,shouldForceMeanDensityAnomaly=true));
            q.addForcing(WVSeasonalSurfaceBuoyancyFlux(q,pattern=pattern,amplitude=Qstar,period=period,phase=0));
            errors = zeros(3,2);
            stepCounts = [24 48 96];
            for j = 1:numel(stepCounts)
                q.Ag_q(:) = 0;
                q.Ag_0(:) = 0;
                q.Amda(:) = 0;
                q.t = 0;
                step = period/stepCounts(j);
                model = WVModel(q);
                model.setupIntegrator(integratorType="exponential",initialStep=step,maximumStep=step,exponentialAdaptive=false);
                model.integrateToTime(time,shouldShowIntegrationDiagnostics=false);
                wave = wavePage.toEnergy*[q.Ag_q(:,index);q.Ag_0(:,index)];
                meanState = meanPage.toEnergy*q.Amda;
                errors(j,:) = [relativeError(wave,waveReference,1),relativeError(meanState,meanReference,1)];
            end
            testCase.verifyLessThan(errors(2:3,:),.2*errors(1:2,:))
            testCase.verifyLessThan(errors(3,:),1e-5)
        end
    end
end

function model = attachSeasonalFlux(q,kappaZ,period,amplitude,step)
[X,~] = ndgrid(q.x,q.y);
pattern = 1+.5*cos(2*pi*X/q.Lx);
q.addForcing(WVVerticalDiffusivity(q,kappa_z=kappaZ,shouldForceMeanDensityAnomaly=true));
q.addForcing(WVSeasonalSurfaceBuoyancyFlux(q,pattern=pattern,amplitude=amplitude,period=period,phase=0));
model = WVModel(q);
model.setupIntegrator(integratorType="exponential",initialStep=step,maximumStep=step,exponentialAdaptive=false);
end

function [wavePage,meanPage,waveSource,meanSource] = seasonalCoefficientSystem(q,kappaZ,amplitude)
[index,page] = testWavenumber(q);
diffusion = WVVerticalDiffusivity(q,kappa_z=kappaZ,shouldForceMeanDensityAnomaly=true);
operators = diffusion.densityDiffusionOperators();
wavePage = operators.pages{page};
meanPage = operators.mda;
[X,~] = ndgrid(q.x,q.y);
source = q.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=amplitude*(1+.5*cos(2*pi*X/q.Lx)));
waveSource = wavePage.toEnergy*[source.Ag_q(:,index);source.Ag_0(:,index)];
meanSource = meanPage.toEnergy*source.Amda;
end

function [fields,eta] = balancedObservations(q,N2,z,sample,index)
[psi,eta,qgpv] = q.reconstructSpectralState();
column = q.klNonzero(index);
ssh = (q.f/q.g)*psi(end,column);
fields = struct(buoyancy=-N2(z).*(sample*eta(:,column)-(1+z/q.Lz)*ssh), ...
    qgpv=sample*qgpv(:,column),ssh=ssh,endpoints=eta([end 1],column)-[ssh;0]);
end

function response = independentlyRefinedResponse(testCase,q,N2,scale,kh,kappaZ,flux,omega,times,z,weights)
dLnN2 = @(z) (2/scale)*ones(size(z));
common = {N2,dLnN2,q.Lz,kh,q.f,q.g,kappaZ};
coarse = balancedDensityDiffusionReference(common{:},36,193,z);
dimensionRefined = balancedDensityDiffusionReference(common{:},54,193,z);
quadratureRefined = balancedDensityDiffusionReference(common{:},54,385,z);
coarseResponse = referenceResponse(coarse,flux,omega,times);
dimensionResponse = referenceResponse(dimensionRefined,flux,omega,times);
response = referenceResponse(quadratureRefined,flux,omega,times);
for name = ["buoyancy","qgpv","ssh","endpoints"]
    metric = 1;
    if name=="buoyancy" || name=="qgpv", metric=weights; end
    testCase.verifyLessThan(relativeError(coarseResponse.(name),dimensionResponse.(name),metric),1e-7)
    testCase.verifyLessThan(relativeError(dimensionResponse.(name),response.(name),metric),1e-7)
end
end

function response = referenceResponse(reference,flux,omega,times)
coefficients = sinusoidalResponse(reference.generator,flux*reference.boundaryLoad(:,1),omega,times);
response = struct(buoyancy=reference.buoyancy*coefficients,qgpv=reference.qgpv*coefficients, ...
    ssh=reference.ssh*coefficients,endpoints=reference.endpoints*coefficients);
end

function verifyBalancedResponse(testCase,actual,reference,weights)
testCase.verifyLessThan(relativeError(actual.buoyancy,reference.buoyancy,weights),2e-4)
testCase.verifyLessThan(relativeError(actual.qgpv,reference.qgpv,weights),1e-2)
testCase.verifyLessThan(relativeError(actual.ssh,reference.ssh,1),2e-4)
testCase.verifyLessThan(relativeError(actual.endpoints(1,:),reference.endpoints(1,:),1),2e-4)
testCase.verifyLessThan(relativeError(actual.endpoints(2,:),reference.endpoints(2,:),1),2e-4)
end

function coefficients = sinusoidalResponse(generator,source,omega,times)
% Integrate the forced finite-dimensional system from rest in one exponential.
count = numel(source);
augmented = [generator,source,zeros(count,1);zeros(1,count),0,omega;zeros(1,count),-omega,0];
coefficients = zeros(count,numel(times));
initial = [zeros(count+1,1);1];
for j = 1:numel(times)
    state = expm(augmented*times(j))*initial;
    coefficients(:,j) = state(1:count);
end
end

function buoyancy = neumannSurfaceFlux(z,depth,kappaZ,amplitude,omega,times)
% Analytic periodic solution plus the insulated transient from its initial field.
lambda = sqrt(1i*omega/kappaZ);
periodic = amplitude*cosh(lambda*(z+depth))/(kappaZ*lambda*sinh(lambda*depth));
mode = 0:128;
decay = kappaZ*(mode*pi/depth).^2;
transient = amplitude*(2-(mode==0)).*(-1).^mode./(depth*(1i*omega+decay));
buoyancy = imag(periodic*exp(1i*omega*times)) ...
    - cos((z+depth)*(mode*pi/depth))*(imag(transient(:)).*exp(-decay(:).*times));
end

function error = relativeError(actual,reference,weights)
error = norm(sqrt(weights).*(actual-reference),'fro')/norm(sqrt(weights).*reference,'fro');
end

function [q,N2] = fluxTransform(scale,Nz,count,accelerations)
N2 = @(z) 1e-4*exp(2*z/scale);
q = WVTransformFreeSurfaceQG([100e3 100e3 100],[8 8 Nz], ...
    N2Function=N2,rho0=1030,latitude=30,g0=accelerations(1),gd=accelerations(2), ...
    verticalGridRule="smoothedBandwidth",quadraticDealiasing="none", ...
    shouldAntialias=false,apvModeCount=count,mdaModeCount=count);
end

function [index,page,kh] = testWavenumber(q)
target = 2*pi/q.Lx;
index = find(abs(abs(q.kNonzero)-target)<10*eps(target) & q.lNonzero==0,1);
page = q.klNonzeroKhUniqueIndex(index);
kh = q.khUnique(page);
end

function [z,weights] = depthQuadrature(count,depth)
[nodes,weights] = legpts(count);
z = depth*(nodes-1)/2;
weights = depth*weights(:)/2;
end
