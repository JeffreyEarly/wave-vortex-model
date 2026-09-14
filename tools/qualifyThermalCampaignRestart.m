function results=qualifyThermalCampaignRestart(outputFolder,options)
% Qualify a short full-physics restart at the declared seasonal target geometry.
% This is a two-hour lifecycle check, not a seasonal trajectory or a resolution
% qualification. The provider-unavailable branch restores stored arrays only.
% - Topic: Developer utilities
% - Parameter outputFolder: checkpoint, reference and CSV artifact directory
% - Parameter options.scientificStateFile: optional MAT cache of an already constructed scientificState
% - Parameter options.restoreOnly: run fresh-process provider-unavailable continuation
% - Returns results: coefficient, physical-field, clock and I/O evidence
arguments (Input)
    outputFolder (1,1) string
    options.scientificStateFile (1,1) string = ""
    options.restoreOnly (1,1) logical = false
end
arguments (Output)
    results table
end
if options.restoreOnly
    assert(isempty(which('IMInternalModes')) && isempty(which('IMSolverSpectral')),'Remove all InternalModes providers in a fresh process before restoration.');
    reference=load(fullfile(outputFolder,'campaign-reference.mat'));
    copyfile(fullfile(outputFolder,'campaign-checkpoint.nc'),fullfile(outputFolder,'campaign-fresh.nc'));
    clock=tic; model=WVModel.modelFromFile(char(fullfile(outputFolder,'campaign-fresh.nc'))); readSeconds=toc(clock);
    cleanup=onCleanup(@()model.closeNetCDFFile());
    compare(model.wvt,reference.checkpoint);
    configureIntegrator(model);
    model.integrateToTime(7200,shouldShowIntegrationDiagnostics=false);
    [coefficientError,fieldError,energyError]=compare(model.wvt,reference.final);
    results=table(coefficientError,fieldError,energyError,readSeconds);
    writetable(results,fullfile(outputFolder,'campaign-fresh.csv'));
    return
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
clock=tic;
if options.scientificStateFile~=""
    cache=load(options.scientificStateFile,'scientificState');
    initial=WVTransformFreeSurfaceThermalQG(scientificState=cache.scientificState);
else
    initial=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 4000],[18 18 385],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),thermalModeCount=257,mdaModeCount=4,kappa_z=1e-5,latitude=24,shouldCheckQuadraticAliasing=true);
end
assert(isequal(initial.domainSize,[5e5;5e5;4000]) && initial.N20==(5.2e-3)^2 && abs(initial.inverseScale-1/1300)<1e-15 && initial.latitude==24 && initial.thermalModeCount==257 && initial.Nx>=18 && initial.Ny>=18 && initial.shouldCheckQuadraticAliasing);
[X,Y]=ndgrid(initial.x,initial.y);
seed=cos(2*pi*X/initial.Lx)+.7*sin(4*pi*Y/initial.Ly)+.3*cos(2*pi*(X/initial.Lx+Y/initial.Ly));
seed=.01*seed/sqrt(mean(seed.^2,'all'));
endpoint=zeros(initial.Nx,initial.Ny,2); endpoint(:,:,1)=seed;
[state,fit]=initial.projectState(zeros(initial.spatialMatrixSize),endpoint);
assert(fit.qgpvRMS<1e-12 && max(fit.endpointRMS)<1e-9,'The declared zero-QGPV, 1 cm surface seed must be resolved.');
initial.Ath=state.Ath; initial.Amda=state.Amda; initial.t=0; initial.t0=0;
initial.addForcing(WVNonlinearAdvection(initial));
period=365.25*86400;
initial.addForcing(WVSeasonalSurfaceAnomalyForcing(initial,pattern=sin(10*pi*Y/initial.Ly),amplitude=10*pi/period,period=period,phase=0));
initial.addForcing(WVBottomFrictionQuadratic(initial,Cd=1e-3));
apv=WVTransformFreeSurfaceQG([initial.Lx initial.Ly initial.Lz],[initial.Nx initial.Ny max(initial.Nz,513)],N2Function=initial.N2Function,latitude=24,apvModeCount=4,mdaModeCount=4);
initial.addForcing(WVThermalAPVDamping.fromAPVTransform(initial,apv,apvCutoffFraction=.5));
setupSeconds=toc(clock);
control=cloneModel(initial); configureOutput(control,fullfile(outputFolder,'campaign-control.nc'));
clock=tic; control.integrateToTime(7200,shouldShowIntegrationDiagnostics=false); integrationSeconds=toc(clock);
final=snapshot(control.wvt); control.closeNetCDFFile();
[~,~,processes]=control.wvt.coefficientTendency();
processNorm=arrayfun(@(p)norm(p.Ath,'fro')+norm(p.Amda),processes.tendencies).';
assert(all(processNorm>0),'Every declared full-physics process must be exercised.');
writetable(table(processes.labels.',processNorm,VariableNames={'process','coefficientTendencyNorm'}),fullfile(outputFolder,'campaign-processes.csv'));
model=cloneModel(initial); file=configureOutput(model,fullfile(outputFolder,'campaign-checkpoint.nc'));
model.integrateToTime(2400,shouldShowIntegrationDiagnostics=false); checkpoint=snapshot(model.wvt);
model.integrateToTime(3600,shouldShowIntegrationDiagnostics=false);
% Diagnostics have committed t=3000 while the complete coefficient record
% remains at t=2400. Write invalid next payloads without finite commit times.
model.wvt.Ath=3*model.wvt.Ath;
for group=reshape(file.outputGroups,1,[]), group.stageTimeStepToNetCDFFile(file.ncfile,4800); end
file.ncfile.sync(); model.closeNetCDFFile();
save(fullfile(outputFolder,'campaign-reference.mat'),'checkpoint','final','-v7.3');
copyfile(fullfile(outputFolder,'campaign-checkpoint.nc'),fullfile(outputFolder,'campaign-continued.nc'));
clock=tic; resumed=WVModel.modelFromFile(char(fullfile(outputFolder,'campaign-continued.nc'))); readSeconds=toc(clock);
cleanup=onCleanup(@()resumed.closeNetCDFFile()); compare(resumed.wvt,checkpoint); configureIntegrator(resumed);
resumed.integrateToTime(7200,shouldShowIntegrationDiagnostics=false);
[coefficientError,fieldError,energyError]=compare(resumed.wvt,final);
resumed.closeNetCDFFile(); clear cleanup
info=dir(fullfile(outputFolder,'campaign-checkpoint.nc'));
results=table(initial.Nx,initial.Ny,initial.Nz,initial.thermalModeCount,initial.mdaModeCount,fit.qgpvRMS,max(fit.endpointRMS),coefficientError,fieldError,energyError,setupSeconds,integrationSeconds,readSeconds,info.bytes,VariableNames={'Nx','Ny','Nz','thermalCount','mdaCount','seedQgpvResidual','seedEndpointResidual','coefficientError','fieldError','energyError','setupSeconds','integrationSeconds','readSeconds','checkpointBytes'});
writetable(results,fullfile(outputFolder,'campaign-restart.csv'));
end

function model=cloneModel(initial)
w=WVTransformFreeSurfaceThermalQG(scientificState=initial.scientificState,coefficientState=initial.coefficientState(),t=initial.t); w.t0=initial.t0;
WVInternal.transferFreeSurfaceForcing(initial,w);
model=WVModel(w); configureIntegrator(model);
end
function configureIntegrator(model)
model.setupIntegrator(integratorType="exponential",initialStep=600,maximumStep=600,exponentialAdaptive=false,physicalAbsTolerance=[1e-14 1e-12 1e-10 1e-10 1e-10],relTolerance=1e-8);
end
function file=configureOutput(model,path)
file=model.createNetCDFFileForModelOutput(char(path),outputInterval=2400,shouldOverwriteExisting=true);
group=file.addNewEvenlySpacedOutputGroup('fields',initialTime=300,outputInterval=900,finalTime=6600);
group.addObservingSystem(WVEulerianFields(model,fieldNames={'ssh','endpointAnomalies'}));
end
function value=snapshot(w)
value=struct(t=w.t,t0=w.t0,coefficients=w.coefficientState(),fields=w.reconstructFields(["u","v","qgpv","buoyancy","ssh","endpointAnomalies"]),energy=w.totalEnergy,forcing={cell(1,numel(w.forcing))});
for j=1:numel(w.forcing)
    force=w.forcing(j); config=struct(class=string(class(force)),name=string(force.name));
    for name=string(force.requiredProperties), config.(name)=force.(name); end
    value.forcing{j}=config;
end
end
function [coefficientError,fieldError,energyError]=compare(w,expected)
actual=snapshot(w);
assert(w.t==expected.t && w.t0==expected.t0 && isequal(actual.forcing,expected.forcing));
coefficientError=0;
for name=["Ath","Amda"]
    coefficientError=max(coefficientError,norm(actual.coefficients.(name)-expected.coefficients.(name),'fro')/max(norm(expected.coefficients.(name),'fro'),realmin));
end
fieldError=0;
for name=string(fieldnames(actual.fields)).'
    a=actual.fields.(name); b=expected.fields.(name);
    fieldError=max(fieldError,norm(a(:)-b(:))/max(norm(b(:)),1e-12));
end
energyError=abs(actual.energy-expected.energy)/max(abs(expected.energy),realmin);
assert(coefficientError<1e-10 && fieldError<1e-10 && energyError<1e-10,'The predeclared campaign-geometry restart allowance is 1e-10 relative.');
end
