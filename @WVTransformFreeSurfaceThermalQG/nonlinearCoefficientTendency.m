function [tendency,speed,diagnostics]=nonlinearCoefficientTendency(self)
% Evaluate complete interior and both-endpoint Jacobians on product quadrature.
% - Topic: Density diffusion integration
% - Returns tendency: retained family rates, without diffusion or external forcing
% - Returns speed: maximum horizontal speed on the product grid and endpoints
% - Returns diagnostics: bounded RHS timings and scratch estimate
if ~self.shouldCheckQuadraticAliasing || ~self.shouldAntialias
    error('WV:ThermalNonlinearQualification','Construct with qualified nonlinear quadrature and horizontal antialiasing.');
end
if isempty(self.nonlinearMaps_)
    self.nonlinearMaps_=WVInternal.thermalNonlinearMaps(self,self.nonlinearQuadratureCount);
end
[tendency,speed,diagnostics]=WVInternal.thermalNonlinearKernel(self,self.nonlinearMaps_);
end
