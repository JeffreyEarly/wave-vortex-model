function state = buildScientificState(Lxyz,Nxyz,options)
% Build the complete persisted free-surface QG representation.
arguments
    Lxyz (1,3) double
    Nxyz (1,3) double
    options struct
end

if isequal(options.N2Function,@isempty) && isequal(options.rhoFunction,@isempty)
    error('WVTransformFreeSurfaceQG:MissingStratification','Supply either N2Function or rhoFunction.');
end

Lz = Lxyz(3);
zDomain = [-Lz 0];
if isequal(options.N2Function,@isempty)
    derivativeStep = max(1,Lz)*eps^(1/3);
    N2Function = @(z) stratificationFromDensity(z,options.rhoFunction,options.rho0,options.g,zDomain,derivativeStep);
else
    N2Function = options.N2Function;
end
if isequal(options.rhoFunction,@isempty)
    rhoFunction = @(z) densityFromStratification(z,N2Function,options.rho0,options.g);
else
    rhoFunction = options.rhoFunction;
end

if isempty(options.z)
    z = linspace(-Lz,0,Nxyz(3)).';
else
    z = options.z(:);
end
if length(z) ~= Nxyz(3) || any(diff(z) <= 0) || abs(z(1)+Lz) > sqrt(eps)*max(1,Lz) || abs(z(end)) > sqrt(eps)*max(1,Lz)
    error('WVTransformFreeSurfaceQG:InvalidVerticalGrid','z must contain Nz increasing points spanning exactly [-Lz,0].');
end
N2Values = N2Function(z);
N2Values = N2Values(:);
if length(N2Values) ~= length(z) || any(~isfinite(N2Values)) || any(N2Values <= 0)
    error('WVTransformFreeSurfaceQG:InvalidStratification','N2Function must return one finite positive value per z point.');
end

g0 = options.g0;
if isnan(g0)
    g0 = -integral(N2Function,-Lz,0);
end
gd = options.gd;
if isnan(g0) || g0 == -Inf || isnan(gd) || gd == -Inf
    error('WVTransformFreeSurfaceQG:InvalidEndpointAcceleration','g0 and gd must be signed finite, zero, or positive Inf.');
end
endpointScale = max([options.g,abs(g0(isfinite(g0))),abs(gd(isfinite(gd))),1]);
if (isfinite(g0) && abs(g0) <= sqrt(eps)*endpointScale) || (isfinite(gd) && abs(gd) <= sqrt(eps)*endpointScale)
    warning('WVTransformFreeSurfaceQG:NearZeroEndpointAcceleration','A finite endpoint acceleration is near zero; verify that the corresponding limiting boundary condition is intended.');
end

horizontalGeometry = WVGeometryDoublyPeriodic(Lxyz(1:2),Nxyz(1:2),shouldAntialias=options.shouldAntialias,Nz=Nxyz(3),shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
kh = hypot(horizontalGeometry.k,horizontalGeometry.l);
klNonzero = find(kh > 0);
kNonzero = horizontalGeometry.k(klNonzero);
lNonzero = horizontalGeometry.l(klNonzero);
khNonzero = kh(klNonzero);
[khUnique,~,klNonzeroKhUniqueIndex] = unique(khNonzero,'sorted');

f0 = 2*options.rotationRate*sind(options.latitude);
if f0 == 0
    error('WVTransformFreeSurfaceQG:ZeroCoriolis','Free-surface QG construction requires nonzero Coriolis frequency.');
end

nCandidate = length(z);
nSolve = nCandidate+4;
nEVP = max(96,3*nSolve);
solver = IMSolverSpectral(nEVP=nEVP);
apvProblem = IMInternalModes.geostrophicAPVModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=g0,gd=gd,surfaceBoundary="freeSurface");
mdaProblem = IMInternalModes.meanDensityAnomalyModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=g0,gd=gd);
apvBasis = solver.solveEVP(apvProblem,nModes=nSolve);
mdaBasis = solver.solveEVP(mdaProblem,nModes=nSolve);

if isempty(options.Nj)
    maximumCandidateCount = min([nSolve,length(z)]);
    [apvTransform,mdaTransform,apvAssessment,mdaAssessment,Nj] = certifiedCommonTransform(apvBasis,mdaBasis,z,maximumCandidateCount);
    apvCandidateModeCount = maximumCandidateCount;
    mdaCandidateModeCount = maximumCandidateCount;
else
    if ~isscalar(options.Nj) || options.Nj < 1 || options.Nj ~= fix(options.Nj)
        error('WVTransformFreeSurfaceQG:InvalidNj','Nj must be a positive integer.');
    end
    Nj = options.Nj;
    if Nj > nSolve || Nj > length(z)
        error('WVTransformFreeSurfaceQG:UncertifiedNj','Requested Nj=%d exceeds the %d available solved modes or physical samples.',Nj,min(nSolve,length(z)));
    end
    try
        [apvTransform,apvAssessment] = apvBasis.discreteTransform(z=z,nModes=Nj,variables=["F","G"]);
        [mdaTransform,mdaAssessment] = mdaBasis.discreteTransform(z=z,nModes=Nj,variables="G");
    catch cause
        exception = MException('WVTransformFreeSurfaceQG:UncertifiedNj','Requested Nj=%d is not certified for both APV and MDA modes on the supplied z grid.',Nj);
        throw(addCause(exception,cause))
    end
    apvCandidateModeCount = Nj;
    mdaCandidateModeCount = Nj;
end
hasPositiveQuadrature = ~apvTransform.hasNegativeWeights && ~mdaTransform.hasNegativeWeights;
if ~hasPositiveQuadrature
    error('WVTransformFreeSurfaceQG:NegativeQuadratureWeight','The common physical grid produced a negative fitted quadrature weight. Supply a better-resolved z grid.');
end

apvF = apvTransform.inverseMatrix(variable="F");
apvG = apvTransform.inverseMatrix(variable="G");
apvFForward = apvTransform.forwardMatrix(variable="F");
apvGForward = apvTransform.forwardMatrix(variable="G");
mdaF = mdaTransform.inverseMatrix(variable="F");
mdaG = mdaTransform.inverseMatrix(variable="G");
mdaGForward = mdaTransform.forwardMatrix(variable="G");

frequencyTerm = (f0^2/options.g)./reshape(apvTransform.h,[],1);
apvMu = frequencyTerm+reshape(khUnique,1,[]).^2;
relativeMuSeparation = abs(apvMu)./(abs(frequencyTerm)+reshape(khUnique,1,[]).^2);
if any(~isfinite(apvMu),'all') || any(relativeMuSeparation <= sqrt(eps),'all')
    error('WVTransformFreeSurfaceQG:NearSingularMu','A retained APV inversion eigenvalue is singular or insufficiently separated.');
end

activeMask = [isfinite(g0),isfinite(gd)];
activeEndpoint = find(activeMask).';
activeEndpointCount = length(activeEndpoint);
sourceEndpoint = activeEndpoint;
nKh = length(khUnique);
if activeEndpointCount > 0
    endpointNames = ["surface","bottom"];
    zeroProblem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2Function,zDomain=zDomain,f0=f0,g=options.g,k=khUnique,endpoints=endpointNames(activeMask),surfaceBoundary="freeSurface");
    zeroModes = solver.solveGeostrophicZeroAPVModes(zeroProblem);
    geostrophicTransform = IMGeostrophicTransform(apvTransform=apvTransform,zeroAPVModes=zeroModes,g0=g0,gd=gd);
    zeroAPVF = zeroModes.F(z);
    zeroAPVG = zeroModes.G(z);
    apvEndpointResponse = geostrophicTransform.apvEndpointResponse;
    minimumRelativeMuSeparation = geostrophicTransform.compatibilityDiagnostics.minimumRelativeMuSeparation;

    endpointZ = [0;-Lz];
    zeroFEndpoints = zeroModes.F(endpointZ);
    zeroGEndpoints = zeroModes.G(endpointZ);
    zeroAPVFPairing = zeros(activeEndpointCount,length(z),nKh);
    zeroAPVGPairing = zeros(activeEndpointCount,length(z),nKh);
    FWeights = reshape(apvTransform.weights/apvTransform.depth,1,[]);
    GWeights = reshape(apvTransform.weights.*apvTransform.N2Values/options.g,1,[]);
    surfaceIndex = find(abs(z) <= sqrt(eps)*max(1,Lz),1);
    bottomIndex = find(abs(z+Lz) <= sqrt(eps)*max(1,Lz),1);
    for iKh = 1:nKh
        zeroAPVFPairing(:,:,iKh) = zeroAPVF(:,:,iKh).'.*FWeights;
        zeroAPVGPairing(:,:,iKh) = zeroAPVG(:,:,iKh).'.*GWeights;
        if isfinite(g0) && g0 ~= 0
            surfaceResponse = zeroGEndpoints(1,:,iKh)-zeroFEndpoints(1,:,iKh);
            zeroAPVGPairing(:,surfaceIndex,iKh) = zeroAPVGPairing(:,surfaceIndex,iKh)+(g0/options.g)*surfaceResponse.';
        end
        if isfinite(gd) && gd ~= 0
            zeroAPVGPairing(:,bottomIndex,iKh) = zeroAPVGPairing(:,bottomIndex,iKh)+(gd/options.g)*zeroGEndpoints(2,:,iKh).';
        end
    end

    matrixG0 = g0;
    matrixGd = gd;
    if isinf(matrixG0), matrixG0 = 0; end
    if isinf(matrixGd), matrixGd = 0; end
    generalizedEnergy = zeroModes.generalizedEnergyMatrix(g0=matrixG0,gd=matrixGd);
    zeroAPVSourceSolve = zeros(activeEndpointCount,activeEndpointCount,nKh);
    zeroAPVGramReciprocalCondition = zeros(nKh,1);
    zeroAPVGramRelativeSeparation = zeros(nKh,1);
    for iKh = 1:nKh
        normalizedGram = (2*khUnique(iKh)^2/apvTransform.depth)*generalizedEnergy(:,:,iKh);
        formScale = norm(zeroModes.energyMatrix(:,:,iKh),2)+abs(matrixG0)*norm(zeroModes.surfaceBuoyancyMatrix(:,:,iKh),2)+abs(matrixGd)*norm(zeroModes.bottomBuoyancyMatrix(:,:,iKh),2);
        normalizedScale = (2*khUnique(iKh)^2/apvTransform.depth)*formScale;
        singularValues = svd(normalizedGram);
        zeroAPVGramReciprocalCondition(iKh) = rcond(normalizedGram);
        zeroAPVGramRelativeSeparation(iKh) = min(singularValues)/max(normalizedScale,realmin);
        zeroAPVSourceSolve(:,:,iKh) = normalizedGram\eye(activeEndpointCount);
    end
    Ag_0 = complex(zeros(activeEndpointCount,length(klNonzero)));
else
    zeroAPVF = zeros(length(z),0,nKh);
    zeroAPVG = zeros(length(z),0,nKh);
    apvEndpointResponse = zeros(0,Nj,nKh);
    zeroAPVFPairing = zeros(0,length(z),nKh);
    zeroAPVGPairing = zeros(0,length(z),nKh);
    zeroAPVSourceSolve = zeros(0,0,nKh);
    zeroAPVGramReciprocalCondition = zeros(0,1);
    zeroAPVGramRelativeSeparation = zeros(0,1);
    minimumRelativeMuSeparation = min(relativeMuSeparation,[],'all');
    Ag_0 = complex(zeros(0,length(klNonzero)));
end

identitySamples = eye(length(z));
apvFSourcePairing = apvTransform.modeProjectionFunctional(identitySamples,variable="F")/apvTransform.depth;
apvGSourcePairing = apvTransform.modeProjectionFunctional(identitySamples,variable="G");
apvFDiagnostics = apvTransform.channelDiagnostics(variable="F");
apvGDiagnostics = apvTransform.channelDiagnostics(variable="G");
mdaDiagnostics = mdaTransform.channelDiagnostics(variable="G");

state = struct();
state.N2Function = N2Function;
state.rhoFunction = rhoFunction;
state.z = z;
state.dLnN2 = gradient(log(N2Values),z);
state.PF0inv = apvF;
state.QG0inv = apvG;
state.PF0 = apvFForward;
state.QG0 = apvGForward;
state.P0 = ones(Nj,1);
state.Q0 = ones(Nj,1);
state.h_0 = reshape(apvTransform.h,[],1);
state.z_int = apvTransform.weights;
state.g0 = g0;
state.gd = gd;
state.activeEndpointCount = activeEndpointCount;
state.activeEndpoint = activeEndpoint;
state.sourceEndpoint = sourceEndpoint;
state.apvMode = (1:Nj).';
state.apvModeNumber = reshape(apvTransform.modeNumber,[],1);
state.mdaMode = (1:Nj).';
state.mdaModeNumber = reshape(mdaTransform.modeNumber,[],1);
state.klNonzero = reshape(klNonzero,[],1);
state.kNonzero = reshape(kNonzero,[],1);
state.lNonzero = reshape(lNonzero,[],1);
state.khNonzero = reshape(khNonzero,[],1);
state.khUnique = reshape(khUnique,[],1);
state.klNonzeroKhUniqueIndex = reshape(klNonzeroKhUniqueIndex,[],1);
state.apvF = apvF;
state.apvG = apvG;
state.apvFForward = apvFForward;
state.apvGForward = apvGForward;
state.apvEquivalentDepth = reshape(apvTransform.h,[],1);
state.apvMu = apvMu;
state.apvEndpointResponse = apvEndpointResponse;
state.apvFSourcePairing = apvFSourcePairing;
state.apvGSourcePairing = apvGSourcePairing;
state.mdaF = mdaF;
state.mdaG = mdaG;
state.mdaGForward = mdaGForward;
state.mdaEquivalentDepth = reshape(mdaTransform.h,[],1);
state.zeroAPVF = zeroAPVF;
state.zeroAPVG = zeroAPVG;
state.zeroAPVFPairing = zeroAPVFPairing;
state.zeroAPVGPairing = zeroAPVGPairing;
state.zeroAPVSourceSolve = zeroAPVSourceSolve;
state.apvCandidateModeCount = apvCandidateModeCount;
state.mdaCandidateModeCount = mdaCandidateModeCount;
state.apvGramError = max(apvFDiagnostics.relativeGramOperatorError,apvGDiagnostics.relativeGramOperatorError);
state.apvRoundTripError = max(apvFDiagnostics.roundTripError,apvGDiagnostics.roundTripError);
state.mdaGramError = mdaDiagnostics.relativeGramOperatorError;
state.mdaRoundTripError = mdaDiagnostics.roundTripError;
state.minimumRelativeMuSeparation = minimumRelativeMuSeparation;
state.zeroAPVGramReciprocalCondition = zeroAPVGramReciprocalCondition;
state.zeroAPVGramRelativeSeparation = zeroAPVGramRelativeSeparation;
state.hasPositiveQuadrature = hasPositiveQuadrature;
state.certificationMethod = "InternalModesEVP common discrete-transform prefix v1";
state.Ag_q = complex(zeros(Nj,length(klNonzero)));
state.Ag_0 = Ag_0;
state.Amda = zeros(Nj,1);

% Keep the strict assessments alive through construction so every requested
% common-prefix policy is evaluated even though only compact results persist.
if apvAssessment.retainedModeCount ~= Nj || mdaAssessment.retainedModeCount ~= Nj
    error('WVTransformFreeSurfaceQG:CertificationInconsistency','InternalModesEVP did not retain the requested common prefix.');
end
end

function [apvTransform,mdaTransform,apvAssessment,mdaAssessment,Nj] = certifiedCommonTransform(apvBasis,mdaBasis,z,maximumCandidateCount)
lastCause = [];
for candidateCount = maximumCandidateCount:-1:1
    try
        [candidateAPV,candidateAPVAssessment] = apvBasis.discreteTransform(z=z,nModes=candidateCount,variables=["F","G"]);
        [candidateMDA,candidateMDAAssessment] = mdaBasis.discreteTransform(z=z,nModes=candidateCount,variables="G");
        apvTransform = candidateAPV;
        mdaTransform = candidateMDA;
        apvAssessment = candidateAPVAssessment;
        mdaAssessment = candidateMDAAssessment;
        Nj = candidateCount;
        return
    catch cause
        lastCause = cause;
    end
end
exception = MException('WVTransformFreeSurfaceQG:NoCertifiedCommonMode','No common APV/MDA mode prefix is certified on the supplied z grid.');
if ~isempty(lastCause)
    exception = addCause(exception,lastCause);
end
throw(exception)
end

function rho = densityFromStratification(z,N2Function,rho0,g)
shape = size(z);
z = z(:);
rho = zeros(size(z));
for iPoint = 1:length(z)
    rho(iPoint) = rho0-(rho0/g)*integral(N2Function,0,z(iPoint));
end
rho = reshape(rho,shape);
end

function N2 = stratificationFromDensity(z,rhoFunction,rho0,g,zDomain,derivativeStep)
shape = size(z);
z = z(:);
zMinus = max(z-derivativeStep,zDomain(1));
zPlus = min(z+derivativeStep,zDomain(2));
if any(zPlus <= zMinus)
    error('WVTransformFreeSurfaceQG:InvalidDensityEvaluationPoint','Density-derived stratification was requested outside the vertical domain.');
end
rhoMinus = reshape(rhoFunction(zMinus),[],1);
rhoPlus = reshape(rhoFunction(zPlus),[],1);
if length(rhoMinus) ~= length(z) || length(rhoPlus) ~= length(z)
    error('WVTransformFreeSurfaceQG:InvalidDensityFunction','rhoFunction must return one value per input depth.');
end
N2 = -(g/rho0)*(rhoPlus-rhoMinus)./(zPlus-zMinus);
N2 = reshape(N2,shape);
end
