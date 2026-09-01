function result = measureAPVZeroAPVQuadraticError(apvBasis,apvTransform,zeroModes,pageIndex,referenceOrder)
% Compare fixed-grid APV/zero-APV products with direct spectral integration.
arguments
    apvBasis (1,1) IMInternalModesBasis
    apvTransform (1,1) IMInternalModesDiscreteTransform
    zeroModes (1,1) IMGeostrophicZeroAPVModesBasis
    pageIndex (1,1) double {mustBeInteger,mustBePositive}
    referenceOrder (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(referenceOrder,4)}
end

z = apvTransform.z;
nModes = length(apvTransform.modeNumber);
referenceSolver = IMSolverSpectral(nEVP=referenceOrder).configuredForEVP(apvBasis.evp);
[referenceZ,referenceWeights] = referenceSolver.nativeQuadratureRule(apvBasis.zDomain);
spec = apvBasis.evp.innerProduct("F");
context = apvBasis.evp.contextForSolver(referenceSolver);
sampleInteriorWeight = IMEigenvalueProblem.evaluateCoefficient(spec.interiorWeight,z,context);
referenceInteriorWeight = IMEigenvalueProblem.evaluateCoefficient(spec.interiorWeight,referenceZ,context);
if isscalar(sampleInteriorWeight)
    sampleInteriorWeight = sampleInteriorWeight*ones(size(z));
end
if isscalar(referenceInteriorWeight)
    referenceInteriorWeight = referenceInteriorWeight*ones(size(referenceZ));
end
sampleInteriorWeight = sampleInteriorWeight(:);
referenceInteriorWeight = referenceInteriorWeight(:);

sampleAPVF = apvTransform.inverseMatrix(variable="F");
sampleZeroF = zeroModes.F(z);
sampleZeroF = sampleZeroF(:,:,pageIndex);
referenceAPVF = apvBasis.F(referenceZ);
referenceAPVF = referenceAPVF(:,1:nModes);
referenceZeroF = zeroModes.F(referenceZ);
referenceZeroF = referenceZeroF(:,:,pageIndex);
endpointZ = apvBasis.zDomain(:);
endpointAPVF = apvBasis.F(endpointZ);
endpointAPVF = endpointAPVF(:,1:nModes);
endpointZeroF = zeroModes.F(endpointZ);
endpointZeroF = endpointZeroF(:,:,pageIndex);

metricDiagonal = diag(apvTransform.metricMatrix(variable="F"));
endpointMetricDiagonal = metricDiagonal-sampleInteriorWeight.*apvTransform.weights;
endpointMetric = endpointMetricDiagonal([1 end]);
targetGram = apvTransform.targetGramMatrix(variable="F");
targetMajorantGram = apvTransform.targetMajorantGramMatrix(variable="F");
active = apvTransform.activeModeMask(variable="F");
forward = apvTransform.forwardMatrix(variable="F");
volumeWeights = referenceWeights.*referenceInteriorWeight;

maximumError = 0;
limitingEndpoint = "";
limitingModeNumber = NaN;
errorByEndpoint = zeros(1,size(sampleZeroF,2));
for iEndpoint = 1:size(sampleZeroF,2)
    sampledProducts = sampleAPVF.*sampleZeroF(:,iEndpoint);
    referenceProducts = referenceAPVF.*referenceZeroF(:,iEndpoint);
    endpointProducts = endpointAPVF.*endpointZeroF(:,iEndpoint);
    sampledCoefficients = forward*sampledProducts;
    referencePairings = referenceAPVF.'*(volumeWeights.*referenceProducts) ...
        + endpointAPVF.'*(endpointMetric.*endpointProducts);
    referenceCoefficients = zeros(nModes,nModes);
    referenceCoefficients(active,:) = targetGram(active,active)\referencePairings(active,:);
    difference = sampledCoefficients-referenceCoefficients;
    numerator = real(sum(conj(difference(active,:)).*(targetMajorantGram(active,active)*difference(active,:)),1));
    productNorm = sum(referenceProducts.*(volumeWeights.*referenceProducts),1) ...
        + sum(abs(endpointMetric).*endpointProducts.*endpointProducts,1);
    productNormScale = max(productNorm);
    if productNormScale > 0
        usable = productNorm > 1e3*eps(productNormScale);
    else
        usable = false(size(productNorm));
    end
    errors = zeros(1,nModes);
    errors(usable) = sqrt(max(0,numerator(usable))./productNorm(usable));
    [endpointMaximum,iMode] = max(errors);
    errorByEndpoint(iEndpoint) = endpointMaximum;
    if endpointMaximum >= maximumError
        maximumError = endpointMaximum;
        limitingEndpoint = zeroModes.endpoints(iEndpoint);
        limitingModeNumber = apvTransform.modeNumber(iMode);
    end
end

result = struct(error=maximumError,limitingEndpoint=limitingEndpoint,limitingModeNumber=limitingModeNumber,errorByEndpoint=errorByEndpoint);
end
