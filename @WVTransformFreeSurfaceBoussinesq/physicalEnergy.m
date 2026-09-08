function diagnostics = physicalEnergy(self,options)
% Evaluate positive physical energy including every selected cross term.
%
% Energy is the horizontal average of one half the depth integral of
% u^2+v^2+w^2+N2*eta^2 plus g*ssh^2/2, per unit reference density.
% Units are m3 s-2. Selected balanced subfamilies generally have cross terms;
% adding their separate energies does not recover the full inventory.
%
% - Topic: Analyze physical energy
% - Declaration: diagnostics = physicalEnergy(options)
% - Parameter options.flowComponent: component of this transform; empty selects all
% - Returns diagnostics: kineticEnergy,interiorPotentialEnergy,surfacePotentialEnergy,totalEnergy
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    diagnostics (1,1) struct
end
fields = self.reconstructSpectralState(flowComponent=options.flowComponent);
% Parseval: compact nonzero columns carry both conjugates, the mean once.
factor = ones(1,self.Nkl); factor(self.k==0 & self.l==0)=.5;
w = self.verticalQuadratureWeights;
kineticEnergy = sum(factor.*sum(w.*(abs(fields.u).^2+abs(fields.v).^2+abs(fields.w).^2),1));
interiorPotentialEnergy = sum(factor.*sum((w.*self.N2).*abs(fields.eta).^2,1));
surfacePotentialEnergy = self.g*sum(factor.*abs(fields.ssh(end,:)).^2);
diagnostics = struct(kineticEnergy=kineticEnergy,interiorPotentialEnergy=interiorPotentialEnergy,surfacePotentialEnergy=surfacePotentialEnergy,totalEnergy=kineticEnergy+interiorPotentialEnergy+surfacePotentialEnergy);
end
