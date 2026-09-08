function [other,assessment] = waveVortexTransformWithResolution(self,Nxyz,options)
% Construct a qualified target and transfer independently retained resolved families.
%
% Each count defaults to its source count rather than following Nz. Scientific
% construction solves the target representation; the transfer then matches
% physical modes and their phase/normalization without mixing the basis.
% Unsupported forcing conversions reject the operation. The source is unchanged.
%
% - Topic: Transfer resolution
% - Declaration: [other,assessment] = waveVortexTransformWithResolution(Nxyz,options)
% - Parameter Nxyz: target horizontal Fourier sizes and vertical sample count
% - Parameter options.waveModeCount: retained wave modes per sign; default source count
% - Parameter options.apvModeCount: retained APV count; default source count
% - Parameter options.mdaModeCount: retained MDA count; default source count
% - Parameter options.inertialModeCount: retained inertial count; default source count
% - Parameter options.modeTolerance: allowed matched-mode physical shape residual
% - Returns other: new transform with transferred state, t/t0 and forcing
% - Returns assessment: positive physical transfer and discarded-content diagnostics
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.waveModeCount (1,1) double {mustBeInteger,mustBePositive} = length(self.waveMode)
    options.apvModeCount (1,1) double {mustBeInteger,mustBePositive} = length(self.apvMode)
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive} = length(self.mdaMode)
    options.inertialModeCount (1,1) double {mustBeInteger,mustBePositive} = length(self.inertialMode)
    options.modeTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
end
arguments (Output)
    other (1,1) WVTransformFreeSurfaceBoussinesq
    assessment (1,1) struct
end
configuration=rmfield(options,'modeTolerance');
for name=["shouldAntialias","N2Function","rho0","planetaryRadius","rotationRate","latitude","g","g0","gd","nEVP","projectionTolerance"]
    configuration.(name)=self.(name);
end
args=namedargs2cell(configuration);
other=WVTransformFreeSurfaceBoussinesq.fromStratification([self.Lx self.Ly self.Lz],Nxyz,args{:});
other.t=self.t; other.t0=self.t0;
[state,assessment]=self.coefficientStateForTransform(other,modeTolerance=options.modeTolerance);
for name=string(fieldnames(state)).', other.(name)=state.(name); end
WVInternal.transferFreeSurfaceForcing(self,other);
end
