function tendency=projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
% Project physical QGPV and strict endpoint-displacement rates with the weak dual.
% Native source samples are interpolated to independent physical quadrature.
% - Topic: Project physical states and sources
% - Parameter Fq: real Nx-by-Ny-by-Nz QGPV tendency in s^-2
% - Parameter Fb: real Nx-by-Ny-by-2 endpoint tendency in m/s
% - Returns tendency: family-keyed coefficient rates
arguments
    self (1,1) WVTransformFreeSurfaceThermalQG
    Fq double {mustBeReal,mustBeFinite}
    Fb double {mustBeReal,mustBeFinite}
end
if ~isequal(size(Fq),[self.Nx self.Ny self.Nz]) || ~isequal(size(Fb),[self.Nx self.Ny 2])
    error('WV:ThermalFieldShape','Supply native QGPV and two-endpoint physical tendencies.');
end
q=self.transformFromSpatialDomainWithFourier(Fq); b=self.endpointGeometry().transformFromSpatialDomainWithFourier(Fb);
meanIndex=find(hypot(self.k,self.l)==0,1);
if max(abs(q(:,meanIndex)))>1e-25+1e-12*max(abs(q),[],'all') || max(abs(b(:,meanIndex)))>1e-20+1e-12*max(abs(b),[],'all')
    error('WV:ThermalMeanSource','Nonzero-mean external sources are not supported; no mean tendency was discarded.');
end
if isempty(self.sourcePairing_)
    [x,w]=legpts(self.assemblyQuadratureCount); z=self.Lz*(x-1)/2; w=w(:)*self.Lz/2;
    r=WVInternal.thermalPolynomialFields(z,self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
    if self.inverseScale==0, targets=1+2*z/self.Lz; else, targets=1+2*expm1(z*self.inverseScale)/(-expm1(-self.Lz*self.inverseScale)); end
    nodes=-cos(pi*(0:self.Nz-1)'/(self.Nz-1));
    self.sourcePairing_=r.psi'*(w.*WVInternal.thermalInterpolation(nodes,targets));
end
tendency=WVInternal.projectThermalWeak(self,self.sourcePairing_*q(:,self.klNonzero),b(:,self.klNonzero));
end
