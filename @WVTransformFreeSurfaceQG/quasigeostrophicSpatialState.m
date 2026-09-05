function [q,u,v,b,ub,vb,phiHat] = quasigeostrophicSpatialState(self)
% Reconstruct the physical state used by QG spatial forcing.
%
% Interior fields have shape `Nx × Ny × Nz`. Endpoint fields have shape
% `Nx × Ny × Ne`, with active endpoints in canonical surface-bottom order.
%
% - Topic: Transform coefficient state
% - Declaration: [q,u,v,b,ub,vb,phiHat] = quasigeostrophicSpatialState(self)
% - Returns q: interior QGPV
% - Returns u: interior zonal velocity
% - Returns v: interior meridional velocity
% - Returns b: active-endpoint anomaly
% - Returns ub: active-endpoint zonal velocity
% - Returns vb: active-endpoint meridional velocity
% - Returns phiHat: spectral streamfunction on the nonzero compact Fourier columns, Nz by NklNonzero
% - Developer: true
arguments
    self (1,1) WVTransformFreeSurfaceQG
end

psiHat = self.reconstructSpectralState();
qHat = complex(zeros(self.Nz,self.Nkl));
qHat(:,self.klNonzero) = self.apvF*self.Ag_q;
if nargout > 6, phiHat = psiHat(:,self.klNonzero); end
q = self.transformToSpatialDomainWithFourier(qHat);
u = self.transformToSpatialDomainWithFourier(-sqrt(-1)*reshape(self.l,1,[]).*psiHat);
v = self.transformToSpatialDomainWithFourier(sqrt(-1)*reshape(self.k,1,[]).*psiHat);

if self.activeEndpointCount == 0
    b = zeros(self.Nx,self.Ny,0);
    ub = zeros(self.Nx,self.Ny,0);
    vb = zeros(self.Nx,self.Ny,0);
    return
end

bNonzero = self.reconstructEndpointAnomalies(self.Ag_q,self.Ag_0);
bHat = complex(zeros(self.activeEndpointCount,self.Nkl));
bHat(:,self.klNonzero) = bNonzero;
endpointVerticalIndex = self.activeEndpoint;
endpointVerticalIndex(self.activeEndpoint == 1) = self.Nz;
endpointVerticalIndex(self.activeEndpoint == 2) = 1;
geometry = self.endpointGeometry();
b = geometry.transformToSpatialDomainWithFourier(bHat);
ub = u(:,:,endpointVerticalIndex);
vb = v(:,:,endpointVerticalIndex);
end
