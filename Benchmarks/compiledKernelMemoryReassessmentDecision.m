function decision = compiledKernelMemoryReassessmentDecision(comparison,frozenSpeed)
% Apply the corrected issue #131 memory and integration gates.
arguments
    comparison (:,1) struct
    frozenSpeed (:,1) struct
end
required = ["status" "exactRetainedRatio" "operationPeakRSSRatio" "libraryIdentityPassed" "nativeExecutionPassed" "noFallback" "planCount" "persistentFullHermitianBytes"];
for name = required
    if ~all(arrayfun(@(item)isfield(item,name),comparison))
        error("WaveVortexModel:MemoryReassessmentDecision","Comparison records are missing %s.",name);
    end
end
if numel(comparison) ~= numel(frozenSpeed) || ~isequal(sort(string({comparison.id})),sort(string({frozenSpeed.id})))
    error("WaveVortexModel:MemoryReassessmentDecision","Corrected memory and frozen speed records must describe identical cases.");
end
complete = string({comparison.status})' == "complete";
coreChecks = complete & [comparison.libraryIdentityPassed]' & [comparison.nativeExecutionPassed]' & [comparison.noFallback]' & [comparison.planCount]' == 17 & [comparison.persistentFullHermitianBytes]' == 0;
correctnessPassed = ~isfield(frozenSpeed,"maximumRelativeError") || all([frozenSpeed.maximumRelativeError]' <= 1e-12);
coreComplete = ~isempty(comparison) && all(coreChecks) && correctnessPassed;
speedGate = all([frozenSpeed.compiledSpeedup]' >= 1.25);
memoryNonregression = coreComplete && all([comparison.exactRetainedRatio]' <= 1.03) && all([comparison.operationPeakRSSRatio]' <= 1.03);
decision = struct( ...
    "coreStatus",conditional(coreComplete,"CORE-COMPLETE","CORE-INCOMPLETE"), ...
    "memoryStatus",conditional(memoryNonregression,"MEMORY-NONREGRESSION","MEMORY-REGRESSION"), ...
    "integrationStatus",conditional(coreComplete&&speedGate&&memoryNonregression,"INTEGRATION-READY","INTEGRATION-NOT-READY"), ...
    "coreComplete",coreComplete, ...
    "frozenCorrectnessPassed",correctnessPassed, ...
    "frozenSpeedGatePassed",speedGate, ...
    "memoryNonregressionPassed",memoryNonregression, ...
    "minimumFrozenSpeedup",min([frozenSpeed.compiledSpeedup]), ...
    "maximumExactRetainedRatio",max([comparison.exactRetainedRatio]), ...
    "maximumOperationPeakRSSRatio",max([comparison.operationPeakRSSRatio]));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
