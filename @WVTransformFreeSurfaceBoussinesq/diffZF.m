function du = diffZF(self,u,options)
% Differentiate a sampled field without projecting onto the APV F modes.
%
% This free-surface alias uses `diffZ` on the fixed reference grid.
% APV, zero-APV, MDA, and general sampled fields use the same derivative;
% the F suffix does not select a modal subspace or an output family.
%
% - Topic: Evaluate physical fields
% - Declaration: du = diffZF(u,n=n)
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
du = self.diffZ(u,n=options.n);
end
