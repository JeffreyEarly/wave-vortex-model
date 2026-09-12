function [u,v,w,eta] = fullBoussinesqNonlinearReference(self,thermodynamics)
% Evaluate the manuscript -N-P sources on the hatted reference grid.
%
% Appendix C includes modal pressure in both P and the horizontal tendency
% H inside N_w. The complete linear operator cancels under projection onto
% the time-dependent basis; it is not added to these coefficient sources.
% Prescribed forcing is mapped separately by spatialFluxForForcingWithName.
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    thermodynamics (1,1) struct = WVInternal.freeSurfaceThermodynamics(self)
end
arguments (Output)
    u (:,:,:) double
    v (:,:,:) double
    w (:,:,:) double
    eta (:,:,:) double
end
spectral = fullBoussinesqSpectralReference(self);
hatted = struct();
for name = ["u","v","w","eta","ssh","p"]
    hatted.(name) = self.transformToSpatialDomainWithFourier(spectral.(name));
end
hatted.ssh = hatted.ssh(:,:,end);
physicalZ = reshape(self.z,1,1,[])+reshape(1+self.z/self.Lz,1,1,[]).*hatted.ssh;
thermal = thermodynamics.evaluateNonlinear(physicalZ,hatted.eta,hatted.ssh,self.N2);
derivative = struct(x=@(field)self.diffX(field),y=@(field)self.diffY(field),xi=@(field)self.diffZ(field));
terms = WVInternal.freeSurfaceNonlinearTerms(hatted,hatted.p,self.z,self.Lz,self.f,self.rho0,self.N2,thermal.buoyancyRemainder,derivative);
u = terms.source.u;
v = terms.source.v;
w = terms.source.w;
eta = terms.source.eta;
end
