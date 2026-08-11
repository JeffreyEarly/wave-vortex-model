function decision = compiledKernelPhaseOnceDecision(cases)
% Apply the issue #123 phase-once adoption gate to comparison records.
sizeKeys=string(arrayfun(@(item)sprintf('%dx%dx%d',item.Nxyz),cases,UniformOutput=false)); sizeKeys=sizeKeys(:); uniqueSizes=unique(sizeKeys)'; qualifyingSizes=strings(1,0);
for sizeKey=uniqueSizes
    selected=cases(sizeKeys==sizeKey);
    if numel(selected)==2&&numel(unique([selected.isHydrostatic]))==2&&all([selected.fivePercentSpeedPassed]), qualifyingSizes(end+1)=sizeKey; end %#ok<AGROW>
end
qualified=~isempty(qualifyingSizes)&&all([cases.correctnessPassed])&&all([cases.phaseCountPassed])&&all([cases.noSpeedRegression])&&all([cases.noMemoryRegression])&&all(string({cases.status})=="complete");
if qualified, outcome="QUALIFIED"; reason="Phase-once execution passed the 5% local-change gate at "+strjoin(qualifyingSizes,", ")+" without a correctness, storage, RSS, or regression failure.";
else, outcome="NOT QUALIFIED"; reason="Phase-once execution did not satisfy every correctness, phase-count, speed, and memory condition."; end
decision=struct("outcome",outcome,"qualified",qualified,"qualifyingSizes",qualifyingSizes,"reason",reason,"speedThreshold",1.05,"maximumRegression",0.03,"correctnessTolerance",1e-12);
end
