function diagnostics = nonlinearEnergy(self)
% Evaluate the full physical-volume kinetic, APE and surface energy.
%
% This total-state inventory uses the moving-volume Jacobian, parcel
% thermodynamics with upper-constant reference density, and g*ssh^2/2. It is distinct from
% the existing quadratic physicalEnergy and totalEnergy diagnostics. There
% is no additive component partition for this nonlinear inventory. Modal
% pressure in the RHS supplies a quadratic-order approximation; this energy
% is a diagnostic, not an exactly imposed finite-inventory invariant.
%
% - Topic: Analyze physical energy
% - Declaration: diagnostics = nonlinearEnergy()
% - Returns diagnostics: kineticEnergy,availablePotentialEnergy,surfaceEnergy,totalEnergy in m3 s-2, and endpoint roundoff diagnostics
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
fields = self.reconstructFields(["u","v","w","eta","ssh","z_physical"]);
thermodynamics = self.thermodynamicContext();
thermal = thermodynamics.evaluate(fields.z_physical,fields.eta,fields.ssh);
gamma = 1+fields.ssh/self.Lz;
weights = reshape(self.verticalQuadratureWeights,1,1,[])/(self.Nx*self.Ny);
kineticEnergy = .5*sum(weights.*gamma.*(fields.u.^2+fields.v.^2+fields.w.^2),'all');
availablePotentialEnergy = sum(weights.*gamma.*thermal.ape,'all');
surfaceEnergy = mean(thermal.energySurface,'all');
diagnostics = struct(kineticEnergy=kineticEnergy,availablePotentialEnergy=availablePotentialEnergy,surfaceEnergy=surfaceEnergy,totalEnergy=kineticEnergy+availablePotentialEnergy+surfaceEnergy,maximumLabelRoundoffAdjustment=thermal.maximumLabelRoundoffAdjustment,adjustedLabelCount=thermal.adjustedLabelCount);
end
