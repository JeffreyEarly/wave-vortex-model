function [w,w_x,w_y,w_z] = transformToSpatialDomainWithGAllDerivatives(self,options)
% Reconstruct a G field and its first derivatives from modal coefficients.
%
% Horizontal wavenumber multipliers are applied on the canonical WV grid,
% while the vertical derivative changes the sine expansion to a cosine
% expansion through $$j\pi/L_z$$. This avoids transforming the reconstructed
% spatial field forward again.
%
% - Topic: Nonlinear flux and forcing internals
% - Parameter Apm: wave coefficients on the canonical WV grid
% - Parameter A0: vortical coefficients on the canonical WV grid
% - Returns w: reconstructed G field `[Nx,Ny,Nz]`
% - Returns w_x: derivative with respect to x `[Nx,Ny,Nz]`
% - Returns w_y: derivative with respect to y `[Nx,Ny,Nz]`
% - Returns w_z: derivative with respect to z on the F grid `[Nx,Ny,Nz]`
arguments
    self WVTransformConstantStratification {mustBeNonempty}
    options.Apm double = 0
    options.A0 double = 0
end
if isscalar(options.Apm) && isscalar(options.A0)
    w = zeros(self.spatialMatrixSize);
    w_x = w;
    w_y = w;
    w_z = w;
    return
end
implementation = WVSpatialDerivativeDispatch.implementation(self.fastTransform.backendIdentifier,"G-all",[self.Nx self.Ny self.Nz],1,self.isHydrostatic);
if implementation == "composed-current"
    w = self.transformToSpatialDomainWithG(Apm=options.Apm,A0=options.A0);
    w_x = self.diffX(w);
    w_y = self.diffY(w);
    w_z = self.diffZG(w);
    return
end
coefficients = self.G_g .* (options.Apm./self.G_wg + options.A0);
wBar = self.verticalTransform.transformBack(coefficients,"sine",self.iDST);
[w,w_x,w_y] = self.fastTransform.transformToSpatialDomainWithFourierAndDerivatives(wBar);
m = pi*self.j/self.Lz;
wZBar = self.verticalTransform.transformBack(m.*coefficients,"cosine",self.iDCT);
w_z = self.transformToSpatialDomainWithFourier(wZBar);
end
