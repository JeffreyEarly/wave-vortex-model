function result = waveQuadraticResolutionExample(outputDirectory,options)
% Plot linear retained counts and sampled quadratic errors for one count map.
%
% Run from an authoring checkout with released dependencies configured. This
% companion uses WVM's dealiased horizontal interaction inventory (excluding
% Nyquist), not the complete FFT inventory in the InternalModes linear-only
% example. Both active boundaries are inputs; their nonlinear outputs remain
% outside the qualified scope. All reported errors are individual products.
arguments (Input)
    outputDirectory (1,1) string = string(tempname)
    options.configuration (1,1) struct = struct()
    options.quadraticTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = .1
    options.productBudget (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 500000
    options.workingMemoryBudget (1,1) double {mustBePositive,mustBeFinite} = 512*1024^2
end
arguments (Output)
    result (1,1) struct
end
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('WVStudy:OutputAlreadyExists','Choose a new output directory to preserve recorded evidence.')
end
config=options.configuration;
if isempty(fieldnames(config))
    config=resolveStudyCase("cal-exponential-17");
    config.id="count-map-exponential-25"; config.profile="exponential-surface";
    config.Lxy=[100000 100000]; config.Nxy=[16 16]; config.Nz=25;
    config.waveCount=11; config.evpOrders=[192 256]; config.gramTolerance=.01;
end
started=tic; data=prepareSourceStudy(config);
prepared=prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true,productBudget=options.productBudget,workingMemoryBudget=options.workingMemoryBudget);
preparationSeconds=toc(started);
kappa=prepared.inventory.magnitudes; positive=find(kappa>0); kappa=kappa(positive);
converged=zeros(numel(positive),1); gridSupported=converged;
for j=1:numel(positive)
    page=positive(j); report=prepared.modeConvergence{page}; pass=false(config.waveCount,1);
    for n=1:config.waveCount
        rows=report.measurements.columnLabel==string(prepared.waveLabels{page}(n)) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
        pass(n)=nnz(rows)==3 && all(report.measurements.status(rows)=="measured") && all(report.measurements.value(rows)<=config.eigenAllowance);
    end
    converged(j)=sum(cumprod(pass)>0);
    gridSupported(j)=sum(cumprod(prepared.waveGram(:,page)<=config.gramTolerance)>0);
end
counts=min(converged,gridSupported);
assessment=assessWaveQuadraticResolution(prepared,waveModeKappa=kappa,waveModeCount=counts,quadraticTolerance=options.quadraticTolerance,productBudget=options.productBudget);
% A second complete map explicitly changes only the retained wave counts.
repeat=assessWaveQuadraticResolution(prepared,waveModeKappa=kappa,waveModeCount=min(counts,3),quadraticTolerance=options.quadraticTolerance,productBudget=options.productBudget);
linear=table(kappa,converged,gridSupported,counts,converged==config.waveCount,VariableNames=["kappa","convergedCount","gridSupportedCount","requestedWaveCount","atCandidateCeiling"]);
fig=figure(Visible="off",Position=[100 100 1150 850]); closeFigure=onCleanup(@()close(fig));
layout=tiledlayout(fig,2,1,TileSpacing="compact",Padding="compact");
ax=nexttile(layout); plot(ax,kappa,converged,'-',LineWidth=1.5,DisplayName="EVP converged"); hold(ax,'on');
plot(ax,kappa,gridSupported,'--',LineWidth=1.5,DisplayName="Grid supported");
plot(ax,kappa,counts,'o-',LineWidth=1.2,DisplayName="Assessed count map");
ceiling=linear.atCandidateCeiling;
plot(ax,kappa(ceiling),converged(ceiling),'^',Color=[.2 .2 .2],DisplayName="Candidate ceiling");
ylim(ax,[0 config.waveCount+2]); ylabel(ax,'Leading wave count (includes external)'); grid(ax,'on'); legend(ax,Location="southwest");
ax=nexttile(layout); productErrors=assessment.pages.quadraticError(positive);
semilogy(ax,kappa,productErrors,'o-',LineWidth=1.5,DisplayName="Requested-map sampled error"); hold(ax,'on');
semilogy(ax,kappa,repeat.pages.quadraticError(positive),'s--',LineWidth=1.2,DisplayName="Same preparation, wave counts capped at 3");
yline(ax,options.quadraticTolerance,'--',DisplayName="Product tolerance");
unqualified=~ismember(assessment.pages.status(positive),["accepted","rejected"]);
if any(unqualified)
    semilogy(ax,kappa(unqualified),repmat(options.quadraticTolerance,nnz(unqualified),1),'x',MarkerSize=9,LineWidth=1.5,DisplayName="Unqualified / no retained-wave test");
end
xlabel(ax,'\kappa (rad m^{-1})'); ylabel(ax,'Normalized retained projection error'); grid(ax,'on'); legend(ax,Location="best");
title(layout,sprintf('%g × %g km; %d × %d horizontal points; %d WKB–Chebyshev points',config.Lxy/1000,config.Nxy,config.Nz));
subtitle(layout,sprintf('One complete map; Gram %.2g, products %.2g; %d tested products; %s',config.gramTolerance,options.quadraticTolerance,assessment.cost.selectedProducts,assessment.status));
mkdir(outputDirectory);
exportgraphics(fig,fullfile(outputDirectory,'count-map-quadratic.png'),Resolution=160);
exportgraphics(fig,fullfile(outputDirectory,'count-map-quadratic.pdf'),ContentType="vector");
writetable(linear,fullfile(outputDirectory,'linear-counts.csv'));
writetable(removevars(assessment.pages,'limitingInteraction'),fullfile(outputDirectory,'quadratic-pages.csv'));
writetable(removevars(repeat.pages,'limitingInteraction'),fullfile(outputDirectory,'repeat-pages.csv'));
writelines(jsonencode(assessment.pages.limitingInteraction,PrettyPrint=true),fullfile(outputDirectory,'limiting-interactions.json'));
writetable(table(data.z,data.w,VariableNames=["z","weight"]),fullfile(outputDirectory,'physical-grid.csv'));
provenance=struct(configuration=config,matlabVersion=string(version),computer=string(computer),source=sourceRevision(),internalModesVersion="2.0.0-beta.4",preparationSeconds=preparationSeconds,cost=assessment.cost,repeatAssessmentSeconds=repeat.cost.assessmentSeconds,repeatStatus=repeat.status,coverage=assessment.coverage,referenceDiagnostics=assessment.referenceDiagnostics,interpretation="Linear counts and individual sampled quadratic products for one coupled map; no arbitrary-superposition or full nonlinear guarantee");
writelines(jsonencode(provenance,PrettyPrint=true),fullfile(outputDirectory,'provenance.json'));
result=struct(outputDirectory=outputDirectory,counts=linear,assessment=assessment,repeatAssessment=repeat,provenance=provenance);
fprintf('Quadratic count-map example: %s\n',outputDirectory);
end

function result=sourceRevision()
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
original=pwd; cleanup=onCleanup(@()cd(original)); cd(root);
[status,revision]=system('git rev-parse HEAD');
if status~=0, error('WVStudy:MissingSourceRevision','Run the example from its authoring checkout.'); end
[status,dirty]=system('git status --porcelain --untracked-files=no');
if status~=0, error('WVStudy:MissingSourceRevision','Cannot determine source status.'); end
result=struct(revision=strtrim(string(revision)),hasTrackedChanges=strlength(strtrim(string(dirty)))>0);
end
