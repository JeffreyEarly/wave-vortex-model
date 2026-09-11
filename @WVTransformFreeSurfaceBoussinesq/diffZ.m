function du = diffZ(self,u,options)
% Differentiate a sampled field along the fixed reference column.
%
% Apply the persisted reference-depth first-derivative matrix successively:
% $$\partial_\xi^n u \approx D_\xi^n u$$. No APV, zero-APV, or MDA
% projection is performed. Each application differentiates the interpolant
% of the preceding sampled derivative on the same reference grid.
%
% In the WKB coordinate $$s=\int_{-L_z}^\xi N\,d\xi'/\int_{-L_z}^0 N\,d\xi'$$,
% $$D_\xi$$ includes the metric $$ds/d\xi=N/\int_{-L_z}^0 N\,d\xi'$$.
% Successive application therefore differentiates the variable metric too;
% it is not a constant-metric multiple of an nth coordinate derivative.
% Accuracy depends on grid and map resolution, with higher orders more
% sensitive to unresolved structure and floating-point error.
%
% Surface flattening is a separate map. For $$\gamma=1+\zeta/D$$
% and $$\alpha=1+\xi/D$$, derivatives at fixed physical position are
% $$\partial_z=\gamma^{-1}D_\xi$$ and
% $$\partial_x|_z=D_x-\alpha\zeta_x\gamma^{-1}D_\xi$$,
% with the corresponding y expression. diffX/diffY hold xi fixed.
%
% ```matlab
% dudz = wvt.diffZ(wvt.u)./(1+wvt.ssh/wvt.Lz);
% ```
%
% - Topic: Evaluate physical fields
% - Declaration: du = diffZ(u,n=n)
% - Parameter u: real or complex sampled field with shape `Nx x Ny x Nz`
% - Parameter n: reference-depth derivative order from 1 through 4; default 1
% - Returns du: sampled reference-depth derivative with the same shape as u
arguments (Input)
    self WVTransformFreeSurfaceBoussinesq
    u double
    options.n (1,1) double {mustBeMember(options.n,1:4)} = 1
end
arguments (Output)
    du double
end
mustBeMember(ndims(u),3);
mustBeMember(size(u,1),self.Nx);
mustBeMember(size(u,2),self.Ny);
mustBeMember(size(u,3),self.Nz);
du = reshape(permute(u,[3 1 2]),self.Nz,[]);
for iDerivative = 1:options.n
    du = self.verticalDerivativeMatrix*du;
end
du = permute(reshape(du,self.Nz,self.Nx,self.Ny),[2 3 1]);
end
