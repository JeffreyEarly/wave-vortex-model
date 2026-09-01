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
[khUnique,klNonzeroKhUniqueIndex] = uniqueWavenumberPages(khNonzero);

f0 = 2*options.rotationRate*sind(options.latitude);
if f0 == 0
    error('WVTransformFreeSurfaceQG:ZeroCoriolis','Free-surface QG construction requires nonzero Coriolis frequency.');
end

nCandidate = Nxyz(3);
nSolve = nCandidate+4;
nEVP = max(96,3*nSolve);
solver = IMSolverSpectral(nEVP=nEVP);
apvProblem = IMInternalModes.geostrophicAPVModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=g0,gd=gd,surfaceBoundary="freeSurface");
mdaProblem = IMInternalModes.meanDensityAnomalyModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=g0,gd=gd);
apvBasis = solver.solveEVP(apvProblem,nModes=nSolve);
mdaBasis = solver.solveEVP(mdaProblem,nModes=nSolve);

if isempty(options.z)
    [z,verticalGridDesign] = apvBasis.modeRootGrid(nPoints=Nxyz(3));
else
    z = options.z(:);
    verticalGridDesign = struct.empty;
end
if length(z) ~= Nxyz(3) || any(diff(z) <= 0) || abs(z(1)+Lz) > sqrt(eps)*max(1,Lz) || abs(z(end)) > sqrt(eps)*max(1,Lz)
    error('WVTransformFreeSurfaceQG:InvalidVerticalGrid','z must contain Nz increasing points spanning exactly [-Lz,0].');
end
N2Values = N2Function(z);
N2Values = N2Values(:);
if length(N2Values) ~= length(z) || any(~isfinite(N2Values)) || any(N2Values <= 0)
    error('WVTransformFreeSurfaceQG:InvalidStratification','N2Function must return one finite positive value per z point.');
end

if isempty(verticalGridDesign)
    [apvCertifiedTransform,apvCertifiedAssessment] = apvBasis.certifiedDiscreteTransform( ...
        z=z,variables=["F","G"],gramTolerance=options.apvGramTolerance, ...
        quadraticAliasingTolerance=options.quadraticAliasingTolerance);
    verticalGridDesign = apvCertifiedAssessment.gridDesign;
else
    [apvCertifiedTransform,apvCertifiedAssessment] = apvBasis.certifiedDiscreteTransform( ...
        z=z,gridDesign=verticalGridDesign,variables=["F","G"],gramTolerance=options.apvGramTolerance, ...
        quadraticAliasingTolerance=options.quadraticAliasingTolerance);
end
[mdaCertifiedTransform,mdaCertifiedAssessment] = mdaBasis.certifiedDiscreteTransform( ...
    z=z,gridDesign=verticalGridDesign,variables="G",gramTolerance=options.mdaGramTolerance);
apvInitialModeCount = max(apvCertifiedAssessment.certificationSearch.modeCount);
mdaInitialModeCount = max(mdaCertifiedAssessment.certificationSearch.modeCount);
apvCertifiedModeCount = apvCertifiedAssessment.retainedModeCount;
mdaCertifiedModeCount = mdaCertifiedAssessment.retainedModeCount;
apvModeCount = selectedModeCount(options.apvModeCount,apvCertifiedModeCount,"APV");
mdaModeCount = selectedModeCount(options.mdaModeCount,mdaCertifiedModeCount,"MDA");
apvTransform = apvCertifiedTransform;
apvAssessment = apvCertifiedAssessment;
if apvModeCount < apvCertifiedModeCount
    [apvTransform,apvAssessment] = apvBasis.fitDiscreteTransform( ...
        z=z,modeCount=apvModeCount,gridDesign=verticalGridDesign,variables=["F","G"], ...
        gramTolerance=options.apvGramTolerance,quadraticAliasingTolerance=options.quadraticAliasingTolerance);
end
mdaTransform = mdaCertifiedTransform;
mdaAssessment = mdaCertifiedAssessment;
if mdaModeCount < mdaCertifiedModeCount
    [mdaTransform,mdaAssessment] = mdaBasis.fitDiscreteTransform( ...
        z=z,modeCount=mdaModeCount,gridDesign=verticalGridDesign,variables="G", ...
        gramTolerance=options.mdaGramTolerance);
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
if any(~isfinite(apvMu),'all') || any(relativeMuSeparation <= options.muTolerance,'all')
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
    geostrophicTransform = IMGeostrophicTransform(apvTransform=apvTransform,zeroAPVModes=zeroModes, ...
        g0=g0,gd=gd,muTolerance=options.muTolerance);
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
    apvEndpointResponse = zeros(0,apvModeCount,nKh);
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
state.P0 = ones(apvModeCount,1);
state.Q0 = ones(apvModeCount,1);
state.h_0 = reshape(apvTransform.h,[],1);
state.z_int = apvTransform.weights;
state.apvQuadratureWeights = apvTransform.weights;
state.mdaQuadratureWeights = mdaTransform.weights;
state.g0 = g0;
state.gd = gd;
state.activeEndpointCount = activeEndpointCount;
state.activeEndpoint = activeEndpoint;
state.sourceEndpoint = sourceEndpoint;
state.apvMode = (1:apvModeCount).';
state.apvModeNumber = reshape(apvTransform.modeNumber,[],1);
state.mdaMode = (1:mdaModeCount).';
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
state.verticalGridKind = string(verticalGridDesign.kind);
state.verticalGridSourceEVP = string(verticalGridDesign.sourceEVP);
state.verticalGridGeneratingVariable = string(verticalGridDesign.generatingVariable);
state.verticalGridGeneratingModeNumber = verticalGridDesign.generatingModeNumber;
state.verticalGridRepresentedModeCount = verticalGridDesign.representedModeCount;
state.verticalGridInterpretation = string(verticalGridDesign.interpretationForG);
state.zeroAPVF = zeroAPVF;
state.zeroAPVG = zeroAPVG;
state.zeroAPVFPairing = zeroAPVFPairing;
state.zeroAPVGPairing = zeroAPVGPairing;
state.zeroAPVSourceSolve = zeroAPVSourceSolve;
state.apvInitialModeCount = apvInitialModeCount;
state.mdaInitialModeCount = mdaInitialModeCount;
state.apvCertifiedModeCount = apvCertifiedModeCount;
state.mdaCertifiedModeCount = mdaCertifiedModeCount;
state.apvGramError = max(apvFDiagnostics.relativeGramOperatorError,apvGDiagnostics.relativeGramOperatorError);
state.apvRoundTripError = max(apvFDiagnostics.roundTripError,apvGDiagnostics.roundTripError);
state.mdaGramError = mdaDiagnostics.relativeGramOperatorError;
state.mdaRoundTripError = mdaDiagnostics.roundTripError;
quadraticDiagnostics = apvAssessment.prefixDiagnostics(end,:);
state.apvGramTolerance = options.apvGramTolerance;
state.mdaGramTolerance = options.mdaGramTolerance;
state.quadraticAliasingTolerance = options.quadraticAliasingTolerance;
state.quadraticAliasingError = quadraticDiagnostics.quadraticAliasingError;
state.quadraticAliasingLimitingChannel = quadraticDiagnostics.quadraticLimitingChannel;
state.quadraticAliasingLimitingModeNumberI = quadraticDiagnostics.quadraticLimitingModeNumberI;
state.quadraticAliasingLimitingModeNumberJ = quadraticDiagnostics.quadraticLimitingModeNumberJ;
state.minimumRelativeMuSeparation = minimumRelativeMuSeparation;
state.muTolerance = options.muTolerance;
state.zeroAPVGramReciprocalCondition = zeroAPVGramReciprocalCondition;
state.zeroAPVGramRelativeSeparation = zeroAPVGramRelativeSeparation;
state.hasPositiveQuadrature = hasPositiveQuadrature;
state.certificationMethod = "InternalModesEVP shared-grid independently-refitted family selection v5";
state.Ag_q = complex(zeros(apvModeCount,length(klNonzero)));
state.Ag_0 = Ag_0;
state.Amda = zeros(mdaModeCount,1);

if apvAssessment.weightFitModeCount ~= apvModeCount || mdaAssessment.weightFitModeCount ~= mdaModeCount ...
        || length(apvTransform.modeNumber) ~= apvModeCount || length(mdaTransform.modeNumber) ~= mdaModeCount
    error('WVTransformFreeSurfaceQG:CertificationInconsistency','InternalModesEVP did not retain the requested family prefixes.');
end
end

function count = selectedModeCount(requestedCount,certifiedCount,familyName)
if isempty(requestedCount)
    count = certifiedCount;
    return
end
if ~isscalar(requestedCount) || requestedCount < 1 || requestedCount ~= fix(requestedCount)
    error('WVTransformFreeSurfaceQG:InvalidModeCount','%s mode count must be a positive integer.',familyName);
end
if requestedCount > certifiedCount
    error('WVTransformFreeSurfaceQG:UncertifiedModeCount','Requested %s mode count %d exceeds its certified maximum of %d.',familyName,requestedCount,certifiedCount);
end
count = requestedCount;
end

function [uniqueValues,index] = uniqueWavenumberPages(values)
if isempty(values)
    uniqueValues = zeros(0,1);
    index = zeros(0,1);
    return
end
[sortedValues,order] = sort(values(:));
sortedIndex = ones(size(sortedValues));
for iValue = 2:length(sortedValues)
    comparisonScale = max(abs(sortedValues(iValue-1:iValue)));
    if abs(sortedValues(iValue)-sortedValues(iValue-1)) > 64*eps(comparisonScale)
        sortedIndex(iValue) = sortedIndex(iValue-1)+1;
    else
        sortedIndex(iValue) = sortedIndex(iValue-1);
    end
end
uniqueValues = accumarray(sortedIndex,sortedValues,[],@mean);
index = zeros(size(sortedIndex));
index(order) = sortedIndex;
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
