function u = transformToSpatialDomainWithFourier(self,uBar)
% Reconstruct a real spatial array through destructive half-x c2r.
%
% WV-grid coefficients already include horizontal normalization, so this
% method intentionally does not apply the FFTW transform's scale factor.
%
% - Topic: Apply horizontal transforms
% - Declaration: u = transformToSpatialDomainWithFourier(uBar)
% - Parameter uBar: normalized canonical WV-grid coefficients `[Nz,Nkl]`
% - Returns u: reconstructed real spatial array `[Nx,Ny,Nz]`
% - Developer: true
halfSpectrum = self.assembleHalfSpectrum(uBar);
u = zeros(self.horizontalTransform.realSize);
[halfSpectrum,u] = self.horizontalTransform.transformBackIntoArrayDestructive(halfSpectrum,u);
if isempty(halfSpectrum)
    error("WaveVortexModel:MissingDestroyedSpectrum","The destructive FFTW inverse did not return its reassigned spectrum.");
end
end
