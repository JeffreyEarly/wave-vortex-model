function runAdvectionTrajectories
% Independent grid, mode and timestep refinement on a declared fixed protocol.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
specs=[8 33 3 4 2 3;16 33 3 4 2 3;16 65 3 4 2 3;16 65 6 8 4 6;24 129 10 12 8 8;24 129 14 18 12 12];
for profile=["constant","exponential"]
    objects=cell(1,6);
    for j=1:6, objects{j}=makeAdvectionStudyTransform(profile,specs(j,:)); end
    for scenario=["linear","waves","mixed"]
        amplitude=.1; seedName=scenario;
        if scenario=="linear", amplitude=1e-4; seedName="waves"; end
        tag=profile+"-"+scenario; rows=struct([]);
        w=objects{5}; a=seed(w,profile,seedName,amplitude);
        op=advectionStudyOperators(w,profile,"divergence");
        reference=runThermodynamicTrajectory(op,a,327,160,2.5);
        timeCheck=runThermodynamicTrajectory(op,a,327,160,1.25,reference.checkpoints);
        w=objects{6}; a=seed(w,profile,seedName,amplitude); op=advectionStudyOperators(w,profile,"divergence");
        spaceCheck=runThermodynamicTrajectory(op,a,327,160,2.5,reference.checkpoints);
        checks=struct(timeVelocity=timeCheck.summary.velocityError,timeDensity=timeCheck.summary.densityError,timeSSH=timeCheck.summary.sshError,spaceVelocity=spaceCheck.summary.velocityError,spaceDensity=spaceCheck.summary.densityError,spaceSSH=spaceCheck.summary.sshError);
        writetable(struct2table(checks),fullfile(output,tag+'-reference.csv'));
        for config=1:5
            w=objects{config}; a=seed(w,profile,seedName,amplitude);
            for form=["divergence","advective","split","compatible"]
                op=advectionStudyOperators(w,profile,form); op.rhs(327,a);
                for dt=[20 10 5]
                    result=runThermodynamicTrajectory(op,a,327,160,dt,reference.checkpoints);
                    row=result.summary; row.profile=profile; row.scenario=scenario; row.form=form; row.config=config;
                    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
                end
            end
            fprintf('%s config %d done\n',tag,config);
            writetable(struct2table(rows),fullfile(output,tag+'-trajectories.csv'));
        end
    end
end
end
function state=seed(w,profile,scenario,amplitude)
w.removeAll(); study=manuscriptEvolutionOperators(w,profile,padding=1); state=study.seed(scenario,amplitude);
end
