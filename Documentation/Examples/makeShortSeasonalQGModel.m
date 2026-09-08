function model = makeShortSeasonalQGModel(options)
% Compose a short seasonal QG case using the ordinary model interfaces.
% This authoring example retains the experiment's physical parameters and
% seed. Its smaller, explicitly retained modal band is a qualification case,
% not a claim of production-resolution seasonal QGPV accuracy.
arguments (Input)
    options.gridSize (1,3) double = [24 24 65]
    options.apvModeCount (1,1) double = 14
    options.mdaModeCount (1,1) double = 2
    options.timeStep (1,1) double = 21600
end
arguments (Output)
    model (1,1) WVModel
end
Lxyz = [500e3 500e3 4000];
N0 = 5.2e-3; scale = 1300;
N2 = @(z) N0^2*exp(2*z/scale);
endpointWeight = N0^2*scale*(1-exp(-2*Lxyz(3)/scale))/2;
wvt = WVTransformFreeSurfaceQG(Lxyz,options.gridSize,N2Function=N2,latitude=24,g0=-endpointWeight,gd=endpointWeight,apvModeCount=options.apvModeCount,mdaModeCount=options.mdaModeCount);
[X,Y] = ndgrid(wvt.x,wvt.y);
seedModes = [1 0;2 0;3 1;4 -1;1 2;2 -2];
phases = [0.1 1.3 2.2 0.7 2.6 1.8];
retained = round([wvt.kNonzero(:)*wvt.Lx wvt.lNonzero(:)*wvt.Ly]/(2*pi));
if ~all(ismember([seedModes;0 5],[retained;-retained],'rows'))
    error('ShortSeasonalQG:UnresolvedPattern','Retain the seed wavevectors and seasonal mode 5 after dealiasing.');
end
seed = zeros(wvt.Nx,wvt.Ny);
for k = 1:size(seedModes,1)
    seed = seed+cos(2*pi*(seedModes(k,1)*X/wvt.Lx+seedModes(k,2)*Y/wvt.Ly)+phases(k));
end
seed = seed-mean(seed,'all');
seed = .01*seed/sqrt(mean(seed.^2,'all'));
field = zeros(wvt.spatialMatrixSize); field(:,:,1) = seed;
seedHat = wvt.transformFromSpatialDomainWithFourier(field);
endpoint = zeros(2,length(wvt.klNonzero)); endpoint(1,:) = seedHat(1,wvt.klNonzero);
[wvt.Ag_q,wvt.Ag_0] = wvt.transformStateForward(zeros(wvt.Nz,length(wvt.klNonzero)),endpoint);
wvt.t = 0;
period = 365.25*86400;
wvt.removeAllForcing();
wvt.addForcing(WVNonlinearAdvection(wvt));
wvt.addForcing(WVSeasonalSurfaceAnomalyForcing(wvt,pattern=sin(10*pi*Y/wvt.Ly),amplitude=10*pi/period,period=period,phase=0));
wvt.addForcing(WVBottomFrictionQuadratic(wvt,Cd=1e-3));
wvt.addForcing(WVAdaptiveDamping(wvt));
wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-5));
model = WVModel(wvt);
model.setupIntegrator(integratorType="exponential",initialStep=options.timeStep,maximumStep=options.timeStep,exponentialAdaptive=false);
end
