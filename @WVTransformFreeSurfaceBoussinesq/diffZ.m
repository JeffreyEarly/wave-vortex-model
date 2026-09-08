function du = diffZ(self,u,options)
% Differentiate a sampled field on the shared physical vertical grid.
%
% Apply the persisted physical first-derivative matrix successively:
% $$\partial_z^n u \approx D_z^n u$$. No APV, zero-APV, or MDA
% projection is performed. Each application differentiates the interpolant
% of the preceding sampled derivative on the same mapped grid.
%
% In the WKB coordinate $$s=\int_{-L_z}^z N\,dz'/\int_{-L_z}^0 N\,dz'$$,
% $$D_z$$ includes the metric $$ds/dz=N/\int_{-L_z}^0 N\,dz'$$.
% Successive application therefore differentiates the variable metric too;
% it is not a constant-metric multiple of an nth coordinate derivative.
% Accuracy depends on grid and map resolution, with higher orders more
% sensitive to unresolved structure and floating-point error.
%
% ```matlab
% dudz = wvt.diffZ(wvt.u);
% ```
%
% - Topic: Evaluate physical fields
% - Declaration: du = diffZ(u,n=n)
% - Parameter u: real or complex sampled field with shape `Nx x Ny x Nz`
% - Parameter n: physical derivative order from 1 through 4; default 1
% - Returns du: sampled physical derivative with the same shape as u
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
