function [self,assessment] = fromStratification(Lxyz,Nxyz,options)
% Solve independent resolved families on one WKB-Chebyshev physical grid.
%
% Omitted counts select independent resolved prefixes on the prescribed grid.
% Convergence and fixed-grid Gram checks determine each linear prefix. A
% common quadratic-dealiasing policy then selects a contiguous sub-prefix.
% Explicit counts are strict under both limits. No basis or quadrature
% weights are fitted.
% Wave/inertial references are always computed, independently of nargout.
% This experimental implementation requires N2>f^2.
%
% - Topic: Create a transform
% - Declaration: [self,assessment] = fromStratification(Lxyz,Nxyz,options)
% - Parameter Lxyz: positive domain lengths in meters
% - Parameter Nxyz: horizontal Fourier sizes and vertical sample count
% - Parameter options.N2Function: positive squared buoyancy frequency versus depth
% - Parameter options.waveModeCount: strict nonnegative prefixes per sign; empty selects automatically; scalar or keyed counts
% - Parameter options.waveModeKappa: physical positive wavenumbers in radians per meter for an explicit complete count map
% - Parameter options.apvModeCount: strict APV count; empty uses the shared QG automatic policy
% - Parameter options.mdaModeCount: strict MDA count; empty uses the shared QG automatic policy
% - Parameter options.inertialModeCount: strict inertial count; empty selects its own qualified prefix
% - Parameter options.nEVP: initial wave/inertial EVP resolution; automatic candidates require at least Nz+4; at most three resolution pairs
% - Parameter options.referenceNEVP: optional fixed higher reference resolution; empty uses a bounded automatically refined reference
% - Parameter options.modeConvergenceTolerance: equivalent-depth and joint field/derivative convergence tolerance
% - Parameter options.gramTolerance: shared fixed-quadrature normalized-Gram tolerance; default 1e-2
% - Parameter options.quadraticDealiasing: vertical policy none, fixedFraction, or effectiveBandwidth; default fixedFraction
% - Parameter options.retainedFraction: fixedFraction retained share of the independently qualified linear prefix; default 2/3
% - Parameter options.energyFraction: effectiveBandwidth cumulative spectral-energy fraction; default 0.99
% - Parameter options.bandwidthFraction: effectiveBandwidth share of the vertical grid degree; default 2/3
% - Parameter options.boundaryResolutionTolerance: fixed zero-APV physical derivative and energy tolerance; default 1e-2
% - Parameter options.g0: surface acceleration for balanced basis; default negative stratification integral
% - Parameter options.gd: bottom acceleration for balanced basis; default positive stratification integral
% - Parameter options.latitude: nonzero latitude in degrees
% - Parameter options.g: gravitational acceleration
% - Parameter options.rho0: reference density
% - Parameter options.rotationRate: planetary rotation rate
% - Parameter options.planetaryRadius: planetary radius in meters
% - Parameter options.shouldAntialias: restrict horizontal bandwidth for nonlinear products; default false for linear dynamics
% - Returns self: zero-state experimental free-surface Boussinesq transform
% - Returns assessment: linear, filtering and selected counts, convergence, Gram, fixed-boundary and quadratic-dealiasing evidence, coverage and construction costs
arguments (Input)
    Lxyz (1,3) double {mustBeReal,mustBeFinite,mustBePositive}
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.N2Function function_handle
    options.waveModeCount (:,1) double {mustBeReal,mustBeInteger,mustBeNonnegative,mustBeFinite} = zeros(0,1)
    options.waveModeKappa (:,1) double {mustBeReal,mustBeFinite,mustBePositive} = zeros(0,1)
    options.apvModeCount (:,1) double {mustBeInteger,mustBePositive} = zeros(0,1)
    options.mdaModeCount (:,1) double {mustBeInteger,mustBePositive} = zeros(0,1)
    options.inertialModeCount (:,1) double {mustBeInteger,mustBePositive} = zeros(0,1)
    options.nEVP (1,1) double {mustBeInteger,mustBePositive} = 64
    options.referenceNEVP (:,1) double {mustBeInteger,mustBePositive,mustBeFinite} = zeros(0,1)
    options.modeConvergenceTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
    options.gramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-2
    options.quadraticDealiasing (1,1) string {mustBeMember(options.quadraticDealiasing,["none","fixedFraction","effectiveBandwidth"])} = "fixedFraction"
    options.retainedFraction (1,1) double {mustBeReal,mustBeFinite,mustBeGreaterThanOrEqual(options.retainedFraction,0),mustBeLessThanOrEqual(options.retainedFraction,1)} = 2/3
    options.energyFraction (1,1) double {mustBeReal,mustBeFinite,mustBeGreaterThan(options.energyFraction,0),mustBeLessThanOrEqual(options.energyFraction,1)} = .99
    options.bandwidthFraction (1,1) double {mustBeReal,mustBeFinite,mustBeGreaterThanOrEqual(options.bandwidthFraction,0),mustBeLessThanOrEqual(options.bandwidthFraction,1)} = 2/3
    options.boundaryResolutionTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-2
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
    options.latitude (1,1) double {mustBeSupportedLatitude} = 30
    options.g (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 9.81
    options.rho0 (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1025
    options.rotationRate (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 7.2921e-5
    options.planetaryRadius (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 6.371e6
    options.shouldAntialias (1,1) logical = false
end
arguments (Output)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    assessment (1,1) struct
end
if numel(options.referenceNEVP)>1 || any(options.referenceNEVP<=options.nEVP)
    error('WVTransformFreeSurfaceBoussinesq:InvalidReferenceResolution','Supply one referenceNEVP greater than nEVP, or leave it empty for an automatically chosen independent reference.')
end
if any([numel(options.apvModeCount),numel(options.mdaModeCount),numel(options.inertialModeCount)]>1)
    error('WV:InvalidModeCount','APV, MDA and inertial counts must be scalar or empty for automatic selection.')
end
constructionTimer=tic;
autoWave=isempty(options.waveModeCount); autoInertial=isempty(options.inertialModeCount);
counts = [options.waveModeCount; options.apvModeCount; options.mdaModeCount; options.inertialModeCount];
if any(counts >= Nxyz(3))
    error('WVTransformFreeSurfaceBoussinesq:InvalidModeCount','Each retained count must be smaller than Nz.')
end
f = 2*options.rotationRate*sind(options.latitude);
profile = chebfun(options.N2Function,[-Lxyz(3) 0]);
if f == 0 || min(profile) <= f^2
    error('WVTransformFreeSurfaceBoussinesq:UnsupportedStratification','The qualified wave band requires nonzero f and N2>f^2 throughout the domain.')
end
balancedOptions = options;
balancedOptions.rhoFunction = @isempty;
balancedOptions.z = zeros(0,1);
balancedOptions.gramTolerance = options.gramTolerance;
balancedOptions.muTolerance = sqrt(eps);
[state,balancedAssessment,vertical] = WVInternal.buildFreeSurfaceBalancedState(Lxyz,Nxyz,balancedOptions);
state.Lxyz = Lxyz; state.Nxyz = Nxyz;
for name = ["shouldAntialias","rho0","planetaryRadius","rotationRate","latitude","g","nEVP","gramTolerance","modeConvergenceTolerance","quadraticDealiasing","retainedFraction","energyFraction","bandwidthFraction","boundaryResolutionTolerance"]
    state.(name) = options.(name);
end
if autoWave && ~isempty(options.waveModeKappa)
    error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','Supply waveModeCount with waveModeKappa, or omit both for automatic selection.')
end
candidateCount=Nxyz(3)-1;
options.nEVP=max(options.nEVP,Nxyz(3)+4);
if ~isempty(options.referenceNEVP) && options.referenceNEVP<=options.nEVP
    error('WVTransformFreeSurfaceBoussinesq:InvalidReferenceResolution','referenceNEVP must exceed the candidate solve resolution, at least Nz+4.')
end
% Explicit physical keys make the count map independent of Fourier ordering.
if isempty(options.waveModeKappa)
    if autoWave
        state.waveModeCountByKh = repmat(candidateCount,numel(state.khUnique),1);
    elseif ~isscalar(options.waveModeCount)
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveCountMap','A vector waveModeCount requires waveModeKappa keys.')
    else
        state.waveModeCountByKh = repmat(options.waveModeCount,numel(state.khUnique),1);
    end
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
requestedMap=state.waveModeCountByKh;
requestedInertial=options.inertialModeCount;
state.waveModeCountByKh=repmat(candidateCount,numel(state.khUnique),1);
options.inertialModeCount=candidateCount;
waveTimer=tic; solveCount=0; waveDealiasingSeconds=0;
for attempt=1:3
    state.nEVP=options.nEVP;
    [state,bases]=WVInternal.buildFreeSurfaceWaveState(state,options);
    activePages=find(state.waveModeCountByKh>0);
    referenceNEVP=options.referenceNEVP;
    if isempty(referenceNEVP), referenceNEVP=max(options.nEVP+16,ceil(1.5*options.nEVP)); end
    [assessment,reference,convergence]=WVInternal.assessWaveModeConstruction(state,bases,activePages,referenceNEVP,options.modeConvergenceTolerance,options);
    waveDealiasingSeconds=waveDealiasingSeconds+assessment.quadraticDealiasingSeconds;
    solveCount=solveCount+2*(numel(activePages)+1);
    desired=assessment.pages.gridSupportedCount;
    desiredInertial=assessment.inertial.gridSupportedCount;
    converged=all(assessment.pages.convergedCount>=desired) && assessment.inertial.convergedCount>=desiredInertial;
    if converged || attempt==3 || ~isempty(options.referenceNEVP), break; end
    options.nEVP=referenceNEVP;
end
waveSeconds=toc(waveTimer);
counts=assessment.pages.usableCount;
if any(isnan(counts)) || isnan(assessment.inertial.usableCount)
    error('WV:InconclusiveModeResolution','Independent EVP comparison did not establish a leading prefix. No automatic count is accepted without a measured reference.')
end
if ~autoWave && any(counts<requestedMap)
    error('WV:StrictWaveModeCountRejected','The explicit wave count map exceeds its converged or fixed-grid Gram prefix. Increase Nz/nEVP or reduce the requested counts; explicit counts are never truncated.')
end
if ~autoInertial && assessment.inertial.usableCount<requestedInertial
    error('WV:StrictInertialModeCountRejected','The explicit inertial count exceeds its converged or fixed-grid Gram prefix. Increase Nz/nEVP or reduce inertialModeCount.')
end
if autoInertial, options.inertialModeCount=assessment.inertial.usableCount; end
if options.inertialModeCount<1
    error('WV:NoResolvedInertialModes','No inertial mode passes the physical-grid and independent convergence checks. Increase Nz/nEVP.')
end
if ~autoWave, counts=requestedMap; end
assessment.pages.candidateCount=repmat(candidateCount,numel(state.khUnique),1);
assessment.inertial.candidateCount=assessment.inertial.requestedCount;
assessment.pages.requestedCount=requestedMap;
if ~autoInertial, assessment.inertial.requestedCount=requestedInertial; end
assessment.apv=balancedAssessment.apv; assessment.mda=balancedAssessment.mda;
assessment.boundary=balancedAssessment.boundary;
assessment.cost=struct(waveEigensolves=solveCount,waveConstructionSeconds=waveSeconds,selectionTrials=0,quadraticDealiasingSeconds=waveDealiasingSeconds+balancedAssessment.cost.quadraticDealiasingSeconds);
assessment=rmfield(assessment,'quadraticDealiasingSeconds');
[state,assessment]=WVInternal.selectFreeSurfaceWaveCounts(state,bases,reference,vertical,counts,options.inertialModeCount,assessment,convergence,options,autoWave,autoInertial);
state.mdaPressureMode=options.g*(state.mdaF-state.mdaF(end,:));
self=WVTransformFreeSurfaceBoussinesq(state);
assessment.cost.constructionSeconds=toc(constructionTimer);
self.constructionAssessment=assessment;
end
