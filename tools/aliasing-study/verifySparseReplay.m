function report = verifySparseReplay(denseDirectory,replayDirectory,scoreDirectory)
% Compare every actually replayed pair against the saved dense reference.
arguments
    denseDirectory (1,1) string
    replayDirectory (1,1) string
    scoreDirectory (1,1) string
end
dense=load(fullfile(denseDirectory,'products.mat'),'raw','rows','summary');
replay=load(fullfile(replayDirectory,'products.mat'),'raw','rows','summary');
scoring=load(fullfile(scoreDirectory,'scores.mat'),'errors','selection','evaluations');
assert(isequal(dense.summary.configuration,replay.summary.configuration),'Replay configuration differs from the dense case.');
keyColumns=["interaction","inputA","inputB","output","channel"];
[found,indices]=ismember(replay.rows(:,keyColumns),dense.rows(:,keyColumns));
assert(all(found),'A replay product group is missing from the dense survey.');
maximumErrorDifference=0; comparisons=0;
for r=1:height(replay.rows)
    a=replay.raw{r}; b=dense.raw{indices(r)};
    keysA=[a.positionA;a.positionB;a.signA;a.signB].';
    keysB=[b.positionA;b.positionB;b.signA;b.signB].';
    [found,pairs]=ismember(keysA,keysB,'rows');
    assert(all(found),'A replayed mode pair is absent from the dense survey.');
    difference=abs(double(a.error)-double(b.error(:,pairs)));
    maximumErrorDifference=max(maximumErrorDifference,max(difference,[],'all'));
    comparisons=comparisons+numel(difference);
end
policy=replay.summary.policy;
if policy=="fixed", column=3; elseif policy=="targeted", column=4; else, error('WVStudy:InvalidReplay','Use a fixed or targeted replay.'); end
prefix=readtable(fullfile(replayDirectory,'sampled-prefixes.csv'));
maximumPrefixDifference=max(abs(prefix.sampledQuadraticError-scoring.errors(:,column)));
assert(maximumErrorDifference<1e-7 && maximumPrefixDifference<1e-7,'Actual sparse replay differs from the virtual policy calculation.');
assert(replay.summary.nonzeroProductEvaluations==scoring.evaluations(end,column),'Measured sparse evaluation count differs from the predeclared plan.');
assert(replay.summary.referencesStable==dense.summary.referencesStable && replay.summary.fixedFamiliesGramAccepted==dense.summary.fixedFamiliesGramAccepted,'Replay scientific status differs from the dense case.');
report=struct(policy=policy,coefficientErrorComparisons=comparisons,maximumErrorDifference=maximumErrorDifference,maximumPrefixDifference=maximumPrefixDifference,status="passed");
fid=fopen(fullfile(replayDirectory,'replay-verification.json'),'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
disp(report)
end
