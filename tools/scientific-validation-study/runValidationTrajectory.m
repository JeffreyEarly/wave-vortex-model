function result=runValidationTrajectory(scientificState,scenario,profile,options)
% Bounded unforced RK4 trajectory with independent manuscript diagnostics.
arguments
    scientificState (1,1) struct
    scenario (1,1) string
    profile (1,1) string
    options.duration (1,1) double
    options.deltaT (1,1) double = 20
    options.padding (1,1) double = 1
    options.reference (1,1) struct = struct()
end
w=WVTransformFreeSurfaceBoussinesq(scientificState); w.t0=-17;
w.addForcing(WVNonlinearAdvection(w));
seed=manuscriptEvolutionOperators(w,profile,padding=1);
observer=manuscriptEvolutionOperators(w,profile,padding=2);
physical=thermodynamicComparisonOperators(w,profile,"displacement");
thermalContext=WVInternal.freeSurfaceThermodynamics(w);
xi=reshape(w.z,1,1,[]); alpha=1+xi/w.Lz;
weights=reshape(w.verticalQuadratureWeights,1,1,[])/(4*w.Nx*w.Ny);
state=seed.seed(scenario,.1); names=string(fieldnames(state)).';
dt=options.deltaT; duration=options.duration; start=327;
comparisonInterval=80*ceil(duration/(48*80));
comparisonTimes=unique([0:comparisonInterval:duration,duration]);
checkpoints={}; states={}; diagnostics=struct([]); errors=struct([]); status="completed"; failure="";
lastTime=0; completedSteps=0; timer=tic; checkIndex=0; scales=[];
for step=0:round(duration/dt)
    elapsed=step*dt; time=start+elapsed;
    try
        if mod(elapsed,80)==0 || elapsed==duration
            rate=rhs(time,state); [d,detail]=observer.observe(time,state,rate);
            h=detail.hatted; gamma=1+h.ssh/w.Lz;
            thermal=thermalContext.evaluate(xi+alpha.*h.ssh,h.eta,h.ssh);
            u=h.u./gamma; v=h.v./gamma;
            vertical=h.w+alpha.*(u.*observer.derivative.x(h.ssh)+v.*observer.derivative.y(h.ssh));
            d.energyAnalytic=d.energy;
            d.energy=sum(weights.*gamma.*(.5*(u.^2+v.^2+vertical.^2)+thermal.ape),'all')+.5*w.g*mean(h.ssh.^2,'all');
            if isempty(diagnostics), diagnostics=d; else, diagnostics(end+1)=d; end %#ok<AGROW>
            if any(elapsed==comparisonTimes)
                checkIndex=checkIndex+1; point=physical.checkpoint(time,state);
                if isempty(scales)
                    z=reshape(linspace(-w.Lz,0,101),1,1,[])+(1+reshape(linspace(-w.Lz,0,101),1,1,[])/w.Lz).*point.ssh;
                    if profile=="constant", I=1e-4*min(z,0); else, I=1e-4*650*expm1(min(z,0)/650); end
                    background=w.rho0-(w.rho0/w.g)*I;
                    scales=[sqrt(mean(point.u.^2+point.v.^2+point.w.^2,'all')),sqrt(mean((point.density-background).^2,'all')),sqrt(mean(point.ssh.^2,'all'))];
                    scales=max(scales,1e-10);
                end
                if isempty(fieldnames(options.reference))
                    checkpoints{checkIndex}=point; states{checkIndex}=state; %#ok<AGROW>
                else
                    ref=options.reference;
                    target=ref.checkpoints{checkIndex};
                    absolute=[sqrt(mean((point.u-target.u).^2+(point.v-target.v).^2+(point.w-target.w).^2,'all')),sqrt(mean((point.density-target.density).^2,'all')),sqrt(mean((point.ssh-target.ssh).^2,'all'))];
                    relative=absolute./ref.scales;
                    item=struct(time=time,velocityRelative=relative(1),densityRelative=relative(2),sshRelative=relative(3),velocityAbsolute=absolute(1),densityAbsolute=absolute(2),sshAbsolute=absolute(3));
                    if isempty(errors), errors=item; else, errors(end+1)=item; end %#ok<AGROW>
                end
            end
        end
        if step==round(duration/dt), break; end
        a=rhs(time,state); b=rhs(time+dt/2,add(state,a,dt/2));
        c=rhs(time+dt/2,add(state,b,dt/2)); d=rhs(time+dt,add(state,c,dt));
        next=state;
        for stageFamily=names, next.(stageFamily)=state.(stageFamily)+dt*(a.(stageFamily)+2*b.(stageFamily)+2*c.(stageFamily)+d.(stageFamily))/6; end
        % Validate the completed state too, not just the four stage states.
        if mod(elapsed+dt,80)==0, rhs(time+dt,next); end
        state=next; completedSteps=completedSteps+1; lastTime=elapsed+dt;
    catch exception
        if any(string(exception.identifier)==["WV:ParcelLabelDomain","WVStudy:ParcelLabels","WV:FreeSurfaceGeometry","WV:ThermodynamicGeometry"])
            status="stopped"; failure=string(exception.identifier)+": "+string(exception.message); break
        end
        rethrow(exception)
    end
end
first=diagnostics(1); last=diagnostics(end);
summary=struct(scenario=scenario,profile=profile,status=status,failure=failure,durationRequested=duration,durationCompleted=lastTime,deltaT=dt,padding=options.padding,nx=w.Nx,nz=w.Nz,wallSeconds=toc(timer),steps=completedSteps,energyInitial=first.energy,energyChange=(last.energy-first.energy)/first.energy,maximumEnergyChange=max(abs([diagnostics.energy]-first.energy))/first.energy,apv2Initial=first.apv2,apv2Change=(last.apv2-first.apv2)/(w.f^2*w.Lz),maximumAPV2Change=max(abs([diagnostics.apv2]-first.apv2))/(w.f^2*w.Lz),maximumEnergyRate=max(abs([diagnostics.energyRate]))/first.energy,maximumBudgetResidual=max(abs([diagnostics.energyBudgetResidual]))/first.energy,maximumSSHResidual=max([diagnostics.sshResidual]),maximumSurfaceResidual=max([diagnostics.surfaceResidual]),maximumBottomResidual=max([diagnostics.bottomResidual]),minimumLabel=min([diagnostics.minimumLabel]),maximumLabel=max([diagnostics.maximumLabel]));
result=struct(summary=summary,diagnostics=struct2table(diagnostics),errors=struct2table(errors),checkpoints={checkpoints},states={states},comparisonTimes=comparisonTimes(1:checkIndex),scales=scales,finalState=state);
    function rate=rhs(time,value)
        w.t=time;
        for rhsFamily=names, w.(rhsFamily)=value.(rhsFamily); end
        if options.padding==1, rate=w.coefficientTendency(); else, rate=observer.rhs(time,value); end
    end
    function value=add(value,rate,scale)
        for incrementFamily=names, value.(incrementFamily)=value.(incrementFamily)+scale*rate.(incrementFamily); end
    end
end
