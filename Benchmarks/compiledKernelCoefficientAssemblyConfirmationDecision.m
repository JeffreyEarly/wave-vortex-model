function decision = compiledKernelCoefficientAssemblyConfirmationDecision(cases)
% Apply the clean-reconstruction confirmation gates for issue #126.
arguments
    cases (:,1) struct
end

correctnessPassed = all([cases.maximumRelativeError]<=1e-12) && all([cases.lifecyclePassed]);
descriptorPassed = all([cases.descriptorReduction]>=0.10);
noRegression = all([cases.completeCallSpeedup]>=1/1.03);
sizes = unique(string(arrayfun(@(item)sprintf("%dx%dx%d",item.Nxyz),cases,UniformOutput=false)));
qualifyingSizes = strings(0,1);
for sizeId = sizes'
    selected = cases(string(arrayfun(@(item)sprintf("%dx%dx%d",item.Nxyz),cases,UniformOutput=false))==sizeId);
    if numel(selected)==2 && any([selected.isHydrostatic]) && any(~[selected.isHydrostatic]) && all([selected.completeCallSpeedup]>=1.05)
        qualifyingSizes(end+1,1) = sizeId; %#ok<AGROW>
    end
end
confirmed = correctnessPassed && descriptorPassed && noRegression && ~isempty(qualifyingSizes);
decision = struct( ...
    "status",conditional(confirmed,"CORE-ADOPT-CONFIRMED","CORE-ADOPT-NOT-CONFIRMED"), ...
    "confirmed",confirmed, ...
    "correctnessPassed",correctnessPassed, ...
    "descriptorPassed",descriptorPassed, ...
    "noRegression",noRegression, ...
    "qualifyingSizes",qualifyingSizes, ...
    "reason",conditional(confirmed,"The clean reconstruction preserves the experimental adoption result.","The clean reconstruction did not reproduce every confirmation gate."));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
