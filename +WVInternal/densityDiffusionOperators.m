function operators = densityDiffusionOperators(self,kappa_z,options)
% Build Galerkin density diffusion on the complete canonical modal state.
%
% Both endpoints must be active. No mode is added or removed. Only stored
% modal arrays and spectral grid operations are used, including on restart.
%
% - Topic: Density diffusion
% - Developer: true
arguments
    self WVTransformFreeSurfaceQG
    kappa_z (1,1) double {mustBeNonnegative,mustBeFinite}
    options.shouldForceMeanDensityAnomaly (1,1) logical = true
end
if self.activeEndpointCount~=2
    error('WV:DensityDiffusionEndpoints','The developmental density diffusion path requires both active endpoints.');
end
metrics = self.physicalMetricOperators();
weights = metrics.weights;
pages = cell(length(self.khUnique),1);
for p = 1:length(pages)
    r = metrics.reconstruction{p};
    pages{p} = WVInternal.densityDiffusionPage(r.phi,r.eta,r.etaZ,r.buoyancyZ,r.phiSurface,weights,metrics.N2,self.khUnique(p),self.f,self.g,kappa_z);
end
r = metrics.mda.reconstruction;
mda = WVInternal.densityDiffusionMDA(r.buoyancy,r.buoyancyZ,weights,kappa_z*options.shouldForceMeanDensityAnomaly);
mda.reconstruction = r;
operators = struct(kappa_z=kappa_z,shouldForceMeanDensityAnomaly=options.shouldForceMeanDensityAnomaly,pages={pages},mda=mda, ...
    reconstruction={metrics.reconstruction},z=metrics.z,weights=weights,N2=metrics.N2,quadratureCount=metrics.quadratureCount);
end
