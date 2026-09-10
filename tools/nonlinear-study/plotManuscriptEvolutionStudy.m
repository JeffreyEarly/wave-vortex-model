function plotManuscriptEvolutionStudy(dataFolder,outputPath)
% Render the committed boundary and trajectory evidence with MATLAB graphics.
arguments (Input)
    dataFolder (1,1) string
    outputPath (1,1) string
end
boundary=readtable(fullfile(dataFolder,'manuscript-boundary-counts.csv'),TextType='string');
history=readtable(fullfile(dataFolder,'manuscript-evolution-history.csv'),TextType='string');
summary=readtable(fullfile(dataFolder,'manuscript-evolution-summary.csv'),TextType='string');
fig=figure(Visible='off',Color='white',Position=[0 0 1150 850]);
cleanup=onCleanup(@()close(fig));
tiledlayout(2,2,TileSpacing='compact',Padding='compact');
nexttile;
order=[2 3 4 5 6 1]; values=zeros(numel(order),2);
for j=1:numel(order)
    row=boundary(boundary.profile=="exponential" & boundary.scenario=="mixed" & boundary.configuration==order(j),:);
    values(j,:)=[row.surfaceResidual,row.bottomResidual];
end
bar(values); set(gca,YScale='log',XTick=1:6,XTickLabel={'Base','More APV','More wave','More MDA','More inertial','All refined'},XTickLabelRotation=25);
ylim([2e-8 3e-4]);
ylabel('Maximum anomaly tendency error (m/s)'); title('Which families resolve the boundaries?');
legend('Surface','Bottom',Location='northeast'); grid on;
nexttile; hold on;
colors=lines(3);
for configuration=1:3
    row=history(history.run=="main" & history.configuration==configuration & history.deltaT==10,:);
    semilogy(row.time(2:end)-327,row.accumulatedSurface(2:end),LineWidth=1.8,Color=colors(configuration,:));
end
set(gca,YScale='log'); xlabel('Elapsed time (s)'); ylabel('Accumulated surface-anomaly mismatch (m)');
title('Boundary mismatch decreases with retained counts');
legend('2 APV / 3 wave / 2 mean','4 APV / 6 wave / 4 mean','8 APV / 12 wave / 8 mean',Location='northwest'); grid on;
nexttile; hold on;
for j=1:3
    names=["main","half","quarter"];
    row=history(history.run==names(j) & history.configuration==3 & history.deltaT==10,:);
    plot(row.time-327,100*(row.apv2/row.apv2(1)-1),LineWidth=1.8,Color=colors(j,:));
end
xlabel('Elapsed time (s)'); ylabel('Physical APV-squared integral change (%)');
title('Amplitude dependence of the remaining drift');
legend('Amplitude 1','Amplitude 1/2','Amplitude 1/4',Location='northwest'); grid on;
nexttile;
names=["main","more-modes","more-samples","horizontal-middle","horizontal"];
values=zeros(1,5);
for j=1:5
    row=summary(summary.run==names(j) & summary.deltaT==10,:);
    if names(j)=="main", row=row(row.configuration==3,:); end
    values(j)=100*row.relativeAPV2Change;
end
bar(values,FaceColor=[.3 .5 .7]);
set(gca,YScale='log',XTick=1:5,XTickLabel={'Baseline','Double counts','Double Nz','12 x 12','16 x 16'},XTickLabelRotation=20);
ylabel('Final physical APV-squared integral change (%)');
title('Resolution controls distinguish the residual drift'); grid on;
sgtitle({'Direct manuscript projection: finite-mode evolution','100 km square, 1 km depth; variable stratification; both active boundaries'},FontWeight='bold');
exportgraphics(fig,outputPath,Resolution=180);
end
