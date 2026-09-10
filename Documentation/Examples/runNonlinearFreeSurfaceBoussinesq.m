function history = runNonlinearFreeSurfaceBoussinesq(outputFolder)
% Run a small, deterministic nonlinear free-surface qualification example.
%
% Use the installed WVM v5 development package and its declared dependencies.
% This is a bounded inviscid example, not a stable-release or breaking-wave
% model. The full nonlinear energy has measurable projection/constraint
% reaction; inspect it alongside the solver residuals, not quadratic energy.
% All six resolved adiabatic families remain the prognostic state.
%
% - Topic: Examples
% - Declaration: history = runNonlinearFreeSurfaceBoussinesq(outputFolder)
% - Parameter outputFolder: directory for NetCDF, CSV, and the diagnostic figure
% - Returns history: energy, work, and equation diagnostics at output times
arguments (Input)
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4+0*z,apvModeCount=4,mdaModeCount=4,inertialModeCount=4,waveModeCount=6,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
state=wvt.coefficientState();
column=find(wvt.kNonzero>0 & wvt.lNonzero==0,1); index=wvt.klNonzero(column);
for mode=1:2
    unit=wvt.coefficientState(); unit.Aw_p(mode,column)=1;
    polarization=wvt.reconstructSpectralState(state=unit);
    height=[2 .15]; phase=[.37 1.1];
    state.Aw_p(mode,column)=height(mode)*exp(1i*phase(mode))/(2*polarization.ssh(end,index));
end
state.Ag_q(1,column)=5e-9*exp(.83i);
state.Aio(1)=.02*exp(.33i)/(2*wvt.inertialF(end,1));
% Prescribe small active endpoint anomalies independently of the APV term.
fields=wvt.reconstructSpectralState(state=state);
existing=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
response=zeros(2);
for mode=1:2
    unit=wvt.coefficientState(); unit.Ag_0(mode,column)=1;
    fields=wvt.reconstructSpectralState(state=unit);
    response(:,mode)=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
end
state.Ag_0(:,column)=response\([.2*exp(.7i);.1*exp(1.3i)]/2-existing);
% Inward mean label offsets keep parcels inside the reference density domain.
state.Amda(1:2)=wvt.mdaG([end 1],1:2)\[2;-2];
yColumn=find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
state.Aw_p(1,yColumn)=.3*exp(.41i)*state.Aw_p(1,column);
state.Aw_m=.2*exp(.63i)*state.Aw_p;
for name=string(fieldnames(state)).', wvt.(name)=state.(name); end
wvt.t0=-17;
wvt.addForcing(WVNonlinearAdvection(wvt));
model=WVModel(wvt);
model.setupIntegrator(integratorType="fixed",deltaT=5);
model.createNetCDFFileForModelOutput(fullfile(outputFolder,'nonlinear-free-surface.nc'),outputInterval=20);
model.eulerianObservingSystem.addNetCDFOutputVariables('u','v','w','eta','eta_i','ssh','z_physical','p_linear');
closeFile=onCleanup(@()model.closeNetCDFFile());
rows=struct([]);
for time=0:20:200
    if time>0, model.integrateToTime(time,shouldShowIntegrationDiagnostics=false); end
    [~,~,stage]=wvt.coefficientTendency();
    [~,pressure]=wvt.fullPressure();
    row=struct(time=time,totalEnergy=stage.totalEnergy,constraintReactionWork=stage.constraintReactionWork,stationarityResidual=stage.solver.relativeResidual,retainedConstraintResidual=norm(stage.solver.constraintResidual,Inf),pressureInteriorDivergence=pressure.interiorDivergence,minimumLabel=stage.minimumLabel,maximumLabel=stage.maximumLabel);
    rows=[rows;row]; %#ok<AGROW> Eleven output records.
end
history=struct2table(rows);
writetable(history,fullfile(outputFolder,'nonlinear-free-surface.csv'));
figureHandle=figure(Visible="off",Position=[100 100 1100 760]);
closeFigure=onCleanup(@()close(figureHandle));
tiledlayout(2,2,TileSpacing="compact",Padding="compact");
nexttile; imagesc(wvt.x/1000,wvt.y/1000,wvt.ssh.'); axis xy equal tight;
xlabel('x (km)'); ylabel('y (km)'); title('Surface height at 200 s'); colorbarHandle=colorbar; colorbarHandle.Label.String='SSH (m)';
nexttile; plot(history.time,history.totalEnergy-history.totalEnergy(1),'LineWidth',1.5); grid on;
xlabel('Time (s)'); ylabel('Energy change (m^3 s^{-2})'); title('Full nonlinear energy');
nexttile; plot(history.time,history.constraintReactionWork,'LineWidth',1.5); grid on;
xlabel('Time (s)'); ylabel('Energy rate (m^3 s^{-3})'); title('Constraint reaction contribution');
nexttile; semilogy(history.time,max(history.stationarityResidual,eps),'LineWidth',1.5); grid on;
xlabel('Time (s)'); ylabel('Relative stationarity residual'); title('Coupled weak solve');
exportgraphics(figureHandle,fullfile(outputFolder,'nonlinear-free-surface.png'),Resolution=160);
exportgraphics(figureHandle,fullfile(outputFolder,'nonlinear-free-surface.pdf'),ContentType="vector");
end
