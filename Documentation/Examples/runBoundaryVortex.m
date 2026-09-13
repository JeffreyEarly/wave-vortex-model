function history = runBoundaryVortex(outputFolder,options)
% Evolve and plot a surface-driven ellipse using ordinary adaptive WVModel integration.
arguments (Input)
    outputFolder (1,1) string
    options.gridSize (1,3) double = [128 128 65]
    options.absTolerance (1,1) double = 1e-8
    options.relTolerance (1,1) double = 1e-8
    options.finalTurnovers (1,1) double = 4
end
arguments (Output)
    history (1,1) struct
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
[wvt,scale]=makeBoundaryVortex(gridSize=options.gridSize);
model=WVModel(wvt);
model.setupIntegrator(integratorType="adaptive",absTolerance=options.absTolerance,relTolerance=options.relTolerance);
times=[0 .5 1 options.finalTurnovers]*scale.time;
boundary=zeros(wvt.Nx,wvt.Ny,4); variance=zeros(4,1); pv=zeros(4,1);
states=cell(4,1); elapsed=tic;
for i=1:4
    if i>1, model.integrateToTime(times(i),shouldShowIntegrationDiagnostics=false); end
    [q,~,~,b]=wvt.quasigeostrophicSpatialState();
    boundary(:,:,i)=b(:,:,1);
    variance(i)=mean(b.^2,'all')/2;
    pv(i)=max(abs(q),[],'all');
    states{i}=wvt.coefficientState();
end
history=struct(options=options,scale=scale,times=times,boundary=boundary,variance=variance,maximumPV=pv,states={states},runtime=toc(elapsed),rhsCount=model.nFluxComputations);
save(fullfile(outputFolder,'boundary-vortex.mat'),'history','-v7.3');
fig=figure(Visible="off",Position=[100 100 1300 380]);
cleanup=onCleanup(@()close(fig));
tiledlayout(1,4,TileSpacing="compact",Padding="compact");
limits=[min(boundary,[],'all') max(boundary,[],'all')];
for i=1:4
    nexttile;
    contourf((wvt.x-wvt.Lx/2)/1000,(wvt.y-wvt.Ly/2)/1000,boundary(:,:,i).',linspace(limits(1),limits(2),17),'LineColor','none');
    axis equal tight; clim(limits); xlim([-25 25]); ylim([-25 25]);
    xlabel('x (km)'); ylabel('y (km)'); title(sprintf('tU/L = %.1f',times(i)/scale.time));
end
bar=colorbar; bar.Layout.Tile='east'; bar.Label.String='Surface endpoint anomaly (m)';
exportgraphics(fig,fullfile(outputFolder,'boundary-vortex.png'),Resolution=180);
exportgraphics(fig,fullfile(outputFolder,'boundary-vortex.pdf'),ContentType="vector");
end
