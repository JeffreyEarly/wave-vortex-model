function inputs = resolveScientificInputs(Lz,options)
% Resolve stratification, endpoint parameters, and rotation for construction.
arguments
    Lz (1,1) double {mustBePositive}
    options struct
end

zDomain = [-Lz 0];
if isequal(options.N2Function,@isempty) && isequal(options.rhoFunction,@isempty)
    error('WVTransformFreeSurfaceQG:MissingStratification','Supply either N2Function or rhoFunction.');
end
if isequal(options.N2Function,@isempty)
    derivativeStep = max(1,Lz)*eps^(1/3);
    N2Function = @(z) stratificationFromDensity(z,options.rhoFunction,options.rho0,options.g,zDomain,derivativeStep);
else
    N2Function = options.N2Function;
end
if isequal(options.rhoFunction,@isempty)
    rhoFunction = @(z) densityFromStratification(z,N2Function,options.rho0,options.g);
else
    rhoFunction = options.rhoFunction;
end

g0 = options.g0;
gd = options.gd;
if isnan(g0) || isnan(gd)
    columnGravity = integral(N2Function,-Lz,0);
    if isnan(g0), g0 = -columnGravity; end
    if isnan(gd), gd = columnGravity; end
end
if isnan(g0) || g0 == -Inf || isnan(gd) || gd == -Inf
    error('WVTransformFreeSurfaceQG:InvalidEndpointAcceleration','g0 and gd must be signed finite, zero, or positive Inf.');
end
endpointScale = max([options.g,abs(g0(isfinite(g0))),abs(gd(isfinite(gd))),1]);
if (isfinite(g0) && abs(g0) <= sqrt(eps)*endpointScale) || (isfinite(gd) && abs(gd) <= sqrt(eps)*endpointScale)
    warning('WVTransformFreeSurfaceQG:NearZeroEndpointAcceleration','A finite endpoint acceleration is near zero; verify that the corresponding limiting boundary condition is intended.');
end

f0 = 2*options.rotationRate*sind(options.latitude);
if f0 == 0
    error('WVTransformFreeSurfaceQG:ZeroCoriolis','Free-surface QG construction requires nonzero Coriolis frequency.');
end

inputs = struct(N2Function=N2Function,rhoFunction=rhoFunction,g0=g0,gd=gd,f0=f0,zDomain=zDomain);
end

function rho = densityFromStratification(z,N2Function,rho0,g)
shape = size(z);
z = z(:);
rho = zeros(size(z));
for iPoint = 1:length(z)
    rho(iPoint) = rho0-(rho0/g)*integral(N2Function,0,z(iPoint));
end
rho = reshape(rho,shape);
end

function N2 = stratificationFromDensity(z,rhoFunction,rho0,g,zDomain,derivativeStep)
shape = size(z);
z = z(:);
zMinus = max(z-derivativeStep,zDomain(1));
zPlus = min(z+derivativeStep,zDomain(2));
if any(zPlus <= zMinus)
    error('WVTransformFreeSurfaceQG:InvalidDensityEvaluationPoint','Density-derived stratification was requested outside the vertical domain.');
end
rhoMinus = reshape(rhoFunction(zMinus),[],1);
rhoPlus = reshape(rhoFunction(zPlus),[],1);
if length(rhoMinus) ~= length(z) || length(rhoPlus) ~= length(z)
    error('WVTransformFreeSurfaceQG:InvalidDensityFunction','rhoFunction must return one value per input depth.');
end
N2 = -(g/rho0)*(rhoPlus-rhoMinus)./(zPlus-zMinus);
N2 = reshape(N2,shape);
end
