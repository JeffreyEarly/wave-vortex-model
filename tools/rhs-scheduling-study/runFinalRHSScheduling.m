function runFinalRHSScheduling(folder)
% Compare integrated production with the frozen pre-change complete RHS.
output=fullfile(fileparts(mfilename('fullpath')),'results'); rows=struct([]);
for profile=["constant","exponential"]
    for config=1:4
        data=load(fullfile(folder,profile+"-"+config+".mat"));
        objects={RHSSchedulingReference(data.scientificState),WVTransformFreeSurfaceBoussinesq(data.scientificState)};
        for j=1:2
            w=objects{j};
            for name=string(fieldnames(data.initial)).', w.(name)=data.initial.(name); end
            w.t=327; w.addForcing(WVNonlinearAdvection(w));
        end
        for mode=["cold","warm","overlap","successive"]
            for j=1:2
                objects{j}.t=327;
                for warmup=1:20, evaluate(objects{j},mode); end
            end
            costs=zeros(2,7);
            for trial=1:7
                order=1:2; if mod(trial,2)==0, order=2:-1:1; end
                for j=order
                    timer=tic; for repeat=1:50, evaluate(objects{j},mode); end
                    costs(j,trial)=toc(timer)/50;
                end
            end
            for j=1:2
                names=["reference","production"];
                row=struct(profile=profile,config=config,nx=objects{j}.Nx,nz=objects{j}.Nz,mode=mode,strategy=names(j),medianSeconds=median(costs(j,:)),minimumSeconds=min(costs(j,:)),maximumSeconds=max(costs(j,:)),trial1=costs(j,1),trial2=costs(j,2),trial3=costs(j,3),trial4=costs(j,4),trial5=costs(j,5),trial6=costs(j,6),trial7=costs(j,7));
                if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            end
        end
        writetable(struct2table(rows),fullfile(output,'final-rhs.csv'));
        fprintf('qualified timing %s config%d\n',profile,config);
    end
end
end
function rate=evaluate(w,mode)
if mode=="cold" || mode=="overlap"
    w.clearVariableCacheOfApAmA0DependentVariables();
    if mode=="overlap", w.reconstructFields(["u_hat","p","ssh"]); end
elseif mode=="successive"
    w.t=w.t+.01;
end
rate=w.coefficientTendency();
end
