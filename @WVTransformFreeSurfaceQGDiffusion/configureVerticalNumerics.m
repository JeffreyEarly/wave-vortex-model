function configureVerticalNumerics(self,options)
% Explicitly configure vertical product quadrature without changing modes.
% Legacy restarts remain unchanged until this method is called.
% - Topic: Create and restore a transform
arguments (Input)
    self WVTransformFreeSurfaceQGDiffusion
    options.quadratureFactor (1,1) double {mustBeGreaterThanOrEqual(options.quadratureFactor,1),mustBeFinite}=2
    options.shouldDealias (1,1) logical=true
end
self.verticalNumerics=WVQGVerticalOperators.fromGrid(self.z,options.quadratureFactor);
self.shouldDealiasVertical=options.shouldDealias;
self.initializeVerticalNumerics();
for force=self.spectralFluxForcing
    if isa(force,'WVAdaptiveDamping'), force.buildDampingOperator(); end
end
end
