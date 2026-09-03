function [Fq,Fb,speed]=dealiasedAdvection(self,physical)
% Over-integrate only nonlinear advection, leaving ordinary forcing native.
% Physical-depth Galerkin projection replaces interpolation back to nodes.
% - Topic: Evolution internals
o=self.verticalNumerics; geometry=self.verticalFourierGeometry_;
nf=length(o.zQuadrature);
q=evaluate(o.qToQuadrature,physical.q(:,:,2:end-1));
u=evaluate(o.phiToQuadrature,physical.u); v=evaluate(o.phiToQuadrature,physical.v);
speed=max(hypot(u,v),[],'all');
advection=u.*geometry.diffX(q)+v.*geometry.diffY(q);
advection=advection-mean(advection,[1 2]);
values=o.qFromQuadrature*reshape(permute(advection,[3 1 2]),nf,[]);
Fq=zeros(self.spatialMatrixSize);
Fq(:,:,2:end-1)=-permute(reshape(values,self.Nz-2,self.Nx,self.Ny),[2 3 1]);
boundary=physical.ub.*self.diffX(physical.b)+physical.vb.*self.diffY(physical.b);
Fb=-(boundary-mean(boundary,[1 2]));
    function fine=evaluate(matrix,field)
        values=matrix*reshape(permute(field,[3 1 2]),size(matrix,2),[]);
        fine=permute(reshape(values,nf,self.Nx,self.Ny),[2 3 1]);
    end
end
