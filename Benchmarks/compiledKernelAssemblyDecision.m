function decision = compiledKernelAssemblyDecision(cases)
% Apply the issue #131 core-completion and MATLAB-integration gates.
arguments
    cases (:,1) struct
end
required = ["status" "compiledSpeedup" "exactMemoryRatio" "peakRSSRatio" "maximumRelativeError" "lifecyclePassed" "libraryIdentityPassed" "nativeExecutionPassed" "noFallback" "persistentFullHermitianBytes"];
for name = required
    if ~all(arrayfun(@(item)isfield(item,name),cases))
        error("WaveVortexModel:CompiledKernelAssemblyDecision","Case records are missing %s.",name);
    end
end
complete = string({cases.status})' == "complete";
correct = [cases.maximumRelativeError]' <= 1e-12;
coreChecks = complete & correct & [cases.lifecyclePassed]' & [cases.libraryIdentityPassed]' & [cases.nativeExecutionPassed]' & [cases.noFallback]' & [cases.persistentFullHermitianBytes]' == 0;
coreComplete = ~isempty(cases) && all(coreChecks);
speedGate = coreComplete && all([cases.compiledSpeedup]' >= 1.25);
memoryNonregression = coreComplete && all([cases.exactMemoryRatio]' <= 1.03) && all([cases.peakRSSRatio]' <= 1.03);
memoryImprovement = coreComplete && all([cases.exactMemoryRatio]' <= 0.80) && all([cases.peakRSSRatio]' <= 0.80);
runtimeNonregression = coreComplete && all(1./[cases.compiledSpeedup]' <= 1.03);
if speedGate && memoryNonregression
    integrationStatus = "INTEGRATION-READY";
elseif ~speedGate && memoryImprovement && runtimeNonregression
    integrationStatus = "MEMORY-ONLY";
else
    integrationStatus = "INTEGRATION-NOT-READY";
end
decision = struct( ...
    "coreStatus",conditional(coreComplete,"CORE-COMPLETE","CORE-INCOMPLETE"), ...
    "integrationStatus",integrationStatus, ...
    "coreComplete",coreComplete, ...
    "speedGatePassed",speedGate, ...
    "memoryNonregressionPassed",memoryNonregression, ...
    "memoryImprovementPassed",memoryImprovement, ...
    "runtimeNonregressionPassed",runtimeNonregression, ...
    "minimumCompiledSpeedup",minimumOrNaN([cases.compiledSpeedup]), ...
    "maximumExactMemoryRatio",maximumOrNaN([cases.exactMemoryRatio]), ...
    "maximumPeakRSSRatio",maximumOrNaN([cases.peakRSSRatio]), ...
    "maximumRelativeError",maximumOrNaN([cases.maximumRelativeError]));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = minimumOrNaN(values)
if isempty(values), value = NaN; else, value = min(values); end
end

function value = maximumOrNaN(values)
if isempty(values), value = NaN; else, value = max(values); end
end
