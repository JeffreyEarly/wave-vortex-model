function [advection,Fb,speed]=advectionOnQuadrature(self,physical,shouldUseFourier)
% Evaluate the same nonlinear product on the same fine vertical quadrature.
o=self.verticalNumerics; geometry=self.verticalFourierGeometry_;
nf=length(o.zQuadrature);
if shouldUseFourier && isfield(physical,'qInteriorHat') && isfield(physical,'phiHat')
    % Linear vertical interpolation commutes with the horizontal transform.
    % Interpolate one streamfunction, not its two velocity components.
    qHat=o.qToQuadrature*physical.qInteriorHat;
    phiHat=o.phiToQuadrature*physical.phiHat;
    k=1i*self.kNonzero.'; l=1i*self.lNonzero.';
    u=spatial(-l.*phiHat); v=spatial(k.*phiHat);
    advection=u.*spatial(k.*qHat)+v.*spatial(l.*qHat);
else
    % Preserve arbitrary supplied grid fields, including unresolved modes.
    q=evaluate(o.qToQuadrature,physical.q(:,:,2:end-1));
    u=evaluate(o.phiToQuadrature,physical.u); v=evaluate(o.phiToQuadrature,physical.v);
    advection=u.*geometry.diffX(q)+v.*geometry.diffY(q);
end
speed=max(hypot(u,v),[],'all');
advection=advection-mean(advection,[1 2]);
boundary=physical.ub.*self.diffX(physical.b)+physical.vb.*self.diffY(physical.b);
Fb=-(boundary-mean(boundary,[1 2]));
    function field=spatial(values)
        padded=complex(zeros(nf,self.Nkl)); padded(:,self.klNonzero)=values;
        field=geometry.transformToSpatialDomainWithFourier(padded);
    end
    function fine=evaluate(matrix,field)
        values=matrix*reshape(permute(field,[3 1 2]),size(matrix,2),[]);
        fine=permute(reshape(values,nf,self.Nx,self.Ny),[2 3 1]);
    end
end
