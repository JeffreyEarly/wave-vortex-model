function [state,assessment,vertical] = buildFreeSurfaceBalancedState(Lxyz,Nxyz,inputs,options)
% Build stored balanced operators shared by free-surface QG and Boussinesq.
arguments
    Lxyz (1,3) double
    Nxyz (1,3) double
    inputs (1,1) struct
    options struct
end

if ~isempty(options.z)
    error('WVTransformFreeSurfaceQG:CustomVerticalGridUnavailable', ...
        'Scientific construction uses the selected Chebyshev-Lobatto rule and Nz. Restore the saved points through complete persisted-state construction.');
end
background = inputs.background;
Lz = background.D;
g0 = inputs.g0;
gd = inputs.gd;
f0 = background.f0;
g = background.g;

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
vertical = WVInternal.buildFreeSurfaceBalancedModes(background,Nxyz(3),verticalOptions);
z = vertical.z;
verticalQuadratureWeights = vertical.weights;
verticalDerivativeMatrix = vertical.Dz;
N2Values = vertical.N2Values;
nEVP = vertical.nEVP;
solver = vertical.solver;
apvTransform = vertical.apvTransform;
mdaTransform = vertical.mdaTransform;
apvModeCount = length(apvTransform.modeNumber);
mdaModeCount = length(mdaTransform.modeNumber);

apvF = apvTransform.inverseMatrix(variable="F");
apvG = apvTransform.inverseMatrix(variable="G");
apvFForward = apvTransform.forwardMatrix(variable="F");
apvGForward = apvTransform.forwardMatrix(variable="G");
mdaF = mdaTransform.inverseMatrix(variable="F");
mdaG = mdaTransform.inverseMatrix(variable="G");
mdaGForward = mdaTransform.forwardMatrix(variable="G");

frequencyTerm = (f0^2/g)./reshape(apvTransform.h,[],1);
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
vertical.zeroReference=[];
boundaryAssessment=struct(status="not-applicable");
if activeEndpointCount > 0
    endpointNames = ["surface","bottom"];
    endpointNames = endpointNames(activeMask);
    % Avoid constructing a large page set when its largest required radius
    % already fails. Passing this check still requires assessing all pages.
    if nKh>=32
        maxProblem = IMGeostrophicZeroAPVModes.atWavenumber(background,khUnique(end),endpoints=endpointNames);
        maxModes = solver.solveGeostrophicZeroAPVModes(maxProblem);
        WVInternal.assessFreeSurfaceBoundaryGrid(maxModes,maxProblem,vertical,inputs,options);
    end
    zeroProblem = IMGeostrophicZeroAPVModes.atWavenumber(background,khUnique,endpoints=endpointNames);
    zeroModes = solver.solveGeostrophicZeroAPVModes(zeroProblem);
    if nKh>0
        [boundaryAssessment,vertical.zeroReference]=WVInternal.assessFreeSurfaceBoundaryGrid(zeroModes,zeroProblem,vertical,inputs,options);
    end
    geostrophicTransform = IMGeostrophicTransform(apvTransform=apvTransform,zeroAPVModes=zeroModes, ...
        g0=g0,gd=gd,muTolerance=options.muTolerance);
    zeroAPVF = zeroModes.F(z);
    zeroAPVG = zeroModes.G(z);
    apvEndpointResponse = geostrophicTransform.apvEndpointResponse;
    minimumRelativeMuSeparation = geostrophicTransform.compatibilityDiagnostics.minimumRelativeMuSeparation;

    zeroAPVFProjection = zeros(activeEndpointCount,length(z),nKh);
    zeroAPVGProjection = zeros(activeEndpointCount,length(z),nKh);
    for iKh = 1:nKh
        [zeroAPVFProjection(:,:,iKh),zeroAPVGProjection(:,:,iKh)] = WVInternal.freeSurfaceBoundarySourceProjections( ...
            zeroAPVF(:,:,iKh),zeroAPVG(:,:,iKh),verticalQuadratureWeights,N2Values,Lz,g,g0,gd);
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
    zeroAPVFProjection = zeros(0,length(z),nKh);
    zeroAPVGProjection = zeros(0,length(z),nKh);
    zeroAPVSourceSolve = zeros(0,0,nKh);
    zeroAPVGramReciprocalCondition = zeros(0,1);
    zeroAPVGramRelativeSeparation = zeros(0,1);
    minimumRelativeMuSeparation = min(relativeMuSeparation,[],'all');
    Ag_0 = complex(zeros(0,length(klNonzero)));
end

pvF = apvTransform.physicalProjection(variable="F");
mda = mdaTransform.physicalProjection(variable="G");
if pvF.physicalDualStatus ~= "available" || mda.physicalDualStatus ~= "available"
    error('WV:UnavailablePhysicalProjection','Retained PV and MDA modes require a finite continuous projection normalization.');
end
apvProjectionNormalization = Lz*(pvF.targetGramMatrix\eye(apvModeCount));
mdaProjectionNormalization = mda.targetGramMatrix\eye(mdaModeCount);
apvFProjection = pvF.physicalDualMatrix;
apvGProjection = WVInternal.freeSurfaceAPVDisplacementProjection(apvF,apvG,verticalQuadratureWeights,N2Values,g,apvProjectionNormalization);
apvFDiagnostics = apvTransform.channelDiagnostics(variable="F");
apvGDiagnostics = apvTransform.channelDiagnostics(variable="G");
mdaDiagnostics = mdaTransform.channelDiagnostics(variable="G");

state = struct();
state.balancedNEVP = nEVP;
state.N2Function = background.N2;
state.rhoFunction = background.rho;
state.rho0 = background.rho0;
state.rotationRate = background.rotationRate;
state.latitude = background.latitude;
state.g = g;
state.z = z;
state.dLnN2 = verticalDerivativeMatrix*log(N2Values/N2Values(end));
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
state.apvFProjection = apvFProjection;
state.apvGProjection = apvGProjection;
state.apvStretchingMoment = sum(apvFProjection,2);
state.apvProjectionNormalization = apvProjectionNormalization;
state.mdaF = mdaF;
state.mdaG = mdaG;
state.mdaGForward = mdaGForward;
state.mdaGProjection = mda.physicalDualMatrix;
state.mdaProjectionNormalization = mdaProjectionNormalization;
state.mdaEquivalentDepth = reshape(mdaTransform.h,[],1);
state.verticalGridKind = "chebyshevLobatto";
state.verticalGridCoordinate = vertical.grid.kind;
state.verticalGridSnapshot = string(jsonencode(vertical.grid.snapshot()));
state.zeroAPVF = zeroAPVF;
state.zeroAPVG = zeroAPVG;
state.zeroAPVFProjection = zeroAPVFProjection;
state.zeroAPVGProjection = zeroAPVGProjection;
state.zeroAPVSourceSolve = zeroAPVSourceSolve;
state.apvGramError = max(apvFDiagnostics.relativeGramOperatorError,apvGDiagnostics.relativeGramOperatorError);
state.apvRoundTripError = max(apvFDiagnostics.roundTripError,apvGDiagnostics.roundTripError);
state.mdaGramError = mdaDiagnostics.relativeGramOperatorError;
state.mdaRoundTripError = mdaDiagnostics.roundTripError;
state.gramTolerance = options.gramTolerance;
state.modeConvergenceTolerance=options.modeConvergenceTolerance;
state.boundaryResolutionTolerance=options.boundaryResolutionTolerance;
state.quadraticDealiasing = options.quadraticDealiasing;
state.retainedFraction = options.retainedFraction;
state.energyFraction = options.energyFraction;
state.bandwidthFraction = options.bandwidthFraction;
state.minimumRelativeMuSeparation = minimumRelativeMuSeparation;
state.muTolerance = options.muTolerance;
state.zeroAPVGramReciprocalCondition = zeroAPVGramReciprocalCondition;
state.zeroAPVGramRelativeSeparation = zeroAPVGramRelativeSeparation;
state.modeSelectionMethod = "linear-prefix-plus-quadratic-dealiasing";
apvDealiasing=vertical.apvDealiasing;
assessment=struct(apv=vertical.apv,mda=vertical.mda,boundary=boundaryAssessment,gramTolerance=options.gramTolerance, ...
    modeConvergenceTolerance=options.modeConvergenceTolerance,boundaryResolutionTolerance=options.boundaryResolutionTolerance, ...
    dealiasing=struct(quadraticDealiasing=options.quadraticDealiasing,retainedFraction=options.retainedFraction, ...
    energyFraction=options.energyFraction,bandwidthFraction=options.bandwidthFraction,gridDegree=Nxyz(3)-1, ...
    coordinateKind=apvDealiasing.coordinateKind),cost=struct(quadraticDealiasingSeconds=vertical.quadraticDealiasingSeconds));
assessment.grid=WVInternal.freeSurfaceGridAssessment(vertical.grid.kind,z,khUnique);
assessment.coverage="Independent APV and MDA convergence, fixed-grid Gram evidence, and fixed boundary resolution. "+ ...
    "APV quadratic filtering applies the selected heuristic to the linearly qualified modes. Nonlinear product errors require separate assessment.";
vertical.zeroModes=[];
if activeEndpointCount>0, vertical.zeroModes=zeroModes; end
state.Ag_q = complex(zeros(apvModeCount,length(klNonzero)));
state.Ag_0 = Ag_0;
state.Amda = zeros(mdaModeCount,1);
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
