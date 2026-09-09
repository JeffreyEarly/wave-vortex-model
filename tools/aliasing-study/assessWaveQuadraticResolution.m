function [report,evidence] = assessWaveQuadraticResolution(data,options)
% Assess common prefixes or an explicit count map using prepared evidence.
%
% With prepareSourceStudy data, preserve the historical common-prefix report.
% With prepareWaveQuadraticAssessment's fixed snapshot, select actual input
% and output counts without repeating any solves or product calculations.
% The snapshot overload returns pages for one complete map; it never treats
% per-page errors as independently selectable nonlinear count limits.
%
% data = prepareSourceStudy(resolveStudyCase("cal-constant-17"));
% prepared = prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true);
% report = assessWaveQuadraticResolution(prepared,waveModeCount=3);
%
% - Declaration: [report,evidence] = assessWaveQuadraticResolution(data,options)
% - Parameter data: source-study data or a prepareWaveQuadraticAssessment snapshot
% - Parameter options.quadraticTolerance: positive normalized product tolerance
% - Parameter options.requestedWaveCount: optional strict count within the prepared band
% - Parameter options.waveModeKappa: positive physical keys for a snapshot count map
% - Parameter options.waveModeCount: scalar or counts aligned with physical keys, including zero
% - Parameter options.productBudget: maximum individual products, including structural zeros
% - Returns report: status, sampled count, prefix/output-page diagnostics, coverage and costs
% - Returns evidence: source-product evidence, or the unchanged input snapshot for a count map
arguments (Input)
    data (1,1) struct
    options.quadraticTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 0.1
    options.requestedWaveCount (1,:) double {mustBeReal,mustBeFinite,mustBeInteger,mustBePositive} = []
    options.waveModeKappa (:,1) double {mustBeReal,mustBeFinite} = zeros(0,1)
    options.waveModeCount (:,1) double {mustBeReal,mustBeFinite,mustBeInteger,mustBeNonnegative} = zeros(0,1)
    options.productBudget (1,1) double {mustBeReal,mustBeFinite,mustBeInteger,mustBePositive} = 500000
end
arguments (Output)
    report (1,1) struct
    evidence (1,1) struct
end
if isfield(data,"kind") && data.kind=="waveQuadraticEvidence-v1"
    if ~isempty(options.requestedWaveCount)
        error('WVStudy:InvalidWaveCountMap','Use waveModeCount with an evidence snapshot; requestedWaveCount belongs to the legacy common-prefix report.')
    end
    report=assessWaveCountMap(data,waveModeKappa=options.waveModeKappa,waveModeCount=options.waveModeCount,quadraticTolerance=options.quadraticTolerance,productBudget=options.productBudget);
    evidence=data;
    return
elseif ~isempty(options.waveModeKappa) || ~isempty(options.waveModeCount)
    error('WVStudy:InvalidPreparation','Call prepareWaveQuadraticAssessment explicitly before assessing a count map.')
end
required=["config","inventory","wave","apv","mda","boundary","z","w","pageDifficulty","requiredConvergence"];
if ~all(isfield(data,required))
    error('WVStudy:InvalidPreparation','Use the complete preparation returned by prepareSourceStudy.')
end
config=data.config; n=config.waveCount; requested=options.requestedWaveCount;
if config.referenceAllowance>options.quadraticTolerance/100 || (isfield(config,'referenceAbsoluteAllowance') && config.referenceAbsoluteAllowance>options.quadraticTolerance/100)
    error('WVStudy:ReferenceAllowanceTooLarge','Prepare both reference allowances below one percent of quadraticTolerance %.3g.',options.quadraticTolerance)
end
if numel(requested)>1 || any(requested>n)
    error('WVStudy:InvalidRequestedCount','requestedWaveCount must be empty or one count within the prepared band 1:%d.',n)
end
selection=selectStudyInteractions(data.inventory,data.pageDifficulty);
indices=selection.fixed(:).';
% Reserve the entire candidate plan before preparing polarizations or doing
% any product projection. Structural zeros consume the reservation too.
pairs=["wave","wave";"wave","apv";"apv","wave";"wave","boundary";"boundary","wave";"apv","boundary";"boundary","apv";"boundary","boundary"];
positions=struct(wave=repelem(1:n,2),apv=1:config.apvCount,boundary=1:2);
pairsPerChannel=0;
for j=1:size(pairs,1)
    [a,b]=ndgrid(positions.(pairs(j,1)),positions.(pairs(j,2)));
    pairsPerChannel=pairsPerChannel+nnz(studyModePairMask(a(:).',b(:).',pairs(j,1),pairs(j,2),n,"fixed"));
end
vectors=table2array(data.inventory.interactions(indices,1:6));
meanOutputs=all(vectors(:,5:6)==0,2);
reservedProducts=pairsPerChannel*sum(13-3*meanOutputs);
if reservedProducts>options.productBudget
    error('WVStudy:ProductBudgetExceeded','The fixed plan requires %d products including structural zeros; productBudget is %d. Increase the explicit budget or prepare a smaller candidate band.',reservedProducts,options.productBudget)
end
timer=tic;
evidence=measureSourceProducts(data,policy="fixed");
summary=evidence.summary;
assert(summary.nonzeroProductEvaluations+summary.structuralZeroProducts==reservedProducts,'The executed inventory differs from the reserved product plan.');
errors=zeros(n,1); evaluations=zeros(n,1); limiting=cell(n,1);
nPages=numel(data.inventory.magnitudes);
pageErrors=nan(n,nPages); pageEvaluations=zeros(n,nPages);
for r=1:height(evidence.rows)
    row=evidence.rows(r,:); record=evidence.raw{r};
    outputPage=data.inventory.interactions.page3(row.interaction);
    for count=1:n
        mask=studyModePairMask(record.positionA,record.positionB,row.inputA,row.inputB,count,"fixed");
        evaluations(count)=evaluations(count)+nnz(mask & ~record.isZero);
        pageEvaluations(count,outputPage)=pageEvaluations(count,outputPage)+nnz(mask & ~record.isZero);
        candidates=find(mask);
        if isempty(candidates), continue; end
        [value,j]=max(record.error(count,candidates));
        if isnan(pageErrors(count,outputPage)) || value>pageErrors(count,outputPage)
            pageErrors(count,outputPage)=double(value);
        end
        if isempty(limiting{count}) || value>errors(count)
            errors(count)=value; pair=candidates(j);
            integers=reshape(table2array(data.inventory.interactions(row.interaction,1:6)),2,3).';
            if row.output=="wave"
                outputLabels=data.wave{find(data.inventory.magnitudes>0,1)}.labels(1:count);
                outputSigns=[1 -1];
            elseif row.output=="mda"
                outputLabels=data.mda.labels; outputSigns=0;
            else
                outputLabels=data.wave{find(data.inventory.magnitudes==0,1)}.labels; outputSigns=0;
            end
            limiting{count}=struct(inputFamilies=[row.inputA,row.inputB],inputModeLabels=[record.labelA(pair),record.labelB(pair)],inputFrequencySigns=[record.signA(pair),record.signB(pair)],integerWavevectors=integers,physicalWavevectors=integers.*(2*pi./config.Lxy),outputFamily=row.output,outputModeLabels=outputLabels,outputFrequencySigns=outputSigns,channel=row.channel,error=double(value));
        end
    end
end
gramAccepted=summary.waveGram(:)<=config.gramTolerance;
quadraticAccepted=errors<=options.quadraticTolerance;
prefixAccepted=cumprod(gramAccepted & quadraticAccepted)>0;
largest=sum(prefixAccepted);
status="assessed"; reasons=strings(0,1);
if ~summary.referencesStable
    status="reference-inconclusive"; reasons(end+1)="reference-convergence";
elseif ~summary.fixedFamiliesGramAccepted
    status="rejected"; reasons(end+1)="fixed-family-gram";
elseif largest==0
    status="rejected"; reasons(end+1)="no-passing-prefix";
end
if ~summary.referencesStable || ~summary.fixedFamiliesGramAccepted, largest=NaN; end
requestedAccepted=[];
if ~isempty(requested)
    requestedAccepted=status=="assessed" && prefixAccepted(requested);
    if ~requestedAccepted
        if status=="assessed", status="rejected"; end
        if ~all(gramAccepted(1:requested)), reasons(end+1)="wave-gram"; end
        if ~all(quadraticAccepted(1:requested)), reasons(end+1)="quadratic-products"; end
    end
end
prefixes=table((1:n).',summary.waveGram(:),errors,gramAccepted,quadraticAccepted,prefixAccepted,evaluations,limiting,VariableNames=["waveCount","gramError","quadraticError","gramAccepted","quadraticAccepted","wavePrefixAccepted","nonzeroProductCount","limitingInteraction"]);
fixedCounts=struct(apv=config.apvCount,mda=config.mdaCount,inertial=config.inertialCount,boundary=2);
coverage=struct(policy="fixed-v1",candidateWaveCount=n,candidateLimitReached=isfinite(largest) && largest==n,totalValidInteractions=height(data.inventory.interactions),selectedInteractionIndices=indices,selectedInteractions=data.inventory.interactions(indices,:),orderedInputFamilies=pairs,channels=evidence.channels,omittedOutputs=["apv","boundary","mean-w"],omittedDynamics="boundary sheet evolution; arbitrary superpositions; full nonlinear operator",modePairEvidence="Second output raw/rows contains every tested input label, sign, structural zero and output-prefix error.");
coverage.outputPageScope="Breakdown by prepared output kappa of the same common wave prefix on every nonzero input/output page; fixed family counts are unchanged. No independent per-page retained-count recommendation.";
coverage.outputPageKappa="Prepared inventory magnitudes; existing inventory groups roundoff-equivalent radii with uniquetol tolerance 1e-12 relative to the largest radius.";
coverage.outputPageStatus="Status applies to sampled quadratic products only, with the same global reference and fixed-family gates. Wave Gram and mode-convergence evidence remain separate.";
outputKappa=repelem(data.inventory.magnitudes(:),n);
commonWaveCount=repmat((1:n).',nPages,1);
outputWaveCount=commonWaveCount; outputWaveCount(outputKappa==0)=0;
quadraticError=pageErrors(:); nonzeroProductCount=pageEvaluations(:);
selectedInteractionCount=zeros(n*nPages,1);
pageStatus=repmat("inconclusive",n*nPages,1);
for page=1:nPages
    pageRows=(page-1)*n+(1:n);
    selectedInteractionCount(pageRows)=nnz(data.inventory.interactions.page3(indices)==page);
end
examined=~isnan(quadraticError);
if ~summary.referencesStable
    pageStatus(examined)="reference-inconclusive";
elseif ~summary.fixedFamiliesGramAccepted
    pageStatus(examined)="rejected";
else
    pageStatus(examined & quadraticError<=options.quadraticTolerance)="accepted";
    pageStatus(examined & quadraticError>options.quadraticTolerance)="rejected";
end
outputPageDiagnostics=table(outputKappa,commonWaveCount,outputWaveCount,quadraticError,nonzeroProductCount,selectedInteractionCount,pageStatus,VariableNames=["outputKappa","commonWaveCount","outputWaveCount","quadraticError","nonzeroProductCount","selectedInteractionCount","status"]);
cost=struct(productBudget=options.productBudget,reservedProducts=reservedProducts,nonzeroProducts=summary.nonzeroProductEvaluations,structuralZeros=summary.structuralZeroProducts,assessmentSeconds=summary.assessmentSeconds,callSeconds=toc(timer),preparationSeconds=data.constructionSeconds,reusedPreparation=true);
report=struct(status=status,rejectionReasons=reasons,requestedWaveCount=requested,requestedCountAccepted=requestedAccepted,largestSampledCount=largest,countDescription="largest count passing the sampled interaction checks",fixedFamilyCounts=fixedCounts,quadraticTolerance=options.quadraticTolerance,gramTolerance=config.gramTolerance,prefixDiagnostics=prefixes,outputPageDiagnostics=outputPageDiagnostics,coverage=coverage,cost=cost,referenceDiagnostics=summary);
end
