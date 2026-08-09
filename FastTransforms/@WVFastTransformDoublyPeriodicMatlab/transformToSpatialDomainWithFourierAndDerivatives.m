function [u,u_x,u_y] = transformToSpatialDomainWithFourierAndDerivatives(self,uBar)
% Reconstruct a field and its first horizontal derivatives from the WV grid.
%
% The input stays in the canonical `[Nz,Nkl]` WV representation. Wavenumber
% multipliers are applied before each inverse transform, avoiding the two
% spatial-to-Fourier transforms required by the composed `diffX`/`diffY`
% implementation.
%
% - Topic: Developer internals
% - Parameter uBar: normalized canonical WV-grid coefficients `[Nz,Nkl]`
% - Returns u: reconstructed real spatial field `[Nx,Ny,Nz]`
% - Returns u_x: first derivative with respect to x `[Nx,Ny,Nz]`
% - Returns u_y: first derivative with respect to y `[Nx,Ny,Nz]`
% - Developer: true
arguments
    self (1,1) WVFastTransformDoublyPeriodicMatlab
    uBar double
end
u = self.transformToSpatialDomainWithFourier(uBar);
u_x = self.transformToSpatialDomainWithFourier((1i*self.wvg.k.').*uBar);
u_y = self.transformToSpatialDomainWithFourier((1i*self.wvg.l.').*uBar);
end
