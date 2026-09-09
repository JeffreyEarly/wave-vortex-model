function addFlowComponent(self,flowComponent)
% Register QG component fields, including interior displacement.
%
% - Topic: Flow components
% - Declaration: addFlowComponent(flowComponent)
% - Parameter flowComponent: one or more components owned by this transform
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    flowComponent (1,:) WVFlowComponent {mustBeNonempty}
end
addFlowComponent@WVTransform(self,flowComponent);
for component = flowComponent
    self.addOperation(self.operationForKnownVariable('eta_i',flowComponent=component));
end
end
