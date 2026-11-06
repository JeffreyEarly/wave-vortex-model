function tendency = projectSources(self,sources)
% Project volume acceleration and total-displacement sources into resolved modes.
%
% This is the linear hatted-equation source projector. Inputs are reference
% equation accelerations, not physical acceleration on the moving mesh.
% Nonlinear physical forcing enters coefficientTendency after its coordinate
% map before projection. Sources need not satisfy continuity or ocean-state boundary constraints.
% The input is the manuscript source vector (Su,Sv,Sw,Seta,0): momentum
% acceleration in m/s^2 and total-displacement rate in m/s. No independent
% surface mass flux or boundary sheet source is included. Surface pressure
% loading may be supplied through its horizontal acceleration.
%
% The projection functionals use the continuous mode normalization,
% physical quadrature and the required endpoint values. Wave projection
% uses all three supplied momentum components. MDA uses the signed
% generalized-energy normalization. All oscillating tendencies refer to t0.
%
% - Topic: Project physical sources
% - Declaration: tendency = projectSources(sources)
% - Parameter sources: scalar structure with real finite u,v,w,eta arrays Nx by Ny by Nz
% - Returns tendency: six independently shaped reference-time coefficient tendencies
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    sources (1,1) struct
end
arguments (Output)
    tendency (1,1) struct
end
if ~isequal(sort(string(fieldnames(sources))),sort(["u";"v";"w";"eta"]))
    error('WVTransformFreeSurfaceBoussinesq:InvalidSources','Supply exactly u,v,w,eta volume sources; independent surface mass flux and boundary sheets are not supported.')
end
for name = ["u","v","w","eta"]
    value = sources.(name);
    if ~isa(value,'double') || ~isreal(value) || any(~isfinite(value),'all') || ~isequal(size(value),[self.Nx self.Ny self.Nz])
        error('WVTransformFreeSurfaceBoussinesq:InvalidSources','%s must be a finite real double array of shape Nx by Ny by Nz.',name)
    end
    spectral.(name) = self.transformFromSpatialDomainWithFourier(value);
end
tendency = WVInternal.projectBoussinesqSpectralSources(self,spectral,self,self.verticalQuadratureWeights,self.N2,self.waveF,self.waveG);
end
