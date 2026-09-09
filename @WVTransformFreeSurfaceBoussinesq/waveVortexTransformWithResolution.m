function [other,assessment] = waveVortexTransformWithResolution(self,Nxyz,options)
% Construct a qualified target and transfer independently retained resolved families.
%
% Each count defaults to its source count rather than following Nz. A
% nonuniform source map is preserved on shared kappa pages; new kappa pages
% require an explicit target map. Scientific
% construction solves the target representation; the transfer then matches
% physical modes and their phase/normalization without mixing the basis.
% Unsupported forcing conversions reject the operation. The source is unchanged.
%
% - Topic: Transfer resolution
% - Declaration: [other,assessment] = waveVortexTransformWithResolution(Nxyz,options)
% - Parameter Nxyz: target horizontal Fourier sizes and vertical sample count
% - Parameter options.waveModeCount: scalar or per-kappa retained wave counts; default source map
% - Parameter options.waveModeKappa: positive physical kappa keys for explicit wave counts
% - Parameter options.apvModeCount: retained APV count; default source count
% - Parameter options.mdaModeCount: retained MDA count; default source count
% - Parameter options.inertialModeCount: retained inertial count; default source count
% - Parameter options.modeTolerance: allowed matched-mode physical shape residual
% - Returns other: new transform with transferred state, t/t0 and forcing
% - Returns assessment: positive physical transfer and discarded-content diagnostics
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.waveModeCount (:,1) double {mustBeReal,mustBeFinite,mustBeInteger,mustBeNonnegative} = zeros(0,1)
    options.waveModeKappa (:,1) double {mustBeReal,mustBeFinite,mustBePositive} = zeros(0,1)
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
if isempty(options.waveModeCount)
    if ~isempty(options.waveModeKappa)
        error('WV:TransferWaveCountMap','Supply waveModeCount with explicit waveModeKappa keys.')
    end
    if isempty(self.waveModeCountByKh) || all(self.waveModeCountByKh==self.waveModeCountByKh(1))
        configuration.waveModeCount=length(self.waveMode);
    else
        geometry=WVGeometryDoublyPeriodic([self.Lx self.Ly],Nxyz(1:2),shouldAntialias=self.shouldAntialias,Nz=Nxyz(3),shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
        kappa=unique(hypot(geometry.k,geometry.l)); kappa=kappa(kappa>0);
        counts=zeros(size(kappa));
        for p=1:length(kappa)
            sourcePage=find(self.khUnique==kappa(p));
            if isempty(sourcePage)
                sourcePage=find(abs(self.khUnique-kappa(p))<=64*eps(max(abs(self.khUnique),kappa(p))));
            end
            if numel(sourcePage)~=1
                error('WV:TransferWaveCountMap','The nonuniform source has no unique count for target kappa %.17g. Supply an explicit target waveModeKappa and waveModeCount map.',kappa(p))
            end
            counts(p)=self.waveModeCountByKh(sourcePage);
        end
        configuration.waveModeKappa=kappa;
        configuration.waveModeCount=counts;
    end
end
for name=["shouldAntialias","N2Function","rho0","planetaryRadius","rotationRate","latitude","g","g0","gd","nEVP","gramTolerance","shouldCheckQuadraticAliasing","quadraticAliasingTolerance","modeConvergenceTolerance","boundaryResolutionTolerance"]
    configuration.(name)=self.(name);
end
args=namedargs2cell(configuration);
other=WVTransformFreeSurfaceBoussinesq.fromStratification([self.Lx self.Ly self.Lz],Nxyz,args{:});
other.t=self.t; other.t0=self.t0;
[state,assessment]=self.coefficientStateForTransform(other,modeTolerance=options.modeTolerance);
for name=string(fieldnames(state)).', other.(name)=state.(name); end
WVInternal.transferFreeSurfaceForcing(self,other);
end
