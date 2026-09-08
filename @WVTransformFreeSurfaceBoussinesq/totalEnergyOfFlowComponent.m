function energy = totalEnergyOfFlowComponent(self,flowComponent)
% Evaluate the physical energy of a selected resolved Boussinesq state.
%
% Cross terms inside the selected state are retained. Energies of disjoint
% coefficient selectors need not sum to the energy of their union.
%
% - Topic: Evaluate physical fields
% - Declaration: energy = totalEnergyOfFlowComponent(flowComponent)
% - Parameter flowComponent: one component belonging to this transform
% - Returns energy: positive physical energy in m3 s-2
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    flowComponent (1,1) WVFlowComponent
end
arguments (Output)
    energy (1,1) double
end
diagnostics = self.physicalEnergy(flowComponent=flowComponent);
energy = diagnostics.totalEnergy;
end
