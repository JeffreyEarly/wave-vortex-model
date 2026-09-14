function [group,found] = groupContainingCompleteVariableSet(ncfile,variableNames)
% Locate one complete local variable set using the shared restart contract.
% This worker preserves ambiguity and local-time checks for every reader.
group = [];
found = false;
if isempty(variableNames)
    return
end
candidates = groupTree(ncfile);
isMatching = false(length(candidates),1);
for iGroup = 1:length(candidates)
    candidate = candidates{iGroup};
    hasVariables = true;
    for iVariable = 1:length(variableNames)
        if strlength(candidate.groupPath) == 0
            localPath = string(variableNames{iVariable});
        else
            localPath = candidate.groupPath + "/" + string(variableNames{iVariable});
        end
        hasVariables = hasVariables && any(ncfile.variablePathsWithName(variableNames{iVariable}) == localPath);
    end
    if hasVariables
        isMatching(iGroup) = true;
    end
end
matchingIndices = find(isMatching);
if length(matchingIndices) > 1
    error('WVTransform:AmbiguousRestartState','A restart file contains %d complete copies of the state variables %s.',length(matchingIndices),strjoin(variableNames,', '));
elseif isempty(matchingIndices)
    return
end
group = candidates{matchingIndices};
found = true;
if strlength(group.groupPath) > 0 && ~localVariableExists(ncfile,group,'t')
    error('WVTransform:MissingRestartTime','The NetCDF group containing the restart state does not contain a local time coordinate.');
end
end

function candidates = groupTree(group)
candidates = {group};
for iChild = 1:length(group.groups)
    candidates = [candidates,groupTree(group.groups(iChild))]; %#ok<AGROW>
end
end

function tf = localVariableExists(ncfile,group,name)
if strlength(group.groupPath) == 0
    localPath = string(name);
else
    localPath = group.groupPath + "/" + string(name);
end
tf = any(ncfile.variablePathsWithName(name) == localPath);
end
