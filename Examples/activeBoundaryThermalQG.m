function result = activeBoundaryThermalQG(options)
% Diffuse a balanced ThermalQG state with homogeneous buoyancy fluxes.
%
% Add the package's Examples folder to the MATLAB path. The initial state
% contains a nonzero horizontal thermal mode and a mean density anomaly.
% Thermal dimension, vertical sampling and assembly quadrature can be
% varied independently. Energy is the positive quadratic physical energy.
%
% result = activeBoundaryThermalQG(profile="exponential")
arguments (Input)
    options.profile (1,1) string {mustBeMember(options.profile,["constant","exponential"])} = "constant"
    options.Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.Nz,33)} = 65
    options.thermalModeCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.thermalModeCount,5)} = 17
    options.assemblyQuadratureCount (1,1) double {mustBeInteger,mustBePositive} = 257
    options.finalTime (1,1) double {mustBeNonnegative,mustBeFinite} = 86400
    options.timeStep (1,1) double {mustBePositive,mustBeFinite} = 10800
end
arguments (Output)
    result (1,1) struct
end

inverseScale = 0;
if options.profile=="exponential", inverseScale = 1/700; end
N2 = @(z) 1e-4*exp(2*inverseScale*z);
D = 100;
kappa_z = 1e-2;
w = WVTransformFreeSurfaceThermalQG.fromStratification([100e3 100e3 D],[4 4 options.Nz],N2Function=N2, ...
    latitude=30,thermalModeCount=options.thermalModeCount,mdaModeCount=4,kappa_z=kappa_z, ...
    shouldAntialias=false,shouldCheckQuadraticAliasing=false,assemblyQuadratureCount=options.assemblyQuadratureCount);

% Manufacture a streamfunction with zero surface value and zero second
% derivative at both endpoints. Its buoyancy has homogeneous Neumann data.
xi = 1+w.z/D;
psi = 10*(xi.^3/6-xi.^4/12-1/12);
psiZ = (10/D)*(xi.^2/2-xi.^3/3);
psiZZ = (10/D^2)*(xi-xi.^2);
eta = -w.f*psiZ./w.N2;
etaZ = -w.f*(psiZZ-2*inverseScale*psiZ)./w.N2;
k = 2*pi/w.Lx;
[X,~] = ndgrid(w.x,w.y);
pattern = cos(k*X);
qgpv = pattern.*reshape(-k^2*psi-w.f*etaZ,1,1,[]);
ends = pattern.*reshape(eta([end 1]),1,1,2);
[state,initialProjection] = w.projectState(qgpv,ends);
w.Ath = state.Ath;

% Initialize the independently retained mean with a Neumann heat solution.
bMean = 1e-6 + 2e-7*cos(pi*xi);
w.Amda = real(w.mdaGForward*(-bMean./w.N2));

names = ["buoyancy","qgpv","ssh","endpointAnomalies"];
initialFields = w.reconstructFields(names);
initialEnergy = w.quadraticDiagnostics();
if options.finalTime>0
    model = WVModel(w);
    model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true, ...
        exponentialAdaptive=false,initialStep=options.timeStep,maximumStep=options.timeStep);
    model.integrateToTime(options.finalTime,shouldShowIntegrationDiagnostics=false);
end

fields = w.reconstructFields(names);
for name = ["ath","amda"]
    components.(name) = w.reconstructFields(names,flowComponent=w.flowComponentWithName(name));
end
meanReference = 1e-6 + 2e-7*exp(-kappa_z*(pi/D)^2*w.t)*cos(pi*xi);
meanError = squeeze(mean(fields.buoyancy,[1 2]))-meanReference;
meanBuoyancyRmsError = sqrt(sum(w.verticalQuadratureWeights.*meanError.^2)/D);
result = struct(transform=w,fields=fields,initialFields=initialFields,components=components, ...
    energy=w.quadraticDiagnostics(),initialEnergy=initialEnergy,constructionAssessment=w.constructionAssessment, ...
    initialProjection=initialProjection,meanBuoyancyRmsError=meanBuoyancyRmsError,time=w.t);
end
