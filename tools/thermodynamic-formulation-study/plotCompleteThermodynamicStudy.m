function plotCompleteThermodynamicStudy
folder=fileparts(mfilename('fullpath'));
selected=readtable(fullfile(folder,'results','selected-trajectory-timings.csv'),TextType='string');
colors=[0 .447 .741;.85 .325 .098];
fig=figure(Visible='off',Position=[100 100 1200 650]); layout=tiledlayout(2,3,TileSpacing='compact');
for profile=["constant","exponential"]
    for scenario=["linear","waves","mixed"]
        data=readtable(fullfile(folder,'results',profile+'-'+scenario+'-trajectories.csv'),TextType='string');
        nexttile; hold on
        for j=1:2
            variants=["displacement","density"]; variant=variants(j);
            r=data(data.variant==variant,:);
            e=max([r.velocityError,r.densityError,r.sshError/10],[],2);
            cost=r.evolutionSeconds+r.diagnosticSeconds;
            chosen=false(height(r),1);
            for k=1:height(selected)
                if selected.profile(k)==profile && selected.caseName(k)==scenario && selected.variant(k)==variant
                    matches=r.config==selected.config(k) & r.deltaT==selected.deltaT(k);
                    cost(matches)=selected.withDiagnosticsMedian(k); chosen=chosen|matches;
                end
            end
            loglog(cost,e,'o',DisplayName=variant,MarkerSize=5,Color=colors(j,:));
            loglog(cost(chosen),e(chosen),'o',HandleVisibility='off',MarkerSize=5,Color=colors(j,:),MarkerFaceColor=colors(j,:));
            [cost,order]=sort(cost); e=e(order); keep=[true;diff(cummin(e))<0];
            loglog(cost(keep),e(keep),'-',HandleVisibility='off',Color=colors(j,:));
        end
        check=readtable(fullfile(folder,'results',profile+'-'+scenario+'-reference.csv'));
        referenceScale=max([check.timeVelocity+check.spaceVelocity,check.timeDensity+check.spaceDensity,(check.timeSSH+check.spaceSSH)/10]);
        yline(referenceScale,':',DisplayName='Reference check scale',Color=[.4 .4 .4]);
        set(gca,XScale='log',YScale='log'); grid on
        title(profile+" / "+scenario,Interpreter='none'); xlabel('Evolution + routine diagnostics (s)'); ylabel('Physical error score E');
        if profile=="constant" && scenario=="linear", legend(Location='best'); end
    end
end
title(layout,'Thermodynamic formulations: 160-second trajectories');
subtitle(layout,'E = max(velocity RMS / 1 m s^{-1}, density RMS / 1 kg m^{-3}, SSH RMS / 10 m); native density changes the finite closure');
drawnow;
exportgraphics(fig,fullfile(folder,'results','cost-versus-error.png'),Resolution=180);
close(fig);
end
