function results = runFreeSurfaceWeakTrajectoryStudy(outputFolder)
% Integrate short interaction-picture trajectories of the diagnostic weak RHS.
%
% The physical-height plus reference, admissible parcel labels, and g*ssh
% surface pressure match the instantaneous study. This driver uses no WVModel
% activation. RK4 advances interaction coefficients and all four work terms
% with the same stage weights; physical labels and constraints are measured
% at every nonlinear RK stage on the quadrature and dense checkpoint grids.
arguments (Input)
    outputFolder (1,1) string
end
arguments (Output)
    results table
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
helper=freeSurfaceWeakStudyHelpers();
configurations=[65 2 3 2 2 2;129 4 6 4 4 2];
duration=200; steps=[10 5 2.5]; phaseStep=min(steps)/2;
rows=cell(0,1); history=cell(0,1); coarseFinal=[]; referenceSeed=[];
for configuration=1:size(configurations,1)
    config=configurations(configuration,:);
    wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[4 4 config(1)],N2Function=@(z)1e-4+0*z,apvModeCount=config(2),waveModeCount=config(3),mdaModeCount=config(4),inertialModeCount=config(5),nEVP=128);
    wvt.t=0; wvt.t0=0;
    context=helper.buildContext(wvt,config(6));
    [basis,linearBasis]=helper.globalBasis(wvt,context);
    H0=helper.gram(basis,context);
    diagonalScale=sqrt(diag(H0));
    R0=chol(H0./(diagonalScale*diagonalScale.'));
    T=diag(1./diagonalScale)/R0;
    for name=["u","v","w","eta","ssh"]
        basis.(name)=basis.(name)*T;
        linearBasis.(name)=linearBasis.(name)*T;
    end
    H0=helper.gram(basis,context);
    seedFields=helper.sampledState(wvt,helper.seedState(wvt),context);
    seedFingerprint=helper.seedCheckpoints(seedFields,context);
    if isempty(referenceSeed), referenceSeed=seedFingerprint; end
    seedDifference=norm(seedFingerprint-referenceSeed)/norm(referenceSeed);
    seed=helper.physicalPair(basis,seedFields,context);
    Kfull=[basis.ssh;basis.eta(context.top,:)-basis.ssh;basis.eta(context.bottom,:)];
    [left,singular,~]=svd(Kfull,'econ');
    rankValue=sum(diag(singular)>1e-10*max(diag(singular)));
    left=left(:,1:rankValue); K=left'*Kfull;
    L=H0\(basis.u'*(context.weights.*linearBasis.u)+basis.v'*(context.weights.*linearBasis.v)+basis.w'*(context.weights.*linearBasis.w)+context.N2*basis.eta'*(context.weights.*linearBasis.eta)+context.g*basis.ssh'*(context.surfaceWeights.*linearBasis.ssh));
    Ws=basis.w(context.top,:);
    linearForcing=context.f*(basis.u'*(context.weights.*basis.v)-basis.v'*(context.weights.*basis.u))+context.N2*(basis.eta'*(context.weights.*basis.w)-basis.w'*(context.weights.*basis.eta))-context.g*Ws'*(context.surfaceWeights.*basis.ssh)+context.g*basis.ssh'*(context.surfaceWeights.*Ws);
    unconstrainedLinear=H0\linearForcing;
    response=H0\K';
    linearTarget=left'*[Ws;zeros(2*context.nSurface,length(seed))];
    linearWeak=unconstrainedLinear-response*((K*response)\(K*unconstrainedLinear-linearTarget));
    study=struct(basis=basis,context=context,Kfull=Kfull,left=left,K=K,L=L,linearWeak=linearWeak,phaseStep=phaseStep);
    phaseCount=round(duration/phaseStep)+1;
    study.forward=zeros(length(seed),length(seed),phaseCount);
    study.backward=study.forward;
    phaseError=0;
    for j=1:phaseCount
        time=(j-1)*phaseStep;
        study.forward(:,:,j)=expm(L*time);
        study.backward(:,:,j)=expm(-L*time);
        phaseError=max(phaseError,norm(study.forward(:,:,j)*study.backward(:,:,j)-eye(length(seed)),2));
    end
    linearFinal=linearControl(seed,study,duration,10);
    linearDrift=norm(linearFinal-seed)/norm(seed);
    linearOperatorError=norm(linearWeak-L,2)/norm(L,2);
    [~,initial]=helper.weakTendency(study,seed);
    baseline=readtable(fullfile(outputFolder,'mapped-weak-budget-study.csv'));
    baseline=baseline(baseline.configuration==configuration & baseline.amplitude==1,:);
    if height(baseline)~=1
        error('WV:WeakTrajectoryBaseline','Run the reviewed instantaneous study in this output folder before the trajectory study.');
    end
    sharedRhsBudgetDifference=abs(initial.energyRate-baseline.constrainedEnergyRate)/max(abs(baseline.constrainedEnergyRate),realmin);
    runs=cell(length(steps),1);
    fprintf('trajectory configuration %d: linear operator %.3g, interaction control drift %.3g, phase group %.3g\n',configuration,linearOperatorError,linearDrift,phaseError);
    for run=1:length(steps)
        dt=steps(run);
        clock=tic;
        A=seed; work=zeros(4,1); extrema=initial;
        for step=1:round(duration/dt)
            time=(step-1)*dt;
            [k1,d1]=stage(A,time,study,helper);
            [k2,d2]=stage(A+dt*k1/2,time+dt/2,study,helper);
            [k3,d3]=stage(A+dt*k2/2,time+dt/2,study,helper);
            [k4,d4]=stage(A+dt*k3,time+dt,study,helper);
            A=A+dt*(k1+2*k2+2*k3+k4)/6;
            work=work+dt*(d1.workRates+2*d2.workRates+2*d3.workRates+d4.workRates)/6;
            for diagnostic={d1,d2,d3,d4}, extrema=mergeExtrema(extrema,diagnostic{1}); end
            state=phaseApply(A,time+dt,study,false);
            energy=helper.energyGeometry(basis,state,context);
            fields=helper.stateFromVector(basis,state,context);
            [labelMin,labelMax]=helper.labelBounds(fields,context);
            extrema.minimumLabel=min(extrema.minimumLabel,labelMin);
            extrema.maximumLabel=max(extrema.maximumLabel,labelMax);
            history{end+1}=struct(configuration=configuration,deltaT=dt,time=time+dt,energy=energy,energyChange=energy-initial.energy,integratedGridWork=work(1),integratedReactionWork=work(2),integratedSolverWork=work(3),integratedSSHGeometryWork=work(4),energyBudgetResidual=energy-initial.energy-sum(work),minimumLabel=labelMin,maximumLabel=labelMax); %#ok<AGROW>
        end
        elapsed=toc(clock);
        finalState=phaseApply(A,duration,study,false);
        [~,final]=helper.weakTendency(study,finalState);
        extrema=mergeExtrema(extrema,final);
        result=struct(configuration=configuration,nz=config(1),apvModeCount=config(2),waveModeCount=config(3),mdaModeCount=config(4),inertialModeCount=config(5),retainedHorizontalGrid=4,quadratureHorizontalGrid=context.shape(1),deltaT=dt,duration=duration,realCoefficientCount=length(seed),constraintRank=rankValue,linearOperatorRelativeError=linearOperatorError,linearInteractionRelativeDrift=linearDrift,phaseGroupError=phaseError,seedRefinementRelativeDifference=seedDifference,sharedRHSRelativeBudgetDifference=sharedRhsBudgetDifference,initialEnergy=initial.energy,finalEnergy=final.energy,energyChange=final.energy-initial.energy,integratedGridWork=work(1),integratedReactionWork=work(2),integratedSolverWork=work(3),integratedSSHGeometryWork=work(4),energyBudgetResidual=final.energy-initial.energy-sum(work),relativeEnergyBudgetResidual=(final.energy-initial.energy-sum(work))/initial.energy,minimumStageLabel=extrema.minimumLabel,maximumStageLabel=extrema.maximumLabel,maximumStageDivergence=extrema.maximumDivergence,maximumStageSSHResidual=extrema.maximumSSHResidual,maximumStageRetainedEndpointResidual=extrema.maximumRetainedEndpointResidual,maximumDiscardedBoundaryTargetRMS=extrema.discardedBoundaryTargetRMS,maximumStageBudgetIdentityError=extrema.budgetIdentityError,trajectorySeconds=elapsed,stageCount=4*round(duration/dt),matlabRelease=string(version('-release')));
        runs{run}=struct(result=result,A=A,state=finalState);
        fprintf('dt %.1f: energy change %.6g, integrated reaction %.6g, budget residual %.3g, elapsed %.2fs\n',dt,result.energyChange,result.integratedReactionWork,result.energyBudgetResidual,elapsed);
    end
    finalFields=helper.stateFromVector(basis,runs{end}.state,context);
    finalFingerprint=helper.seedCheckpoints(finalFields,context);
    if isempty(coarseFinal), coarseFinal=finalFingerprint; end
    spatialDifference=norm(finalFingerprint-coarseFinal)/norm(coarseFinal);
    for run=1:length(steps)
        result=runs{run}.result;
        result.fixedStateRelativeStepError=norm(runs{run}.A-runs{end}.A)/norm(runs{end}.A);
        result.finestDeltaT=steps(end);
        result.finestTimeStepCommonGridStateDifferenceToCoarse=spatialDifference;
        rows{end+1}=result; %#ok<AGROW>
    end
end
results=struct2table(vertcat(rows{:}));
writetable(results,fullfile(outputFolder,'mapped-weak-trajectory-study.csv'));
writetable(struct2table(vertcat(history{:})),fullfile(outputFolder,'mapped-weak-trajectory-history.csv'));
end

function [rate,diagnostics] = stage(A,time,study,helper)
state=phaseApply(A,time,study,false);
[physicalRate,diagnostics]=helper.weakTendency(study,state);
rate=phaseApply(physicalRate-study.L*state,time,study,true);
end

function value = phaseApply(value,time,study,backward)
index=round(time/study.phaseStep)+1;
if abs((index-1)*study.phaseStep-time)>1e-10
    error('WV:WeakTrajectoryPhaseTime','The requested stage time is outside the precomputed phase grid.');
end
if backward, value=study.backward(:,:,index)*value; else, value=study.forward(:,:,index)*value; end
end

function A = linearControl(A,study,duration,dt)
% Supply the independently assembled linear weak equations, not a zero RHS.
for step=1:round(duration/dt)
    time=(step-1)*dt;
    k1=linearStage(A,time,study);
    k2=linearStage(A+dt*k1/2,time+dt/2,study);
    k3=linearStage(A+dt*k2/2,time+dt/2,study);
    k4=linearStage(A+dt*k3,time+dt,study);
    A=A+dt*(k1+2*k2+2*k3+k4)/6;
end
end

function rate = linearStage(A,time,study)
state=phaseApply(A,time,study,false);
rate=phaseApply(study.linearWeak*state-study.L*state,time,study,true);
end

function result = mergeExtrema(result,value)
result.minimumLabel=min(result.minimumLabel,value.minimumLabel);
result.maximumLabel=max(result.maximumLabel,value.maximumLabel);
for name=["maximumDivergence","maximumSSHResidual","maximumRetainedEndpointResidual","discardedBoundaryTargetRMS"]
    result.(name)=max(result.(name),value.(name));
end
result.budgetIdentityError=max(abs(result.budgetIdentityError),abs(value.budgetIdentityError));
end
