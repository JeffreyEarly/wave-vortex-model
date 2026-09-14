function energy = totalEnergyOfFlowComponent(self,flowComponent)
% Evaluate physical energy of a family-selected thermal state in m3 s-2.
%
% All cross terms within the selection remain. Energies of disjoint thermal
% selectors need not add to the energy of their union.
%
% - Topic: Evaluate physical fields
% - Parameter flowComponent: component belonging to this transform
% - Returns energy: horizontally averaged, depth-integrated physical energy
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    flowComponent (1,1) WVFlowComponent
end
arguments (Output)
    energy (1,1) double
end
diagnostics=self.quadraticDiagnostics(state=self.coefficientState(flowComponent=flowComponent));
energy=diagnostics.totalEnergy;
end
