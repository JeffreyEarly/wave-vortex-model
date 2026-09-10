function [pressure,diagnostics] = fullPressure(self)
% Recover instantaneous collocation pressure for the full mapped equations.
%
% The pressure anomaly is relative to the explicit C1 hydrostatic reference
% and obeys p(surface)/rho0=g*ssh-J(ssh). It includes registered prescribed
% momentum sources in their declared coordinates. This instantaneous
% diagnostic is not a modal constraint multiplier: a reduced trajectory
% additionally has projection and constraint-reaction errors.
%
% Boundary rows replace the pressure PDE. Diagnostics report interior and
% endpoint divergence separately; the latter is not enforced by the solve.
% Reference LU factors are reused and rebuilt lazily after file restoration.
%
% - Topic: Evaluate physical fields
% - Declaration: [pressure,diagnostics] = fullPressure()
% - Returns pressure: full pressure anomaly in Pa on the reference samples
% - Returns diagnostics: collocation solver diagnostics; internal pressure residuals use p/rho0, in m2 s-2
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
fields = self.reconstructFields(["u_hat","v_hat","w_hat","eta","ssh"]);
hatted = struct(u=fields.u_hat,v=fields.v_hat,w=fields.w_hat,eta=fields.eta,ssh=fields.ssh);
derivative = struct(x=@(value)self.diffX(value),y=@(value)self.diffY(value),xi=@(value)self.diffZ(value));
physical = WVInternal.freeSurfacePhysicalFields(hatted,self.z,self.Lz,self.diffX(hatted.ssh),self.diffY(hatted.ssh));
thermodynamics = self.thermodynamicContext();
thermal = thermodynamics.evaluate(physical.z,hatted.eta,hatted.ssh);
zero = zeros(self.Nx,self.Ny,self.Nz);
force = WVInternal.freeSurfaceMappedTendency(hatted,zero,thermal.buoyancy,self.z,self.Lz,self.f,self.rho0,derivative);
alpha = reshape(1+self.z/self.Lz,1,1,[]);
for forcing = self.spatialFluxForcing
    if isa(forcing,'WVNonlinearAdvection')
        % The full pressure-free equations above already contain advection.
        continue
    elseif isa(forcing,'WVPrescribedBoussinesqSource')
        [u,v,w,~] = forcing.addNonhydrostaticSpatialForcing(self,zero,zero,zero,zero);
        if forcing.sourceCoordinates=="physical"
            w = w-alpha.*(u.*self.diffX(hatted.ssh)+v.*self.diffY(hatted.ssh));
            u = physical.gamma.*u;
            v = physical.gamma.*v;
        end
        force.u = force.u+u; force.v = force.v+v; force.w = force.w+w;
    else
        error('WVTransform:UnsupportedNonlinearForcing','Full free-surface pressure does not support %s.',class(forcing))
    end
end
solver = self.pressureContext();
[pressure,diagnostics] = solver.solve(hatted.ssh,force,thermal.pressureSurface);
pressure = self.rho0*pressure;
diagnostics.referenceConvention = thermodynamics.referenceConvention;
diagnostics.maximumLabelRoundoffAdjustment = thermal.maximumLabelRoundoffAdjustment;
end
