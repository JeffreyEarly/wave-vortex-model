function result = waveQuadraticResolutionExample(outputDirectory,options)
% Plot the original kappa-dependent linear counts with bounded quadratic checks.
%
% Run from an authoring checkout with released dependencies configured. This
% default preserves InternalModes' full FFT linear inventory and 24 candidates.
% Three quadratic triads use WVM's smaller dealiased inventory. Supplying an
% explicit configuration runs the original complete-map control instead. Both active boundaries are inputs; their nonlinear outputs remain
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
    result=kappaDependentExample(outputDirectory,options);
    return
end
started=tic; data=prepareSourceStudy(config); config=data.config;
prepared=WVInternal.prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true,productBudget=options.productBudget,workingMemoryBudget=options.workingMemoryBudget);
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


function result=kappaDependentExample(outputDirectory,options)
% Reuse the provider example verbatim; reduce product coverage, not its band.
started=tic;
linearResult=waveModeCountsByWavenumber(outputDirectory=fullfile(outputDirectory,"linear"),figureVisible="off");
closeLinear=onCleanup(@()close(linearResult.figure));
linearSeconds=toc(started); linear=linearResult.waves;
config=resolveStudyCase("cal-exponential-17");
config.id="kappa-dependent-exponential-25"; config.profile="exponential-surface";
config.Lxy=[1000 1000]; config.Nxy=[16 16]; config.Nz=25;
config.waveCount=24; config.evpOrders=[192 256]; config.gramTolerance=.01;
started=tic; data=prepareSourceStudy(config); config=data.config;
assert(max(abs(data.z-linearResult.z))<1e-9 && max(abs(data.w-linearResult.weights))<1e-9,'The linear and product studies must use the same physical sampling.');
kappa=data.inventory.magnitudes; positive=find(kappa>0);
counts=zeros(numel(positive),1);
for j=1:numel(positive)
    [distance,index]=min(abs(linear.kappa-kappa(positive(j))));
    assert(distance<64*eps(kappa(positive(j))),'Each product page must match the original Fourier inventory.');
    counts(j)=linear.combinedCount(index);
    assert(sum(cumprod(data.waveGram(:,positive(j))<=config.gramTolerance)>0)==linear.gridSupportedCount(index),'Refined product modes must reproduce the original grid-supported counts.');
end
% Deterministic low/middle/high output pages within the supported inventory.
% At each output choose the triad with the smallest maximum input kappa.
selectedPages=positive(unique(round(linspace(1,numel(positive),3))));
triads=data.inventory.interactions; indices=zeros(1,numel(selectedPages));
for j=1:numel(selectedPages)
    rows=find(triads.page3==selectedPages(j));
    difficulty=max(kappa(triads.page1(rows)),kappa(triads.page2(rows)));
    [~,first]=min(difficulty); indices(j)=rows(first);
end
prepared=WVInternal.prepareWaveQuadraticAssessment(data,interactionIndices=indices,productBudget=options.productBudget,workingMemoryBudget=options.workingMemoryBudget);
preparationSeconds=toc(started);
assessment=assessWaveQuadraticResolution(prepared,waveModeKappa=kappa(positive),waveModeCount=counts,quadraticTolerance=options.quadraticTolerance,productBudget=options.productBudget);
repeat=assessWaveQuadraticResolution(prepared,waveModeKappa=kappa(positive),waveModeCount=min(counts,3),quadraticTolerance=options.quadraticTolerance,productBudget=options.productBudget);
selected=assessment.pages(selectedPages,:); repeated=repeat.pages(selectedPages,:);
fig=figure(Visible="off",Color="w",Position=[100 100 1150 850]); closeFigure=onCleanup(@()close(fig));
layout=tiledlayout(fig,2,1,TileSpacing="compact",Padding="compact");
ax1=nexttile(layout);
plot(ax1,linear.kappa,linear.convergedCount,'-',LineWidth=1.5,DisplayName="EVP converged (24-candidate ceiling)"); hold(ax1,'on');
plot(ax1,linear.kappa,linear.combinedCount,'o-',LineWidth=1.5,MarkerSize=4,DisplayName="Grid-supported / combined count");
plot(ax1,selected.kappa,selected.requestedWaveCount,'s',MarkerSize=10,LineWidth=1.5,Color=[.75 .25 .1],DisplayName="Selected quadratic output pages");
ylim(ax1,[0 27]); ylabel(ax1,'Leading wave modes, including external'); grid(ax1,'on'); legend(ax1,Location="southwest");
ax2=nexttile(layout); hold(ax2,'on'); set(ax2,YScale="log");
reports={selected,repeated}; markers=['o','s']; colors=[.0 .45 .74;.85 .33 .1];
names=["Linear count map","Counts capped at 3"];
for j=1:2
    pages=reports{j}; qualified=ismember(pages.status,["accepted","rejected"]);
    if any(qualified)
        plot(ax2,pages.kappa(qualified),max(pages.quadraticError(qualified),realmin),markers(j),Color=colors(j,:),MarkerFaceColor=colors(j,:),MarkerSize=8,DisplayName=names(j)+" — mixed reference check passed");
    end
    if any(~qualified)
        plot(ax2,pages.kappa(~qualified),max(pages.quadraticError(~qualified),realmin),markers(j),Color=colors(j,:),MarkerSize=9,LineWidth=1.5,DisplayName=names(j)+" — UNQUALIFIED estimate");
    end
end
yline(ax2,options.quadraticTolerance,'--',DisplayName="Product tolerance (requires stable references)");
xlabel(ax2,'\kappa (rad m^{-1})'); ylabel(ax2,'Sampled projection error at 3 outputs'); grid(ax2,'on'); legend(ax2,Location="northeast");
for ax=[ax1 ax2]
    xlim(ax,[0 1.03*max(linear.kappa)]);
    xline(ax,max(kappa),':',"WVM dealiased limit",HandleVisibility="off",LabelVerticalAlignment="top");
end
linkaxes([ax1 ax2],'x');
title(layout,'1 × 1 km; 16 × 16 horizontal points; 25 WKB–Chebyshev samples; 24 candidates');
referenceStatus="inconclusive";
if assessment.referenceDiagnostics.referencesStable, referenceStatus="mixed-qualified"; end
subtitle(layout,sprintf('Full FFT linear sweep; 3 selected quadratic triads; quadratic references: %s',referenceStatus));
exportgraphics(fig,fullfile(outputDirectory,'count-map-quadratic.png'),Resolution=160);
exportgraphics(fig,fullfile(outputDirectory,'count-map-quadratic.pdf'),ContentType="vector");
writetable(linear,fullfile(outputDirectory,'linear-counts.csv'));
writetable(removevars(assessment.pages,'limitingInteraction'),fullfile(outputDirectory,'quadratic-pages.csv'));
writetable(removevars(repeat.pages,'limitingInteraction'),fullfile(outputDirectory,'repeat-pages.csv'));
selectedTriads=addvars(triads(indices,:),indices(:),Before=1,NewVariableNames="interactionIndex");
selectedTriads.outputKappa=kappa(selectedTriads.page3);
writetable(selectedTriads,fullfile(outputDirectory,'selected-triads.csv'));
writelines(jsonencode(selected.limitingInteraction,PrettyPrint=true),fullfile(outputDirectory,'limiting-interactions.json'));
provenance=struct(configuration=config,matlabVersion=string(version),computer=string(computer),source=sourceRevision(),internalModesVersion="2.0.0-beta.4",linearPreparationSeconds=linearSeconds,preparationSeconds=preparationSeconds,cost=assessment.cost,repeatAssessmentSeconds=repeat.cost.assessmentSeconds,repeatStatus=repeat.status,coverage=assessment.coverage,referenceDiagnostics=assessment.referenceDiagnostics,interpretation="Original full FFT linear sweep plus three selected WVM triads; untested pages are not qualified; open markers are unqualified estimates, not a nonlinear count recommendation");
writelines(jsonencode(provenance,PrettyPrint=true),fullfile(outputDirectory,'provenance.json'));
result=struct(outputDirectory=outputDirectory,counts=linear,assessment=assessment,repeatAssessment=repeat,provenance=provenance);
fprintf('Kappa-dependent quadratic example: %s\n',outputDirectory);
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
