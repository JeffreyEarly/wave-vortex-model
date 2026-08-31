function [psiHat,etaHat,qHat] = reconstructSpectralState(self)
% Reconstruct compact spectral streamfunction, displacement, and APV.
%
% - Topic: Transform coefficient state
% - Declaration: [psiHat,etaHat,qHat] = reconstructSpectralState(self)
% - Returns psiHat: streamfunction on the compact full-kl grid
% - Returns etaHat: displacement on the compact full-kl grid
% - Returns qHat: APV on the compact full-kl grid
arguments
    self (1,1) WVTransformFreeSurfaceQG
end

psiHat = complex(zeros(length(self.z),self.Nkl));
etaHat = complex(zeros(length(self.z),self.Nkl));
qHat = complex(zeros(length(self.z),self.Nkl));
for iKl = 1:length(self.klNonzero)
    fullKlIndex = self.klNonzero(iKl);
    iKh = self.klNonzeroKhUniqueIndex(iKl);
    apvStreamfunctionCoefficients = -self.Ag_q(:,iKl)./self.apvMu(:,iKh);
    psiHat(:,fullKlIndex) = self.apvF*apvStreamfunctionCoefficients;
    etaHat(:,fullKlIndex) = (self.f/self.g)*(self.apvG*apvStreamfunctionCoefficients);
    qHat(:,fullKlIndex) = self.apvF*self.Ag_q(:,iKl);
    if self.activeEndpointCount > 0
        zeroStreamfunctionCoefficients = -self.Ag_0(:,iKl)/self.khNonzero(iKl)^2;
        psiHat(:,fullKlIndex) = psiHat(:,fullKlIndex)+self.zeroAPVF(:,:,iKh)*zeroStreamfunctionCoefficients;
        etaHat(:,fullKlIndex) = etaHat(:,fullKlIndex)+(self.f/self.g)*(self.zeroAPVG(:,:,iKh)*zeroStreamfunctionCoefficients);
    end
end

meanIndex = find(hypot(self.k,self.l) == 0,1);
if ~isempty(meanIndex)
    etaHat(:,meanIndex) = self.mdaG*self.Amda;
end
end
