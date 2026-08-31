function initFromNetCDFFile(wvt,ncfile,options)
% initialize the flow from a NetCDF file
%
% Restores the annotated coefficient families found in the file at the
% requested committed time.
% 
% This is intended to be used in conjunction with
% [`waveVortexTransformFromFile`](/classes/transforms/wvtransform/wavevortextransformfromfile.html)
% e.g.,
%
% ```matlab
% [wvt,ncfile] = WVTransform.waveVortexTransformFromFile('cyprus-eddy.nc');
% t = ncfile.readVariables('t');
% for iTime=1:length(t)
%     wvt.initFromNetCDFFile(ncfile,iTime=iTime)
%     // some analysis
% end
% ```
%
% Note that this method only lightly checks that you are reading from a
% file that is compatible with this transform! So be careful.
%
% See also the users guide for [reading and writing to
% file](/users-guide/reading-and-writing-to-file.html).
% 
% - Topic: Initial conditions
% - Declaration: initFromNetCDFFile(ncfile,options)
% - Parameter ncfile: a NetCDF file object
% - Parameter options.iTime: time index to initialize from; default `1`
% - Parameter options.shouldDisplayInit: display the restored representation; default `false`
arguments
    wvt WVTransform {mustBeNonempty}
    ncfile NetCDFFile {mustBeNonempty}
    options.iTime (1,1) double {mustBePositive} = 1
    options.shouldDisplayInit (1,1) = 0
end

wvt.t0 = ncfile.readVariables('t0');

coefficientNames = wvt.coefficientStateVariableNamesForPersistence();
stateVariableNames = coefficientNames;
[stateGroup,hasState] = groupContainingCompleteVariableSet(ncfile,stateVariableNames);
if ~hasState
    stateVariableNames = {'u','v','eta'};
    [stateGroup,hasState] = groupContainingCompleteVariableSet(ncfile,stateVariableNames);
end
if ~hasState
    stateVariableNames = {'A0'};
    [stateGroup,hasState] = groupContainingCompleteVariableSet(ncfile,stateVariableNames);
end
if ~hasState
    stateVariableNames = {};
    stateGroup = ncfile;
end

hasTimeDimension = 0;
if stateGroup.hasDimensionWithName('t') && stateGroup.hasVariableWithName('t')
    hasTimeDimension = 1;
    tDim = stateGroup.readVariables('t');
    committedCount = WVModelOutputGroup.committedRecordCountForGroup(stateGroup);
    tDim = reshape(tDim,[],1);
    tDim = tDim(1:committedCount);
    if isinf(options.iTime)
        iTime = committedCount;
        if iTime == 0
            error('WVTransform:NoCommittedRestartRecord','The selected output group contains no committed records.');
        end
    elseif options.iTime > length(tDim)
        error('Index out of bounds! There are %d time points in this file, you requested %d.',length(tDim),options.iTime);
    else
        iTime = options.iTime;
    end
    wvt.t = tDim(iTime);
else
    wvt.t = stateGroup.readVariables('t');
end

if ~isempty(coefficientNames) && all(ismember(coefficientNames,stateVariableNames))
    if hasTimeDimension == 1
        values = cell(1,length(coefficientNames));
        [values{:}] = stateGroup.readVariablesAtIndexAlongDimension('t',iTime,coefficientNames{:});
    else
        values = cell(1,length(coefficientNames));
        [values{:}] = stateGroup.readVariables(coefficientNames{:});
    end
    for iFamily = 1:length(coefficientNames)
        familyName = coefficientNames{iFamily};
        wvt.(familyName) = reshape(values{iFamily},size(wvt.(familyName)));
    end
    if options.shouldDisplayInit == 1
        fprintf('%s initialized from %s.\n',ncfile.attributes('WVTransform'),strjoin(coefficientNames,', '));
    end
elseif all(ismember({'u','v','eta'},stateVariableNames))
    if hasTimeDimension == 1
        [u,v,eta] = stateGroup.readVariablesAtIndexAlongDimension('t',iTime,'u','v','eta');
    else
        [u,v,eta] = stateGroup.readVariables('u','v','eta');
    end
    [wvt.Ap,wvt.Am,wvt.A0] = wvt.transformUVEtaToWaveVortex(u,v,eta);
    if options.shouldDisplayInit == 1
        fprintf('%s initialized from u, u, eta.\n',ncfile.attributes('WVTransform'));
    end
elseif isequal(stateVariableNames,{'A0'})
    if hasTimeDimension == 1
        wvt.A0 = reshape(stateGroup.readVariablesAtIndexAlongDimension('t',iTime,'A0'),wvt.spectralMatrixSize);
    else
        wvt.A0 = stateGroup.readVariables('A0');
    end
    if options.shouldDisplayInit == 1
        fprintf('%s initialized from A0.\n',ncfile.attributes('AnnotatedClass'));
    end
else
    warning('%s initialized without data.\n',ncfile.attributes('AnnotatedClass'));
end

end

function [group,found] = groupContainingCompleteVariableSet(ncfile,variableNames)
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
