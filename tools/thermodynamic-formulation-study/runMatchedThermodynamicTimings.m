function runMatchedThermodynamicTimings
% Repeated complete-trajectory timing of the selected qualifying inventories.
folder=fileparts(mfilename('fullpath')); rows=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
    if profile=="exponential"
        high=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],N2Function=N2,apvModeCount=10,waveModeCount=12,mdaModeCount=8,inertialModeCount=8,nEVP=256,shouldAntialias=false);
    end
    for scenario=["linear","waves","mixed"]
        amplitude=.1; seedScenario=scenario;
        if scenario=="linear", amplitude=.0001; seedScenario="waves"; end
        w.removeAll(); study=manuscriptEvolutionOperators(w,profile,padding=1); a=study.seed(seedScenario,amplitude);
        operators={thermodynamicComparisonOperators(w,profile,"displacement"),thermodynamicComparisonOperators(w,profile,"density")};
        states={a,thermodynamicCoefficientMap(w,profile,a,327)}; variants=["displacement","density"]; configs=[1 1];
        if profile=="exponential" && scenario~="linear"
            high.removeAll(); study=manuscriptEvolutionOperators(high,profile,padding=1); a=study.seed(seedScenario,amplitude);
            operators{3}=thermodynamicComparisonOperators(high,profile,"density");
            states{3}=thermodynamicCoefficientMap(high,profile,a,327); variants(3)="density"; configs(3)=6;
        end
        for j=1:numel(operators), runThermodynamicTrajectory(operators{j},states{j},327,40,20); end
        times=zeros(5,numel(operators)); diagnostics=times;
        for repeat=1:5
            order=1:numel(operators); if mod(repeat,2)==0, order=fliplr(order); end
            for j=order
                run=runThermodynamicTrajectory(operators{j},states{j},327,160,20);
                times(repeat,j)=run.summary.evolutionSeconds;
                diagnostics(repeat,j)=run.summary.diagnosticSeconds;
            end
        end
        for j=1:numel(operators)
            combined=times(:,j)+diagnostics(:,j);
            row=struct(profile=profile,caseName=scenario,variant=variants(j),config=configs(j),deltaT=20,evolutionMedian=median(times(:,j)),withDiagnosticsMedian=median(combined),withDiagnosticsMinimum=min(combined),withDiagnosticsMaximum=max(combined),trials=5);
            if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
        end
    end
end
writetable(struct2table(rows),fullfile(folder,'results','selected-trajectory-timings.csv'));
end
