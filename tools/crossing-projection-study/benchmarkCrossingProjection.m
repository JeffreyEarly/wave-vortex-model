function benchmarkCrossingProjection
% Complete production callback with a source-load candidate, including cache invalidation.
folder=fileparts(mfilename('fullpath')); addpath(fullfile(fileparts(folder),'nonlinear-study'));
rows=struct([]); checks=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    for nx=[8 24]
        counts=[17 65]; if nx==24, counts=[33 65]; end
        for nz=counts
            base=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[nx nx nz],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
            study=manuscriptEvolutionOperators(base,profile,padding=1); initial=study.seed("mixed",.01);
            objects={base,CrossingProjectionCandidate(base.scientificState())};
            for j=1:2
                w=objects{j};
                for name=string(fieldnames(initial)).', w.(name)=initial.(name); end
                w.t=327; w.t0=-17; w.addForcing(WVNonlinearAdvection(w));
                p=WVInternal.prepareBoussinesqRHSAssessment(w);
                reference=WVInternal.evaluateBoussinesqRHSAssessment(p,[max(nx,64) max(nx,64) 129],crossingOrder=16);
                rate=w.coefficientTendency();
                for name=string(fieldnames(rate)).'
                    item=struct(profile=profile,nx=nx,nz=nz,strategy=j,family=name,absoluteError=norm(rate.(name)-reference.tendency.(name),'fro'),referenceNorm=norm(reference.tendency.(name),'fro'));
                    if isempty(checks), checks=item; else, checks(end+1)=item; end %#ok<AGROW>
                end
            end
            for j=1:2, for warm=1:10, evaluate(objects{j}); end, end
            costs=zeros(2,5);
            for trial=1:5
                order=1:2; if mod(trial,2)==0, order=2:-1:1; end
                for j=order
                    timer=tic; for repeat=1:30, evaluate(objects{j}); end
                    costs(j,trial)=toc(timer)/30;
                end
            end
            for j=1:2
                item=struct(profile=profile,nx=nx,nz=nz,strategy=j,medianSeconds=median(costs(j,:)),trial1=costs(j,1),trial2=costs(j,2),trial3=costs(j,3),trial4=costs(j,4),trial5=costs(j,5));
                if isempty(rows), rows=item; else, rows(end+1)=item; end %#ok<AGROW>
            end
            fprintf('callback %s %dx%dx%d baseline %.3g split %.3g ms\n',profile,nx,nx,nz,1000*median(costs(1,:)),1000*median(costs(2,:)));
            writetable(struct2table(rows),fullfile(folder,'results','runtime.csv'));
            writetable(struct2table(checks),fullfile(folder,'results','runtime-accuracy.csv'));
        end
    end
end
end
function rate=evaluate(w)
w.t=w.t+.01; rate=w.coefficientTendency();
end
