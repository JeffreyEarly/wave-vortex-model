function report = assessWaveCountMap(prepared,options)
% Select retained inputs and outputs from a fixed product-evidence snapshot.
arguments (Input)
    prepared (1,1) struct
    options.waveModeKappa (:,1) double {mustBeReal,mustBeFinite} = zeros(0,1)
    options.waveModeCount (:,1) double {mustBeReal,mustBeFinite,mustBeInteger,mustBeNonnegative} = zeros(0,1)
    options.quadraticTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 0.1
    options.productBudget (1,1) double {mustBeReal,mustBeFinite,mustBeInteger,mustBePositive} = 500000
end
arguments (Output)
    report (1,1) struct
end
required=["kind","configuration","inventory","products","rows","waveGram","waveLabels","modeConvergence","fixedFamilyCounts","fixedFamilyLabels","referenceDiagnostics","physicalGrid","coverage","cost"];
if ~all(isfield(prepared,required)) || prepared.kind~="waveQuadraticEvidence-v1"
    error('WVStudy:InvalidPreparation','Use the unchanged snapshot from prepareWaveQuadraticAssessment.')
end
timer=tic; config=prepared.configuration;
if config.referenceAllowance>options.quadraticTolerance/100
    error('WVStudy:ReferenceAllowanceTooLarge','Prepare reference errors below one percent of the requested product tolerance.')
end
if prepared.cost.reservedProducts>options.productBudget
    error('WVStudy:ProductBudgetExceeded','The snapshot reserved %d products; the supplied productBudget is %d.',prepared.cost.reservedProducts,options.productBudget)
end
kappa=prepared.inventory.magnitudes(:); positive=find(kappa>0); np=numel(kappa);
requested=options.waveModeCount; keys=options.waveModeKappa;
if isempty(requested), requested=config.waveCount; end
if any(requested>config.waveCount)
    error('WVStudy:InvalidWaveCountMap','Counts must lie between zero and the prepared candidate count %d.',config.waveCount)
end
counts=zeros(np,1);
if isempty(keys)
    if ~isscalar(requested)
        error('WVStudy:InvalidWaveCountMap','Supply physical waveModeKappa keys for a nonuniform count map.')
    end
    counts(positive)=requested;
else
    if any(keys<=0) || ~(isscalar(requested) || numel(requested)==numel(keys))
        error('WVStudy:InvalidWaveCountMap','Use positive physical keys with one count per key or a scalar count.')
    end
    if isscalar(requested), requested=repmat(requested,numel(keys),1); end
    assigned=false(np,1);
    for j=1:numel(keys)
        match=find(kappa==keys(j) & kappa>0);
        if isempty(match), match=find(abs(kappa-keys(j))<=64*eps(max(abs(kappa),abs(keys(j)))) & kappa>0); end
        if numel(match)~=1 || (assigned(match) && counts(match)~=requested(j))
            error('WVStudy:InvalidWaveCountMap','A key is unsupported/ambiguous or repeated with conflicting counts.')
        end
        counts(match)=requested(j); assigned(match)=true;
    end
    if ~all(assigned(positive)), error('WVStudy:InvalidWaveCountMap','Cover every positive kappa in the prepared inventory.'); end
end
p=prepared.products;
na=reshape(counts(p.pageA),1,[]); nb=reshape(counts(p.pageB),1,[]); no=reshape(counts(p.pageOut),1,[]);
stressBand=max(1,max(na.*p.waveA,nb.*p.waveB));
selected=(~p.waveA | p.positionA<=na) & (~p.waveB | p.positionB<=nb) & (~p.waveOut | no>0) & p.firstCount<=stressBand;
columns=find(selected); outputCount=max(1,no(columns));
errors=double(p.error(sub2ind(size(p.error),outputCount,columns)));
out=p.pageOut(columns);
tested=accumarray(out(:),1,[np 1]);
nonzero=accumarray(out(:),double(~p.isZero(columns)).',[np 1]);
quadraticError=accumarray(out(:),errors(:),[np 1],@max,0); quadraticError(tested==0)=NaN;
absoluteReferenceProductCount=nan(np,1); relativeReferenceError=nan(np,1);
if isfield(p,'referenceUsesAbsolute')
    absoluteReferenceProductCount=accumarray(out(:),double(p.referenceUsesAbsolute(columns)).',[np 1]);
    relativeReferenceError=accumarray(out(:),p.relativeReferenceError(columns).',[np 1],@max,0);
    relativeReferenceError(tested==0)=NaN;
end
gramError=nan(np,1); convergenceError=nan(np,1); limiting=cell(np,1);
for page=1:np
    if kappa(page)==0
        gramError(page)=prepared.referenceDiagnostics.inertialGram;
    elseif counts(page)>0
        gramError(page)=max(prepared.waveGram(1:counts(page),page));
    end
    measurements=prepared.modeConvergence{page}.measurements;
    count=counts(page); if kappa(page)==0, count=config.inertialCount; end
    labels=string(prepared.waveLabels{page}(1:count));
    required=ismember(measurements.columnLabel,labels) & ismember(measurements.quantity,["equivalentDepth","h1"]);
    if count>0 && nnz(required)==3*count && all(measurements.status(required)=="measured")
        convergenceError(page)=max(measurements.value(required));
    end
    indices=find(out==page);
    if ~isempty(indices)
        [~,j]=max(errors(indices)); product=columns(indices(j)); row=prepared.rows(p.row(product),:);
        integers=reshape(table2array(prepared.inventory.interactions(row.interaction,1:6)),2,3).';
        if row.output=="wave", outputLabels=prepared.waveLabels{page}(1:count); outputSigns=[1 -1];
        elseif row.output=="inertial", outputLabels=prepared.waveLabels{page}; outputSigns=0;
        else, outputLabels=prepared.fixedFamilyLabels.mda; outputSigns=0;
        end
        endpointLabels=strings(1,2);
        if row.inputA=="boundary", endpointLabels(1)=prepared.fixedFamilyLabels.boundary(p.labelA(product)); end
        if row.inputB=="boundary", endpointLabels(2)=prepared.fixedFamilyLabels.boundary(p.labelB(product)); end
        limiting{page}=struct(inputEndpointLabels=endpointLabels,interaction=row.interaction,inputFamilies=[row.inputA,row.inputB],inputModeLabels=[p.labelA(product),p.labelB(product)],inputFrequencySigns=[p.signA(product),p.signB(product)],integerWavevectors=integers,physicalWavevectors=integers.*(2*pi./config.Lxy),inputWaveCounts=[counts(p.pageA(product)),counts(p.pageB(product))],outputFamily=row.output,outputModeLabels=outputLabels,outputFrequencySigns=outputSigns,outputWaveCount=counts(page),channel=row.channel,error=quadraticError(page));
    end
end
status=repmat("accepted",np,1);
requestedPage=kappa==0 | counts>0;
status(~requestedPage)="not-requested";
status(requestedPage & tested==0)="inconclusive";
status(requestedPage & isnan(convergenceError))="reference-inconclusive";
status(requestedPage & (gramError>config.gramTolerance | (prepared.referenceDiagnostics.referencesStable & quadraticError>options.quadraticTolerance)))="rejected";
if ~prepared.referenceDiagnostics.fixedFamiliesGramAccepted
    status(requestedPage)="rejected";
end
if ~prepared.referenceDiagnostics.referencesStable
    status(requestedPage & status~="rejected")="reference-inconclusive";
end
if any(status=="rejected"), overall="rejected";
elseif any(status=="reference-inconclusive"), overall="reference-inconclusive";
elseif any(status=="inconclusive"), overall="inconclusive";
else, overall="assessed";
end
cost=prepared.cost; cost.selectedProducts=nnz(selected); cost.selectedNonzeroProducts=nnz(selected & ~p.isZero); cost.reusedPreparation=true; cost.newEigensolves=0; cost.newProductEvaluations=0; cost.assessmentSeconds=toc(timer);
coverage=prepared.coverage; coverage.countMapScope="One complete map; per-output errors cannot be combined into independently selectable count recommendations.";
coverage.missingOutputKappa=kappa(requestedPage & tested==0);
coverage.fixedInputSelection="Candidate-band cumulative low/middle/cutoff stresses, filtered by actual input counts and their maximum stress band; all fixed-family columns remain eligible.";
report=struct(configuration=config,physicalGrid=prepared.physicalGrid,waveModeLabels={prepared.waveLabels},status=overall,requestedCountAccepted=overall=="assessed",pages=table(kappa,counts,convergenceError,gramError,quadraticError,tested,nonzero,absoluteReferenceProductCount,relativeReferenceError,status,limiting,VariableNames=["kappa","requestedWaveCount","modeConvergenceError","gramError","quadraticError","testedProductCount","nonzeroProductCount","absoluteReferenceProductCount","relativeReferenceError","status","limitingInteraction"]),fixedFamilyCounts=prepared.fixedFamilyCounts,referenceDiagnostics=prepared.referenceDiagnostics,quadraticTolerance=options.quadraticTolerance,gramTolerance=config.gramTolerance,modeConvergenceTolerance=config.eigenAllowance,cost=cost,coverage=coverage);
end
