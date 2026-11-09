function inputs = resolveFreeSurfaceInputs(Lz,options)
% Resolve stratification, endpoint parameters, and rotation for construction.
arguments
    Lz (1,1) double {mustBePositive}
    options struct
end

hasN2 = ~isequal(options.N2Function,@isempty);
hasDensity = ~isequal(options.rhoFunction,@isempty);
hasSpline = isfield(options,"rhoSpline") && ~isempty(options.rhoSpline);
if ~hasN2 && ~hasDensity && ~hasSpline
    error('WVTransformFreeSurfaceQG:MissingStratification','Supply N2Function, rhoFunction, or rhoSpline.');
end
physics = struct(zDomain=[-Lz 0],rotationRate=options.rotationRate,latitude=options.latitude,g=options.g,surfaceCondition="freeSurface");
if hasN2
    physics.N2 = options.N2Function;
end
if hasDensity
    physics.rho = options.rhoFunction;
end
if hasSpline
    if ~ismember('rhoSplineRecord',properties('IMBackground'))
        error('WV:DensitySplineProviderRequired','Supply an InternalModes version that supports the rhoSpline background input.');
    end
    physics.rhoSpline = options.rhoSpline;
end
if isfield(options,"rho0")
    physics.rho0 = options.rho0;
end
backgroundArguments = namedargs2cell(physics);
background = IMBackground(backgroundArguments{:});

g0 = options.g0;
gd = options.gd;
if isnan(g0) || isnan(gd)
    if hasSpline
        columnGravity = (background.g/background.rho0)*(background.rho(-Lz)-background.rho(0));
    else
        columnGravity = integral(background.N2,background.zDomain(1),background.zDomain(2));
    end
    if isnan(g0), g0 = -columnGravity; end
    if isnan(gd), gd = columnGravity; end
end
if isnan(g0) || g0 == -Inf || isnan(gd) || gd == -Inf
    error('WVTransformFreeSurfaceQG:InvalidEndpointAcceleration','g0 and gd must be signed finite, zero, or positive Inf.');
end
endpointScale = max([background.g,abs(g0(isfinite(g0))),abs(gd(isfinite(gd))),1]);
if (isfinite(g0) && abs(g0) <= sqrt(eps)*endpointScale) || (isfinite(gd) && abs(gd) <= sqrt(eps)*endpointScale)
    warning('WVTransformFreeSurfaceQG:NearZeroEndpointAcceleration','A finite endpoint acceleration is near zero; verify that the corresponding limiting boundary condition is intended.');
end

if background.f0 == 0
    error('WVTransformFreeSurfaceQG:ZeroCoriolis','Free-surface QG construction requires nonzero Coriolis frequency.');
end

inputs = struct(background=background,g0=g0,gd=gd);
if hasSpline, inputs.rhoSplineRecord = background.rhoSplineRecord; end
end
