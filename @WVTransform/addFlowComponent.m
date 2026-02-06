function addFlowComponent(self,flowComponent)
% add a flow component
%
% - Topic: Flow components
arguments
    self WVTransform {mustBeNonempty}
    flowComponent (1,:) WVFlowComponent {mustBeNonempty}
end
for i=1:length(flowComponent)
    if all(flowComponent(i).maskAp(:) == self.totalFlowComponent.maskAp(:)) && all(flowComponent(i).maskAm(:) == self.totalFlowComponent.maskAm(:)) && all(flowComponent(i).maskA0(:) == self.totalFlowComponent.maskA0(:))
        error("You are attempting to add a flow component named " + flowComponent.name + " that is just the total flow component.");
    end
    keys = self.flowComponentNameMap.keys;
    vals = self.flowComponentNameMap.values;
    for iExisting = 1:numel(keys)
        if all(flowComponent(i).maskAp(:) == vals{iExisting}.maskAp(:)) && all(flowComponent(i).maskAm(:) == vals{iExisting}.maskAm(:)) && all(flowComponent(i).maskA0(:) == vals{iExisting}.maskA0(:))
            error("You are attempting to add a flow component named " + flowComponent.name + " that has the same masks as the existing flow component named " + vals{iExisting}.name);
        end
    end
    
    self.flowComponentNameMap{flowComponent(i).shortName} = flowComponent(i);

    variables = cellstr(self.maskableVariables);
    self.addOperation(self.operationForKnownVariable(variables{:},flowComponent=flowComponent(i)));
end
end