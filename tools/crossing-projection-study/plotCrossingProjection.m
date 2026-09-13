function plotCrossingProjection
% Compare unsplit and split quadrature at fixed modal inventory.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
rows=readtable(fullfile(output,'convergence.csv'),TextType="string");
f=figure(Visible="off",Color="w",Position=[100 100 900 400]); cleanup=onCleanup(@()close(f));
layout=tiledlayout(f,1,2,TileSpacing="compact",Padding="compact");
colors=[0 .447 .698;.835 .369 0;0 .620 .451]; summary=struct([]);
for profile=["constant","exponential"]
    ax=nexttile(layout); hold(ax,'on'); j=0;
    for amplitude=[.01 .1 1]
        j=j+1;
        for order=[0 8]
            selected=rows(rows.profile==profile & rows.amplitude==amplitude & rows.order==order,:);
            counts=unique(selected.count); errors=zeros(size(counts)); passed=false(size(counts));
            for k=1:numel(counts)
                points=selected(selected.count==counts(k),:);
                errors(k)=max((points.absoluteError+points.referenceChange)./max(points.referenceNorm,1e-18));
                passed(k)=all(points.status=="assessed");
            end
            style='o-'; if order==8, style='s--'; end
            loglog(ax,counts,errors,style,Color=colors(j,:),LineWidth=1.3,MarkerSize=4,HandleVisibility='off');
            item=struct(profile=profile,amplitude=amplitude,order=order,firstPassingNz=min(counts(passed)));
            if isempty(summary), summary=item; else, summary(end+1)=item; end %#ok<AGROW>
        end
    end
    h=gobjects(1,5);
    for j=1:3, h(j)=plot(ax,NaN,NaN,'-',Color=colors(j,:),LineWidth=1.5); end
    h(4)=plot(ax,NaN,NaN,'ko-'); h(5)=plot(ax,NaN,NaN,'ks--');
    yline(ax,1e-3,':',Color=[.2 .2 .2],HandleVisibility='off');
    set(ax,XScale='log',YScale='log',XLim=[8 70],YLim=[2e-11 .1],XTick=[9 13 17 25 33 49 65],FontSize=11,Box='off');
    grid(ax,'on'); ax.XMinorGrid='off'; ax.YMinorGrid='off'; ax.GridAlpha=.12;
    xlabel(ax,'Vertical evaluation samples, Z');
    if profile=="constant"
        title(ax,'Constant stratification'); ylabel(ax,'Relative tendency error + reference change');
    else
        title(ax,'Exponential stratification');
        lg=legend(ax,h,{'\epsilon = 0.01','\epsilon = 0.1','\epsilon = 1','Original quadrature','Split crossing (Q = 8)'},NumColumns=5,Box='off',FontSize=10);
        lg.Layout.Tile='south';
    end
end
exportgraphics(f,fullfile(output,'crossing-convergence.pdf'),ContentType='vector');
exportgraphics(f,fullfile(output,'crossing-convergence.png'),Resolution=180);
writetable(struct2table(summary),fullfile(output,'qualified-grids.csv'));
clear cleanup
end
