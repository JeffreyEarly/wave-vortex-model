function runRHSSchedulingBenchmarks(folder,options)
arguments
    folder (1,1) string
    options.strategies (1,:) string = ["production","baseline","setup","source","spectral","combined"]
    options.prefix (1,1) string = "candidate"
end
% Isolated paired complete-RHS timing, preserving production cache ownership.
output=fullfile(fileparts(mfilename('fullpath')),'results'); rows=struct([]); checks=struct([]);
strategies=options.strategies;
for profile=["constant","exponential"]
    for config=1:4
        data=load(fullfile(folder,profile+"-"+config+".mat")); objects=cell(1,numel(strategies));
        for j=1:numel(strategies)
            if j==1, w=RHSSchedulingReference(data.scientificState); else, w=RHSSchedulingCandidate(data.scientificState,strategies(j)); end
            for field=string(fieldnames(data.initial)).', w.(field)=data.initial.(field); end
            w.t=327; w.addForcing(WVNonlinearAdvection(w)); objects{j}=w; evaluate(w,"cold");
        end
        [expected,expectedSource]=evaluate(objects{1},"cold");
        for j=2:numel(strategies)
            [actual,source]=evaluate(objects{j},"cold");
            for family=string(fieldnames(expected)).'
                e=max(abs(actual.(family)-expected.(family)),[],'all'); scale=max(abs(expected.(family)),[],'all');
                assert(e<=3e-10*scale+1e-18);
                row=struct(profile=profile,config=config,strategy=strategies(j),quantity=family,maxError=e,referenceMax=scale);
                if isempty(checks), checks=row; else, checks(end+1)=row; end %#ok<AGROW>
            end
            for field=["u","v","w","eta"]
                e=max(abs(source.(field)-expectedSource.(field)),[],'all'); scale=max(abs(expectedSource.(field)),[],'all');
                assert(e<=3e-10*scale+1e-17);
                row=struct(profile=profile,config=config,strategy=strategies(j),quantity=field,maxError=e,referenceMax=scale);
                checks(end+1)=row; %#ok<AGROW>
            end
        end
        for mode=["cold","warm","overlap","successive"]
            costs=zeros(numel(strategies),5);
            for j=1:numel(objects)
                objects{j}.t=327;
                for warmup=1:3, evaluate(objects{j},mode); end
            end
            for trial=1:5
                order=1:numel(strategies); if mod(trial,2)==0, order=fliplr(order); end
                for j=order
                    timer=tic; for repeat=1:30, evaluate(objects{j},mode); end
                    costs(j,trial)=toc(timer)/30;
                end
            end
            for j=1:numel(strategies)
                row=struct(profile=profile,config=config,nx=objects{j}.Nx,nz=objects{j}.Nz,mode=mode,strategy=strategies(j),medianSeconds=median(costs(j,:)),minimumSeconds=min(costs(j,:)),maximumSeconds=max(costs(j,:)),trial1=costs(j,1),trial2=costs(j,2),trial3=costs(j,3),trial4=costs(j,4),trial5=costs(j,5));
                if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            end
        end
        writetable(struct2table(rows),fullfile(output,options.prefix+'s.csv'));
        writetable(struct2table(checks),fullfile(output,options.prefix+'-equivalence.csv'));
        fprintf('benchmarked %s config%d\n',profile,config);
    end
end
end
function [rate,source]=evaluate(w,mode)
if mode=="cold" || mode=="overlap"
    w.clearVariableCacheOfApAmA0DependentVariables();
    if mode=="overlap", w.reconstructFields(["u_hat","p","ssh"]); end
elseif mode=="successive"
    w.t=w.t+.01;
end
rate=w.coefficientTendency();
if nargout>1
    w.clearVariableCacheOfApAmA0DependentVariables();
    [source.u,source.v,source.w,source.eta]=w.nonlinearAdvectionSources();
end
end
