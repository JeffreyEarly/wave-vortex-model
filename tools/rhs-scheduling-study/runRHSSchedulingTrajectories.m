function runRHSSchedulingTrajectories(folder)
% Short RK4 trajectories through the registered complete coefficient callback.
output=fullfile(fileparts(mfilename('fullpath')),'results'); rows=struct([]);
for profile=["constant","exponential"]
    data=load(fullfile(folder,profile+"-3.mat"));
    objects={RHSSchedulingReference(data.scientificState),WVTransformFreeSurfaceBoussinesq(data.scientificState)};
    for j=1:2, objects{j}.addForcing(WVNonlinearAdvection(objects{j})); integrate(objects{j},data.initial); end
    costs=zeros(2,7); final=cell(1,2);
    for trial=1:7
        order=1:2; if mod(trial,2)==0, order=2:-1:1; end
        for j=order
            timer=tic; final{j}=integrate(objects{j},data.initial); costs(j,trial)=toc(timer);
        end
        assert(isequaln(final{1},final{2}),'The scheduling change must preserve this trajectory exactly.')
    end
    names=["reference","production"];
    for j=1:2
        row=struct(profile=profile,strategy=names(j),nx=objects{j}.Nx,nz=objects{j}.Nz,duration=40,step=5,rhsCalls=32,medianSeconds=median(costs(j,:)),trial1=costs(j,1),trial2=costs(j,2),trial3=costs(j,3),trial4=costs(j,4),trial5=costs(j,5),trial6=costs(j,6),trial7=costs(j,7),maxCoefficientDifference=0);
        if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
    end
end
writetable(struct2table(rows),fullfile(output,'final-trajectories.csv'));
end
function state=integrate(w,state)
w.t0=-17;
for time=327:5:362
    k1=rhs(w,time,state); k2=rhs(w,time+2.5,advance(state,k1,2.5));
    k3=rhs(w,time+2.5,advance(state,k2,2.5)); k4=rhs(w,time+5,advance(state,k3,5));
    for name=string(fieldnames(state)).'
        state.(name)=state.(name)+(5/6)*(k1.(name)+2*k2.(name)+2*k3.(name)+k4.(name));
    end
end
end
function rate=rhs(w,time,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
w.t=time; rate=w.coefficientTendency();
end
function state=advance(state,rate,step)
for name=string(fieldnames(state)).', state.(name)=state.(name)+step*rate.(name); end
end
