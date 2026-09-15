function [w,manifest] = thermalReadinessCase(configuration,options)
% Construct or restore one immutable authoring case for thermal readiness.
% A source transform is authoritative: transfer its physical state without
% renormalizing the target. The cache holds scientific and coefficient arrays,
% not an integrator or an independently reconstructed scientific basis.
% - Topic: Developer utilities
% - Parameter configuration: declared case overrides; unknown fields are rejected
% - Parameter options.scientificState: optional authoritative construction cache
% - Parameter options.source: optional thermal transform supplying the initial physical state
% - Parameter options.cacheFile: optional immutable MAT case cache; existing contents are checked
% - Returns w: initialized thermal transform with the selected physical forcings
% - Returns manifest: case identity, normalization, fit, clocks and stored-array identities
arguments (Input)
    configuration (1,1) struct = struct()
    options.scientificState (1,1) struct = struct()
    options.source = []
    options.cacheFile (1,1) string = ""
end
arguments (Output)
    w (1,1) WVTransformFreeSurfaceThermalQG
    manifest (1,1) struct
end
configuration = completeConfiguration(configuration);
sourceHash = "";
if ~isempty(options.source)
    if ~isa(options.source,'WVTransformFreeSurfaceThermalQG') || ~isscalar(options.source)
        error('WV:ReadinessSource','Supply one authoritative thermal source transform.');
    end
    sourceHash = thermalReadinessIdentity(struct(scientificState=options.source.scientificState,coefficientState=options.source.coefficientState()));
end
requestHash = thermalReadinessIdentity(struct(configuration=configuration,sourceStateHash=sourceHash));
try
    if options.cacheFile ~= "" && isfile(options.cacheFile)
        cache = load(options.cacheFile,'scientificState','coefficientState','manifest');
        if ~all(isfield(cache,{'scientificState','coefficientState','manifest'})) || ~all(isfield(cache.manifest,{'requestHash','scientificStateHash','coefficientStateHash','caseId'})) || cache.manifest.requestHash ~= requestHash
            error('WV:ReadinessCacheIdentity','The existing case cache belongs to a different declared configuration or initial state.');
        end
        if thermalReadinessIdentity(rmfield(cache.manifest,'caseId')) ~= cache.manifest.caseId
            error('WV:ReadinessCacheIdentity','The stored case manifest does not match its recorded identity.');
        end
        if ~isempty(fieldnames(options.scientificState)) && thermalReadinessIdentity(options.scientificState) ~= cache.manifest.scientificStateHash
            error('WV:ReadinessCacheIdentity','The supplied scientific arrays disagree with the existing authoritative case cache.');
        end
        if thermalReadinessIdentity(cache.scientificState) ~= cache.manifest.scientificStateHash || thermalReadinessIdentity(cache.coefficientState) ~= cache.manifest.coefficientStateHash
            error('WV:ReadinessCacheIdentity','The case cache arrays do not match their recorded identities.');
        end
        w = WVTransformFreeSurfaceThermalQG(scientificState=cache.scientificState,coefficientState=cache.coefficientState,t=configuration.t);
        manifest = cache.manifest;
    else
        if isempty(fieldnames(options.scientificState))
            c = configuration;
            w = WVTransformFreeSurfaceThermalQG.fromStratification(c.domainSize,[c.Nx c.Ny c.Nz],N2Function=@(z)c.N0^2*exp(2*c.inverseScale*z),thermalModeCount=c.thermalCount,mdaModeCount=c.mdaCount,kappa_z=c.kappa_z,latitude=c.latitude,assemblyQuadratureCount=c.assemblyCount,nonlinearQuadratureCount=c.productCount,shouldCheckQuadraticAliasing=true);
        else
            w = WVTransformFreeSurfaceThermalQG(scientificState=options.scientificState);
        end
        validateScientificState(w,configuration);
        if isempty(options.source)
            [normalization,fit] = initializeState(w,configuration);
        else
            if isequal(options.source.scientificState,w.scientificState)
                state=options.source.coefficientState();
                fit=struct(method="identical scientific arrays; exact canonical copy",relativeFieldError=0,qgpvRMS=0,buoyancyRMS=0,velocityRMS=0,endpointRMS=zeros(2,1),sshRMS=0,meanDisplacementRMS=0,errorEnergy=0,discardedFourierCount=0);
            else
                [state,fit] = options.source.coefficientStateForTransform(w);
            end
            w.Ath = state.Ath;
            w.Amda = state.Amda;
            normalization = struct(method="authoritative physical transfer; no target renormalization",factor=NaN,sourceStateHash=sourceHash);
        end
        w.t = configuration.t;
        w.t0 = configuration.t0;
        scientificState = w.scientificState;
        coefficientState = w.coefficientState();
        manifest = struct(schema="thermal-readiness-case-v1",configuration=configuration,requestHash=requestHash,sourceStateHash=sourceHash,normalization=normalization,initialFit=fit,scientificStateHash=thermalReadinessIdentity(scientificState),coefficientStateHash=thermalReadinessIdentity(coefficientState),actualAssemblyCount=w.assemblyQuadratureCount,actualProductCount=w.nonlinearQuadratureCount,activeEndpoints=w.activeEndpoint,seasonalArgument=2*pi*w.t/configuration.period+configuration.phase);
        manifest.caseId = thermalReadinessIdentity(manifest);
        if options.cacheFile ~= ""
            folder = fileparts(options.cacheFile);
            if folder ~= "" && ~isfolder(folder), mkdir(folder); end
            save(options.cacheFile,'scientificState','coefficientState','manifest','-v7.3');
        end
    end
    validateScientificState(w,configuration);
    w.t = configuration.t;
    w.t0 = configuration.t0;
    registerForcings(w,configuration);
catch exception
    % The target belongs to this helper until it returns successfully. Never
    % delete options.source, which remains owned by the caller.
    if exist('w','var') && isvalid(w), delete(w); end
    rethrow(exception);
end
end

function c = completeConfiguration(given)
c = struct(kind="developed",Nx=64,Ny=64,Nz=385,thermalCount=257,mdaCount=4,assemblyCount=2057,productCount=1537,domainSize=[5e5 5e5 4000],latitude=24,N0=5.2e-3,inverseScale=1/1300,kappa_z=1e-5,seasonalM=10,period=365.25*86400,phase=0,t=0,t0=0,seedRMS=.01,velocityRMS=.01,meanAmplitude=.1,normalizationCount=513,shouldIncludeAdvection=true,shouldIncludeSeasonal=true,shouldIncludeBottomDrag=true,Cd=1e-3);
unknown = setdiff(fieldnames(given),fieldnames(c));
if ~isempty(unknown), error('WV:ReadinessConfiguration','Unknown case field %s.',unknown{1}); end
for name = string(fieldnames(given)).', c.(name) = given.(name); end
c.kind = string(c.kind);
if ~isscalar(c.kind) || ~ismember(c.kind,["cold","developed"])
    error('WV:ReadinessConfiguration','Case kind must be cold or developed.');
end
if c.kind == "cold" && ~isfield(given,'meanAmplitude'), c.meanAmplitude = 0; end
for name = ["Nx","Ny","Nz","thermalCount","mdaCount","normalizationCount"]
    validateattributes(c.(name),{'double'},{'scalar','integer','finite','>=',4},mfilename,char(name));
end
for name = ["assemblyCount","productCount"]
    validateattributes(c.(name),{'double'},{'scalar','integer','finite','nonnegative'},mfilename,char(name));
end
validateattributes(c.domainSize,{'double'},{'size',[1 3],'real','finite','positive'});
for name = ["N0","period","normalizationCount"]
    validateattributes(c.(name),{'double'},{'scalar','real','finite','positive'},mfilename,char(name));
end
for name = ["kappa_z","seasonalM","seedRMS","velocityRMS","meanAmplitude","Cd","t","t0"]
    validateattributes(c.(name),{'double'},{'scalar','real','finite','nonnegative'},mfilename,char(name));
end
for name = ["latitude","inverseScale","phase"]
    validateattributes(c.(name),{'double'},{'scalar','real','finite'},mfilename,char(name));
end
for name = ["shouldIncludeAdvection","shouldIncludeSeasonal","shouldIncludeBottomDrag"]
    validateattributes(c.(name),{'logical'},{'scalar'},mfilename,char(name));
end
if c.thermalCount < 5 || c.Nx < 8 || c.Ny < 8 || c.normalizationCount < 65
    error('WV:ReadinessConfiguration','Use at least five thermal directions, an 8-by-8 grid and 65 common normalization points.');
end
if c.shouldIncludeSeasonal && c.Ny < 18
    error('WV:ReadinessSeasonalSupport','Annual meridional mode 5 requires Ny >= 18 with horizontal antialiasing.');
end
if c.kind == "cold" && c.meanAmplitude ~= 0
    error('WV:ReadinessColdStart','The cold start has zero mean anomaly.');
end
end

function validateScientificState(w,c)
if ~isequal(w.domainSize,c.domainSize.') || ~isequal(w.gridSize,[c.Nx;c.Ny;c.Nz]) || w.thermalModeCount ~= c.thermalCount || w.mdaModeCount ~= c.mdaCount || abs(w.N20-c.N0^2)>10*eps(c.N0^2) || abs(w.inverseScale-c.inverseScale)>10*eps(max(1,abs(c.inverseScale))) || w.latitude ~= c.latitude || w.kappa_z ~= c.kappa_z || ~w.shouldCheckQuadraticAliasing || numel(w.activeEndpoint) ~= 2
    error('WV:ReadinessScientificState','Stored scientific arrays do not match the declared case physics, resolution or nonlinear policy.');
end
if (c.assemblyCount > 0 && w.assemblyQuadratureCount ~= c.assemblyCount) || (c.productCount > 0 && w.nonlinearQuadratureCount ~= c.productCount)
    error('WV:ReadinessScientificState','Stored assembly/product counts do not match the declared case.');
end
end

function [normalization,fit] = initializeState(w,c)
w.Ath = zeros(size(w.Ath));
w.Amda = zeros(size(w.Amda));
if c.kind == "cold"
    [X,Y] = ndgrid(w.x,w.y);
    factor = c.seedRMS/sqrt((1+.49+.09)/2);
    surface = factor*(cos(2*pi*X/w.Lx)+.7*sin(4*pi*Y/w.Ly)+.3*cos(2*pi*(X/w.Lx+Y/w.Ly)));
    endpoints = zeros(w.Nx,w.Ny,2);
    endpoints(:,:,1) = surface;
    [state,fit] = w.projectState(zeros(w.spatialMatrixSize),endpoints);
    if fit.qgpvRMS > 1e-12 || max(fit.endpointRMS) > 1e-9
        error('WV:ReadinessColdStartFit','The declared zero-QGPV cold start is unresolved: QGPV RMS %.3g, endpoint RMS %.3g m.',fit.qgpvRMS,max(fit.endpointRMS));
    end
    w.Ath = state.Ath;
    w.Amda = state.Amda;
    normalization = struct(method="analytic common-support surface RMS; applied once",factor=factor,unnormalizedRMS=sqrt((1+.49+.09)/2),targetRMS=c.seedRMS,horizontalModes=[1 0;0 2;1 1]);
else
    modes = [1 0;0 2;1 1];
    pressure = complex(zeros(5,3));
    phases = [1,.7+.2i,-.4+.3i];
    for j = 1:3
        pressure([1 2 j+2],j) = [1;.3;1]*phases(j);
    end
    [nodes,weights] = legpts(c.normalizationCount);
    z = (nodes-1)*w.Lz/2;
    fields = WVInternal.thermalPolynomialFields(z,5,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
    kh2 = (2*pi*modes(:,1)/w.Lx).^2+(2*pi*modes(:,2)/w.Ly).^2;
    unnormalizedRMS = sqrt(sum(weights(:).*abs(fields.psi*pressure).^2.*kh2.','all'));
    factor = c.velocityRMS/unnormalizedRMS;
    pressure = factor*pressure;
    for j = 1:3
        column = find(w.kMode_wv(w.klNonzero)==modes(j,1) & w.lMode_wv(w.klNonzero)==modes(j,2));
        if ~isscalar(column), error('WV:ReadinessInitialSupport','The common-support pressure mode is unavailable.'); end
        polynomial = complex(zeros(w.thermalModeCount,1));
        polynomial(1:5) = pressure(:,j);
        page = w.klNonzeroKhUniqueIndex(column);
        w.Ath(:,column) = w.polynomialToThermal(:,:,page)*polynomial;
    end
    w.Amda(1:4) = c.meanAmplitude*[1;-2;3;-1];
    fit = struct(method="declared low-degree pressure in the thermal WKB polynomial space",qgpvRMS=NaN,endpointRMS=[NaN;NaN]);
    normalization = struct(method="fixed physical quadrature of prescribed pressure; applied once",factor=factor,unnormalizedRMS=unnormalizedRMS,targetRMS=c.velocityRMS,quadratureCount=c.normalizationCount,horizontalModes=modes,pressurePolynomial=pressure,polynomialCoordinate="normalized WKB coordinate",meanCoefficients=w.Amda);
end
end

function registerForcings(w,c)
if c.shouldIncludeAdvection, w.addForcing(WVNonlinearAdvection(w)); end
if c.shouldIncludeSeasonal
    pattern = repmat(sin(10*pi*w.y'/w.Ly),w.Nx,1);
    w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=c.seasonalM*pi/c.period,period=c.period,phase=c.phase));
end
if c.shouldIncludeBottomDrag, w.addForcing(WVBottomFrictionQuadratic(w,Cd=c.Cd)); end
end
