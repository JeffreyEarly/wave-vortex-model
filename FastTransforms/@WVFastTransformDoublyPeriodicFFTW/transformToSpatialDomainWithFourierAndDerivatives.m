function [u,u_x,u_y] = transformToSpatialDomainWithFourierAndDerivatives(self,uBar)
% Reconstruct a field and its first horizontal derivatives from the WV grid.
%
% Each result uses a transient half-x spectrum and the existing destructive
% c2r plan. No preserving inverse is used and no spectrum-sized scratch or
% persistent derivative buffer is retained.
%
% - Topic: Apply spatial derivatives
% - Parameter uBar: normalized canonical WV-grid coefficients `[Nz,Nkl]`
% - Returns u: reconstructed real spatial field `[Nx,Ny,Nz]`
% - Returns u_x: first derivative with respect to x `[Nx,Ny,Nz]`
% - Returns u_y: first derivative with respect to y `[Nx,Ny,Nz]`
% - Developer: true
arguments
    self (1,1) WVFastTransformDoublyPeriodicFFTW
    uBar double
end
u = self.transformToSpatialDomainWithFourier(uBar);
u_x = self.transformToSpatialDomainWithFourier((1i*self.wvg.k.').*uBar);
u_y = self.transformToSpatialDomainWithFourier((1i*self.wvg.l.').*uBar);
end
