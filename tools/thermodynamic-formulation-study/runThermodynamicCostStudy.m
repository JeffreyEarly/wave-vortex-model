function runThermodynamicCostStudy
% Paired complete-RHS timing, including label validity and density inversion.
folder=fileparts(mfilename('fullpath')); rows=struct([]); kernels=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    representedDegree=length(chebfun(N2,[-1000 0],'splitting','off'))-1;
    specifications=[8 16 16;33 65 65;3 3 6;4 4 8;2 2 4];
    if profile=="exponential", specifications=[specifications,[8;33;10;12;8],[8;65;10;12;8],[16;65;10;12;8]]; end
    for spec=specifications
        clock=tic;
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[spec(1) spec(1) spec(2)],N2Function=N2,apvModeCount=spec(3),waveModeCount=spec(4),mdaModeCount=spec(5),inertialModeCount=3,nEVP=256,shouldAntialias=false);
        setup=toc(clock); study=manuscriptEvolutionOperators(w,profile,padding=1); a=study.seed("mixed",.1);
        b=thermodynamicCoefficientMap(w,profile,a,327);
        old=QuadratureBuoyancyReference(w.scientificState());
        options=cell(1,4); operatorSetup=zeros(1,4); firstCall=zeros(1,4);
        variants=["displacement","displacement","density","equivalent"];
        for j=1:4
            object=w; if j==1, object=old; end
            clock=tic; options{j}=thermodynamicComparisonOperators(object,profile,variants(j)); operatorSetup(j)=toc(clock);
        end
        states={a,a,b,b}; labels=["quadrature displacement","optimized displacement","native density","equivalent density"];
        for j=1:4, clock=tic; options{j}.rhs(327,states{j}); firstCall(j)=toc(clock); end
        samples=zeros(5,4); diagnostics=zeros(5,4);
        for trial=1:5
            order=1:4; if mod(trial,2)==0, order=4:-1:1; end
            for j=order
                clock=tic; for repeat=1:5, options{j}.rhs(327,states{j}); end; samples(trial,j)=toc(clock)/5;
                clock=tic; for repeat=1:3, options{j}.observe(327,states{j}); end; diagnostics(trial,j)=toc(clock)/3;
            end
        end
        for j=1:4
            row=struct(profile=profile,Nx=spec(1),Nz=spec(2),apvModes=spec(3),waveModes=spec(4),variant=labels(j),profileDegree=representedDegree,setupSeconds=setup,operatorSetupSeconds=operatorSetup(j),firstRHSSeconds=firstCall(j),rhsMedian=median(samples(:,j)),rhsMinimum=min(samples(:,j)),rhsMaximum=max(samples(:,j)),diagnosticMedian=median(diagnostics(:,j)));
            if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
        end
        % Independent kernel timings are descriptive, not an additive decomposition.
        w.t=327; for name=string(fieldnames(a)).', w.(name)=a.(name); end
        f=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
        z=reshape(w.z,1,1,[])+reshape(1+w.z/w.Lz,1,1,[]).*f.ssh;
        geometryEta=z-reshape(w.z,1,1,[]); context=WVInternal.freeSurfaceThermodynamics(w);
        [source.u,source.v,source.w,source.eta]=w.nonlinearAdvectionSources();
        functions={@()context.evaluateNonlinear(z,f.eta,f.ssh,w.N2),@()context.evaluateNonlinear(z,geometryEta,f.ssh,w.N2),@()w.projectSources(source),@()coldReconstruct(w),@()invertThermodynamicCoefficientMap(w,profile,b,327)};
        names=["displacement thermodynamics","density geometry thermodynamics","source transforms and projection","cold modal and grid reconstruction","coefficient inverse"];
        for j=1:numel(functions)
            functions{j}(); times=zeros(3,1);
            for trial=1:3, clock=tic; for repeat=1:5, functions{j}(); end; times(trial)=toc(clock)/5; end
            row=struct(profile=profile,Nx=spec(1),Nz=spec(2),apvModes=spec(3),waveModes=spec(4),kernel=names(j),seconds=median(times));
            if isempty(kernels), kernels=row; else, kernels(end+1)=row; end %#ok<AGROW>
        end
    end
end
writetable(struct2table(rows),fullfile(folder,'results','rhs-costs.csv'));
writetable(struct2table(kernels),fullfile(folder,'results','kernel-costs.csv'));
[~,cpu]=system('sysctl -n machdep.cpu.brand_string');
metadata=struct(matlab=version,computer=computer,cpu=strtrim(cpu),sourceRevision='cf343b95523240a5de658dcfd309401032b9ad80',timing='Five alternating-order trials; five RHS evaluations per sample; contexts warmed; coefficient assignments invalidate state caches normally.');
fid=fopen(fullfile(folder,'results','runtime.json'),'w'); cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(metadata,PrettyPrint=true));
end
function fields=coldReconstruct(w)
w.clearVariableCacheOfApAmA0DependentVariables();
fields=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
end
