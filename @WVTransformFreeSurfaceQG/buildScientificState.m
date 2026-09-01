function state = buildScientificState(Lxyz,Nxyz,options)
% Build the complete persisted free-surface QG representation.
arguments
    Lxyz (1,3) double
    Nxyz (1,3) double
    options struct
end

Lz = Lxyz(3);
if ~isempty(options.z)
    error('WVTransformFreeSurfaceQG:CustomVerticalGridUnavailable', ...
        'Scientific construction uses the WKB-stretched Chebyshev-Lobatto rule determined by Nz. Restore custom points only through complete persisted-state construction.');
end
inputs = WVTransformFreeSurfaceQG.resolveScientificInputs(Lz,options);
N2Function = inputs.N2Function;
rhoFunction = inputs.rhoFunction;
g0 = inputs.g0;
gd = inputs.gd;
f0 = inputs.f0;
zDomain = inputs.zDomain;

horizontalGeometry = WVGeometryDoublyPeriodic(Lxyz(1:2),Nxyz(1:2),shouldAntialias=options.shouldAntialias,Nz=Nxyz(3),shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
kh = hypot(horizontalGeometry.k,horizontalGeometry.l);
klNonzero = find(kh > 0);
kNonzero = horizontalGeometry.k(klNonzero);
lNonzero = horizontalGeometry.l(klNonzero);
khNonzero = kh(klNonzero);
[khUnique,klNonzeroKhUniqueIndex] = uniqueWavenumberPages(khNonzero);

verticalOptions = options;
verticalOptions.g0 = g0;
verticalOptions.gd = gd;
vertical = WVTransformFreeSurfaceQG.buildVerticalModes(Lz,Nxyz(3),N2Function,verticalOptions);
z = vertical.z;
verticalQuadratureWeights = vertical.weights;
verticalDerivativeMatrix = vertical.Dz;
N2Values = vertical.N2Values;
nEVP = vertical.nEVP;
solver = vertical.solver;
apvBasis = vertical.apvBasis;
apvTransform = vertical.apvTransform;
mdaTransform = vertical.mdaTransform;
apvAssessment = vertical.apvAssessment;
mdaAssessment = vertical.mdaAssessment;
apvModeCount = length(apvTransform.modeNumber);
mdaModeCount = length(mdaTransform.modeNumber);

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
    if nKh > 0
        crossAssessment = WVTransformFreeSurfaceQG.measureAPVZeroAPVQuadraticError(apvBasis,apvTransform,zeroModes,nKh,2*nEVP);
        apvZeroAPVQuadraticError = crossAssessment.error;
        apvZeroAPVLimitingEndpoint = crossAssessment.limitingEndpoint;
        apvZeroAPVLimitingModeNumber = crossAssessment.limitingModeNumber;
        if apvZeroAPVQuadraticError > options.quadraticAliasingTolerance
            limit = WVTransformFreeSurfaceQG.supportedHorizontalWavenumber(apvBasis,apvTransform,N2Function,f0,options.g, ...
                endpointNames(activeMask),nEVP,options.quadraticAliasingTolerance,rejectedKh=khUnique(end));
            error('WVTransformFreeSurfaceQG:UnderresolvedVerticalGrid', ...
                ['Nz=%d resolves APV/zero-APV products through kh approximately %.6g rad m^-1 at tolerance %.3g, ' ...
                'but the horizontal grid retains %.6g rad m^-1 with error %.3g. The first rejected bracket is %.6g rad m^-1, ' ...
                'and the corresponding minimum horizontal wavelength is %.6g m. Increase Nz or reduce horizontal resolution.'], ...
                Nxyz(3),limit.maximumSupportedKh,options.quadraticAliasingTolerance,khUnique(end),apvZeroAPVQuadraticError, ...
                limit.firstRejectedKh,limit.minimumHorizontalWavelength);
        end
    else
        apvZeroAPVQuadraticError = NaN;
        apvZeroAPVLimitingEndpoint = "";
        apvZeroAPVLimitingModeNumber = NaN;
    end

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
    apvZeroAPVQuadraticError = NaN;
    apvZeroAPVLimitingEndpoint = "";
    apvZeroAPVLimitingModeNumber = NaN;
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
state.verticalQuadratureWeights = verticalQuadratureWeights;
state.verticalDerivativeMatrix = verticalDerivativeMatrix;
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
state.verticalGridKind = "chebyshevLobatto";
state.verticalGridCoordinate = "wkb";
state.zeroAPVF = zeroAPVF;
state.zeroAPVG = zeroAPVG;
state.zeroAPVFPairing = zeroAPVFPairing;
state.zeroAPVGPairing = zeroAPVGPairing;
state.zeroAPVSourceSolve = zeroAPVSourceSolve;
state.apvGramError = max(apvFDiagnostics.relativeGramOperatorError,apvGDiagnostics.relativeGramOperatorError);
state.apvRoundTripError = max(apvFDiagnostics.roundTripError,apvGDiagnostics.roundTripError);
state.mdaGramError = mdaDiagnostics.relativeGramOperatorError;
state.mdaRoundTripError = mdaDiagnostics.roundTripError;
quadraticDiagnostics = apvAssessment.prefixDiagnostics(apvModeCount,:);
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
state.apvZeroAPVQuadraticError = apvZeroAPVQuadraticError;
state.apvZeroAPVLimitingEndpoint = apvZeroAPVLimitingEndpoint;
state.apvZeroAPVLimitingModeNumber = apvZeroAPVLimitingModeNumber;
state.modeSelectionMethod = "fixed-native-quadrature-v1";
state.Ag_q = complex(zeros(apvModeCount,length(klNonzero)));
state.Ag_0 = Ag_0;
state.Amda = zeros(mdaModeCount,1);

if ~isempty(apvAssessment.weightFit) || ~isempty(mdaAssessment.weightFit) ...
        || length(apvTransform.modeNumber) ~= apvModeCount || length(mdaTransform.modeNumber) ~= mdaModeCount
    error('WVTransformFreeSurfaceQG:ModeSelectionInconsistency','InternalModesEVP did not use the supplied fixed quadrature rule.');
end
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
