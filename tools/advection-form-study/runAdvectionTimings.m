function runAdvectionTimings
% Five alternating-order measurements; run without other simulation processes.
folder=fileparts(mfilename('fullpath')); rows=struct([]); trajectoryRows=struct([]); equivalenceRows=struct([]);
for profile=["constant","exponential"]
    for spec=[8 33 3 4 2 3;16 65 3 4 2 3;16 65 6 8 4 6;24 129 10 12 8 8].'
        setup=tic; w=makeAdvectionStudyTransform(profile,spec.'); setupSeconds=toc(setup);
        seed=manuscriptEvolutionOperators(w,profile,padding=1); state=seed.seed("mixed",.1);
        forms=["production","divergence","advective","split","compatible"]; ops=cell(1,5); costs=zeros(5,5); trajectories=zeros(5,5); operatorSetup=zeros(1,5);
        for j=1:5
            operatorClock=tic;
            if j==1, ops{j}=thermodynamicComparisonOperators(w,profile,"displacement"); else, ops{j}=advectionStudyOperators(w,profile,forms(j)); end
            operatorSetup(j)=toc(operatorClock);
            for warmup=1:3, ops{j}.rhs(327,state); end
            if w.Nx==8, runThermodynamicTrajectory(ops{j},state,327,160,20); end
        end
        expected=ops{1}.rhs(327,state);
        for j=2:5
            actual=ops{j}.rhs(327,state);
            for family=string(fieldnames(expected)).'
                error=actual.(family)-expected.(family);
                row=struct(profile=profile,nx=w.Nx,nz=w.Nz,waveCount=spec(4),form=forms(j),family=family,rmsDifference=sqrt(mean(abs(error).^2,'all')),productionRMS=sqrt(mean(abs(expected.(family)).^2,'all')));
                if isempty(equivalenceRows), equivalenceRows=row; else, equivalenceRows(end+1)=row; end %#ok<AGROW>
            end
        end
        for trial=1:5
            order=1:5; if mod(trial,2)==0, order=5:-1:1; end
            for j=order
                op=ops{j}; timer=tic;
                for repeat=1:30, op.rhs(327,state); end
                costs(j,trial)=toc(timer)/30;
                if w.Nx==8
                    result=runThermodynamicTrajectory(op,state,327,160,20);
                    trajectories(j,trial)=result.summary.evolutionSeconds+result.summary.diagnosticSeconds;
                end
            end
        end
        for j=1:5
            row=struct(profile=profile,nx=w.Nx,nz=w.Nz,apvCount=spec(3),waveCount=spec(4),form=forms(j),setupSeconds=setupSeconds,operatorSetupSeconds=operatorSetup(j),medianSeconds=median(costs(j,:)),minimumSeconds=min(costs(j,:)),maximumSeconds=max(costs(j,:)),trial1=costs(j,1),trial2=costs(j,2),trial3=costs(j,3),trial4=costs(j,4),trial5=costs(j,5));
            if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            if w.Nx==8
                row=struct(profile=profile,form=forms(j),duration=160,dt=20,medianSeconds=median(trajectories(j,:)),minimumSeconds=min(trajectories(j,:)),maximumSeconds=max(trajectories(j,:)),trial1=trajectories(j,1),trial2=trajectories(j,2),trial3=trajectories(j,3),trial4=trajectories(j,4),trial5=trajectories(j,5));
                if isempty(trajectoryRows), trajectoryRows=row; else, trajectoryRows(end+1)=row; end %#ok<AGROW>
            end
        end
        fprintf('timing %s %dx%d modes %d done\n',profile,w.Nx,w.Nz,spec(4));
        writetable(struct2table(rows),fullfile(folder,'results','rhs-timings.csv'));
        writetable(struct2table(equivalenceRows),fullfile(folder,'results','same-grid-tendencies.csv'));
        writetable(struct2table(trajectoryRows),fullfile(folder,'results','trajectory-timings.csv'));
    end
end
runtime=struct(matlab=version,computer=computer,baseline="2ee008de824a9ff8ba0c943bf47098b20a14ca1c",date=string(datetime('now')));
file=fopen(fullfile(folder,'results','runtime.json'),'w'); fprintf(file,'%s\n',jsonencode(runtime,PrettyPrint=true)); fclose(file);
end
