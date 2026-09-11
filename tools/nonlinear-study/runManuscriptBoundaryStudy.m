function results = runManuscriptBoundaryStudy(outputFolder,options)
% Isolate retained-family contributions to direct manuscript boundary rates.
arguments (Input)
    outputFolder (1,1) string
    options.profiles (1,:) string {mustBeMember(options.profiles,["constant","exponential"])} = ["constant","exponential"]
    options.scenarios (1,:) string {mustBeMember(options.scenarios,["waves","waveBalanced","mixed"])} = ["waves","waveBalanced","mixed"]
    options.configurations (1,:) double {mustBeInteger,mustBeMember(options.configurations,1:7)} = 1:7
    options.Nz (1,1) double {mustBeInteger,mustBePositive} = 129
    options.amplitude (1,1) double {mustBePositive} = 1
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
% [APV wave MDA inertial]. Keep the two zero-APV endpoints in every row.
counts=[8 12 8 8;2 3 2 2;8 3 2 2;2 12 2 2;2 3 8 2;2 3 2 8;4 6 4 4];
rows={}; contributions={}; reference=struct();
for profile=options.profiles
    N2=@(z)1e-4+0*z;
    if profile=="exponential", N2=@(z)1e-4*exp(z/650); end
    for configuration=options.configurations
        c=counts(configuration,:); clock=tic;
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 options.Nz],N2Function=N2,apvModeCount=c(1),waveModeCount=c(2),mdaModeCount=c(3),inertialModeCount=c(4),nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
        constructionSeconds=toc(clock); w.t0=-17;
        study=manuscriptEvolutionOperators(w,profile);
        for scenario=options.scenarios
            state=study.seed(scenario,options.amplitude);
            [fingerprint,minimum,maximum]=study.checkpoint(327,state);
            key=profile+scenario;
            if ~isfield(reference,key), reference.(key)=fingerprint; end
            seedDifference=norm(fingerprint-reference.(key))/norm(reference.(key));
            assert(seedDifference<1e-7,'Refinement changed the physical seed.');
            assert(minimum>=-w.Lz && maximum<=0,'The common-grid seed labels are invalid.');
            rate=study.rhs(327,state); % warm-up before complete-RHS timing
            elapsed=zeros(1,3);
            for repeat=1:3, clock=tic; rate=study.rhs(327,state); elapsed(repeat)=toc(clock); end
            [d,detail]=study.observe(327,state,rate);
            d.profile=profile; d.scenario=scenario; d.configuration=configuration;
            d.apvCount=c(1); d.waveCount=c(2); d.mdaCount=c(3); d.inertialCount=c(4);
            d.Nz=options.Nz; d.amplitude=options.amplitude; d.seedDifference=seedDifference;
            d.constructionSeconds=constructionSeconds; d.rhsSeconds=median(elapsed);
            for pair={"ssh","surface","bottom"}
                name=string(pair{1}); value=detail.("R"+name);
                d.(name+"MeanResidual")=abs(mean(value,'all'));
                d.(name+"NonmeanResidual")=max(abs(value-mean(value,'all')),[],'all');
            end
            rows{end+1,1}=struct2table(d); %#ok<AGROW>
            summed=struct(ssh=zeros(size(detail.Rssh)),surface=zeros(size(detail.Rssh)),bottom=zeros(size(detail.Rssh)));
            for family=string(fieldnames(rate)).'
                isolated=w.coefficientState(); isolated.(family)=rate.(family);
                field=study.sample(327,isolated,2);
                value=struct(ssh=field.ssh,surface=field.eta(:,:,end)-field.ssh,bottom=field.eta(:,:,1));
                row=struct(profile=profile,scenario=scenario,configuration=configuration,family=family);
                for name=["ssh","surface","bottom"]
                    summed.(name)=summed.(name)+value.(name);
                    row.(name+"Maximum")=max(abs(value.(name)),[],'all');
                    row.(name+"Mean")=mean(value.(name),'all');
                end
                contributions{end+1,1}=struct2table(row); %#ok<AGROW>
            end
            assert(max(abs(summed.ssh-detail.nonlinear.ssh),[],'all')<1e-12,'Family SSH rates do not sum to the direct rate.');
            fprintf('%s %s [%d %d %d %d]: SSH %.3g, surface %.3g (mean %.3g), bottom %.3g (mean %.3g), seed %.3g\n',profile,scenario,c,d.sshResidual,d.surfaceResidual,d.surfaceMeanResidual,d.bottomResidual,d.bottomMeanResidual,seedDifference);
        end
    end
end
results=vertcat(rows{:});
writetable(results,fullfile(outputFolder,'manuscript-boundary-counts.csv'));
writetable(vertcat(contributions{:}),fullfile(outputFolder,'manuscript-boundary-families.csv'));
end
