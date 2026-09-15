function comparison = compareConstructionOptimizationStudy(baselineFolder,candidateFolder)
% Compare matched study outputs, including exact scientific and report parity.
arguments (Input)
    baselineFolder (1,1) string
    candidateFolder (1,1) string
end
baselineTiming = jsondecode(fileread(fullfile(baselineFolder,"timing.json")));
candidateTiming = jsondecode(fileread(fullfile(candidateFolder,"timing.json")));
baseline = load(fullfile(baselineFolder,"scientific-result.mat"));
candidate = load(fullfile(candidateFolder,"scientific-result.mat"));
comparison = struct(baselineMedianSeconds=baselineTiming.medianSeconds,candidateMedianSeconds=candidateTiming.medianSeconds);
comparison.secondsSaved = comparison.baselineMedianSeconds-comparison.candidateMedianSeconds;
comparison.percentReduction = 100*comparison.secondsSaved/comparison.baselineMedianSeconds;
comparison.speedup = comparison.baselineMedianSeconds/comparison.candidateMedianSeconds;
comparison.scientificStateExactlyEqual = isequaln(baseline.state,candidate.state);
comparison.assessmentExceptTimingExactlyEqual = isequaln(withoutTiming(baseline.assessment),withoutTiming(candidate.assessment));
writelines(jsonencode(comparison,PrettyPrint=true),fullfile(candidateFolder,"comparison.json"));
assert(comparison.scientificStateExactlyEqual,'Scientific state changed.');
assert(comparison.assessmentExceptTimingExactlyEqual,'Assessment changed beyond elapsed timing.');

baseline = load(fullfile(baselineFolder,"profile.mat"));
candidate = load(fullfile(candidateFolder,"profile.mat"));
% Function identity includes absolute paths. Match identical files across the
% two worktrees without modifying either stored profile; moved lines remain
% secondary evidence because their line numbers need not identify the same work.
for name = ["completeName","fileName"]
    baseline.analysis.functionMetrics.(name) = replace(baseline.analysis.functionMetrics.(name),baselineTiming.wvmRoot,candidateTiming.wvmRoot);
    baseline.analysis.functionMetrics.(name) = replace(baseline.analysis.functionMetrics.(name),baselineTiming.internalModesRoot,candidateTiming.internalModesRoot);
end
baseline.analysis.lineMetrics.fileName = replace(baseline.analysis.lineMetrics.fileName,baselineTiming.wvmRoot,candidateTiming.wvmRoot);
baseline.analysis.lineMetrics.fileName = replace(baseline.analysis.lineMetrics.fileName,baselineTiming.internalModesRoot,candidateTiming.internalModesRoot);
profiles = compareProfileHotspots(baseline.analysis,candidate.analysis,projectRoots=[string(candidateTiming.wvmRoot),string(candidateTiming.internalModesRoot)]);
writetable(profiles.functionDiffs,fullfile(candidateFolder,"profile-function-diff.csv"));
comparison.baselineProfileSeconds = baseline.analysis.elapsedTime;
comparison.candidateProfileSeconds = candidate.analysis.elapsedTime;
writelines(jsonencode(comparison,PrettyPrint=true),fullfile(candidateFolder,"comparison.json"));
disp(comparison)
end

function value = withoutTiming(value)
% Preserve all counters and scientific evidence, ignoring only named timers.
if isstruct(value)
    for index = 1:numel(value)
        for name = string(fieldnames(value)).'
            if ismember(name,["assessmentSeconds","waveConstructionSeconds","constructionSeconds"])
                value(index).(name) = NaN;
            else
                value(index).(name) = withoutTiming(value(index).(name));
            end
        end
    end
elseif iscell(value)
    value = cellfun(@withoutTiming,value,UniformOutput=false);
end
end
