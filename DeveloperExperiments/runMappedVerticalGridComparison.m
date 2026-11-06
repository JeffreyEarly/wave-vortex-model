function comparison = runMappedVerticalGridComparison(options)
% Compare mapped Lobatto grids using the same resolved continuous modes.
%
% Volume Gram errors and sample-noise amplification refer to individual
% channels scaled in physical L2. These are diagnostics of sampling and
% reconstruction, distinct from WVM's signed state and source projectors.
% Derivative errors use the larger of the reference derivative scale and
% field scale divided by depth, including when the exact derivative is zero.
arguments (Input)
    options.pointCounts (1,:) double {mustBeNonempty,mustBeInteger,mustBeGreaterThanOrEqual(options.pointCounts,3)} = [65 97]
    options.nEVP (1,1) double {mustBeInteger,mustBePositive} = 256
    options.modeCount (1,1) double {mustBeInteger,mustBePositive} = 8
end
if options.modeCount > min(options.pointCounts)
    error("WV:ComparisonSampleCount","Use at least one sample per mode in the comparison.");
end

profiles = {@(z) 1e-4*ones(size(z)),@(z) 1e-4*exp(2*z/700), ...
    @(z) 2e-6+1.5e-4*exp(-((z+140)/85).^2)};
profileNames = ["constant","exponential","stronglyVarying"];
zDomain = [-1000 0];
kappa = 2*pi/4000;
g0 = 0;
gd = 0.01;
solver = IMSolverSpectral(nEVP=options.nEVP);
referenceSolver = IMSolverSpectral(nEVP=ceil(1.5*options.nEVP));
[zReference,wReference] = legpts(max(512,2*options.nEVP),zDomain);
wReference = wReference(:);
records = cell(numel(profiles),numel(options.pointCounts),2);
for iProfile = 1:numel(profiles)
    background = IMBackground(N2=profiles{iProfile},zDomain=zDomain,latitude=33,surfaceCondition="freeSurface");
    apv = IMInternalModes.geostrophicAPVModes(background,g0=g0,gd=gd);
    mda = IMInternalModes.meanDensityAnomalyModes(background,g0=g0,gd=gd);
    wave = IMInternalModes.waveModesAtWavenumber(background,k=kappa);
    boundary = IMGeostrophicZeroAPVModes.atWavenumber(background,kappa,endpoints=["surface","bottom"]);
    bases = {solver.solveEVP(apv,nModes=options.modeCount),solver.solveEVP(mda,nModes=options.modeCount), ...
        solver.solveEVP(wave,nModes=options.modeCount),solver.solveGeostrophicZeroAPVModes(boundary)};
    references = {referenceSolver.solveEVP(apv,nModes=options.modeCount),referenceSolver.solveEVP(mda,nModes=options.modeCount), ...
        referenceSolver.solveEVP(wave,nModes=options.modeCount),referenceSolver.solveGeostrophicZeroAPVModes(boundary)};
    for iPoints = 1:numel(options.pointCounts)
        Nz = options.pointCounts(iPoints);
        grids = {IMVerticalGrid.wkb(background,Nz),IMVerticalGrid.smoothedBandwidth(background,Nz)};
        for iGrid = 1:numel(grids)
            grid = grids{iGrid};
            rows = cell(4,1);
            for iFamily = 1:numel(bases)
                rows{iFamily} = compareFamily(bases{iFamily},references{iFamily},grid,iFamily,zReference,wReference);
            end
            metrics = vertcat(rows{:});
            count = height(metrics);
            records{iProfile,iPoints,iGrid} = [table(repmat(profileNames(iProfile),count,1),repmat(Nz,count,1), ...
                repmat(grid.kind,count,1),VariableNames=["profile","Nz","grid"]),metrics];
        end
    end
end
comparison = struct(configuration=struct(nEVP=options.nEVP,referenceNEVP=referenceSolver.nEVP, ...
    referenceQuadratureCount=numel(zReference),modeCount=options.modeCount,kappa=kappa,g0=g0,gd=gd), ...
    metrics=vertcat(records{:}));
end

function rows = compareFamily(basis,reference,grid,iFamily,zReference,wReference)
families = ["APV","MDA","wave","boundary"];
channels = ["F","G"];
if families(iFamily) == "MDA", channels = "G"; end
if ~isequal(basis.modeInfo.columnLabel,reference.modeInfo.columnLabel)
    error("WV:ComparisonModeLabels","The two %s solves returned different scientific columns.",families(iFamily));
end
depthDifference = NaN;
if families(iFamily) ~= "boundary"
    depthDifference = max(abs(basis.h-reference.h)./abs(reference.h));
end
Dz = grid.calculus.firstDerivativeMatrix();
P = grid.calculus.interpolationMatrix(zReference);
measurements = zeros(numel(channels),8);
for j = 1:numel(channels)
    channel = channels(j);
    V = basis.evaluate(grid.z,variable=channel);
    Vz = basis.evaluate(grid.z,variable=channel,derivativeOrder=1);
    Q = basis.evaluate(zReference,variable=channel);
    R = reference.evaluate(zReference,variable=channel);
    scale = vecnorm(sqrt(wReference).*Q);
    Q = Q./scale;
    V = V./scale;
    Vz = Vz./scale;
    R = R./vecnorm(sqrt(wReference).*R);
    overlap = sum(wReference.*conj(R).*Q,1);
    R = R.*sign(overlap);

    continuous = max(vecnorm(sqrt(wReference).*(Q-R)));
    reconstructed = max(vecnorm(sqrt(wReference).*(P*V-Q)));
    sampledDerivative = Dz*V;
    derivativeScale = vecnorm(sqrt(grid.weights).*Vz);
    derivativeError = max(vecnorm(sqrt(grid.weights).*(sampledDerivative-Vz))./max(derivativeScale,1/grid.D));
    endpointScale = max(max(abs(Vz),[],1),max(abs(V),[],1)/grid.D);
    endpointError = max(max(abs(sampledDerivative([1 end],:)-Vz([1 end],:)),[],1)./endpointScale);
    sampleGram = V'*(grid.weights.*V);
    referenceGram = Q'*(wReference.*Q);
    pairingError = norm(sampleGram-referenceGram,2);
    boundaryForm = V(end,:)'*V(end,:)-V(1,:)'*V(1,:);
    derivativePair = V'*(grid.weights.*sampledDerivative);
    weakError = grid.D*norm(derivativePair+derivativePair'-boundaryForm,2);
    sampleSingularValues = svd(sqrt(grid.weights).*V);
    noise = Inf;
    if sampleSingularValues(end) > max(size(V))*eps(sampleSingularValues(1))
        noise = 1/sampleSingularValues(end);
    end
    measurements(j,:) = [depthDifference,continuous,reconstructed,derivativeError,endpointError,pairingError,weakError,noise];
end
rows = [table(repmat(families(iFamily),numel(channels),1),channels.',VariableNames=["family","channel"]), ...
    array2table(measurements,VariableNames=["continuousDepthDifference","continuousDifference","retainedFieldError","derivativeError", ...
        "endpointDerivativeError","volumeGramError","weakBoundaryResidual","noiseAmplification"])];
end
