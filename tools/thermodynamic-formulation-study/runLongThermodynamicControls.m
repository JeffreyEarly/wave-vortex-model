function runLongThermodynamicControls
% Extend the variable-stratification cases to roughly two external-wave periods.
folder=fileparts(mfilename('fullpath')); specs=[8 33 3 4 2 3;8 33 10 12 8 8;24 129 10 12 8 8;24 129 14 18 12 12]; objects=cell(1,4);
for j=1:4
    s=specs(j,:); objects{j}=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[s(1) s(1) s(2)],N2Function=@(z)1e-4*exp(z/650),apvModeCount=s(3),waveModeCount=s(4),mdaModeCount=s(5),inertialModeCount=s(6),nEVP=256,shouldAntialias=false);
end
for scenario=["waves","mixed"]
    fprintf('LONG %s reference\n',scenario);
    w=objects{3}; a=seed(w,scenario); op=thermodynamicComparisonOperators(w,"exponential","displacement");
    reference=runThermodynamicTrajectory(op,a,327,2000,5);
    checkTime=runThermodynamicTrajectory(op,a,327,2000,2.5,reference.checkpoints);
    w=objects{4}; a=seed(w,scenario); op=thermodynamicComparisonOperators(w,"exponential","displacement");
    checkSpace=runThermodynamicTrajectory(op,a,327,2000,5,reference.checkpoints);
    rows=struct([]);
    for j=1:3
        w=objects{j}; a=seed(w,scenario);
        for variant=["displacement","density"]
            state=a; if variant=="density", state=thermodynamicCoefficientMap(w,"exponential",a,327); end
            op=thermodynamicComparisonOperators(w,"exponential",variant); op.rhs(327,state);
            for dt=[20 10]
                fprintf('LONG %s config%d %s dt%g\n',scenario,j,variant,dt);
                run=runThermodynamicTrajectory(op,state,327,2000,dt,reference.checkpoints);
                r=run.summary; r.variant=variant; r.config=j; r.caseName=scenario;
                if isempty(rows), rows=r; else, rows(end+1)=r; end %#ok<AGROW>
            end
        end
    end
    writetable(struct2table(rows),fullfile(folder,'results','long-'+scenario+'-trajectories.csv'));
    time=checkTime.summary; space=checkSpace.summary;
    checks=struct(timeVelocity=time.velocityError,timeDensity=time.densityError,timeSSH=time.sshError,spaceVelocity=space.velocityError,spaceDensity=space.densityError,spaceSSH=space.sshError);
    writetable(struct2table(checks),fullfile(folder,'results','long-'+scenario+'-reference.csv'));
end
end
function a=seed(w,scenario)
w.removeAll(); study=manuscriptEvolutionOperators(w,"exponential",padding=1); a=study.seed(scenario,.1);
end
