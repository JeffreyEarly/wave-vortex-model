function psiHat=boundaryStreamfunction(self,endpoint)
% Reconstruct one endpoint streamfunction without a volume reconstruction.
% - Topic: Evaluate physical fields
% - Parameter endpoint: surface or bottom
% - Returns psiHat: compact nonzero Fourier row in m2/s
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    endpoint (1,1) string {mustBeMember(endpoint,["surface","bottom"])}
end
arguments (Output)
    psiHat (1,:) double
end
[~,iz]=min(self.z);
if endpoint=="surface", [~,iz]=max(self.z); end
page=self.klNonzeroKhUniqueIndex;
psiHat=self.apvF(iz,:)*(-self.Ag_q./self.apvMu(:,page));
if self.activeEndpointCount>0
    response=reshape(self.zeroAPVF(iz,:,page),self.activeEndpointCount,[]);
    psiHat=psiHat-sum(response.*self.Ag_0,1)./reshape(self.khNonzero.^2,1,[]);
end
end
