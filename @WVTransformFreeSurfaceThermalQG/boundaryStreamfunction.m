function psiHat=boundaryStreamfunction(self,endpoint)
% Reconstruct one endpoint streamfunction without a volume reconstruction.
% - Topic: Evaluate physical fields
% - Parameter endpoint: surface or bottom
% - Returns psiHat: compact nonzero Fourier row in m2/s
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    endpoint (1,1) string {mustBeMember(endpoint,["surface","bottom"])}
end
arguments (Output)
    psiHat (1,:) double
end
trace=ones(1,self.thermalModeCount);
if endpoint=="bottom", trace=(-1).^(0:self.thermalModeCount-1); end
psiHat=complex(zeros(1,numel(self.klNonzero)));
for p=1:numel(self.khUnique)
    columns=self.klNonzeroKhUniqueIndex==p;
    psiHat(columns)=(trace*self.thermalToPolynomial(:,:,p))*self.Ath(:,columns);
end
end
