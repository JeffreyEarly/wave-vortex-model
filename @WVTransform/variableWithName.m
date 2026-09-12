function varargout = variableWithName(self,variableNames)
% Compute or retrieve one or more registered transform variables.
%
% Request several variables in one call to preserve their requested order:
%
% ```matlab
% [u,v,eta] = wvt.variableWithName('u','v','eta');
% ```
%
% - Topic: State variables
% - Declaration: varargout = variableWithName(variableNames)
% - Parameter variableNames: names of registered state variables
% - Returns varargout: state-variable arrays in the requested order
arguments
    self WVTransform {mustBeNonempty}
end
arguments (Repeating)
    variableNames char
end

while ~all(isKey(self.variableCache,variableNames))
    missingIndex = find(~isKey(self.variableCache,variableNames),1);
    missingName = variableNames{missingIndex};
    if ~isKey(self.operationVariableNameMap,missingName)
        error("No variable named '%s' is registered with this transform.",missingName)
    end
    annotation = self.operationVariableNameMap(missingName);
    operation = annotation.modelOp;
    % This operation supports partial outputs without changing the cache.
    if isa(operation,'WVInternal.FreeSurfaceFieldOperation')
        missing = string(variableNames(~isKey(self.variableCache,variableNames)));
        selected = intersect(missing,string({operation.outputVariables.name}),'stable');
        operation.computeSelected(self,selected);
    else
        self.performOperation(operation);
    end
end

varargout = cell(size(variableNames));
[varargout{:}] = self.fetchFromVariableCache(variableNames{:});
end
