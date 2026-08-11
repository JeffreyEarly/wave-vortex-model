function decision = compiledKernelModalVectorizationDecision(cases)
% Apply the issue #126 contained-change speed-or-memory gate.
sizeKeys = string(arrayfun(@(item)sprintf('%dx%dx%d',item.Nxyz),cases,UniformOutput=false));
qualifyingSizes = strings(1,0);
qualifyingMechanisms = strings(1,0);
for sizeKey = unique(sizeKeys(:))'
    selected = cases(sizeKeys==sizeKey);
    if numel(selected)~=2 || numel(unique([selected.isHydrostatic]))~=2, continue, end
    speedPassed = all([selected.speedup]>=1.10);
    memoryPassed = all([selected.exactStorageRatio]<=0.90) && all([selected.peakRSSRatio]<=0.90);
    if speedPassed || memoryPassed
        qualifyingSizes(end+1) = sizeKey; %#ok<AGROW>
        qualifyingMechanisms(end+1) = conditional(speedPassed,"speed","memory"); %#ok<AGROW>
    end
end
commonPassed = all(string({cases.status})=="complete") && all([cases.correctnessPassed]) && all([cases.implementationExecuted]) && all([cases.noSpeedRegression]) && all([cases.noMemoryRegression]);
qualified = commonPassed && ~isempty(qualifyingSizes);
if qualified
    outcome = "QUALIFIED";
    reason = "The cumulative candidate passed the 10% "+strjoin(qualifyingMechanisms,"/")+" gate at "+strjoin(qualifyingSizes,", ")+" without a correctness or greater-than-3% regression failure.";
else
    outcome = "NOT QUALIFIED";
    reason = "No common hydrostatic/nonhydrostatic size passed the 10% speed-or-memory gate with all correctness and regression conditions.";
end
decision = struct("outcome",outcome,"qualified",qualified,"qualifyingSizes",qualifyingSizes,"qualifyingMechanisms",qualifyingMechanisms,"reason",reason,"speedThreshold",1.10,"memoryThreshold",0.90,"maximumRegression",0.03,"correctnessTolerance",1e-12);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end
