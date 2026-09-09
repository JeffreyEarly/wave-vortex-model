function [other,assessment] = waveVortexTransformWithResolution(self,Nxyz,options)
% Construct a qualified target and transfer matching resolved QG content.
%
% Retained counts default to the source counts, independently of Nz. Target
% scientific construction may solve modes; failed qualification rejects the
% requested resolution without silently dropping modes. Normalization and
% shape matching use coefficientStateForTransform. Forcing conversion is
% explicit and an unsupported conversion rejects the whole operation.
%
% - Topic: Transfer resolution
% - Declaration: [other,assessment] = waveVortexTransformWithResolution(Nxyz,options)
% - Parameter Nxyz: target horizontal Fourier sizes and vertical sample count
% - Parameter options.apvModeCount: target APV prefix count; default source count
% - Parameter options.mdaModeCount: target MDA prefix count; default source count
% - Parameter options.modeTolerance: allowed matched-mode physical shape residual
% - Returns other: new transform with transferred state, t/t0 and forcing
% - Returns assessment: positive physical transfer and discarded-content diagnostics
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.apvModeCount (1,1) double {mustBeInteger,mustBePositive} = self.apvModeCount
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive} = self.mdaModeCount
    options.modeTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
end
arguments (Output)
    other (1,1) WVTransformFreeSurfaceQG
    assessment (1,1) struct
end
configuration=struct();
for name=["shouldAntialias","N2Function","rho0","planetaryRadius","rotationRate","latitude","g","g0","gd","gramTolerance","modeConvergenceTolerance","boundaryResolutionTolerance","quadraticAliasingTolerance","muTolerance"]
    configuration.(name)=self.(name);
end
configuration.apvModeCount=options.apvModeCount; configuration.mdaModeCount=options.mdaModeCount;
args=namedargs2cell(configuration);
other=WVTransformFreeSurfaceQG([self.Lx self.Ly self.Lz],Nxyz,args{:});
other.t=self.t; other.t0=self.t0;
[state,assessment]=self.coefficientStateForTransform(other,modeTolerance=options.modeTolerance);
for name=string(fieldnames(state)).', other.(name)=state.(name); end
WVInternal.transferFreeSurfaceForcing(self,other);
end
