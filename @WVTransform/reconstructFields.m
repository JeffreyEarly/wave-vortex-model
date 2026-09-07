function fields = reconstructFields(self,variableNames,options)
% Reconstruct named physical fields at the current transform time.
%
% The default implementation uses the existing model-specific operation
% factory, including optimized wave and balanced reconstruction paths.
% This call computes fields directly without changing coefficient state.
%
% - Topic: Evaluate physical fields
% - Declaration: fields = reconstructFields(variableNames,options)
% - Parameter variableNames: row of supported physical field names
% - Parameter options.flowComponent: one component of this transform; empty selects the full state
% - Returns fields: scalar structure of physical arrays keyed by requested name
arguments (Input)
    self (1,1) WVTransform
    variableNames (1,:) string {mustBeNonempty}
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    fields (1,1) struct
end

component = options.flowComponent;
if ~isempty(component) && (~isscalar(component) || component.wvt ~= self)
    error('WVTransform:InvalidComponent','Select one component belonging to this transform.')
end
fields = struct();
for name = variableNames
    operation = self.operationForKnownVariable(char(name),flowComponent=component);
    fields.(name) = operation.compute(self);
end
end
