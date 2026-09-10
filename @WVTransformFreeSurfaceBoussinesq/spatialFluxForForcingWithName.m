function [u,v,w,eta] = spatialFluxForForcingWithName(self,name)
% Return one forcing's pressure-free hatted equation-source increments.
%
% Momentum increments are reference-variable accelerations. A prescribed
% physical source is mapped using the total surface geometry. Nonlinear
% advection returns the full mapped nonlinear excess beyond the analytical
% linear equations. No pressure or constraint response is included; use
% fluxForForcing for the corresponding resolved coefficient response.
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
