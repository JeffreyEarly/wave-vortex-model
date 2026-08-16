function validateThreeInterfaceBenchmarkContract(raw)
% Validate the evidence required to publish a matched three-interface run.
requiredInterfaces = ["matlab-builtin" "matlab-compiled" "standalone-compiled"];
tolerance = double(raw.configuration.correctnessTolerance);
processRunCount = double(raw.configuration.processRunCount);
validateCompiledProvider(raw);
definitions = raw.cases;
comparisons = raw.comparison;
allowedCases = ["nonlinear-flux" "fixed-rk4-continuation" "adaptive-rk23-observer-output"];
caseIds = string({definitions.id});
if isempty(definitions) || numel(definitions) ~= numel(comparisons) || numel(unique(caseIds)) ~= numel(caseIds) || any(~ismember(caseIds,allowedCases))
    error("WaveVortexBenchmark:MatchedContractFailed","Publication requires one or more unique recognized benchmark cases.");
end
for iCase = 1:numel(definitions)
    definition = definitions(iCase);
    comparisonIndex = find(string({comparisons.id}) == string(definition.id),1);
    if isempty(comparisonIndex)
        error("WaveVortexBenchmark:MatchedContractFailed","The comparison for %s is missing.",string(definition.id));
    end
    comparison = comparisons(comparisonIndex);
    caseRuns = raw.runs(string(arrayfun(@(run)run.case.id,raw.runs,"UniformOutput",false)) == string(definition.id));
    if numel(caseRuns) ~= processRunCount*numel(requiredInterfaces) || any(string({caseRuns.status}) ~= "complete")
        error("WaveVortexBenchmark:MatchedContractFailed","Case %s does not contain the required complete fresh-process runs.",string(definition.id));
    end
    validateIntegrators(caseRuns,definition,comparison);
    validateAdaptiveWork(caseRuns,definition,comparison);
    validateMemory(caseRuns,comparison);
    validateRunProviders(caseRuns,requiredInterfaces,raw);
    validateNumerics(comparison,definition,tolerance);
    if ~logical(comparison.matchedContractPassed)
        error("WaveVortexBenchmark:MatchedContractFailed","Case %s did not pass its matched contract.",string(definition.id));
    end
end
end


function validateAdaptiveWork(caseRuns,definition,comparison)
if string(definition.requestedIntegrator) ~= "adaptive-rk23"
    return
end
if ~isfield(comparison,"adaptiveWorkAgreementPassed") || ~logical(comparison.adaptiveWorkAgreementPassed)
    error("WaveVortexBenchmark:AdaptiveWorkMismatch","Publication requires equivalent adaptive controller work in every interface.");
end
% Fingerprint disagreement is diagnostic. Low-bit quantization has hard bin
% boundaries, so exact cross-language hash equality is not a sound numerical
% equivalence criterion for independently evaluated tolerance formulas. Older
% passing artifacts predate the explicit comparison field; their required hash
% records remain sufficient to recover the diagnostic value during publishing.
required = ["controller" "relativeTolerance" "absoluteToleranceHash" "absoluteToleranceHashClearedMantissaBits" "absoluteToleranceComponentHashes" "requestedInitialStep" "effectiveInitialStep" "requestedMaximumStep" "effectiveMaximumStep" "initialTime" "finalTime" "acceptedStepCount" "rejectedStepCount" "rhsEvaluationCount" "denseOutputEvaluationCount" "outputRecordCounts"];
if any(arrayfun(@(run)~all(isfield(run.integrator,required)),caseRuns))
    error("WaveVortexBenchmark:AdaptiveWorkMismatch","An adaptive interface omitted required controller or work-count evidence.");
end
end

function validateCompiledProvider(raw)
provider = raw.provider;
valid = string(provider.status) == "available" && logical(provider.isAvailable);
valid = valid && string(provider.provider.id) == "native-neon-pthreads" && string(provider.provider.threadBackend) == "pthreads";
valid = valid && logical(provider.module.identityValidated) && ~logical(provider.libraries.openmp.detected);
valid = valid && double(provider.contract.threadCount) == double(raw.configuration.threadCount);
valid = valid && string(provider.libraries.base.path) ~= "" && string(provider.libraries.thread.path) ~= "";
valid = valid && isfinite(provider.featureValidation.maximumRelativeError) && provider.featureValidation.maximumRelativeError <= raw.configuration.correctnessTolerance;
if ~valid
    error("WaveVortexBenchmark:ProviderMismatch","Publication requires the validated native FFTW provider for both compiled interfaces.");
end
end

function validateIntegrators(caseRuns,definition,comparison)
expected = string(definition.requestedIntegrator);
valid = logical(comparison.integratorAgreementPassed);
valid = valid && all(arrayfun(@(run)logical(run.integrator.matched) && string(run.integrator.requested) == expected && string(run.integrator.actual) == expected,caseRuns));
if ~valid
    error("WaveVortexBenchmark:IntegratorMismatch","Publication requires the requested integrator to execute in every interface.");
end
end

function validateMemory(caseRuns,comparison)
valid = logical(comparison.memoryAgreementPassed);
valid = valid && all(arrayfun(@validMemoryRecord,caseRuns));
if ~valid
    error("WaveVortexBenchmark:IncomparableMemory","Publication requires complete process-tree RSS measurements for every interface.");
end
end

function valid = validMemoryRecord(run)
memory = run.memory;
valid = string(memory.status) == "complete" && string(memory.provider) == "macos-ps-process-tree";
valid = valid && isfinite(memory.totalPeakRSSBytes) && memory.totalPeakRSSBytes > 0;
valid = valid && isfinite(memory.peakIncrementBytes) && memory.peakIncrementBytes >= 0;
valid = valid && isfinite(memory.finalRSSBytes) && memory.finalRSSBytes >= 0;
end

function validateRunProviders(caseRuns,requiredInterfaces,raw)
for interface = requiredInterfaces
    selected = caseRuns(string({caseRuns.interface}) == interface);
    if numel(selected) ~= double(raw.configuration.processRunCount)
        error("WaveVortexBenchmark:ProviderMismatch","Interface %s does not contain the required provider records.",interface);
    end
    for iRun = 1:numel(selected)
        provider = selected(iRun).provider;
        valid = logical(provider.noFallback) && double(provider.threads) == double(raw.configuration.threadCount);
        if interface == "matlab-builtin"
            valid = valid && string(provider.id) == "matlab-builtin" && string(provider.baseLibrary) == "" && string(provider.threadLibrary) == "";
        else
            valid = valid && string(provider.id) == string(raw.provider.provider.id) && string(provider.version) == string(raw.provider.provider.version);
            valid = valid && samePath(provider.baseLibrary,raw.provider.libraries.base.path) && samePath(provider.threadLibrary,raw.provider.libraries.thread.path);
        end
        if ~valid
            error("WaveVortexBenchmark:ProviderMismatch","Interface %s did not execute its required transform provider without fallback.",interface);
        end
    end
end
end

function validateNumerics(comparison,definition,tolerance)
if ~isfinite(comparison.maximumRelativeError) || comparison.maximumRelativeError > tolerance
    error("WaveVortexBenchmark:NumericalMismatch","Case %s exceeds the relative-error tolerance %.3e.",string(definition.id),tolerance);
end
if ~logical(comparison.outputAgreementPassed) || ~logical(comparison.outputGraph.passed)
    error("WaveVortexBenchmark:OutputGraphMismatch","Case %s does not agree across its complete output graph.",string(definition.id));
end
graph = comparison.outputGraph;
if ~isfinite(graph.maximumRelativeError) || graph.maximumRelativeError > tolerance || any(~[graph.categories.passed]) || any(~isfinite([graph.categories.maximumRelativeError])) || any([graph.categories.maximumRelativeError] > tolerance)
    error("WaveVortexBenchmark:OutputGraphMismatch","Case %s contains an output payload outside the relative-error tolerance.",string(definition.id));
end
requiredCategories = "coefficients";
if string(definition.operation) == "model-continuation"
    requiredCategories = [requiredCategories "eulerianFields" "moorings" "particles" "tracers" "times"];
end
if ~all(ismember(requiredCategories,string({graph.categories.name})))
    error("WaveVortexBenchmark:OutputGraphMismatch","Case %s is missing a required output category.",string(definition.id));
end
end

function value = samePath(left,right)
value = string(left) == string(right);
end
