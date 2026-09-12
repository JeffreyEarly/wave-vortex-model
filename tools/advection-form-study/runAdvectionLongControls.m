function runAdvectionLongControls
% Two external-wave-period controls with independent time/mode references.
folder=fileparts(mfilename('fullpath')); rows=struct([]); checks=struct([]);
profile="exponential";
specs=[8 33 3 4 2 3;16 65 6 8 4 6;24 129 10 12 8 8;24 129 14 18 12 12];
objects=cell(1,4); for j=1:4, objects{j}=makeAdvectionStudyTransform(profile,specs(j,:)); end
for scenario=["waves","mixed"]
    w=objects{3}; a=seed(w,scenario); op=advectionStudyOperators(w,profile,"divergence");
    reference=runThermodynamicTrajectory(op,a,327,2000,5);
    timeCheck=runThermodynamicTrajectory(op,a,327,2000,2.5,reference.checkpoints);
    w=objects{4}; a=seed(w,scenario); op=advectionStudyOperators(w,profile,"divergence");
    spaceCheck=runThermodynamicTrajectory(op,a,327,2000,5,reference.checkpoints);
    row=struct(scenario=scenario,timeVelocity=timeCheck.summary.velocityError,timeDensity=timeCheck.summary.densityError,timeSSH=timeCheck.summary.sshError,spaceVelocity=spaceCheck.summary.velocityError,spaceDensity=spaceCheck.summary.densityError,spaceSSH=spaceCheck.summary.sshError);
    if isempty(checks), checks=row; else, checks(end+1)=row; end %#ok<AGROW>
    writetable(struct2table(checks),fullfile(folder,'results','long-references.csv'));
    for config=1:2
        w=objects{config}; a=seed(w,scenario);
        for form=["divergence","advective","split","compatible"]
            op=advectionStudyOperators(w,profile,form);
            for dt=[20 10]
                result=runThermodynamicTrajectory(op,a,327,2000,dt,reference.checkpoints);
                row=result.summary; row.scenario=scenario; row.form=form; row.config=config;
                if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            end
        end
        fprintf('long %s config%d done\n',scenario,config);
        writetable(struct2table(rows),fullfile(folder,'results','long-trajectories.csv'));
    end
end
end
function a=seed(w,scenario)
w.removeAll(); study=manuscriptEvolutionOperators(w,"exponential",padding=1); a=study.seed(scenario,.1);
end
