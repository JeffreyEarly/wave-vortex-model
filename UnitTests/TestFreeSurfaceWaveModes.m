classdef TestFreeSurfaceWaveModes < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function constantModesCrossTheExternalModeTransition(testCase)
            transition = sqrt((1e-4-1e-8)/(9.81*1000));
            for kh = [2*pi/1e5 transition 2*pi/1e4 2*pi/1e3]
                [rows,modes] = qualifyCase("constant",kh,65);
                verifyQualified(testCase,rows(end));
                testCase.verifyLessThan(max(modes.hRelativeError),1e-7)
                testCase.verifyEqual(modes.interiorNodes,(0:5).')
            end
        end

        function variableModesAgreeWithIndependentShooting(testCase)
            for kh = [2*pi/1e5 2*pi/1e3]
                [rows,modes] = qualifyCase("exponential",kh,[17 33 65 129]);
                verifyQualified(testCase,rows(end));
                testCase.verifyLessThan(max(modes.referenceFrequencyConvergence),1e-8)
                testCase.verifyLessThan(rows(end).verticalMomentumResidual,rows(1).verticalMomentumResidual/100)
                testCase.verifyLessThan(rows(end).energyGramError,rows(1).energyGramError/100)
                testCase.verifyEqual(modes.interiorNodes,(0:5).')
            end
        end

        function realFieldsHaveTheDeclaredPositiveEnergy(testCase)
            N2 = @(z)1e-4*ones(size(z));
            kh = 2*pi/1e4; f = 1e-4; g = 9.81;
            evp = makeEVP(N2,kh);
            basis = IMSolverSpectral(nEVP=96,coordinateKind="wkb").solveEVP(evp,nModes=6);
            [z,weights] = basis.solver.nativeQuadratureRule([-1000 0]);
            [p,omega] = WVInternal.freeSurfaceWavePolarization(basis.F(z),basis.G(z),basis.h(:),.6*kh,.8*kh,f=f);
            energyWeights = [weights;weights;weights;weights.*N2(z);g];
            B = fieldMatrix(p);
            h = repmat(basis.h(:),2,1);
            amplitudes = exp(1i*(1:12)')./sqrt(2*h.*(1:12)');
            expected = sum(2*h.*abs(amplitudes).^2);
            [x,y] = ndgrid(2*pi*(0:7)/8);
            phase = exp(1i*(x(:)+y(:))).';
            for t = [0 1e3 1e5]
                signedOmega = [omega -omega].';
                realFields = 2*real((B*(amplitudes.*exp(1i*signedOmega*t)))*phase);
                energy = sum(energyWeights.*mean(realFields.^2,2))/2;
                testCase.verifyEqual(energy,expected,RelTol=1e-8)
            end
        end

        function polarizationRejectsInvalidModeLayouts(testCase)
            testCase.verifyError(@()WVInternal.freeSurfaceWavePolarization(ones(5,2),ones(5,1),[1;2],1,1,f=1e-4),'WV:WaveModeShape')
            testCase.verifyError(@()WVInternal.freeSurfaceWavePolarization(ones(5,2),ones(5,2),[1;2],0,0,f=1e-4),'WV:ZeroWaveWavenumber')
        end
    end

    methods (Static)
        function [summary,modes] = runStudy(outputDirectory,options)
            % Run and optionally export the bounded #366 wave validation.
            arguments (Input)
                outputDirectory (1,1) string = ""
                options.nEVP (1,1) double {mustBeInteger,mustBeGreaterThan(options.nEVP,6)} = 64
            end
            summary = table(); modes = table();
            transition = sqrt((1e-4-1e-8)/(9.81*1000));
            for profile = ["constant" "exponential"]
                wavenumbers = [2*pi/1e5 2*pi/1e4 2*pi/1e3];
                if profile == "constant", wavenumbers = sort([wavenumbers transition]); end
                for kh = wavenumbers
                    [rows,modeRows] = qualifyCase(profile,kh,[17 33 65 129],options.nEVP);
                    summary = [summary;struct2table(rows)]; %#ok<AGROW>
                    modes = [modes;modeRows]; %#ok<AGROW>
                end
            end
            if strlength(outputDirectory) > 0
                if ~isfolder(outputDirectory), mkdir(outputDirectory); end
                writetable(summary,fullfile(outputDirectory,'issue-366-wave-validation.csv'));
                writetable(modes,fullfile(outputDirectory,'issue-366-wave-modes.csv'));
            end
        end
    end
end

function verifyQualified(testCase,row)
testCase.verifyLessThan(row.frequencyRelativeError,1e-7)
testCase.verifyLessThan(row.modeShapeRelativeError,1e-7)
testCase.verifyLessThan(row.normalizationError,1e-8)
testCase.verifyLessThan(row.energyGramError,1e-8)
testCase.verifyLessThan(row.projectionRelativeError,1e-8)
testCase.verifyLessThan(row.energyDrift,1e-8)
% Pressure differentiation amplifies eigenvector roundoff for the long
% external mode; this bound is qualified by the nEVP resolution study.
testCase.verifyLessThan(row.verticalMomentumResidual,2e-7)
for name = ["horizontalMomentumResidual" "continuityResidual" "displacementResidual" "apvResidual" "surfaceDynamicResidual" "surfaceKinematicResidual" "bottomVelocityResidual" "interiorEndpointResidual"]
    testCase.verifyLessThan(row.(name),1e-7,char(name))
end
end

function [rows,modes] = qualifyCase(profile,kh,gridCounts,nEVP)
if nargin < 4, nEVP = 64; end
D = 1000; f = 1e-4; g = 9.81; rho0 = 1025; nModes = 6;
if profile == "constant", N2 = @(z)1e-4*ones(size(z)); else, N2 = @(z)1e-4*exp(2*z/700); end
evp = makeEVP(N2,kh);
basis = IMSolverSpectral(nEVP=nEVP,coordinateKind="wkb").solveEVP(evp,nModes=nModes);
h = basis.h(:);
omega = sqrt(f^2+g*h*kh^2);
if profile == "constant"
    reference = constantReference(kh,f,g,.01,D,nModes);
    referenceConvergence = zeros(nModes,1);
else
    coarseReference = shootingReference(N2,kh,f,g,D,h,3e-10);
    reference = shootingReference(N2,kh,f,g,D,h,3e-12);
    referenceConvergence = abs(sqrt(f^2+g*coarseReference.h*kh^2)-sqrt(f^2+g*reference.h*kh^2))./sqrt(f^2+g*reference.h*kh^2);
end
referenceOmega = sqrt(f^2+g*reference.h*kh^2);
zCheck = -D*(1+cos(pi*(0:2048)'/2048))/2;
checkFields = reference.evaluate(zCheck);
interiorNodes = sum(checkFields.G(2:end-2,:).*checkFields.G(3:end-1,:) < 0,1).';
modes = table(repmat(profile,nModes,1),repmat(kh,nModes,1),(1:nModes).',basis.modeNumber(:),h,reference.h,omega,referenceOmega, ...
    abs(h-reference.h)./reference.h,abs(omega-referenceOmega)./referenceOmega,referenceConvergence,interiorNodes, ...
    VariableNames=["profile" "kh" "familyIndex" "providerModeNumber" "h" "referenceH" "omega" "referenceOmega" "hRelativeError" "frequencyRelativeError" "referenceFrequencyConvergence" "interiorNodes"]);
rows = struct([]);
for nGrid = gridCounts
    calculus = IMSolverSpectral(nEVP=nGrid,coordinateKind="wkb").configuredForEVP(evp);
    [z,weights,Dz] = calculus.nativeDifferentiationRule([-D 0]);
    F = basis.F(z); G = basis.G(z);
    [p,~] = WVInternal.freeSurfaceWavePolarization(F,G,h,.6*kh,.8*kh,f=f,g=g,rho0=rho0);
    exact = reference.evaluate(z);
    orientation = sign(sum(weights.*F.*exact.F,1));
    orientation(orientation==0) = 1;
    Fref = exact.F.*orientation; Gref = exact.G.*orientation;
    pref = WVInternal.freeSurfaceWavePolarization(Fref,Gref,reference.h,.6*kh,.8*kh,f=f,g=g,rho0=rho0);
    B = fieldMatrix(p); Bref = fieldMatrix(pref);
    energyWeights = [weights;weights;weights;weights.*N2(z);g];
    modalEnergy = 2*repmat(h,2,1);
    scaledB = B./sqrt(modalEnergy.');
    energyGram = scaledB'*(energyWeights.*scaledB);
    normalization = G'*(weights.*((N2(z)-f^2)/g).*G)+G(end,:)'*G(end,:);
    row = physicalResiduals(p,z,weights,Dz,N2(z),kh,f,g,rho0,D,omega);
    row.profile = profile; row.kh = kh; row.D = D; row.f = f; row.g = g; row.rho0 = rho0;
    row.nEVP = nEVP; row.nModesPerSign = nModes; row.nGrid = nGrid;
    row.frequencyRelativeError = max(modes.frequencyRelativeError);
    row.referenceFrequencyConvergence = max(referenceConvergence);
    row.modeShapeRelativeError = max(sqrt(sum(energyWeights.*abs(B-Bref).^2,1))./sqrt(sum(energyWeights.*abs(Bref).^2,1)));
    row.normalizationError = norm(normalization-eye(nModes),2);
    row.energyGramError = norm(energyGram-eye(2*nModes),2);
    amplitudes = exp(1i*(1:2*nModes)')./sqrt(modalEnergy.*(1:2*nModes)');
    recovered = (B'*(energyWeights.*(B*amplitudes)))./modalEnergy;
    row.projectionRelativeError = sqrt(sum(modalEnergy.*abs(recovered-amplitudes).^2)/sum(modalEnergy.*abs(amplitudes).^2));
    times = [0 1e3 1e5];
    phases = exp(1i*[omega;-omega]*times);
    states = B*(amplitudes.*phases);
    energies = real(sum(energyWeights.*abs(states).^2,1));
    row.energyDrift = max(abs(energies-energies(1)))/energies(1);
    rows = [rows;row]; %#ok<AGROW>
end
end

function evp = makeEVP(N2,kh)
evp = IMInternalModes.waveModesAtWavenumber(N2=N2,zDomain=[-1000 0],k=kh,f0=1e-4,g=9.81,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0));
end

function B = fieldMatrix(p)
nz = size(p.u,1);
B = [reshape(p.u,nz,[]);reshape(p.v,nz,[]);reshape(p.w,nz,[]);reshape(p.eta,nz,[]);reshape(p.ssh,1,[])];
end

function row = physicalResiduals(p,z,weights,Dz,N2,kh,f,g,rho0,D,omega)
nz = length(z); k = .6*kh; l = .8*kh;
u = reshape(p.u,nz,[]); v = reshape(p.v,nz,[]); w = reshape(p.w,nz,[]);
eta = reshape(p.eta,nz,[]); pressure = reshape(p.p,nz,[]); ssh = reshape(p.ssh,1,[]);
signedOmega = [omega.' -omega.'];
dt = 1i*signedOmega;
row.horizontalMomentumResidual = max(relativeResidual(weights,dt.*u-f*v+1i*k*pressure/rho0,dt.*u,f*v,1i*k*pressure/rho0), ...
    relativeResidual(weights,dt.*v+f*u+1i*l*pressure/rho0,dt.*v,f*u,1i*l*pressure/rho0));
row.verticalMomentumResidual = relativeResidual(weights,dt.*w+Dz*pressure/rho0+N2.*eta,dt.*w,Dz*pressure/rho0,N2.*eta);
row.continuityResidual = relativeResidual(weights,1i*k*u+1i*l*v+Dz*w,1i*k*u,1i*l*v,Dz*w);
row.displacementResidual = relativeResidual(weights,dt.*eta-w,dt.*eta,w);
row.apvResidual = relativeResidual(weights,1i*k*v-1i*l*u-f*Dz*eta,1i*k*v,1i*l*u,f*Dz*eta);
row.surfaceDynamicResidual = max(abs(pressure(end,:)-rho0*g*eta(end,:))./(max(abs(pressure),[],1)+rho0*g*max(abs(eta),[],1)));
row.surfaceKinematicResidual = max(abs(w(end,:)-dt.*ssh)./(max(abs(w),[],1)+abs(dt.*ssh)));
row.bottomVelocityResidual = max(abs(w(1,:))./max(abs(w),[],1));
etaInterior = eta-(1+z/D).*ssh;
wInterior = w-(1+z/D).*(dt.*ssh);
row.interiorEndpointResidual = max([max(abs(etaInterior([1 end],:)),[],1)./(max(abs(eta),[],1)+abs(ssh)), ...
    max(abs(wInterior([1 end],:)),[],1)./(max(abs(w),[],1)+abs(dt.*ssh))]);
end

function value = relativeResidual(weights,residual,varargin)
denominator = zeros(1,size(residual,2));
for i = 1:length(varargin), denominator = denominator+sqrt(sum(weights.*abs(varargin{i}).^2,1)); end
value = max(sqrt(sum(weights.*abs(residual).^2,1))./max(denominator,realmin));
end

function reference = constantReference(kh,f,g,N0,D,nModes)
K = kh*D; mu = (N0^2-f^2)*D/g;
roots = zeros(1,nModes); kind = zeros(1,nModes); h = zeros(nModes,1);
if abs(K^2-mu) < 1e-12*mu
    h(1) = D;
elseif K^2 < mu
    roots(1) = fzero(@(x)tan(x)-mu*x/(x*x+K*K),[1e-8 pi/2-1e-8]);
    kind(1) = 1;
    h(1) = mu*D/(roots(1)^2+K^2);
else
    roots(1) = fzero(@(y)(K*K-y*y)*tanh(y)/y-mu,[1e-8 K]);
    kind(1) = -1;
    h(1) = D*tanh(roots(1))/roots(1);
end
for j = 2:nModes
    roots(j) = fzero(@(x)tan(x)-mu*x/(x*x+K*K),[(j-1)*pi+1e-8 (j-.5)*pi-1e-8]);
    kind(j) = 1;
    h(j) = mu*D/(roots(j)^2+K^2);
end
norms = zeros(1,nModes);
for j = 1:nModes
    x = roots(j);
    if kind(j) == 0
        integralG2 = D/3; surfaceG = 1;
    elseif kind(j) == 1
        integralG2 = D*(.5-sin(2*x)/(4*x)); surfaceG = sin(x);
    else
        integralG2 = D*(sinh(2*x)/(4*x)-.5)/sinh(x)^2; surfaceG = 1;
    end
    norms(j) = sqrt((N0^2-f^2)*integralG2/g+surfaceG^2);
end
reference.h = h;
reference.evaluate = @(z)constantFields(z,D,h,roots,kind,norms);
end

function fields = constantFields(z,D,h,roots,kind,norms)
s = (z(:)+D)/D;
G = zeros(length(z),length(h)); F = G;
for j = 1:length(h)
    x = roots(j);
    if kind(j) == 0
        G(:,j) = s; F(:,j) = h(j)/D;
    elseif kind(j) == 1
        G(:,j) = sin(x*s); F(:,j) = h(j)*x/D*cos(x*s);
    else
        G(:,j) = sinh(x*s)/sinh(x); F(:,j) = h(j)*x/D*cosh(x*s)/sinh(x);
    end
end
fields = struct(F=F./norms,G=G./norms);
end

function reference = shootingReference(N2,kh,f,g,D,seedH,tolerance)
options = odeset(RelTol=tolerance,AbsTol=tolerance/100);
h = zeros(size(seedH)); solutions = cell(size(seedH)); norms = zeros(1,length(h));
[z,weights] = gaussRule(-D,0,256);
for j = 1:length(h)
    root = fzero(@(logH)shootingResidual(exp(logH),N2,kh,f,g,D,options),log(seedH(j))+[-.05 .05],optimset(TolX=1e-13));
    h(j) = exp(root);
    solutions{j} = shoot(h(j),N2,kh,f,g,D,options);
    values = deval(solutions{j},z); surface = deval(solutions{j},0);
    norms(j) = sqrt(sum(weights.*((N2(z)-f^2)/g).*values(1,:).'.^2)+surface(1)^2);
end
reference.h = h;
reference.evaluate = @(z)shootingFields(z,h,solutions,norms);
end

function value = shootingResidual(h,N2,kh,f,g,D,options)
solution = shoot(h,N2,kh,f,g,D,options);
surface = solution.y(:,end);
value = (surface(1)-h*surface(2))/hypot(surface(1),D*surface(2));
end

function solution = shoot(h,N2,kh,f,g,D,options)
solution = ode113(@(z,y)[y(2);(kh^2-(N2(z)-f^2)/(g*h))*y(1)],[-D 0],[0;1],options);
end

function fields = shootingFields(z,h,solutions,norms)
F = zeros(length(z),length(h)); G = F;
for j = 1:length(h)
    values = deval(solutions{j},z);
    G(:,j) = values(1,:).'/norms(j);
    F(:,j) = h(j)*values(2,:).'/norms(j);
end
fields = struct(F=F,G=G);
end

function [z,weights] = gaussRule(a,b,n)
offDiagonal = (1:n-1)'./sqrt(4*(1:n-1)'.^2-1);
[vectors,values] = eig(diag(offDiagonal,1)+diag(offDiagonal,-1),'vector');
[values,order] = sort(values);
z = (a+b)/2+(b-a)*values/2;
weights = (b-a)*vectors(1,order).'.^2;
end
