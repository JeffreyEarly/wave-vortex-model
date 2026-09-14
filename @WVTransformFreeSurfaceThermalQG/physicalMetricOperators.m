function operators = physicalMetricOperators(self)
% Build physical quadrature maps and full quadratic metrics from stored arrays.
%
% Thermal pages retain all cross terms. Their factors map Ath to weighted
% physical fields; contractions use these factors to avoid squaring the
% conditioning of nearly cancelling source or null directions. Energy uses
% total displacement, while physical buoyancy uses interior displacement.
% MDA maps interpolate the authoritative native arrays in their WKB coordinate.
% These immutable caches require no scientific mode solve and are not saved.
%
% - Topic: Inspect scientific operators
% - Returns operators: quadrature, reconstruction maps, factors and Gram matrices
% - Developer: true
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
end
arguments (Output)
    operators (1,1) struct
end
if ~isempty(self.physicalMetricOperators_)
    operators=self.physicalMetricOperators_; return
end
[z,weights]=legpts(max(self.assemblyQuadratureCount,2*self.Nz+1));
z=self.Lz*(z-1)/2; weights=weights(:)*self.Lz/2;
r=WVInternal.thermalPolynomialFields(z,self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
e=WVInternal.thermalPolynomialFields([0;-self.Lz],self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
N2=self.N20*exp(2*self.inverseScale*z);
pages=cell(numel(self.khUnique),1); reconstruction=cell(size(pages));
for p=1:numel(pages)
    C=self.thermalToPolynomial(:,:,p); kh=self.khUnique(p);
    maps=struct(psi=r.psi*C,eta=r.eta*C,eta_i=r.eta_i*C,buoyancy=r.buoyancy*C, ...
        q=(r.qgpv-kh^2*r.psi)*C,endpoint=e.eta_i*C,ssh=r.ssh*C);
    factors=struct(kineticEnergy=sqrt(weights)*kh.*maps.psi, ...
        interiorPotentialEnergy=sqrt(weights.*N2).*maps.eta, ...
        surfacePotentialEnergy=sqrt(self.g)*maps.ssh, ...
        potentialEnstrophy=sqrt(weights).*maps.q, ...
        surfaceAnomalyVariance=maps.endpoint(1,:),bottomAnomalyVariance=maps.endpoint(2,:));
    page=struct(factors=factors);
    for name=string(fieldnames(factors)).', page.(name)=factors.(name)'*factors.(name); end
    pages{p}=page; reconstruction{p}=maps;
end
P=WVInternal.thermalVerticalInterpolation(self.z,z,self.Lz,self.inverseScale);
MG=P*self.mdaG; MQ=-self.f*(P*self.mdaGZ);
maps=struct(eta=MG,eta_i=MG,buoyancy=-N2.*MG,q=MQ,endpoint=self.mdaG([end 1],:));
factors=struct(kineticEnergy=zeros(1,self.mdaModeCount), ...
    interiorPotentialEnergy=sqrt(weights.*N2).*MG,surfacePotentialEnergy=zeros(1,self.mdaModeCount), ...
    potentialEnstrophy=sqrt(weights).*MQ,surfaceAnomalyVariance=maps.endpoint(1,:),bottomAnomalyVariance=maps.endpoint(2,:));
mda=struct(reconstruction=maps,factors=factors);
for name=string(fieldnames(factors)).', mda.(name)=factors.(name)'*factors.(name); end
operators=struct(pages={pages},reconstruction={reconstruction},mda=mda,z=z,weights=weights,N2=N2,quadratureCount=numel(z));
self.physicalMetricOperators_=operators;
end
