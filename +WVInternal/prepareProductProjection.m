function context = prepareProductProjection(basis,transform,variable,zReference,referenceWeights)
% Prepare signed sampled and continuous projections with a positive error norm.
arguments (Input)
    basis (1,1) IMInternalModesBasis
    transform (1,1) IMInternalModesDiscreteTransform
    variable (1,1) string {mustBeMember(variable,["F","G"])}
    zReference (:,1) double
    referenceWeights (:,1) double
end
n = length(transform.modeNumber);
spec = basis.evp.innerProduct(variable);
coefficientContext = basis.evp.contextForSolver(basis.solver);
sampleWeight = IMEigenvalueProblem.evaluateCoefficient(spec.interiorWeight,transform.z,coefficientContext);
referenceWeight = IMEigenvalueProblem.evaluateCoefficient(spec.interiorWeight,zReference,coefficientContext);
sampleWeight = sampleWeight.*ones(size(transform.z));
referenceWeight = referenceWeight.*ones(size(zReference));
metric = transform.metricMatrix(variable=variable);
endpointMetric = diag(metric)-sampleWeight.*transform.weights;
% The provider's direct scalar channels have value-only endpoint terms.
interior = endpointMetric(2:end-1);
if any(abs(interior)>64*eps(max(1,norm(diag(metric),Inf))))
    error('WVStudy:UnsupportedMetric','The scalar adapter requires diagonal volume weights and value-only endpoint terms.')
end
if variable == "F", values = basis.F(zReference); else, values = basis.G(zReference); end
endpointValues = flipud(transform.endpointValues(variable=variable));
context = struct(sampleValues=transform.inverseMatrix(variable=variable),sampleMetric=metric,sampleGram=transform.gramMatrix(variable=variable),targetGram=transform.targetGramMatrix(variable=variable),majorantGram=transform.targetMajorantGramMatrix(variable=variable),active=transform.activeModeMask(variable=variable),referenceValues=values(:,1:n),volumeWeights=referenceWeights.*referenceWeight,endpointValues=endpointValues,endpointMetric=endpointMetric([1 end]),variable=variable);
end
