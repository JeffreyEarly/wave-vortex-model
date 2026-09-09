function evidence = measureSourceProducts(data,options)
% Assess prepared physical source products without solving modes or writing files.
arguments (Input)
    data (1,1) struct
    options.interactionIndices (1,:) double = []
    options.policy (1,1) string {mustBeMember(options.policy,["dense","fixed","targeted"])} = "dense"
    options.showProgress (1,1) logical = false
    options.streamOutputs (1,1) logical = true
end
config=data.config;
constructionTimer=tic;
inventory=data.inventory;
channels=WVInternal.sourceChannelInventory();
familyPairs=["wave" "wave";"wave" "apv";"apv" "wave";"wave" "boundary";"boundary" "wave";"apv" "boundary";"boundary" "apv";"boundary" "boundary"];
selection=WVInternal.selectStudyInteractions(inventory,data.pageDifficulty);
indices=options.interactionIndices;
if isempty(indices)
    if options.policy=="dense", indices=1:height(inventory.interactions); else, indices=selection.(options.policy).'; end
end
if isfield(config,'constructionPolicy') && options.streamOutputs
    pages=unique(inventory.interactions.page3(indices));
    pages=pages(arrayfun(@(p)p==1 || ~isempty(data.wave{p}.labels),pages));
    blocks=cell(numel(pages),1);
    for block=1:numel(pages)
        blockIndices=indices(inventory.interactions.page3(indices)==pages(block));
        blocks{block}=WVInternal.measureSourceProducts(data,interactionIndices=blockIndices,policy=options.policy,streamOutputs=false);
    end
    blocks=blocks(~cellfun(@isempty,blocks));
    if isempty(blocks), error('WV:InconclusiveQuadraticAssessment','No eligible products were measured for the requested map.'); end
    evidence=blocks{1};
    for block=2:numel(blocks)
        other=blocks{block}; evidence.raw=[evidence.raw;other.raw]; evidence.rows=[evidence.rows;other.rows];
        for field=["referenceStability","eigenProductStability","referenceQualificationFraction"]
            evidence.summary.(field)=max(evidence.summary.(field),other.summary.(field));
        end
        for field=["projectionPreparationSeconds","projectionCount","assessmentSeconds","interactionCount","nonzeroProductEvaluations","structuralZeroProducts","absoluteReferenceProductCount"]
            evidence.summary.(field)=evidence.summary.(field)+other.summary.(field);
        end
        evidence.summary.referencesStable=evidence.summary.referencesStable && other.summary.referencesStable;
        evidence.summary.relativeReferencesStable=evidence.summary.relativeReferencesStable && other.summary.relativeReferencesStable;
    end
    evidence.summary.constructionSeconds=data.constructionSeconds+evidence.summary.projectionPreparationSeconds;
    return
end
selectedRows=table2array(inventory.interactions(indices,1:6));
[~,inputIndices]=ismember([selectedRows(:,1:2);selectedRows(:,3:4)],inventory.vectors,'rows');
[~,outputIndices]=ismember(selectedRows(:,5:6),inventory.vectors,'rows');
fields=cell(size(inventory.vectors,1),3);
names=["wave","apv","boundary"];
for j=unique(inputIndices).'
    if all(inventory.vectors(j,:)==0), continue; end
    for family=1:3, fields{j,family}=WVInternal.sourceStudyFields(data,names(family),j); end
end
contexts=cell(size(fields,1),4,3); projections=cell(size(contexts)); targetNames=strings(size(fields,1),4); outputCounts=cell(size(fields,1),4);
components=["u","v","w","eta"];
for j=unique(outputIndices).'
    for c=1:4
        [contexts{j,c,1},outputCounts{j,c},targetNames(j,c)]=WVInternal.sourceProjectionContext(data,j,components(c),"R");
        contexts{j,c,2}=WVInternal.sourceProjectionContext(data,j,components(c),"Q");
        contexts{j,c,3}=WVInternal.sourceProjectionContext(data,j,components(c),"H");
        if targetNames(j,c)~="null-mean-w"
            for reference=1:3
                projections{j,c,reference}=WVInternal.prepareProductProjections(contexts{j,c,reference},outputCounts{j,c});
            end
        end
    end
end
projectionPreparationSeconds=toc(constructionTimer);
projectionCount=sum(cellfun(@(x)nnz(~cellfun(@isempty,x)),projections(~cellfun(@isempty,projections))));
setupSeconds=data.constructionSeconds+projectionPreparationSeconds;
records=cell(length(indices)*height(channels)*size(familyPairs,1),1); raw=records;
r=0; evaluated=0; zeroProducts=0; timer=tic;
for t=indices
    row=inventory.interactions(t,:);
    [~,v1]=ismember([row.k1x row.k1y],inventory.vectors,'rows');
    [~,v2]=ismember([row.k2x row.k2y],inventory.vectors,'rows');
    [~,v3]=ismember([row.k3x row.k3y],inventory.vectors,'rows');
    for pair=1:size(familyPairs,1)
        aName=familyPairs(pair,1); bName=familyPairs(pair,2);
        a=fields{v1,find(names==aName)}; b=fields{v2,find(names==bName)};
        [i,j]=ndgrid(1:length(a.labels),1:length(b.labels)); i=i(:).'; j=j(:).';
        if isfield(config,'constructionPolicy')
            mask=WVInternal.constructionModePairMask(a.positions(i),b.positions(j),aName,bName,max([a.positions 0]),max([b.positions 0]));
        else
            mask=WVInternal.studyModePairMask(a.positions(i),b.positions(j),aName,bName,config.waveCount,options.policy);
        end
        i=i(mask); j=j(mask);
        if isempty(i), continue; end
        for c=1:height(channels)
            source=channels.advected(c); component=find(components==source);
            target=targetNames(v3,component);
            if target=="null-mean-w", continue; end
            products=struct(); scales=zeros(3,numel(i));
            for setName=["S","R","Q","E","H","J"]
                [av,bv]=channelFactors(data,a,b,i,j,channels(c,:),v2,setName);
                products.(setName)=-av.*bv;
                reference=find(["R","Q","H"]==setName,1);
                if ~isempty(reference)
                    endpointName="E"; if reference==3, endpointName="J"; end
                    [ea,eb]=channelFactors(data,a,b,i,j,channels(c,:),v2,endpointName);
                    scales(reference,:)=WVInternal.productReferenceScale(contexts{v3,component,reference},av,bv,ea,eb);
                end
            end
            % Every individual channel has a real vertical shape times a
            % scalar phase. At zero output align that phase to represent a
            % real conjugate-pair forcing, as required by the mean families.
            if all(inventory.vectors(v3,:)==0)
                [~,pivot]=max(abs(products.Q),[],1);
                value=products.Q(sub2ind(size(products.Q),pivot,1:length(i)));
                phase=ones(size(value)); nonzero=value~=0; phase(nonzero)=conj(value(nonzero))./abs(value(nonzero));
                for setName=["S","R","Q","E","H","J"], products.(setName)=real(products.(setName).*phase); end
            end
            context1=contexts{v3,component,1}; context2=contexts{v3,component,2}; counts=outputCounts{v3,component};
            if target~="mda", endpoints=zeros(size(products.E)); else, endpoints=products.E; end
            low=WVInternal.measureProductProjection(context1,products.S,products.R,endpoints,counts,projections=projections{v3,component,1});
            high=WVInternal.measureProductProjection(context2,products.S,products.Q,endpoints,counts,projections=projections{v3,component,2});
            stability=WVInternal.compareProductReferences(context2,low,high,counts);
            endpointsHigh=zeros(size(products.J)); if target=="mda", endpointsHigh=products.J; end
            independent=WVInternal.measureProductProjection(contexts{v3,component,3},zeros(size(products.S)),products.H,endpointsHigh,counts,projections=projections{v3,component,3});
            eigenProductStability=WVInternal.compareProductReferences(context2,high,independent,counts);
            scale=max(scales,[],1);
            q=WVInternal.qualifyProductReferences(context2,low,high,counts,scale,config.referenceAllowance,config.referenceAbsoluteAllowance);
            e=WVInternal.qualifyProductReferences(context2,high,independent,counts,scale,config.referenceAllowance,config.referenceAbsoluteAllowance);
            qualification=max(q.allowanceFraction,e.allowanceFraction);
            relativeReferenceError=max(q.relativeError,e.relativeError);
            usesAbsolute=qualification<=1 & relativeReferenceError>config.referenceAllowance;
            errorRows=config.waveCount;
            if isfield(config,'selectInertial'), errorRows=max(errorRows,config.inertialCount); end
            if isfield(config,'constructionPolicy') && target~="mda"
                errors=nan(errorRows,size(high.error,2));
                measuredCounts=counts; if target=="wave", measuredCounts=counts/2; end
                errors(measuredCounts,:)=high.error;
            else
                errors=high.error;
                if size(errors,1)<errorRows, errors(end+1:errorRows,:)=repmat(errors(end,:),errorRows-size(errors,1),1); end
            end
            r=r+1; evaluated=evaluated+nnz(~high.isZero); zeroProducts=zeroProducts+nnz(high.isZero);
            [worst,limiting]=max(high.error(end,:));
            records{r}=struct(interaction=t,inputA=aName,inputB=bName,output=target,channel=channels.name(c),error=worst,modeA=a.labels(i(limiting)),signA=a.signs(i(limiting)),modeB=b.labels(j(limiting)),signB=b.signs(j(limiting)),referenceStability=stability,eigenProductStability=eigenProductStability,referenceQualificationFraction=max(qualification),absoluteReferenceProductCount=nnz(usesAbsolute),productCount=nnz(~high.isZero),zeroProductCount=nnz(high.isZero));
            raw{r}=struct(positionA=a.positions(i),positionB=b.positions(j),labelA=a.labels(i),labelB=b.labels(j),signA=a.signs(i),signB=b.signs(j),tail=max(a.tail(i),b.tail(j)),error=single(errors),isZero=high.isZero,referenceQualificationFraction=qualification,relativeReferenceError=relativeReferenceError,referenceUsesAbsolute=usesAbsolute,referenceFactorScale=scale);
        end
    end
    if options.showProgress && mod(t,20)==0, fprintf('Source interactions %d/%d; %d nonzero products; %.1f s.\n',t,height(inventory.interactions),evaluated,toc(timer)); end
end
assessmentSeconds=toc(timer);
if r==0, evidence=[]; return; end
records=records(1:r); raw=raw(1:r); rows=struct2table(vertcat(records{:}));
summary=struct(status="survey-complete",policy=options.policy,pageDifficulty=data.pageDifficulty,configuration=config,constructionSeconds=setupSeconds,projectionPreparationSeconds=projectionPreparationSeconds,projectionCount=projectionCount,assessmentSeconds=assessmentSeconds,interactionCount=length(indices),nonzeroProductEvaluations=evaluated,structuralZeroProducts=zeroProducts,referenceStability=max(rows.referenceStability),eigenConvergence=max(data.requiredConvergence,[],'all'),allModeDerivativeConvergence=max(data.convergence,[],'all'),eigenProductStability=max(rows.eigenProductStability),eigenConvergenceByMetric=max(data.convergence,[],1),sobolevConvergenceByMetric=max(data.requiredConvergence,[],1),boundaryInterpolationError=data.boundaryInterpolationError,waveGram=max(data.waveGram,[],2),apvGram=data.apv.assessment.prefixDiagnostics.gramError(config.apvCount),mdaGram=data.mda.assessment.prefixDiagnostics.gramError(config.mdaCount),inertialGram=data.inertialGram,apvControl=data.apv.assessment.prefixDiagnostics,matlabVersion=string(version),computer=string(computer));
summary.relativeReferencesStable=summary.referenceStability<=config.referenceAllowance && summary.eigenConvergence<=config.eigenAllowance && summary.eigenProductStability<=config.referenceAllowance && summary.boundaryInterpolationError<=config.eigenAllowance;
summary.referenceQualificationFraction=max(rows.referenceQualificationFraction);
summary.absoluteReferenceProductCount=sum(rows.absoluteReferenceProductCount);
summary.referencePolicy=struct(name="mixed-physical-factor-v1",relativeAllowance=config.referenceAllowance,absoluteAllowance=config.referenceAbsoluteAllowance,scale="Maximum across reference grids/solves of min(sup(a)*norm_mu(b),sup(b)*norm_mu(a)); mu uses positive volume and absolute endpoint weights",scope="Individual sampled products and all prepared output prefixes; no coherent-sum guarantee; raw quadratic sampling test unchanged");
summary.referencesStable=summary.referenceQualificationFraction<=1 && summary.eigenConvergence<=config.eigenAllowance && summary.boundaryInterpolationError<=config.eigenAllowance;
summary.fixedFamiliesGramAccepted=max([summary.apvGram summary.mdaGram summary.inertialGram])<=config.gramTolerance;
evidence=struct(raw={raw},inventory=inventory,summary=summary,rows=rows,channels=channels,selection=selection);
end

function [av,bv]=channelFactors(data,a,b,i,j,channel,vectorIndex,setName)
av=a.(setName).(channel.advecting)(:,i); bv=b.(setName).(channel.advected)(:,j);
switch channel.factor
    case "x", bv=1i*data.inventory.physicalVectors(vectorIndex,1)*bv;
    case "y", bv=1i*data.inventory.physicalVectors(vectorIndex,2)*bv;
    case "z", bv=b.(setName).("d"+channel.advected)(:,j);
    case "stratification"
        if setName=="H", zz=data.zQ; elseif setName=="J", zz=[-data.config.Lz;0]; else, zz=data.allZ(data.sets.(setName)); end
        bv=bv.*data.profile.dLogN2(zz);
end
end
