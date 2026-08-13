function decision = portableIntegrationDecision(fixedComparison,adaptiveEvidence)
% Apply the portable integration readiness decisions independently.
arguments
    fixedComparison (:,1) struct
    adaptiveEvidence (1,1) struct
end

complete = ~isempty(fixedComparison) && all(string({fixedComparison.status}) == "complete");
correct = complete && all([fixedComparison.maximumRelativeError] <= 1e-12);
identity = complete && all([fixedComparison.nativeIdentityPassed]) && all([fixedComparison.noFallback]) && all([fixedComparison.planCount] == 17) && all([fixedComparison.persistentFullHermitianBytes] == 0);
previewReady = correct && identity && all([fixedComparison.builtinSpeedup] >= 1.25);
orchestrationEfficient = correct && identity && all([fixedComparison.standaloneToCompiledMatlabRatio] <= 1.03);

adaptiveFields = ["status" "convergencePassed" "toleranceControlPassed" "rejectionPassed" "forcingSemanticsPassed" "continuousOutputPassed" "restartReconstructionPassed"];
adaptiveAvailable = all(isfield(adaptiveEvidence,adaptiveFields)) && string(adaptiveEvidence.status) == "complete" && all(cellfun(@(name)logical(adaptiveEvidence.(name)),cellstr(adaptiveFields(2:end))));

decision = struct( ...
    "runtimePreviewStatus",conditional(previewReady,"RUNTIME-PREVIEW-READY","RUNTIME-PREVIEW-NOT-READY"), ...
    "runtimePreviewReady",previewReady, ...
    "orchestrationStatus",conditional(orchestrationEfficient,"ORCHESTRATION-EFFICIENT","ORCHESTRATION-NOT-EFFICIENT"), ...
    "orchestrationEfficient",orchestrationEfficient, ...
    "adaptiveStatus",conditional(adaptiveAvailable,"ADAPTIVE-RK23-AVAILABLE","ADAPTIVE-RK23-NOT-AVAILABLE"), ...
    "adaptiveAvailable",adaptiveAvailable, ...
    "integrationSpeedThreshold",1.25, ...
    "orchestrationRatioThreshold",1.03, ...
    "correctnessTolerance",1e-12);
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end
