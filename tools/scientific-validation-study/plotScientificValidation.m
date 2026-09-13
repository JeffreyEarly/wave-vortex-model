function plotScientificValidation
% Separate resolved energy variation, timestep sensitivity, and field refinement.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
cases=readtable(fullfile(output,'cases.csv'),TextType="string");
energy=table();
for scenario=["waves","balanced","mixed"]
    energy=[energy;readtable(fullfile(output,scenario+'-energy-quadrature.csv'),TextType="string")]; %#ok<AGROW>
end
colors=[0 .447 .698;.835 .369 0;0 .620 .451];
f=figure(Visible="off",Color="w",Position=[100 100 960 440]); cleanup=onCleanup(@()close(f));
layout=tiledlayout(f,1,2,TileSpacing="compact",Padding="compact");
a=nexttile(layout); hold(a,'on'); handles=gobjects(1,6); comparison=zeros(4,3); rows=struct([]);
scenarios=["waves","balanced","mixed"]; controls=["timeFine","vertical","horizontal","modes"];
for j=1:3
    scenario=scenarios(j); selected=energy(energy.scenario==scenario,:); initial=selected.energy(1);
    period=cases.period(cases.scenario==scenario);
    variation=abs(selected.energy-initial)/initial; variation(variation==0)=NaN;
    handles(j)=semilogy(a,(selected.time-327)/period,variation,'-',Color=colors(j,:),LineWidth=1.5);
    base=readtable(fullfile(output,scenario+'-baseline-diagnostics.csv'));
    fine=readtable(fullfile(output,scenario+'-timeFine-diagnostics.csv'));
    [times,ib,ir]=intersect(base.time,fine.time);
    sensitivity=abs(base.energy(ib)-fine.energy(ir))/initial; sensitivity(sensitivity==0)=NaN;
    semilogy(a,(times-327)/period,sensitivity,'--',Color=colors(j,:),LineWidth=1,HandleVisibility='off');
    points=isfinite(selected.referenceChange) & selected.referenceChange>0;
    semilogy(a,(selected.time(points)-327)/period,selected.referenceChange(points)/initial,'^',Color=colors(j,:),MarkerSize=5,HandleVisibility='off');
    for k=1:numel(controls)
        errors=readtable(fullfile(output,scenario+'-'+controls(k)+'-errors.csv'));
        values=[errors.velocityRelative,errors.densityRelative,errors.sshRelative];
        comparison(k,j)=max(values,[],'all');
        row=struct(scenario=scenario,control=controls(k),velocityError=max(values(:,1)),densityError=max(values(:,2)),sshError=max(values(:,3)),initialError=max(values(1,:)),maximumError=comparison(k,j),meetsTarget=comparison(k,j)<=1e-3);
        if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
    end
end
handles(4)=semilogy(a,NaN,NaN,'k-',LineWidth=1.3);
handles(5)=semilogy(a,NaN,NaN,'k--',LineWidth=1.3);
handles(6)=semilogy(a,NaN,NaN,'k^',MarkerSize=5);
set(a,YScale='log',FontSize=11,Box='off',XLim=[0 3.05],XTick=0:3); grid(a,'on'); a.YMinorGrid='off'; a.GridAlpha=.12;
xlabel(a,'Elapsed wave / inertial periods'); ylabel(a,'Absolute relative energy change'); title(a,'Physical energy and numerical sensitivity');
lg=legend(a,handles,{'Waves (constant)','Balanced (variable)','Mixed (variable)','Energy change','Timestep sensitivity','Energy quadrature check'},NumColumns=3,Box='off',FontSize=10); lg.Layout.Tile='south';
b=nexttile(layout); bars=bar(b,comparison,'grouped',BaseValue=1e-12);
for j=1:3, bars(j).FaceColor=colors(j,:); end
set(b,YScale='log',YLim=[1e-12 max(.01,2*max(comparison,[],'all'))],XTick=1:4,XTickLabel={'Time','Vertical grid','Horizontal grid','Modes'},FontSize=10,Box='off');
yline(b,1e-3,':k','0.1% target',LabelHorizontalAlignment='left');
ylabel(b,'Maximum relative physical-field difference'); title(b,'Independent refinement controls'); grid(b,'on'); b.YMinorGrid='off'; b.GridAlpha=.12;
exportgraphics(f,fullfile(output,'scientific-validation.pdf'),ContentType='vector');
exportgraphics(f,fullfile(output,'scientific-validation.png'),Resolution=180);
writetable(struct2table(rows),fullfile(output,'refinement-summary.csv'));
clear cleanup
end
