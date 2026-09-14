function tendency=boundaryMomentumTendency(self,tauXHat,tauYHat,endpoint)
% Project boundary momentum stress with the physical-energy weak dual.
%
% Stress per unit density is in m2/s2. The load for a test streamfunction
% is minus its endpoint trace times the stress curl. Thus the physical
% energy rate is the horizontal mean of u*tauX+v*tauY, including the
% free-surface energy in the authoritative thermal metric. Both endpoint
% equations respond through the complete balanced inverse; no volume cell
% or direct horizontal-mean source is introduced.
% - Topic: Project physical states and sources
% - Parameter tauXHat: zonal stress, compact nonzero Fourier row
% - Parameter tauYHat: meridional stress, compact nonzero Fourier row
% - Parameter endpoint: surface or bottom
% - Returns tendency: Ath and Amda coefficient rates
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    tauXHat (1,:) double {mustBeFinite}
    tauYHat (1,:) double {mustBeFinite}
    endpoint (1,1) string {mustBeMember(endpoint,["surface","bottom"])}
end
arguments (Output)
    tendency (1,1) struct
end
if numel(tauXHat)~=numel(self.klNonzero) || numel(tauYHat)~=numel(self.klNonzero)
    error('WV:ThermalStressSize','Stress rows must have one entry per klNonzero.');
end
trace=ones(self.thermalModeCount,1);
if endpoint=="bottom", trace=(-1).^(0:self.thermalModeCount-1)'; end
curl=1i*self.k(self.klNonzero).'.*tauYHat-1i*self.l(self.klNonzero).'.*tauXHat;
tendency=struct(Ath=complex(zeros(size(self.Ath))),Amda=zeros(size(self.Amda)));
for p=1:numel(self.khUnique)
    columns=self.klNonzeroKhUniqueIndex==p;
    tendency.Ath(:,columns)=-(self.sourceDual(:,:,p)*trace)*curl(columns);
end
end
