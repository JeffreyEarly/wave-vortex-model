function self = fromStratification(Lxyz,Nxyz,options)
% Solve independent resolved families on one WKB-Chebyshev physical grid.
%
% Explicit family counts are strict retained prefixes. The provider rejects
% a balanced band that does not meet its fixed-grid qualification. Wave and
% inertial Gram errors are checked separately without fitting weights or
% changing the basis. This initial wave implementation requires N2>f^2.
%
% - Topic: Create a transform
% - Declaration: self = fromStratification(Lxyz,Nxyz,options)
% - Parameter Lxyz: positive domain lengths in meters
% - Parameter Nxyz: horizontal Fourier sizes and vertical sample count
% - Parameter options.N2Function: positive squared buoyancy frequency versus depth
% - Parameter options.waveModeCount: wave modes per frequency sign, including external mode
% - Parameter options.apvModeCount: independent APV mode count
% - Parameter options.mdaModeCount: independent mean-density-anomaly count
% - Parameter options.inertialModeCount: independent inertial mode count
% - Parameter options.nEVP: wave/inertial spectral solve resolution
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
arguments (Input)
    Lxyz (1,3) double {mustBeReal,mustBeFinite,mustBePositive}
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.N2Function function_handle
    options.waveModeCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.apvModeCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive} = 2
    options.inertialModeCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.nEVP (1,1) double {mustBeInteger,mustBePositive} = 64
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
end
counts = [options.waveModeCount options.apvModeCount options.mdaModeCount options.inertialModeCount];
if any(counts >= Nxyz(3)) || any([options.waveModeCount options.inertialModeCount] >= options.nEVP)
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
state.waveMode = (1:options.waveModeCount).';
state.inertialMode = (1:options.inertialModeCount).';
nz = length(state.z); nw = length(state.waveMode); np = length(state.khUnique);
state.waveF = zeros(nz,nw,np); state.waveG = zeros(nz,nw,np);
state.waveGForward = zeros(nw,nz,np); state.waveEquivalentDepth = zeros(nw,np);
state.waveFrequency = zeros(nw,np); state.waveGramError = zeros(np,1);
solver = IMSolverSpectral(nEVP=options.nEVP,coordinateKind="wkb");
% Share coordinate preparation across the exact requested wave pencils.
% Zero wavenumber has its own count and must be evaluated separately.
bases = solver.solveWaveModesAtWavenumbers([0 state.khUnique(:).'],N2=state.N2Function,zDomain=[-Lxyz(3) 0],f0=f,g=options.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=nw,nInertialModes=options.inertialModeCount);
for p = 0:np
    basis = bases.bases{bases.basisIndex(p+1)};
    h = basis.h(:);
    if p == 0, count = options.inertialModeCount; else, count = nw; end
    if any(h<=0) || length(h)~=count
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveBand','The requested wave/inertial prefix must contain only finite positive equivalent depths.')
    end
    if p == 0
        state.inertialEquivalentDepth = h;
        state.inertialModeNumber = basis.modeNumber(:);
    else
        state.waveEquivalentDepth(:,p) = h;
        state.waveFrequency(:,p) = sqrt(f^2+options.g*h*state.khUnique(p)^2);
        if p == 1, state.waveModeNumber = basis.modeNumber(:); end
    end
end
state.inertialF = bases.evaluate(state.z,variable="F",pages=1);
state.inertialFForward = (state.inertialF'.*state.verticalQuadratureWeights.')./state.inertialEquivalentDepth;
state.inertialGramError = norm(state.inertialFForward*state.inertialF-eye(options.inertialModeCount),2);
if np > 0
    bases.evaluateChunks(state.z,@acceptWaveF,variable="F",pages=2:np+1);
    bases.evaluateChunks(state.z,@acceptWaveG,variable="G",pages=2:np+1);
end
% Preserve the prescribed physical pairing, including the surface term.
for p = 1:np
    G = state.waveG(:,:,p);
    forward = G'.*(state.verticalQuadratureWeights.*((state.N2Function(state.z)-f^2)/options.g)).';
    forward(:,end) = forward(:,end)+G(end,:).';
    state.waveGForward(:,:,p) = forward;
    state.waveGramError(p) = norm(forward*G-eye(nw),2);
end
if np == 0, state.waveModeNumber = state.waveMode; end
if max([state.waveGramError;state.inertialGramError]) > options.projectionTolerance
    error('WVTransformFreeSurfaceBoussinesq:UnderresolvedWaveGrid','Wave/inertial Gram error %.3g exceeds %.3g. Increase Nz or reduce retained counts; the resolved modes have not been changed.',max([state.waveGramError;state.inertialGramError]),options.projectionTolerance)
end
% MDA pressure has zero surface gauge and follows the stored G modes:
% dp/dz=-rho0*N2*eta. The provider F differs only by its surface constant.
state.mdaPressureMode = options.g*(state.mdaF-state.mdaF(end,:));
self = WVTransformFreeSurfaceBoussinesq(state);

    function acceptWaveF(values,rows,~,pages)
        state.waveF(rows,:,pages-1) = values;
    end

    function acceptWaveG(values,rows,~,pages)
        state.waveG(rows,:,pages-1) = values;
    end
end
