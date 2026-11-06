function result = activeBoundaryBoussinesq(options)
% Evolve a small mixed free-surface Boussinesq state using linear dynamics.
%
% Add the package's Examples folder to the MATLAB path. Use the returned
% transform to inspect individual mode labels, grid and construction evidence.
% The linear reference-geometry energy includes cross terms. The disjoint
% field partition is wave, balanced, and inertial. Balanced includes MDA.
%
% result = activeBoundaryBoussinesq(profile="exponential")
arguments (Input)
    options.profile (1,1) string {mustBeMember(options.profile,["constant","exponential"])} = "constant"
    options.Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.Nz,33)} = 65
    options.finalTime (1,1) double {mustBeNonnegative,mustBeFinite} = 600
end
arguments (Output)
    result (1,1) struct
end

if options.profile=="constant"
    N2 = @(z) 1e-4*ones(size(z));
else
    N2 = @(z) 1e-4*exp(2*z/700);
end
[w,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([100e3 100e3 1000],[8 8 options.Nz], ...
    N2Function=N2,rho0=1030,latitude=30,g0=.02,gd=.03,verticalGridRule="smoothedBandwidth", ...
    quadraticDealiasing="none",shouldAntialias=false,apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4);

% Choose one physical horizontal Fourier mode and both gravity-wave signs.
kh = 2*pi/w.Lx;
j = find(abs(abs(w.kNonzero)-kh)<16*eps(kh) & w.lNonzero==0,1);
w.Aw_p(1,j) = .002;
w.Aw_m(2,j) = .001;
w.Aw_p(3,j) = -.0003i;
w.Aw_m(4,j) = .0002i;
w.Ag_q(2,j) = 1e-8;
w.Ag_0(:,j) = [1;-1]*1e-8;
w.Aio(1) = .002;
w.Amda(1) = .01;

names = ["u_hat","v_hat","w_hat","eta","ssh","qgpv"];
initialFields = w.reconstructFields(names);
initialEnergy = w.physicalEnergy();
if options.finalTime>0
    model = WVModel(w,shouldUseLinearDynamics=true);
    model.integrateToTime(options.finalTime,shouldShowIntegrationDiagnostics=false);
end

fields = w.reconstructFields(names);
for name = ["wave","balanced","inertial","mda"]
    components.(name) = w.reconstructFields(names,flowComponent=w.flowComponentWithName(name));
end
surfaceMask = w.activeWaveModes & (w.waveModeNumber(:)==1);
surface = WVFlowComponent(w,coefficientMasks=struct(Aw_p=surfaceMask,Aw_m=surfaceMask));
interiorMask = w.activeWaveModes & ~surfaceMask;
interior = WVFlowComponent(w,coefficientMasks=struct(Aw_p=interiorMask,Aw_m=interiorMask));
components.surfaceGravityWave = w.reconstructFields(names,flowComponent=surface);
components.internalGravityWave = w.reconstructFields(names,flowComponent=interior);

result = struct(transform=w,fields=fields,initialFields=initialFields,components=components, ...
    energy=w.physicalEnergy(),initialEnergy=initialEnergy,constructionAssessment=assessment, ...
    time=w.t,waveFourierColumn=j);
end
