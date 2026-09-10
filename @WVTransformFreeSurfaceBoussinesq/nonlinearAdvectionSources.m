function [u,v,w,eta] = nonlinearAdvectionSources(self,stage)
% Return full mapped zero-pressure nonlinear excess on the hatted grid.
%
% Subtract the zero-pressure linear terms (f*v,-f*u,-N2*eta,w) from
% the full mapped RHS. Geometry and exact buoyancy are included; pressure,
% modal projection, weak solves, and prescribed forcing are not evaluated.
% A supplied shared stage has hatted, physical, and thermodynamics fields.
% Otherwise reconstruct once and use this transform's cached thermodynamics.
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    stage (1,1) struct = struct()
end
arguments (Output)
    u (:,:,:) double
    v (:,:,:) double
    w (:,:,:) double
    eta (:,:,:) double
end
derivative = struct(x=@(field)self.diffX(field),y=@(field)self.diffY(field),xi=@(field)self.diffZ(field));
if isempty(fieldnames(stage))
    spectral = self.reconstructSpectralState();
    for name = ["u","v","w","eta","ssh"]
        stage.hatted.(name) = self.transformToSpatialDomainWithFourier(spectral.(name));
    end
    stage.hatted.ssh = stage.hatted.ssh(:,:,end);
    stage.physical = WVInternal.freeSurfacePhysicalFields(stage.hatted,self.z,self.Lz,derivative.x(stage.hatted.ssh),derivative.y(stage.hatted.ssh));
    thermodynamics = self.thermodynamicContext();
    stage.thermodynamics = thermodynamics.evaluate(stage.physical.z,stage.hatted.eta,stage.hatted.ssh);
elseif ~all(isfield(stage,{'hatted','physical','thermodynamics'}))
    error('WVTransformFreeSurfaceBoussinesq:InvalidAdvectionStage','A shared advection stage must contain hatted, physical, and thermodynamics fields.');
end
zero = zeros(self.Nx,self.Ny,self.Nz);
full = WVInternal.freeSurfaceMappedTendency(stage.hatted,zero,stage.thermodynamics.buoyancy,self.z,self.Lz,self.f,self.rho0,derivative);
u = full.u-self.f*stage.hatted.v;
v = full.v+self.f*stage.hatted.u;
w = full.w+reshape(self.N2,1,1,[]).*stage.hatted.eta;
eta = full.eta-stage.hatted.w;
end
