function [FqHat,FbHat,speed]=dealiasedAdvectionFourierTendency(self,physical)
% Return dealiased advection on compact nonzero horizontal Fourier entries.
% FqHat has Nz-2 interior rows (s^-2); FbHat has one surface row (m/s). The nonlinear
% product uses the same fine quadrature as dealiasedAdvection. Only its
% linear interpolation and projection move into horizontal Fourier space.
% Optional qInteriorHat and phiHat in physical share the current stage's
% reconstruction. Without them, the supplied physical grid fields are used.
% - Topic: Evolution internals
arguments (Input)
    self WVTransformFreeSurfaceQGDiffusion
    physical (1,1) struct
end
arguments (Output)
    FqHat (:,:) double
    FbHat (:,:) double
    speed (1,1) double
end
[advection,Fb,speed]=self.advectionOnQuadrature(physical,true);
values=self.verticalFourierGeometry_.transformFromSpatialDomainWithFourier(advection);
FqHat=-self.verticalNumerics.qFromQuadrature*values(:,self.klNonzero);
FbHat=self.spectralField(Fb);
end
