function result=runThermodynamicTrajectory(op,initial,start,duration,dt,reference)
% Fixed-step RK4 with physical observations at 40-second endpoints.
arguments
    op (1,1) struct
    initial (1,1) struct
    start (1,1) double
    duration (1,1) double
    dt (1,1) double
    reference (1,:) cell = {}
end
state=initial; names=string(fieldnames(state)).';
checkpoints={}; diagnostics=struct([]); rhsSeconds=0; diagnosticSeconds=0; comparisonSeconds=0;
maximumError=zeros(1,3); initialError=maximumError;
clock=tic;
for step=0:round(duration/dt)
    time=start+step*dt;
    if mod(step*dt,40)==0
        timer=tic; point=op.checkpoint(time,state); comparisonSeconds=comparisonSeconds+toc(timer);
        timer=tic; d=op.observe(time,state);
        diagnosticSeconds=diagnosticSeconds+toc(timer);
        if isempty(diagnostics), diagnostics=d; else, diagnostics(end+1)=d; end %#ok<AGROW>
        index=1+round(step*dt/40);
        if isempty(reference)
            checkpoints{index}=point; %#ok<AGROW>
        else
            target=reference{index};
            error=[sqrt(mean((point.u-target.u).^2+(point.v-target.v).^2+(point.w-target.w).^2,'all')),sqrt(mean((point.density-target.density).^2,'all')),sqrt(mean((point.ssh-target.ssh).^2,'all'))];
            maximumError=max(maximumError,error);
            if step==0, initialError=error; end
        end
    end
    if step==round(duration/dt), break; end
    timer=tic;
    a=op.rhs(time,state);
    b=op.rhs(time+dt/2,add(state,a,dt/2));
    c=op.rhs(time+dt/2,add(state,b,dt/2));
    d=op.rhs(time+dt,add(state,c,dt));
    for name=names, state.(name)=state.(name)+dt*(a.(name)+2*b.(name)+2*c.(name)+d.(name))/6; end
    rhsSeconds=rhsSeconds+toc(timer);
end
elapsed=toc(clock); first=diagnostics(1); last=diagnostics(end);
summary=struct(deltaT=dt,duration=duration,acceptedRHS=4*round(duration/dt),rejectedRHS=0, ...
    evolutionSeconds=rhsSeconds,diagnosticSeconds=diagnosticSeconds,comparisonSeconds=comparisonSeconds,wallSeconds=elapsed, ...
    velocityError=maximumError(1),densityError=maximumError(2),sshError=maximumError(3), ...
    initialVelocityError=initialError(1),initialDensityError=initialError(2),initialSSHError=initialError(3), ...
    energyInitial=first.energy,energyChange=last.energy-first.energy,volumeChange=last.volume-first.volume, ...
    densityMomentChange=last.densityMoment-first.densityMoment,densitySquaredMomentChange=last.densitySquaredMoment-first.densitySquaredMoment, ...
    minimumLabel=min([diagnostics.minimumLabel]),maximumLabel=max([diagnostics.maximumLabel]));
result=struct(summary=summary,checkpoints={checkpoints},diagnostics=diagnostics,finalState=state);

    function value=add(value,rate,scale)
        for name=names, value.(name)=value.(name)+scale*rate.(name); end
    end
end
