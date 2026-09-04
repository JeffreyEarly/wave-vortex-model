function tendency = boundaryMomentumTendency(self,tauXHat,tauYHat,endpoint)
% Project momentum stress per unit density onto the signed balanced basis.
% Stress inputs are compact nonzero-wavenumber Fourier rows in m^2 s^-2.
% The zero-APV source uses the stored inverse signed Gram matrix and leaves
% the public coefficients in their boundary-normalized coordinates.
% - Topic: Transform coefficient state
% - Developer: true
arguments
    self WVTransformFreeSurfaceQG
    tauXHat (1,:) double {mustBeFinite}
    tauYHat (1,:) double {mustBeFinite}
    endpoint (1,1) string {mustBeMember(endpoint,["surface","bottom"])}
end
nkl=length(self.klNonzero);
if numel(tauXHat)~=nkl || numel(tauYHat)~=nkl
    error('WVTransformFreeSurfaceQG:InvalidStressSize','Stress rows must have one entry per klNonzero.');
end
[~,surfaceIndex]=max(self.z); [~,bottomIndex]=min(self.z);
indices=[surfaceIndex bottomIndex]; selected=1+double(endpoint=="bottom"); iz=indices(selected);
if self.activeEndpointCount>0 && isempty(self.boundaryMomentumResponse_)
    response=zeros(self.activeEndpointCount,2,length(self.khUnique));
    for ip=1:length(self.khUnique)
        response(:,:,ip)=self.zeroAPVSourceSolve(:,:,ip)*(self.zeroAPVF(indices,:,ip).'/self.Lz);
    end
    self.boundaryMomentumResponse_=response;
end
curl=1i*self.kNonzero.'.*tauYHat-1i*self.lNonzero.'.*tauXHat;
sourceQ=(self.apvF(iz,:).'/self.Lz).*curl;
source0=complex(zeros(self.activeEndpointCount,nkl));
if self.activeEndpointCount>0
    response=reshape(self.boundaryMomentumResponse_(:,selected,:),self.activeEndpointCount,[]);
    source0=response(:,self.klNonzeroKhUniqueIndex).*curl;
end
tendency=struct(Ag_q=sourceQ,Ag_0=source0,Amda=zeros(size(self.Amda)));
end
