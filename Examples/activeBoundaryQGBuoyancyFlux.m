function result = activeBoundaryQGBuoyancyFlux(options)
% Evolve free-surface QG under an inward buoyancy flux and vertical diffusion.
%
% The surface pattern has a horizontal mean and one Fourier component.
% The bottom is insulated. The example uses enhanced diffusivity in a
% shallow column so that its 10-day forcing penetrates a resolved depth.
% The flux amplitude is in square meters per cubic second.
arguments (Input)
    options.profile (1,1) string {mustBeMember(options.profile,["constant","exponential"])} = "constant"
    options.Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.Nz,4)} = 65
    options.apvModeCount (1,1) double {mustBeInteger,mustBePositive} = 24
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive} = 24
end
arguments (Output)
    result (1,1) struct
end
if options.profile=="constant"
    N2 = @(z) 1e-4*ones(size(z));
else
    N2 = @(z) 1e-4*exp(2*z/700);
end

period = 10*86400;
amplitude = 1e-8;
diffusivity = 1e-2;
q = WVTransformFreeSurfaceQG([100e3 100e3 100],[8 8 options.Nz], ...
    N2Function=N2,rho0=1030,latitude=30,g0=.02,gd=.03,verticalGridRule="smoothedBandwidth", ...
    shouldAntialias=false,quadraticDealiasing="none",apvModeCount=options.apvModeCount,mdaModeCount=options.mdaModeCount);
[X,~] = ndgrid(q.x,q.y);
pattern = 1+.5*cos(2*pi*X/q.Lx);
q.addForcing(WVVerticalDiffusivity(q,kappa_z=diffusivity));
q.addForcing(WVSeasonalSurfaceBuoyancyFlux(q,pattern=pattern,amplitude=amplitude,period=period,phase=0));

model = WVModel(q);
step = period/96;
model.setupIntegrator(integratorType="exponential",initialStep=step,maximumStep=step,exponentialAdaptive=false);
model.integrateToTime(period/4,shouldShowIntegrationDiagnostics=false);

names = ["u","v","eta_i","qgpv","ssh"];
fields = q.reconstructFields(names);
for name = ["apv","zeroapv","mda"]
    components.(name) = q.reconstructFields(names,flowComponent=q.flowComponentWithName(name));
end
calculus = q.verticalGrid.calculus;
[z,weights] = calculus.quadratureRule(2*q.Nz+1);
meanDisplacement = reshape(mean(fields.eta_i,[1 2]),[],1);
meanBuoyancy = -q.N2Function(z).*(calculus.interpolationMatrix(z)*meanDisplacement);
omega = 2*pi/period;
columnBuoyancy = weights.'*meanBuoyancy;
expectedColumnBuoyancy = mean(pattern,"all")*(amplitude/omega)*(1-cos(omega*q.t));
result = struct(transform=q,fields=fields,components=components,energy=q.quadraticDiagnostics(), ...
    constructionAssessment=q.constructionAssessment,time=q.t,period=period,step=step, ...
    columnBuoyancy=columnBuoyancy,expectedColumnBuoyancy=expectedColumnBuoyancy, ...
    penetrationDepth=sqrt(diffusivity*period/pi));
end
