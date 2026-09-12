function runSupplementalThermodynamicResolution
% Fill the coarse-grid/high-mode combinations implicated by the first sweep.
folder=fileparts(mfilename('fullpath')); objects=cell(1,4); setup=zeros(1,4);
specs=[24 129;8 33;8 65;16 65];
for j=1:4
    clock=tic; objects{j}=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[specs(j,1) specs(j,1) specs(j,2)],N2Function=@(z)1e-4*exp(z/650),apvModeCount=10,waveModeCount=12,mdaModeCount=8,inertialModeCount=8,nEVP=256,shouldAntialias=false);
    setup(j)=toc(clock);
end
for scenario=["waves","mixed"]
    tag="exponential-"+scenario;
    w=objects{1}; w.removeAll(); study=manuscriptEvolutionOperators(w,"exponential",padding=1); a=study.seed(scenario,.1);
    op=thermodynamicComparisonOperators(w,"exponential","displacement");
    reference=runThermodynamicTrajectory(op,a,327,160,2.5);
    table=readtable(fullfile(folder,'results',tag+'-trajectories.csv'),TextType='string');
    history=readtable(fullfile(folder,'results',tag+'-history.csv'),TextType='string');
    table=table(table.config<=5,:); history=history(history.config<=5,:);
    for j=2:4
        w=objects{j}; w.removeAll(); study=manuscriptEvolutionOperators(w,"exponential",padding=1); a=study.seed(scenario,.1);
        for variant=["displacement","density"]
            state=a; if variant=="density", state=thermodynamicCoefficientMap(w,"exponential",a,327); end
            clock=tic; op=thermodynamicComparisonOperators(w,"exponential",variant); extraSetup=toc(clock);
            op.rhs(327,state);
            for dt=[20 10 5]
                fprintf('SUPPLEMENT %s config%d %s dt%g\n',tag,j+4,variant,dt);
                run=runThermodynamicTrajectory(op,state,327,160,dt,reference.checkpoints);
                row=run.summary; row.profile="exponential"; row.caseName=scenario; row.variant=variant; row.config=j+4; row.setupSeconds=setup(j)+extraSetup;
                table=[table;struct2table(row)]; %#ok<AGROW>
                for d=run.diagnostics
                    d.profile="exponential"; d.caseName=scenario; d.variant=variant; d.config=j+4; d.deltaT=dt;
                    history=[history;struct2table(d)]; %#ok<AGROW>
                end
                writetable(table,fullfile(folder,'results',tag+'-trajectories.csv'));
                writetable(history,fullfile(folder,'results',tag+'-history.csv'));
            end
        end
    end
end
end
