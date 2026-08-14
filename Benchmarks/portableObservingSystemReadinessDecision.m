function decision = portableObservingSystemReadinessDecision(compatibility,noOutputComparisons)
% Classify the portable observing-system compatibility evidence.
arguments
    compatibility (1,:) struct
    noOutputComparisons (1,:) struct
end

requiredObservers = ["WVCoefficients" "WVEulerianFields" "WVMooring" "WVLagrangianParticles" "WVTracer"];
requiredDirections = ["runtime-to-matlab" "matlab-to-runtime"];
complete = true;
passedObservers = strings(0,1);
for observer = requiredObservers
    for direction = requiredDirections
        match = compatibility(string({compatibility.observer}) == observer & string({compatibility.direction}) == direction);
        complete = complete && isscalar(match) && match.passed;
        if isscalar(match) && match.passed
            passedObservers(end+1,1) = observer; %#ok<AGROW>
        end
    end
end
regressionPassed = ~isempty(noOutputComparisons) && all([noOutputComparisons.candidateNoOutputRatio] <= 1.03) && all([noOutputComparisons.correctnessPassed]);
allGatesPassed = complete && regressionPassed;
if allGatesPassed
    status = "FULL-OUTPUT-COMPATIBLE";
elseif ~isempty(unique(passedObservers))
    status = "PARTIAL";
else
    status = "NOT-READY";
end
decision = struct("status",status,"allBuiltinsPassed",complete,"noOutputRegressionPassed",regressionPassed,"passedObserverCount",numel(unique(passedObservers)),"requiredObserverCount",numel(requiredObservers));
end
