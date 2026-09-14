function [tendency,speed,diagnostics]=thermalNonlinearKernel(w,maps)
% Evaluate dealiased products and project before any native-grid resampling.
% Horizontally uniform MDA has no horizontal gradient or velocity.
% - Topic: Developer utilities
timer=tic;
C=complex(zeros(size(w.Ath)));
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p;
    C(:,columns)=w.thermalToPolynomial(:,:,p)*w.Ath(:,columns);
end
k=w.k(w.klNonzero).'; l=w.l(w.klNonzero).';
psi=maps.psi*C; q=maps.qZero*C-(k.^2+l.^2).*psi;
epsi=maps.endpointPsi*C; b=maps.endpointAnomaly*C;
[u,v,qx,qy]=fields(maps.geometry,psi,q,k,l,w.klNonzero);
[ub,vb,bx,by]=fields(maps.endpointGeometry,epsi,b,k,l,w.klNonzero);
reconstructionSeconds=toc(timer); timer=tic;
Fq=-(u.*qx+v.*qy); Fb=-(ub.*bx+vb.*by);
qMean=mean(Fq,[1 2]); bMean=mean(Fb,[1 2]);
qScale=max(abs(u.*qx)+abs(v.*qy),[],'all'); bScale=max(abs(ub.*bx)+abs(vb.*by),[],'all');
if max(abs(qMean),[],'all')>1e-12*max(qScale,realmin) || max(abs(bMean),[],'all')>1e-12*max(bScale,realmin)
    error('WV:ThermalJacobianMean','Nonlinear horizontal mean is larger than roundoff; inspect the Fourier product policy.');
end
Fq=Fq-qMean; Fb=Fb-bMean;
speed=max([max(hypot(u,v),[],'all'),max(hypot(ub,vb),[],'all')]);
productSeconds=toc(timer); timer=tic;
qHat=maps.geometry.transformFromSpatialDomainWithFourier(Fq);
bHat=maps.endpointGeometry.transformFromSpatialDomainWithFourier(Fb);
tendency=WVInternal.projectThermalWeak(w,maps.pairing*qHat(:,w.klNonzero),bHat(:,w.klNonzero));
projectionSeconds=toc(timer);
if nargout>2
    diagnostics=struct(reconstructionSeconds=reconstructionSeconds,productSeconds=productSeconds,projectionSeconds=projectionSeconds, ...
        qMean=max(abs(qMean),[],'all'),endpointMean=reshape(abs(bMean),1,[]),qSourceMaximum=qScale,endpointSourceMaximum=bScale, ...
        scratchBytesEstimate=8*8*w.Nx*w.Ny*(maps.count+2)+16*5*w.Nkl*(maps.count+2)+16*2*numel(w.Ath), ...
        quadratureCount=maps.count,radiusGroups=numel(w.khUnique));
end
end
function [u,v,ax,ay]=fields(geometry,psi,a,k,l,indices)
hat=complex(zeros(size(psi,1),geometry.Nkl));
hat(:,indices)=-1i*l.*psi; u=geometry.transformToSpatialDomainWithFourier(hat);
hat(:,indices)=1i*k.*psi; v=geometry.transformToSpatialDomainWithFourier(hat);
hat(:,indices)=1i*k.*a; ax=geometry.transformToSpatialDomainWithFourier(hat);
hat(:,indices)=1i*l.*a; ay=geometry.transformToSpatialDomainWithFourier(hat);
end
