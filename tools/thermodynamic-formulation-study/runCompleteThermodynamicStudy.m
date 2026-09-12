function runCompleteThermodynamicStudy(options)
% Complete bounded assessment under comparison-protocol.json.
arguments
    options.profiles (1,:) string = ["constant","exponential"]
    options.cases (1,:) string = ["linear","waves","mixed"]
end
folder=fileparts(mfilename('fullpath')); protocol=jsondecode(fileread(fullfile(folder,'comparison-protocol.json')));
configs=[protocol.grids(:,1),protocol.grids(:,3),protocol.mode_counts_apv_wave_mda_io];
for profile=options.profiles
    objects=cell(1,6); setup=zeros(1,6);
    for config=1:6
        if config==6, spec=[24 129 14 18 12 12]; else, spec=configs(config,:); end
        timer=tic; objects{config}=makeTransform(profile,spec); setup(config)=toc(timer);
    end
    for caseName=options.cases
        caseSpec=protocol.cases(string({protocol.cases.name})==caseName);
        tag=profile+"-"+caseName; rows=struct([]); histories=struct([]);
        fprintf('START %s reference\n',tag);
        w=objects{5}; a=seed(w,profile,caseSpec);
        op=thermodynamicComparisonOperators(w,profile,"displacement");
        reference=runThermodynamicTrajectory(op,a,protocol.start_s,protocol.duration_s,protocol.reference_timestep_s);
        timeCheck=runThermodynamicTrajectory(op,a,protocol.start_s,protocol.duration_s,protocol.reference_timestep_s/2,reference.checkpoints);
        w=objects{6}; a=seed(w,profile,caseSpec); op=thermodynamicComparisonOperators(w,profile,"displacement");
        spaceCheck=runThermodynamicTrajectory(op,a,protocol.start_s,protocol.duration_s,protocol.reference_timestep_s,reference.checkpoints);
        checks=struct(timeVelocity=timeCheck.summary.velocityError,timeDensity=timeCheck.summary.densityError,timeSSH=timeCheck.summary.sshError,spaceVelocity=spaceCheck.summary.velocityError,spaceDensity=spaceCheck.summary.densityError,spaceSSH=spaceCheck.summary.sshError);
        writetable(struct2table(checks),fullfile(folder,'results',tag+'-reference.csv'));
        for config=1:5
            w=objects{config}; a=seed(w,profile,caseSpec);
            for variant=["displacement","density"]
                state=a;
                if variant=="density", state=thermodynamicCoefficientMap(w,profile,a,protocol.start_s); end
                timer=tic; op=thermodynamicComparisonOperators(w,profile,variant); operatorSetup=toc(timer);
                op.rhs(protocol.start_s,state); % Build cached contexts before timing.
                for dt=protocol.timesteps_s.'
                    fprintf('RUN %s config%d %s dt%g\n',tag,config,variant,dt);
                    run=runThermodynamicTrajectory(op,state,protocol.start_s,protocol.duration_s,dt,reference.checkpoints);
                    row=run.summary; row.profile=profile; row.caseName=caseName; row.variant=variant; row.config=config; row.setupSeconds=setup(config)+operatorSetup;
                    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
                    for d=run.diagnostics
                        d.profile=profile; d.caseName=caseName; d.variant=variant; d.config=config; d.deltaT=dt;
                        if isempty(histories), histories=d; else, histories(end+1)=d; end %#ok<AGROW>
                    end
                    writetable(struct2table(rows),fullfile(folder,'results',tag+'-trajectories.csv'));
                    writetable(struct2table(histories),fullfile(folder,'results',tag+'-history.csv'));
                end
            end
        end
        % Exact finite-evolution control on one small, fixed inventory.
        w=objects{1}; a=seed(w,profile,caseSpec);
        op=thermodynamicComparisonOperators(w,profile,"displacement");
        control=runThermodynamicTrajectory(op,a,protocol.start_s,40,5);
        b=thermodynamicCoefficientMap(w,profile,a,protocol.start_s);
        [recovered,inverse]=invertThermodynamicCoefficientMap(w,profile,b,protocol.start_s); %#ok<ASGLU>
        op=thermodynamicComparisonOperators(w,profile,"equivalent");
        equivalent=runThermodynamicTrajectory(op,b,protocol.start_s,40,5,control.checkpoints);
        r=equivalent.summary; r.inverseIterations=inverse.iterations; r.inverseResidual=inverse.residual;
        r.displacementSeconds=control.summary.evolutionSeconds;
        writetable(struct2table(r),fullfile(folder,'results',tag+'-inverse-control.csv'));
        fprintf('DONE %s\n',tag);
    end
end
end
function w=makeTransform(profile,spec)
if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[spec(1) spec(1) spec(2)],N2Function=N2,apvModeCount=spec(3),waveModeCount=spec(4),mdaModeCount=spec(5),inertialModeCount=spec(6),nEVP=256,shouldAntialias=false);
end
function a=seed(w,profile,spec)
w.removeAll(); w.t0=0;
study=manuscriptEvolutionOperators(w,profile,padding=1);
a=study.seed(string(spec.seed),spec.amplitude);
end
