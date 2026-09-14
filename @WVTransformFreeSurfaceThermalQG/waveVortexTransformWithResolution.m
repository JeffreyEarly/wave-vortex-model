function [other,assessment]=waveVortexTransformWithResolution(self,Nxyz,options)
% Construct a target and transfer physical QGPV, endpoint and mean content.
% Target construction may solve scientific modes; transfer and canonical
% restoration use stored operators. Forcing conversions reject unresolved
% patterns and the source remains unchanged if any part of transfer fails.
% - Topic: Transfer resolution
% - Parameter Nxyz: target horizontal Fourier sizes and vertical sample count
% - Parameter options.thermalModeCount: target complete thermal dimension
% - Parameter options.mdaModeCount: target independently retained mean dimension
% - Returns other: new transform with transferred state, clocks and forcing
% - Returns assessment: physical discarded-content and projection residuals
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    Nxyz (1,3) double {mustBeInteger,mustBeGreaterThanOrEqual(Nxyz,4)}
    options.thermalModeCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.thermalModeCount,3)} = self.thermalModeCount
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive} = self.mdaModeCount
end
arguments (Output)
    other (1,1) WVTransformFreeSurfaceThermalQG
    assessment (1,1) struct
end
configuration=options;
for name=["N2Function","kappa_z","latitude","g","shouldAntialias","gramTolerance","modeConvergenceTolerance","boundaryResolutionTolerance","shouldCheckQuadraticAliasing","nonlinearQuadratureTolerance"]
    configuration.(name)=self.(name);
end
configuration.assemblyQuadratureCount=max(self.assemblyQuadratureCount,4*options.thermalModeCount+1);
if self.shouldCheckQuadraticAliasing
    configuration.nonlinearQuadratureCount=max(self.nonlinearQuadratureCount,3*options.thermalModeCount+1);
end
args=namedargs2cell(configuration);
other=WVTransformFreeSurfaceThermalQG.fromStratification([self.Lx self.Ly self.Lz],Nxyz,args{:});
[state,assessment]=self.coefficientStateForTransform(other);
other.Ath=state.Ath; other.Amda=state.Amda; other.t=self.t; other.t0=self.t0;
WVInternal.transferFreeSurfaceForcing(self,other);
end
