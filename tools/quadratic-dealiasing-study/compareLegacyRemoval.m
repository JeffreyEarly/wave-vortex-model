function comparisons = compareLegacyRemoval(beforeFolder,afterFolder)
% Require exact new-policy scientific state and assessment parity after cleanup.
arguments (Input)
    beforeFolder (1,1) string
    afterFolder (1,1) string
end
beforeSummary = jsondecode(fileread(fullfile(beforeFolder,'summary.json')));
afterSummary = jsondecode(fileread(fullfile(afterFolder,'summary.json')));
comparisons = struct([]);
for policy = ["none","fixedFraction","effectiveBandwidth"]
    before = load(fullfile(beforeFolder,policy+"-scientific.mat"));
    after = load(fullfile(afterFolder,policy+"-scientific.mat"));
    a = beforeSummary.policies(string({beforeSummary.policies.policy})==policy);
    b = afterSummary.policies(string({afterSummary.policies.policy})==policy);
    row = struct(policy=policy,scientificFieldCount=numel(fieldnames(before.state)),scientificStateExactlyEqual=isequaln(before.state,after.state), ...
        assessmentExceptTimersExactlyEqual=isequaln(withoutTimers(before.assessment),withoutTimers(after.assessment)), ...
        beforeMedianSeconds=a.medianSeconds,afterMedianSeconds=b.medianSeconds, ...
        beforeFilteringSeconds=a.medianFilteringSeconds,afterFilteringSeconds=b.medianFilteringSeconds);
    comparisons = [comparisons;row]; %#ok<AGROW>
end
writelines(jsonencode(comparisons,PrettyPrint=true),fullfile(afterFolder,'comparison.json'));
assert(all([comparisons.scientificStateExactlyEqual]),'Cleanup changed scientific state.');
assert(all([comparisons.assessmentExceptTimersExactlyEqual]),'Cleanup changed assessment beyond named timers.');
disp(struct2table(comparisons));
end

function value = withoutTimers(value)
% Preserve every counter, limit, tolerance and scientific measurement.
timerNames = ["assessmentSeconds","waveConstructionSeconds","constructionSeconds","quadraticDealiasingSeconds"];
if isstruct(value)
    for i = 1:numel(value)
        for name = string(fieldnames(value)).'
            if ismember(name,timerNames)
                value(i).(name) = NaN;
            else
                value(i).(name) = withoutTimers(value(i).(name));
            end
        end
    end
elseif iscell(value)
    value = cellfun(@withoutTimers,value,UniformOutput=false);
elseif istable(value)
    for name = string(value.Properties.VariableNames)
        value.(name) = withoutTimers(value.(name));
    end
end
end
