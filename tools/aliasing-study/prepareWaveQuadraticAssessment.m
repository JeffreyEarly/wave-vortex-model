function prepared = prepareWaveQuadraticAssessment(data,options)
% Prepare reusable product evidence for explicit retained wave-count maps.
%
% This value snapshot owns a fixed grid, candidate band and reference/product
% inventory. Assess it alone with assessWaveQuadraticResolution; never pair
% it with a changed preparation. Changing modes, grid, references or physical
% operators requires this explicit preparation again. No model cache or
% provider object is retained. The source-study data must remain unmodified
% between prepareSourceStudy and this call.
arguments (Input)
    data (1,1) struct
    options.policy (1,1) string {mustBeMember(options.policy,["fixed","targeted","dense"])} = "fixed"
    options.interactionIndices (1,:) double {mustBeInteger,mustBePositive,mustBeFinite} = []
    options.ensureOutputCoverage (1,1) logical = false
    options.productBudget (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 500000
    options.workingMemoryBudget (1,1) double {mustBePositive,mustBeFinite} = 512*1024^2
end
arguments (Output)
    prepared (1,1) struct
end
required=["config","inventory","wave","apv","mda","boundary","z","w","pageDifficulty","requiredConvergence"];
if ~all(isfield(data,required))
    error('WVStudy:InvalidPreparation','Supply an unchanged prepareSourceStudy result.')
end
timer=tic; config=data.config; n=config.waveCount; inventory=data.inventory;
selection=selectStudyInteractions(inventory,data.pageDifficulty);
indices=options.interactionIndices;
if isempty(indices)
    if options.policy=="dense", indices=1:height(inventory.interactions); else, indices=selection.(options.policy).'; end
end
if any(indices>height(inventory.interactions)) || numel(unique(indices))~=numel(indices)
    error('WVStudy:InvalidInteractions','Use distinct indices from the prepared interaction inventory.')
end
if options.ensureOutputCoverage
    missing=setdiff(1:numel(inventory.magnitudes),inventory.interactions.page3(indices));
    for page=missing
        first=find(inventory.interactions.page3==page,1);
        if ~isempty(first), indices(end+1)=first; end %#ok<AGROW>
    end
end
pairs=["wave","wave";"wave","apv";"apv","wave";"wave","boundary";"boundary","wave";"apv","boundary";"boundary","apv";"boundary","boundary"];
positions=struct(wave=repelem(1:n,2),apv=1:config.apvCount,boundary=1:2);
pairsPerChannel=0; largestBatch=0;
for p=1:size(pairs,1)
    [a,b]=ndgrid(positions.(pairs(p,1)),positions.(pairs(p,2)));
    count=nnz(studyModePairMask(a(:).',b(:).',pairs(p,1),pairs(p,2),n,options.policy));
    pairsPerChannel=pairsPerChannel+count; largestBatch=max(largestBatch,count);
end
vectors=table2array(inventory.interactions(indices,1:6));
reserved=pairsPerChannel*sum(13-3*all(vectors(:,5:6)==0,2));
if reserved>options.productBudget
    error('WVStudy:ProductBudgetExceeded','Preparation reserves %d products; productBudget is %d. Reduce the candidate band/inventory or increase the explicit budget.',reserved,options.productBudget)
end
% Conservative workspace estimate, not an OS peak measurement: simultaneous
% raw/flattened evidence, six complex product grids, prefix coefficients,
% all polarized field/context arrays and table/struct overhead allowance.
rows=numel(indices)*13*size(pairs,1);
inputVectors=size(unique([vectors(:,1:2);vectors(:,3:4)],'rows'),1);
outputVectors=size(unique(vectors(:,5:6),'rows'),1);
fieldBytes=inputVectors*8*sum([numel(data.z),numel(data.zR),2*numel(data.zQ),4])*(2*n+config.apvCount+2)*16;
contextBytes=outputVectors*4*3*(2*n)*numel(data.allZ)*16;
workingBytes=reserved*(8*n+320)+rows*8192+largestBatch*(16*10*numel(data.allZ)+128*n^2)+2*(fieldBytes+contextBytes);
if workingBytes>options.workingMemoryBudget
    error('WVStudy:WorkingMemoryBudgetExceeded','Estimated preparation workspace is %.1f MiB; budget is %.1f MiB. Reduce the band/inventory or increase the explicit budget.',workingBytes/1024^2,options.workingMemoryBudget/1024^2)
end
reservationSeconds=toc(timer);
evidence=measureSourceProducts(data,interactionIndices=indices,policy=options.policy);
assert(evidence.summary.nonzeroProductEvaluations+evidence.summary.structuralZeroProducts==reserved);
products=struct();
for field=["positionA","positionB","labelA","labelB","signA","signB","error","isZero","referenceQualificationFraction","relativeReferenceError","referenceUsesAbsolute","referenceFactorScale"]
    values=cellfun(@(r)r.(field),evidence.raw,UniformOutput=false);
    products.(field)=cat(2,values{:});
end
lengths=cellfun(@(r)numel(r.positionA),evidence.raw);
products.row=reshape(repelem((1:height(evidence.rows)).',lengths),1,[]);
row=evidence.rows(products.row,:);
triads=inventory.interactions(row.interaction,:);
products.pageA=triads.page1.'; products.pageB=triads.page2.'; products.pageOut=triads.page3.';
products.waveA=(row.inputA=="wave").'; products.waveB=(row.inputB=="wave").'; products.waveOut=(row.output=="wave").';
% Preserve exactly the historical cumulative stress selection for a uniform
% map. Unequal maps filter these stresses by their actual input prefixes.
products.firstCount=zeros(1,reserved);
offset=0;
for j=1:numel(evidence.raw)
    raw=evidence.raw{j}; columns=offset+(1:lengths(j)); first=zeros(1,lengths(j));
    for count=1:n
        selected=studyModePairMask(raw.positionA,raw.positionB,evidence.rows.inputA(j),evidence.rows.inputB(j),count,options.policy);
        first(selected & first==0)=count;
    end
    products.firstCount(columns)=first; offset=offset+lengths(j);
end
assert(all(products.firstCount>0));
waveLabels=cellfun(@(b)b.labels,data.wave,UniformOutput=false);
modeConvergence=cellfun(@(b)b.modeConvergence,data.wave,UniformOutput=false);
fixedLabels=struct(apv=data.apv.labels,mda=data.mda.labels,boundary=["surface","bottom"]);
fixedCounts=struct(apv=config.apvCount,mda=config.mdaCount,inertial=config.inertialCount,boundary=2);
prepared=struct(kind="waveQuadraticEvidence-v1",configuration=config,inventory=inventory,products=products,rows=evidence.rows,channels=evidence.channels,waveGram=data.waveGram,waveLabels={waveLabels},modeConvergence={modeConvergence},fixedFamilyCounts=fixedCounts,fixedFamilyLabels=fixedLabels,referenceDiagnostics=evidence.summary,physicalGrid=struct(z=data.z,weights=data.w),coverage=struct(policy=options.policy,selectedInteractionIndices=indices,ensureOutputCoverage=options.ensureOutputCoverage,referenceScope="Entire prepared candidate inventory; conservative for reduced maps",inputFamilyPairs=pairs,omittedInputFamilies=["inertial","mda"],omittedOutputs=["apv","boundary","mean-w"],exhaustiveGuarantee=false,superpositionGuarantee=false));
prepared.cost=struct(reservedProducts=reserved,productBudget=options.productBudget,workingMemoryEstimateBytes=workingBytes,workingMemoryBudget=options.workingMemoryBudget,largestProductBatch=largestBatch,sourcePreparationSeconds=data.constructionSeconds,reservationSeconds=reservationSeconds,projectionPreparationSeconds=evidence.summary.projectionPreparationSeconds,productEvaluationSeconds=evidence.summary.assessmentSeconds,evidencePreparationSeconds=toc(timer),projectionCount=evidence.summary.projectionCount);
if isfield(data,'preparationCost'), prepared.cost.sourcePreparation=data.preparationCost; end
memory=whos('prepared'); prepared.cost.retainedBytes=memory.bytes;
end
