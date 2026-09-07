function [psiHat,etaHat,qHat] = reconstructSpectralState(self,options)
% Reconstruct compact spectral streamfunction, displacement, and full QGPV.
%
% The zero-horizontal-wavenumber displacement is the MDA field, with
% $$\overline q = -f\partial_z\overline\eta_i.$$ The mean SSH
% gauge is zero. Nonzero-wavenumber QGPV is reconstructed from APV modes.
%
% - Topic: Transform coefficient state
% - Declaration: [psiHat,etaHat,qHat] = reconstructSpectralState(options)
% - Parameter options.flowComponent: selector belonging to this transform; empty selects the full state
% - Returns psiHat: streamfunction on the compact full-kl grid
% - Returns etaHat: displacement on the compact full-kl grid
% - Returns qHat: full QGPV, including MDA, on the compact full-kl grid
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    psiHat double
    etaHat double
    qHat double
end
state = self.coefficientState(flowComponent=options.flowComponent);

nz = length(self.z);
nonzeroIndex = self.klNonzero;
pageIndex = self.klNonzeroKhUniqueIndex;
nNonzero = length(nonzeroIndex);
fOverG = self.f/self.g;

apvStreamfunctionCoefficients = -state.Ag_q./self.apvMu(:,pageIndex);
psiNonzero = self.apvF*apvStreamfunctionCoefficients;

if self.activeEndpointCount > 0
    zeroStreamfunctionCoefficients = -state.Ag_0./reshape(self.khNonzero.^2,1,[]);
    zeroCoefficientPages = reshape(zeroStreamfunctionCoefficients,self.activeEndpointCount,1,nNonzero);
    zeroF = pagemtimes(self.zeroAPVF(:,:,pageIndex),zeroCoefficientPages);
    psiNonzero = psiNonzero+reshape(zeroF,nz,nNonzero);
end

psiHat = complex(zeros(nz,self.Nkl));
psiHat(:,nonzeroIndex) = psiNonzero;

if nargout > 1
    etaNonzero = fOverG*(self.apvG*apvStreamfunctionCoefficients);
    if self.activeEndpointCount > 0
        zeroG = pagemtimes(self.zeroAPVG(:,:,pageIndex),zeroCoefficientPages);
        etaNonzero = etaNonzero+fOverG*reshape(zeroG,nz,nNonzero);
    end
    etaHat = complex(zeros(nz,self.Nkl));
    etaHat(:,nonzeroIndex) = etaNonzero;
    meanIndex = find(hypot(self.k,self.l) == 0,1);
    if ~isempty(meanIndex)
        etaHat(:,meanIndex) = self.mdaG*state.Amda;
    end
end
if nargout > 2
    qHat = complex(zeros(nz,self.Nkl));
    qHat(:,nonzeroIndex) = self.apvF*state.Ag_q;
    if ~isempty(meanIndex)
        qHat(:,meanIndex) = -self.f*(self.mdaDisplacementDerivative()*state.Amda);
    end
end
end
