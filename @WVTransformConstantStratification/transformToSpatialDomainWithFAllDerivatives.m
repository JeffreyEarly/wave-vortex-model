function [u,u_x,u_y,u_z] = transformToSpatialDomainWithFAllDerivatives(self,options)
% Reconstruct an F field and its first derivatives from modal coefficients.
%
% Horizontal wavenumber multipliers are applied on the canonical WV grid,
% while the vertical derivative changes the cosine expansion to a sine
% expansion through $$-j\pi/L_z$$. This avoids transforming the reconstructed
% spatial field forward again.
%
% - Topic: Nonlinear flux and forcing internals
% - Parameter Apm: wave coefficients on the canonical WV grid
% - Parameter A0: vortical coefficients on the canonical WV grid
% - Returns u: reconstructed F field `[Nx,Ny,Nz]`
% - Returns u_x: derivative with respect to x `[Nx,Ny,Nz]`
% - Returns u_y: derivative with respect to y `[Nx,Ny,Nz]`
% - Returns u_z: derivative with respect to z on the G grid `[Nx,Ny,Nz]`
arguments
    self WVTransformConstantStratification {mustBeNonempty}
    options.Apm double = 0
    options.A0 double = 0
end
if isscalar(options.Apm) && isscalar(options.A0)
    u = zeros(self.spatialMatrixSize);
    u_x = u;
    u_y = u;
    u_z = u;
    return
end
implementation = WVSpatialDerivativeDispatch.implementation(self.fastTransform.backendIdentifier,"F-all",[self.Nx self.Ny self.Nz],1,self.isHydrostatic);
if implementation == "composed-current"
    u = self.transformToSpatialDomainWithF(Apm=options.Apm,A0=options.A0);
    u_x = self.diffX(u);
    u_y = self.diffY(u);
    u_z = self.diffZF(u);
    return
end
coefficients = self.F_g .* (options.Apm./self.F_wg + options.A0);
uBar = self.verticalTransform.transformBack(coefficients,"cosine",self.iDCT);
[u,u_x,u_y] = self.fastTransform.transformToSpatialDomainWithFourierAndDerivatives(uBar);
m = -pi*self.j/self.Lz;
uZBar = self.verticalTransform.transformBack(m.*coefficients,"sine",self.iDST);
u_z = self.transformToSpatialDomainWithFourier(uZBar);
end
