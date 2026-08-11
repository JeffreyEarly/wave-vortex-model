function decision = compiledKernelDenseWriteDecision(comparisons)
% Apply the issue #127 common-size speed-or-memory adoption rule.
required = ["Nxyz" "isHydrostatic" "completeCallSpeedup" "maximumLiveRatio" "maximumRelativeError" "selectedScheduleExecuted"];
if ~all(isfield(comparisons,required)), error("WaveVortexBenchmark:DenseWriteDecisionFields","Issue #127 comparisons are missing required fields."); end
regressionPassed = all([comparisons.completeCallSpeedup] >= 1/1.03) && all([comparisons.maximumLiveRatio] <= 1.03);
correctnessPassed = all([comparisons.maximumRelativeError] <= 1e-12) && all([comparisons.selectedScheduleExecuted]);
qualifiedSize = "";
keys = string(arrayfun(@(item)sprintf('%dx%dx%d',item.Nxyz),comparisons,UniformOutput=false));
for key = unique(keys)
    selected = comparisons(keys==key);
    if numel(selected) ~= 2 || ~all(ismember([true false],[selected.isHydrostatic])), continue, end
    speedPassed = all([selected.completeCallSpeedup] >= 1.05);
    memoryPassed = all([selected.maximumLiveRatio] <= 0.95);
    if speedPassed || memoryPassed, qualifiedSize = string(key); break, end
end
adopted = qualifiedSize ~= "" && regressionPassed && correctnessPassed;
decision = struct("status",conditional(adopted,"CORE-ADOPT","CORE-REJECT"),"adopted",adopted,"qualifyingSize",qualifiedSize,"regressionPassed",regressionPassed,"correctnessPassed",correctnessPassed,"reason",conditional(adopted,"Both physical configurations passed the 5% complete-call speed-or-memory gate at "+qualifiedSize+".","No common size passed the 5% gate with correctness and the 3% regression limit."));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
