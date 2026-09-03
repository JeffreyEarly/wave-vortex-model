function [Fq,Fb,speed]=dealiasedAdvection(self,physical)
% Over-integrate only nonlinear advection, leaving ordinary forcing native.
% Physical-depth Galerkin projection replaces interpolation back to nodes.
% - Topic: Evolution internals
o=self.verticalNumerics; nf=length(o.zQuadrature);
[advection,Fb,speed]=self.advectionOnQuadrature(physical,false);
values=o.qFromQuadrature*reshape(permute(advection,[3 1 2]),nf,[]);
Fq=zeros(self.spatialMatrixSize);
Fq(:,:,2:end-1)=-permute(reshape(values,self.Nz-2,self.Nx,self.Ny),[2 3 1]);
end
