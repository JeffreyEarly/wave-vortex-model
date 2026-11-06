function tendency = projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
% Project physical QG tendencies into canonical coefficient families.
%
% The physical APV F projection functional gives `Ag_q` from interior
% QGPV. The active-endpoint tendency remaining after that APV response
% determines `Ag_0`.
% Periodic horizontal advection gives the horizontal-mean `Amda` family an
% exact zero tendency.
%
% - Topic: Transform coefficient state
% - Declaration: tendency = projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
% - Parameter Fq: physical QGPV tendency with shape `Nx × Ny × Nz`
% - Parameter Fb: endpoint-anomaly tendency with shape `Nx × Ny × Ne`
% - Returns tendency: family-keyed coefficient tendency
% - Developer: true
arguments
    self (1,1) WVTransformFreeSurfaceQG
    Fq double
    Fb double
end

if size(Fq,1) ~= self.Nx || size(Fq,2) ~= self.Ny || size(Fq,3) ~= self.Nz
    error('WVTransformFreeSurfaceQG:InvalidQGPTendencyShape','Fq must have shape Nx x Ny x Nz.');
end
if size(Fb,1) ~= self.Nx || size(Fb,2) ~= self.Ny || size(Fb,3) ~= self.activeEndpointCount
    error('WVTransformFreeSurfaceQG:InvalidEndpointTendencyShape','Fb must have shape Nx x Ny x activeEndpointCount.');
end

FqHat = self.transformFromSpatialDomainWithFourier(Fq);
if self.activeEndpointCount > 0
    geometry = self.endpointGeometry();
    FbHat = geometry.transformFromSpatialDomainWithFourier(Fb);
else
    FbHat = complex(zeros(0,self.Nkl));
end
Ag_q = self.apvFProjection*FqHat(:,self.klNonzero);
Ag_0 = self.zeroAPVCoefficientsFromEndpoints(Ag_q,FbHat(:,self.klNonzero));
tendency = struct('Ag_q',Ag_q,'Ag_0',Ag_0,'Amda',zeros(size(self.Amda)));
end
