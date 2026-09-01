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

nz = length(self.z);
nonzeroIndex = self.klNonzero;
pageIndex = self.klNonzeroKhUniqueIndex;
nNonzero = length(nonzeroIndex);
fOverG = self.f/self.g;

apvStreamfunctionCoefficients = -self.Ag_q./self.apvMu(:,pageIndex);
psiNonzero = self.apvF*apvStreamfunctionCoefficients;
etaNonzero = fOverG*(self.apvG*apvStreamfunctionCoefficients);
qNonzero = self.apvF*self.Ag_q;

if self.activeEndpointCount > 0
    zeroStreamfunctionCoefficients = -self.Ag_0./reshape(self.khNonzero.^2,1,[]);
    zeroCoefficientPages = reshape(zeroStreamfunctionCoefficients,self.activeEndpointCount,1,nNonzero);
    zeroF = pagemtimes(self.zeroAPVF(:,:,pageIndex),zeroCoefficientPages);
    zeroG = pagemtimes(self.zeroAPVG(:,:,pageIndex),zeroCoefficientPages);
    psiNonzero = psiNonzero+reshape(zeroF,nz,nNonzero);
    etaNonzero = etaNonzero+fOverG*reshape(zeroG,nz,nNonzero);
end

psiHat = complex(zeros(nz,self.Nkl));
etaHat = complex(zeros(nz,self.Nkl));
qHat = complex(zeros(nz,self.Nkl));
psiHat(:,nonzeroIndex) = psiNonzero;
etaHat(:,nonzeroIndex) = etaNonzero;
qHat(:,nonzeroIndex) = qNonzero;

meanIndex = find(hypot(self.k,self.l) == 0,1);
if ~isempty(meanIndex)
    etaHat(:,meanIndex) = self.mdaG*self.Amda;
end
end
