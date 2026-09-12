function plotBoussinesqResolution
% Plot fixed-basis convergence, retaining measured reference changes.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
rows=readtable(fullfile(output,'convergence.csv'),TextType="string");
figureHandle=figure(Visible="off",Color="w",Position=[100 100 900 420]);
cleanup=onCleanup(@()close(figureHandle));
layout=tiledlayout(figureHandle,1,2,TileSpacing="compact",Padding="compact");
colors=[0 .447 .698;.835 .369 0;0 .620 .451]; summaries=struct([]);
for profile=["constant","exponential"]
    ax=nexttile(layout); hold(ax,'on'); handles=gobjects(1,3); amplitudeIndex=0;
    for amplitude=[.01 .1 1]
        amplitudeIndex=amplitudeIndex+1;
        selected=rows(rows.profile==profile & rows.amplitude==amplitude & rows.direction=="vertical",:);
        counts=unique(selected.count); errors=zeros(size(counts)); margins=errors; passed=false(size(counts));
        for j=1:numel(counts)
            points=selected(selected.count==counts(j),:);
            errors(j)=max((points.absoluteError+points.referenceChange)./max(points.referenceNorm,1e-18));
            margins(j)=max(points.referenceChange./max(points.referenceNorm,1e-18));
            passed(j)=all(points.status=="assessed");
        end
        handles(amplitudeIndex)=loglog(ax,counts,errors,'o-',Color=colors(amplitudeIndex,:),LineWidth=1.5,MarkerSize=4);
        yline(ax,max(margins),':',Color=.5+.5*colors(amplitudeIndex,:),LineWidth=.8,HandleVisibility='off');
        row=struct(profile=profile,amplitude=amplitude,firstPassingNz=min(counts(passed)),maximumSSHMetres=max(selected.maximumSSHOverDepth)*1000,referenceMargin=max(margins),referenceNz=join(string(unique(selected.referenceNz)),'/'));
        if isempty(summaries), summaries=row; else, summaries(end+1)=row; end %#ok<AGROW>
    end
    yline(ax,1e-3,'--',Color=[.2 .2 .2],HandleVisibility='off');
    text(ax,80,1.4e-3,'0.1% target',FontSize=10);
    set(ax,XScale='log',YScale='log',XLim=[8 280],YLim=[2e-8 .15],XTick=[9 17 33 65 129 257],XTickLabel={'9','17','33','65','129','257'},FontSize=12,Box='off');
    grid(ax,'on'); ax.XMinorGrid='off'; ax.YMinorGrid='off'; ax.GridAlpha=.12;
    xlabel(ax,'Vertical evaluation samples, Z');
    if profile=="constant"
        title(ax,'Constant stratification'); ylabel(ax,{'Relative tendency discrepancy','+ reference-refinement change'});
    else
        title(ax,'Exponential stratification');
        legend(ax,handles,{'\epsilon = 0.01','\epsilon = 0.1','\epsilon = 1'},Location='northeast',Box='off');
    end
end
exportgraphics(figureHandle,fullfile(output,'vertical-convergence.pdf'),ContentType='vector');
exportgraphics(figureHandle,fullfile(output,'vertical-convergence.png'),Resolution=200);
writetable(struct2table(summaries),fullfile(output,'qualified-grids.csv'));
clear cleanup
end
