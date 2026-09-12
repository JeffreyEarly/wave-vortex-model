function plotAdvectionStudy
% Export scientific evidence; budgets and accuracy are distinct quantities.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
m=readtable(fullfile(output,'manufactured.csv'),TextType="string");
t=readtable(fullfile(output,'rhs-timings.csv'),TextType="string");
forms=["divergence","advective","split","compatible"];
colors=lines(4); figure('Visible','off','Position',[100 100 1080 420]);
tiledlayout(1,2,TileSpacing='compact'); nexttile; hold on;
for j=1:4
    a=m(m.form==forms(j) & m.nx==32 & m.scenario=="oscillatory",:);
    loglog(a.nz,a.rmsError,'-o',Color=colors(j,:),DisplayName=forms(j),LineWidth=1.5);
end
set(gca,'XScale','log','YScale','log'); grid on;
xlabel('Vertical samples'); ylabel('Analytic scalar transport RMS error (s^{-1})');
title('Resolved horizontal grid; oscillatory vertical field'); legend(Location='southwest');
nexttile; hold on;
a=t(t.profile=="exponential",:);
configs=unique([a.nx a.nz a.waveCount],'rows','stable');
for j=1:4
    ratios=zeros(size(configs,1),1);
    for k=1:size(configs,1)
        select=a.nx==configs(k,1) & a.nz==configs(k,2) & a.waveCount==configs(k,3);
        ratios(k)=a.medianSeconds(select & a.form==forms(j))/a.medianSeconds(select & a.form=="production");
    end
    plot(1:numel(ratios),ratios,'-o',Color=colors(j,:),DisplayName=forms(j),LineWidth=1.5);
end
yline(1,'k:'); xlim([.85 size(configs,1)+.15]); xticks(1:size(configs,1)); xticklabels(compose('%dx%d, %d waves',configs)); xtickangle(20);
ylabel('Complete RHS time / production time'); title('Exponential profile; five-trial medians'); grid on;
exportgraphics(gcf,fullfile(output,'accuracy-and-cost.png'),Resolution=170); close(gcf);
end
