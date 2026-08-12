function decision = compiledMemoryRefinementDecision(comparison)
% Classify the speed-neutral compiled-preview memory reassessment.
arguments
    comparison (:,1) struct
end

required = ["candidateRelativeToBaselineTime" "candidateSpeedup" "maximumRelativeError" "candidateExactRetainedRatio" "candidateOperationPeakRSSRatio" "exactRetainedReduction" "requiredExactRetainedReduction" "libraryIdentityPassed" "nativeExecutionPassed" "noFallback" "lifecyclePassed" "planCount" "persistentFullHermitianBytes"];
if isempty(comparison) || ~all(isfield(comparison,required))
    error("WaveVortexBenchmark:InvalidMemoryRefinementComparison","Memory-refinement comparison records are incomplete.");
end

speedNeutralPassed = all([comparison.candidateRelativeToBaselineTime] <= 1.03);
speedFloorPassed = all([comparison.candidateSpeedup] >= 1.25);
correctnessPassed = all([comparison.maximumRelativeError] <= 1e-12);
identityPassed = all([comparison.libraryIdentityPassed]) && all([comparison.nativeExecutionPassed]) && all([comparison.noFallback]);
lifecyclePassed = all([comparison.lifecyclePassed]) && all([comparison.planCount] == 17) && all([comparison.persistentFullHermitianBytes] == 0);
mandatoryPassed = speedNeutralPassed && speedFloorPassed && correctnessPassed && identityPassed && lifecyclePassed;
memoryQualified = mandatoryPassed && all([comparison.candidateExactRetainedRatio] <= 1.03) && all([comparison.candidateOperationPeakRSSRatio] <= 1.03);
memoryImproved = mandatoryPassed && all([comparison.exactRetainedReduction] >= [comparison.requiredExactRetainedReduction]) && all([comparison.candidateOperationPeakRSSRatio] <= 1.03);

if memoryQualified
    status = "MEMORY-QUALIFIED";
elseif memoryImproved
    status = "MEMORY-IMPROVED";
else
    status = "MEMORY-UNCHANGED";
end
decision = struct( ...
    "status",status, ...
    "previewAvailable",true, ...
    "speedNeutralPassed",speedNeutralPassed, ...
    "speedFloorPassed",speedFloorPassed, ...
    "correctnessPassed",correctnessPassed, ...
    "identityPassed",identityPassed, ...
    "lifecyclePassed",lifecyclePassed, ...
    "mandatoryPassed",mandatoryPassed, ...
    "memoryQualified",memoryQualified, ...
    "memoryImproved",memoryImproved);
end
