function evidence = measureSourceProducts(data,options)
% Assess prepared physical source products without solving modes or writing files.
arguments (Input)
    data (1,1) struct
    options.interactionIndices (1,:) double = []
    options.policy (1,1) string {mustBeMember(options.policy,["dense","fixed","targeted"])} = "dense"
    options.showProgress (1,1) logical = false
end
config=data.config;
constructionTimer=tic;
inventory=data.inventory;
channels=sourceChannelInventory();
familyPairs=["wave" "wave";"wave" "apv";"apv" "wave";"wave" "boundary";"boundary" "wave";"apv" "boundary";"boundary" "apv";"boundary" "boundary"];
selection=selectStudyInteractions(inventory,data.pageDifficulty);
indices=options.interactionIndices;
if isempty(indices)
    if options.policy=="dense", indices=1:height(inventory.interactions); else, indices=selection.(options.policy).'; end
end
selectedRows=table2array(inventory.interactions(indices,1:6));
[~,inputIndices]=ismember([selectedRows(:,1:2);selectedRows(:,3:4)],inventory.vectors,'rows');
[~,outputIndices]=ismember(selectedRows(:,5:6),inventory.vectors,'rows');
fields=cell(size(inventory.vectors,1),3);
names=["wave","apv","boundary"];
for j=unique(inputIndices).'
    if all(inventory.vectors(j,:)==0), continue; end
    for family=1:3, fields{j,family}=sourceStudyFields(data,names(family),j); end
end
contexts=cell(size(fields,1),4,3); targetNames=strings(size(fields,1),4); outputCounts=cell(size(fields,1),4);
components=["u","v","w","eta"];
for j=unique(outputIndices).'
    for c=1:4
        [contexts{j,c,1},outputCounts{j,c},targetNames(j,c)]=sourceProjectionContext(data,j,components(c),"R");
        contexts{j,c,2}=sourceProjectionContext(data,j,components(c),"Q");
        contexts{j,c,3}=sourceProjectionContext(data,j,components(c),"H");
    end
end
setupSeconds=data.constructionSeconds+toc(constructionTimer);
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
        mask=studyModePairMask(a.positions(i),b.positions(j),aName,bName,config.waveCount,options.policy);
        i=i(mask); j=j(mask);
        for c=1:height(channels)
            source=channels.advected(c); component=find(components==source);
            target=targetNames(v3,component);
            if target=="null-mean-w", continue; end
            products=struct();
            for setName=["S","R","Q","E","H","J"]
                av=a.(setName).(channels.advecting(c))(:,i);
                bv=b.(setName).(source)(:,j);
                switch channels.factor(c)
                    case "x", bv=1i*inventory.physicalVectors(v2,1)*bv;
                    case "y", bv=1i*inventory.physicalVectors(v2,2)*bv;
                    case "z", bv=b.(setName).("d"+source)(:,j);
                    case "stratification"
                        if setName=="H", zz=data.zQ; elseif setName=="J", zz=[-config.Lz;0]; else, zz=data.allZ(data.sets.(setName)); end
                        bv=bv.*data.profile.dLogN2(zz);
                end
                products.(setName)=-av.*bv;
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
            low=measureProductProjection(context1,products.S,products.R,endpoints,counts);
            high=measureProductProjection(context2,products.S,products.Q,endpoints,counts);
            stability=compareProductReferences(context2,low,high,counts);
            endpointsHigh=zeros(size(products.J)); if target=="mda", endpointsHigh=products.J; end
            independent=measureProductProjection(contexts{v3,component,3},zeros(size(products.S)),products.H,endpointsHigh,counts);
            eigenProductStability=compareProductReferences(context2,high,independent,counts);
            errors=high.error;
            if target~="wave", errors=repmat(errors,config.waveCount,1); end
            r=r+1; evaluated=evaluated+nnz(~high.isZero); zeroProducts=zeroProducts+nnz(high.isZero);
            [worst,limiting]=max(errors(end,:));
            records{r}=struct(interaction=t,inputA=aName,inputB=bName,output=target,channel=channels.name(c),error=worst,modeA=a.labels(i(limiting)),signA=a.signs(i(limiting)),modeB=b.labels(j(limiting)),signB=b.signs(j(limiting)),referenceStability=stability,eigenProductStability=eigenProductStability,productCount=nnz(~high.isZero),zeroProductCount=nnz(high.isZero));
            raw{r}=struct(positionA=a.positions(i),positionB=b.positions(j),labelA=a.labels(i),labelB=b.labels(j),signA=a.signs(i),signB=b.signs(j),tail=max(a.tail(i),b.tail(j)),error=single(errors),isZero=high.isZero);
        end
    end
    if options.showProgress && mod(t,20)==0, fprintf('Source interactions %d/%d; %d nonzero products; %.1f s.\n',t,height(inventory.interactions),evaluated,toc(timer)); end
end
assessmentSeconds=toc(timer);
records=records(1:r); raw=raw(1:r); rows=struct2table(vertcat(records{:}));
summary=struct(status="survey-complete",policy=options.policy,pageDifficulty=data.pageDifficulty,configuration=config,constructionSeconds=setupSeconds,assessmentSeconds=assessmentSeconds,interactionCount=length(indices),nonzeroProductEvaluations=evaluated,structuralZeroProducts=zeroProducts,referenceStability=max(rows.referenceStability),eigenConvergence=max(data.requiredConvergence,[],'all'),allModeDerivativeConvergence=max(data.convergence,[],'all'),eigenProductStability=max(rows.eigenProductStability),eigenConvergenceByMetric=max(data.convergence,[],1),sobolevConvergenceByMetric=max(data.requiredConvergence,[],1),boundaryInterpolationError=data.boundaryInterpolationError,waveGram=max(data.waveGram,[],2),apvGram=data.apv.assessment.prefixDiagnostics.gramError(end),mdaGram=data.mda.assessment.prefixDiagnostics.gramError(end),inertialGram=data.inertialGram,apvControl=data.apv.assessment.prefixDiagnostics,matlabVersion=string(version),computer=string(computer));
summary.referencesStable=summary.referenceStability<=config.referenceAllowance && summary.eigenConvergence<=config.eigenAllowance && summary.eigenProductStability<=config.referenceAllowance && summary.boundaryInterpolationError<=config.eigenAllowance;
summary.fixedFamiliesGramAccepted=max([summary.apvGram summary.mdaGram summary.inertialGram])<=config.gramTolerance;
evidence=struct(raw={raw},inventory=inventory,summary=summary,rows=rows,channels=channels,selection=selection);
end
