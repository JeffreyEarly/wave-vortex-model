function [self,assessment] = fromStratification(Lxyz,Nxyz,options)
% Solve independent resolved families on one WKB-Chebyshev physical grid.
%
% Explicit family counts are strict retained prefixes. The provider rejects
% a balanced band that does not meet its fixed-grid qualification. Wave and
% inertial Gram errors are checked separately without fitting weights or
% changing the basis. This initial wave implementation requires N2>f^2.
%
% - Topic: Create a transform
% - Declaration: [self,assessment] = fromStratification(Lxyz,Nxyz,options)
% - Parameter Lxyz: positive domain lengths in meters
% - Parameter Nxyz: horizontal Fourier sizes and vertical sample count
% - Parameter options.N2Function: positive squared buoyancy frequency versus depth
% - Parameter options.waveModeCount: nonnegative retained prefixes per sign; scalar or counts keyed by waveModeKappa
% - Parameter options.waveModeKappa: physical positive wavenumbers in radians per meter for explicit counts; empty uses a uniform scalar
% - Parameter options.apvModeCount: independent APV mode count
% - Parameter options.mdaModeCount: independent mean-density-anomaly count
% - Parameter options.inertialModeCount: independent inertial mode count
% - Parameter options.nEVP: wave/inertial spectral solve resolution
% - Parameter options.referenceNEVP: optional higher resolution for explicit mode-convergence assessment
% - Parameter options.modeConvergenceTolerance: equivalent-depth and joint field/derivative convergence tolerance
% - Parameter options.projectionTolerance: per-family fixed-quadrature Gram tolerance
% - Parameter options.g0: surface acceleration for balanced basis; default negative stratification integral
% - Parameter options.gd: bottom acceleration for balanced basis; default positive stratification integral
% - Parameter options.latitude: nonzero latitude in degrees
% - Parameter options.g: gravitational acceleration
% - Parameter options.rho0: reference density
% - Parameter options.rotationRate: planetary rotation rate
% - Parameter options.planetaryRadius: planetary radius in meters
% - Parameter options.shouldAntialias: apply existing horizontal antialiasing rule
% - Returns self: zero-state experimental free-surface Boussinesq transform
% - Returns assessment: per-kappa linear convergence and sampled-grid evidence for the actual constructed modes; no additional solve unless referenceNEVP is supplied
arguments (Input)
    Lxyz (1,3) double {mustBeReal,mustBeFinite,mustBePositive}
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.N2Function function_handle
    options.waveModeCount (:,1) double {mustBeReal,mustBeInteger,mustBeNonnegative,mustBeFinite} = 4
    options.waveModeKappa (:,1) double {mustBeReal,mustBeFinite,mustBePositive} = zeros(0,1)
    options.apvModeCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive} = 2
    options.inertialModeCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.nEVP (1,1) double {mustBeInteger,mustBePositive} = 64
    options.referenceNEVP (:,1) double {mustBeInteger,mustBePositive,mustBeFinite} = zeros(0,1)
    options.modeConvergenceTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
    options.projectionTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-7
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
    options.latitude (1,1) double {mustBeSupportedLatitude} = 30
    options.g (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 9.81
    options.rho0 (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1025
    options.rotationRate (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 7.2921e-5
    options.planetaryRadius (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 6.371e6
    options.shouldAntialias (1,1) logical = true
end
arguments (Output)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    assessment (1,1) struct
end
if numel(options.referenceNEVP)>1 || any(options.referenceNEVP<=options.nEVP)
    error('WVTransformFreeSurfaceBoussinesq:InvalidReferenceResolution','Supply one referenceNEVP greater than nEVP, or leave it empty to avoid an additional solve.')
end
counts = [options.waveModeCount; options.apvModeCount; options.mdaModeCount; options.inertialModeCount];
if any(counts >= Nxyz(3)) || any([options.waveModeCount; options.inertialModeCount] >= options.nEVP)
    error('WVTransformFreeSurfaceBoussinesq:InvalidModeCount','Each retained count must be smaller than Nz; wave and inertial counts must also be smaller than nEVP.')
end
f = 2*options.rotationRate*sind(options.latitude);
profile = chebfun(options.N2Function,[-Lxyz(3) 0]);
if f == 0 || min(profile) <= f^2
    error('WVTransformFreeSurfaceBoussinesq:UnsupportedStratification','The qualified wave band requires nonzero f and N2>f^2 throughout the domain.')
end
balancedOptions = options;
balancedOptions.rhoFunction = @isempty;
balancedOptions.z = zeros(0,1);
balancedOptions.apvGramTolerance = options.projectionTolerance;
balancedOptions.mdaGramTolerance = options.projectionTolerance;
balancedOptions.quadraticAliasingTolerance = .1;
balancedOptions.muTolerance = sqrt(eps);
state = WVInternal.buildFreeSurfaceBalancedState(Lxyz,Nxyz,balancedOptions);
state.Lxyz = Lxyz; state.Nxyz = Nxyz;
for name = ["shouldAntialias","rho0","planetaryRadius","rotationRate","latitude","g","nEVP","projectionTolerance"]
    state.(name) = options.(name);
end
% Explicit physical keys make the count map independent of Fourier ordering.
if isempty(options.waveModeKappa)
    if ~isscalar(options.waveModeCount)
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','A vector waveModeCount requires waveModeKappa keys.')
    end
    state.waveModeCountByKh = repmat(options.waveModeCount,numel(state.khUnique),1);
else
    keyedCounts = options.waveModeCount;
    if isscalar(keyedCounts), keyedCounts = repmat(keyedCounts,size(options.waveModeKappa)); end
    if numel(keyedCounts) ~= numel(options.waveModeKappa)
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','Supply one count per waveModeKappa key, or one scalar count to broadcast.')
    end
    state.waveModeCountByKh = nan(numel(state.khUnique),1);
    for iKey = 1:numel(options.waveModeKappa)
        key = options.waveModeKappa(iKey);
        matches = find(state.khUnique==key);
        if isempty(matches)
            matches = find(abs(state.khUnique-key) <= 64*eps(max(abs(state.khUnique),abs(key))));
        end
        if numel(matches) ~= 1
            error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','Every waveModeKappa key must match one supported positive horizontal wavenumber.')
        end
        previous = state.waveModeCountByKh(matches);
        if ~isnan(previous) && previous ~= keyedCounts(iKey)
            error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','Repeated physical wavenumber keys must have the same count.')
        end
        state.waveModeCountByKh(matches) = keyedCounts(iKey);
    end
    if any(isnan(state.waveModeCountByKh))
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','The explicit count map must cover every supported positive horizontal wavenumber.')
    end
end
state.waveMode = (1:max([state.waveModeCountByKh;0])).';
state.inertialMode = (1:options.inertialModeCount).';
nz = length(state.z); nw = length(state.waveMode); np = length(state.khUnique);
state.waveF = zeros(nz,nw,np); state.waveG = zeros(nz,nw,np);
state.waveGForward = zeros(nw,nz,np); state.waveEquivalentDepth = zeros(nw,np);
state.waveFrequency = zeros(nw,np); state.waveGramError = zeros(np,1);
solver = IMSolverSpectral(nEVP=options.nEVP,coordinateKind="wkb");
% Share coordinate preparation across the exact requested wave pencils.
% Zero wavenumber has its own count and must be evaluated separately.
activePages = find(state.waveModeCountByKh > 0);
bases = solver.solveWaveModesAtWavenumbers([0 state.khUnique(activePages).'],N2=state.N2Function,zDomain=[-Lxyz(3) 0],f0=f,g=options.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=state.waveModeCountByKh(activePages).',nInertialModes=options.inertialModeCount);
for iPage = 1:numel(activePages)+1
    if iPage == 1, p = 0; else, p = activePages(iPage-1); end
    basis = bases.bases{bases.basisIndex(iPage)};
    h = basis.h(:);
    if p == 0, count = options.inertialModeCount; else, count = state.waveModeCountByKh(p); end
    if any(h<=0) || length(h)~=count
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveBand','The requested wave/inertial prefix must contain only finite positive equivalent depths.')
    end
    if p == 0
        state.inertialEquivalentDepth = h;
        state.inertialModeNumber = basis.modeNumber(:);
    else
        state.waveEquivalentDepth(1:count,p) = h;
        state.waveFrequency(1:count,p) = sqrt(f^2+options.g*h*state.khUnique(p)^2);
        if count == nw, state.waveModeNumber = basis.modeNumber(:); end
    end
end
state.inertialF = bases.evaluate(state.z,variable="F",pages=1);
state.inertialFForward = (state.inertialF'.*state.verticalQuadratureWeights.')./state.inertialEquivalentDepth;
state.inertialGramError = norm(state.inertialFForward*state.inertialF-eye(options.inertialModeCount),2);
% Homogeneous count groups share evaluation while preserving exact prefixes.
for count = unique(state.waveModeCountByKh(activePages)).'
    collectionPages = find(state.waveModeCountByKh(activePages) == count).'+1;
    bases.evaluateChunks(state.z,@acceptWaveF,variable="F",pages=collectionPages);
    bases.evaluateChunks(state.z,@acceptWaveG,variable="G",pages=collectionPages);
end
% Preserve the prescribed physical pairing, including the surface term.
for p = 1:np
    count = state.waveModeCountByKh(p);
    if count == 0, continue; end
    G = state.waveG(:,1:count,p);
    forward = G'.*(state.verticalQuadratureWeights.*((state.N2Function(state.z)-f^2)/options.g)).';
    forward(:,end) = forward(:,end)+G(end,:).';
    state.waveGForward(1:count,:,p) = forward;
    state.waveGramError(p) = norm(forward*G-eye(count),2);
end
if nw == 0, state.waveModeNumber = state.waveMode; end
if max([state.waveGramError;state.inertialGramError]) > options.projectionTolerance
    error('WVTransformFreeSurfaceBoussinesq:UnderresolvedWaveGrid','Wave/inertial Gram error %.3g exceeds %.3g. Increase Nz or reduce retained counts; the resolved modes have not been changed.',max([state.waveGramError;state.inertialGramError]),options.projectionTolerance)
end
% MDA pressure has zero surface gauge and follows the stored G modes:
% dp/dz=-rho0*N2*eta. The provider F differs only by its surface constant.
state.mdaPressureMode = options.g*(state.mdaF-state.mdaF(end,:));
self = WVTransformFreeSurfaceBoussinesq(state);
assessment=struct();
if nargout>1 || ~isempty(options.referenceNEVP)
    assessment=WVInternal.assessWaveModeConstruction(state,bases,activePages,options.referenceNEVP,options.modeConvergenceTolerance);
end

    function acceptWaveF(values,rows,~,pages)
        state.waveF(rows,1:size(values,2),activePages(pages-1)) = values;
    end

    function acceptWaveG(values,rows,~,pages)
        state.waveG(rows,1:size(values,2),activePages(pages-1)) = values;
    end
end
