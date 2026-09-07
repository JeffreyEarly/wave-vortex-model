function state = coefficientState(self,options)
% Copy the canonical coefficient families, optionally selecting a component.
%
% Arrays retain their independent shapes, numeric domains, and reference
% time. Selection does not advance wave phases or mutate the transform.
%
% - Topic: Inspect wave-vortex coefficients
% - Declaration: state = coefficientState(options)
% - Parameter options.flowComponent: selector belonging to this transform; empty selects the full state
% - Returns state: scalar structure keyed in coefficient-annotation order
arguments (Input)
    self (1,1) WVTransform
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    state (1,1) struct
end

component = options.flowComponent;
if ~isempty(component) && (~isscalar(component) || component.wvt ~= self)
    error('WVTransform:InvalidComponent','Select one component belonging to this transform.')
end
if ~isempty(component), masks = component.coefficientMasks; end
state = struct();
for annotation = self.coefficientStateAnnotations()
    name = annotation.name;
    value = self.(name);
    if ~isempty(component)
        mask = masks.(name);
        if ~isscalar(mask) && ~isequal(size(mask),size(value))
            error('WVTransform:InvalidComponentMask','Mask %s must be scalar or exactly the coefficient-family shape.',name)
        end
        value = value.*mask;
    end
    state.(name) = value;
end
end
