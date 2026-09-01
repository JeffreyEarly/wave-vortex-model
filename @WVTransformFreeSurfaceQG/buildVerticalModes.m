function vertical = buildVerticalModes(Lz,Nz,N2Function,options)
% Build APV and MDA transforms on one fixed WKB quadrature rule.
arguments
    Lz (1,1) double {mustBePositive}
    Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(Nz,4)}
    N2Function function_handle
    options struct
end

zDomain = [-Lz 0];
nSolve = Nz+4;
nEVP = max(96,3*nSolve);
solver = IMSolverSpectral(nEVP=nEVP);
apvProblem = IMInternalModes.geostrophicAPVModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=options.g0,gd=options.gd,surfaceBoundary="freeSurface");
mdaProblem = IMInternalModes.meanDensityAnomalyModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=options.g0,gd=options.gd);
apvBasis = solver.solveEVP(apvProblem,nModes=nSolve);
mdaBasis = solver.solveEVP(mdaProblem,nModes=nSolve);

gridSolver = IMSolverSpectral(nEVP=Nz,coordinateKind="wkb").configuredForEVP(apvProblem);
[z,weights] = gridSolver.nativeQuadratureRule(zDomain);
weights = weights*(Lz/sum(weights));
if length(z) ~= Nz || any(diff(z) <= 0) || abs(z(1)+Lz) > sqrt(eps)*max(1,Lz) || abs(z(end)) > sqrt(eps)*max(1,Lz)
    error('WVTransformFreeSurfaceQG:InvalidVerticalGrid','The WKB quadrature must contain Nz increasing points spanning exactly [-Lz,0].');
end
if any(~isfinite(weights)) || any(weights <= 0) || abs(sum(weights)-Lz) > 64*eps(max(1,Lz))
    error('WVTransformFreeSurfaceQG:InvalidVerticalQuadrature','The WKB quadrature must have finite positive weights that integrate the exact depth.');
end
N2Values = N2Function(z);
N2Values = N2Values(:);
if length(N2Values) ~= length(z) || any(~isfinite(N2Values)) || any(N2Values <= 0)
    error('WVTransformFreeSurfaceQG:InvalidStratification','N2Function must return one finite positive value per z point.');
end

[apvTransform,apvAssessment] = apvBasis.discreteTransform(z=z,weights=weights,variables=["F","G"], ...
    gramTolerance=options.apvGramTolerance,quadraticAliasingTolerance=options.quadraticAliasingTolerance);
[mdaTransform,mdaAssessment] = mdaBasis.discreteTransform(z=z,weights=weights,variables="G",gramTolerance=options.mdaGramTolerance);
quadraticPolicy = apvAssessment.quadraticAliasingPolicy;
hasProjectionContract = isfield(quadraticPolicy,'projectionPairing') && isequal(string(quadraticPolicy.projectionPairing),"signedPontryagin");
hasErrorContract = isfield(quadraticPolicy,'errorNorm') && isequal(string(quadraticPolicy.errorNorm),"inducedHilbertMajorant");
if ~hasProjectionContract || ~hasErrorContract
    error('WVTransformFreeSurfaceQG:UnsupportedQuadraticAliasingContract', ...
        'The active InternalModes checkout must use signed Pontryagin projection and the induced Hilbert majorant for coupled quadratic-aliasing errors.');
end
if apvTransform.hasNegativeWeights || mdaTransform.hasNegativeWeights ...
        || max(abs(apvTransform.weights-weights)) > 0 || max(abs(mdaTransform.weights-weights)) > 0
    error('WVTransformFreeSurfaceQG:InvalidVerticalQuadrature','InternalModes did not preserve the shared positive physical quadrature rule.');
end
if ~isempty(apvAssessment.weightFit) || ~isempty(mdaAssessment.weightFit)
    error('WVTransformFreeSurfaceQG:ModeSelectionInconsistency','InternalModesEVP did not use the supplied fixed quadrature rule.');
end

vertical = struct(z=z,weights=weights,N2Values=N2Values,nEVP=nEVP,solver=solver,apvProblem=apvProblem,mdaProblem=mdaProblem, ...
    apvBasis=apvBasis,mdaBasis=mdaBasis,apvTransform=apvTransform,mdaTransform=mdaTransform,apvAssessment=apvAssessment,mdaAssessment=mdaAssessment);
end
