function [u,v,w,eta] = spatialFluxForForcingWithName(self,name)
% Return one forcing's hatted equation-source increments.
%
% Physical momentum sources are mapped using the total surface geometry.
% Their vertical coordinate coupling accounts for the source contribution
% to H in Appendix C; nonlinear advection evaluates H without forcing.
% Reference sources already specify hatted accelerations and are unchanged.
% Nonlinear advection includes -N-P using the reconstructed modal pressure.
% fluxForForcing applies the source projector to these same increments.
%
% - Topic: Project physical sources
% - Declaration: [u,v,w,eta] = spatialFluxForForcingWithName(name)
% - Parameter name: registered forcing name
% - Returns u: hatted zonal acceleration, Nx by Ny by Nz, m s-2
% - Returns v: hatted meridional acceleration, Nx by Ny by Nz, m s-2
% - Returns w: hatted vertical acceleration, Nx by Ny by Nz, m s-2
% - Returns eta: total-displacement source, Nx by Ny by Nz, m s-1
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    name (1,1) string
end
forcing=self.forcingWithName(name);
zero=zeros(self.Nx,self.Ny,self.Nz);
[u,v,w,eta]=forcing.addNonhydrostaticSpatialForcing(self,zero,zero,zero,zero);
if isa(forcing,'WVPrescribedBoussinesqSource') && forcing.sourceCoordinates=="physical"
    ssh=self.ssh; gamma=1+ssh/self.Lz; alpha=reshape(1+self.z/self.Lz,1,1,[]);
    w=w-alpha.*(u.*self.diffX(ssh)+v.*self.diffY(ssh));
    u=gamma.*u; v=gamma.*v;
end
end
