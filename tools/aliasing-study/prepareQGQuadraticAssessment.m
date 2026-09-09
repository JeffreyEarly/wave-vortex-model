function prepared = prepareQGQuadraticAssessment(data,options)
% Prepare bounded APV and active-endpoint product evidence from solved modes.
% This optional value snapshot never mutates a transform or selects modes.
arguments (Input)
    data (1,1) struct
    options.policy (1,1) string {mustBeMember(options.policy,["fixed","dense"])} = "fixed"
    options.interactionIndices (1,:) double {mustBeInteger,mustBePositive,mustBeFinite} = []
    options.productBudget (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 500000
    options.workingMemoryBudget (1,1) double {mustBePositive,mustBeFinite} = 512*1024^2
end
timer=tic; config=data.config; inventory=data.inventory;
if ~isfield(config,'referenceAbsoluteAllowance'), error('WVStudy:InvalidPreparation','Prepare modes with explicit reference allowances.'); end
selection=selectStudyInteractions(inventory,data.pageDifficulty);
indices=options.interactionIndices;
if isempty(indices)
    if options.policy=="dense", indices=1:height(inventory.interactions); else, indices=selection.fixed.'; end
end
if any(indices>height(inventory.interactions)) || numel(unique(indices))~=numel(indices)
    error('WVStudy:InvalidInteractions','Choose distinct prepared interaction indices.');
end
% Individual mean-output channels are omitted; assembled convolution checks
% their exact Jacobian cancellation separately. No QG mean APV family exists.
indices=indices(data.inventory.magnitudes(inventory.interactions.page3(indices))>0);
if isempty(indices), error('WVStudy:InvalidInteractions','Choose at least one nonzero output interaction.'); end
n=config.apvCount+2; reserved=numel(indices)*n^2*3*5;
workingBytes=reserved*1024+16*12*numel(data.allZ)*n^2;
if reserved>options.productBudget, error('WVStudy:ProductBudgetExceeded','QG preparation reserves %d scalar output measurements; increase the explicit budget or reduce the inventory.',reserved); end
if workingBytes>options.workingMemoryBudget, error('WVStudy:WorkingMemoryBudgetExceeded','QG preparation estimates %.1f MiB; reduce the inventory or increase the explicit budget.',workingBytes/1024^2); end
contexts=cell(1,3); projections=cell(1,3); 
for s=1:3
    if s==1, zr=data.zR; wr=data.wR; else, zr=data.zQ; wr=data.wQ; end
    contexts{s}=prepareProductProjection(data.apv.basis,data.apv.transform,"F",zr,wr);
    if s==3, contexts{s}.referenceValues=data.apv.H.F; end
    projections{s}=prepareProductProjections(contexts{s},config.apvCount);
end
projectionSeconds=toc(timer); records=cell(numel(indices)*15,1); index=0;
[a,b]=ndgrid(1:n,1:n); a=a(:).'; b=b(:).';
for t=indices
    triad=inventory.interactions(t,:); p1=triad.page1; p2=triad.page2; p3=triad.page3;
    k1=2*pi*[triad.k1x/config.Lxy(1),triad.k1y/config.Lxy(2)];
    k2=2*pi*[triad.k2x/config.Lxy(1),triad.k2y/config.Lxy(2)];
    % -u*d_x -v*d_y = (k1x*k2y-k1y*k2x)*psi_a*q_b.
    factors=[-k1(2)*k2(1),k1(1)*k2(2),k1(1)*k2(2)-k1(2)*k2(1)];
    names=["-u*dx","-v*dy","-J"];
    for channel=1:3
        samples=cell(1,4); endpoints=cell(1,4); scales=zeros(1,numel(a)); endpointScale=zeros(2,numel(a)); response=cell(1,3);
        for s=1:4
            setName=["S","R","Q","H"]; setName=setName(s);
            A=qgStudyFields(data,p1,setName); B=qgStudyFields(data,p2,setName);
            x=A.psi(:,a); y=factors(channel)*B.q(:,b);
            samples{s}=x.*y;
            endpoints{s}=factors(channel)*A.psiEndpoint(:,a).*B.b(:,b);
            if s>1
                context=contexts{s-1};
                scales=max(scales,productReferenceScale(context,x,y,zeros(2,numel(a)),zeros(2,numel(a))));
                endpointScale=max(endpointScale,abs(factors(channel))*max(abs(A.psi(:,a)),[],1).*abs(B.b(:,b)));
                if inventory.magnitudes(p3)>0
                    O=qgStudyFields(data,p3,setName); response{s-1}=O.apvEndpointResponse;
                else
                    response{s-1}=zeros(2,config.apvCount);
                end
            end
        end
        measurements=cell(1,3);
        for s=1:3
            measurements{s}=measureProductProjection(contexts{s},samples{1},samples{s+1},zeros(2,numel(a)),config.apvCount,projections=projections{s});
        end
        low=measurements{1}; high=measurements{2}; independent=measurements{3};
        qr=qualifyProductReferences(contexts{2},low,high,config.apvCount,scales,config.referenceAllowance,config.referenceAbsoluteAllowance);
        er=qualifyProductReferences(contexts{2},high,independent,config.apvCount,scales,config.referenceAllowance,config.referenceAbsoluteAllowance);
        qualification=max(qr.allowanceFraction,er.allowanceFraction); relative=max(qr.relativeError,er.relativeError);
        addRows("apv",high.error,qualification,relative,high.isZero);
        for e=1:2
            endpointName=["surface","bottom"]; endpointName=endpointName(e);
            lo=endpoints{2}(e,:); hi=endpoints{3}(e,:); ind=endpoints{4}(e,:);
            [fraction,rel]=scalarReferences(lo,hi,ind,endpointScale(e,:),config);
            samplingError=ratio(abs(endpoints{1}(e,:)-hi),abs(hi));
            addRows(endpointName,samplingError,fraction,rel,hi==0);
            % APV-first projection induces a compensating boundary response.
            % Use the Cauchy bound of this actual endpoint functional on the
            % positive F norm; never divide by a cancellation-prone residual.
            E=response{2}(e,:); M=contexts{2}.majorantGram;
            dual=sqrt(max(0,real((E/M)*E')));
            lo=response{1}(e,:)*low.referenceCoefficients{1};
            hi=E*high.referenceCoefficients{1}; ind=response{3}(e,:)*independent.referenceCoefficients{1};
            P=dual*min([sqrt(low.productNormSquared);sqrt(high.productNormSquared);sqrt(independent.productNormSquared)],[],1);
            delta=max(abs(lo-hi),abs(hi-ind));
            fraction=ratio(delta,config.referenceAllowance*P+config.referenceAbsoluteAllowance*dual*scales);
            rel=ratio(delta,P);
            samplingError=ratio(abs(E*(high.sampleCoefficients{1}-high.referenceCoefficients{1})),dual*sqrt(high.productNormSquared));
            addRows(endpointName+"Residual",samplingError,fraction,rel,high.isZero);
        end
    end
end
rows=vertcat(records{1:index});
boundaries=qgBoundaryGridAssessment(data);
convergence=max(data.apv.resolutionConvergence);
for p=find(inventory.magnitudes>0).', convergence=max(convergence,max(data.boundary{p}.resolutionConvergence)); end
prepared=struct(kind="qgQuadraticEvidence-v1",configuration=config,inventory=inventory,rows=rows,boundaries=boundaries,modeConvergenceError=convergence,apvGramError=data.apv.assessment.prefixDiagnostics.gramError(end),coverage=struct(policy=options.policy,selectedInteractionIndices=indices,inputFamilies=["apv","surface","bottom"],outputs=["apv","surface","bottom","surfaceResidual","bottomResidual"],omittedDynamics=["wave-coupled","MDA inputs","individual mean-output channels","finite-amplitude free-surface corrections"],superpositionGuarantee=false,exhaustiveGuarantee=false),cost=struct(reservedProducts=reserved,productBudget=options.productBudget,workingMemoryEstimateBytes=workingBytes,workingMemoryBudget=options.workingMemoryBudget,sourcePreparationSeconds=data.constructionSeconds,projectionPreparationSeconds=projectionSeconds,evidencePreparationSeconds=toc(timer),additionalModeSolves=0));
memory=whos('prepared'); prepared.cost.retainedBytes=memory.bytes;

    function addRows(output,samplingError,fraction,relative,isZero)
        index=index+1;
        count=numel(a);
        records{index}=table(repmat(t,count,1),repmat(p3,count,1),A.labels(a).',B.labels(b).',repmat(names(channel),count,1),repmat(output,count,1),samplingError(:),fraction(:),relative(:),fraction(:)<=1 & relative(:)>config.referenceAllowance,isZero(:),VariableNames={'interaction','outputPage','inputA','inputB','channel','output','samplingError','referenceFraction','relativeReferenceError','usesAbsoluteReference','isZero'});
    end
end

function [fraction,relative]=scalarReferences(lo,hi,ind,scale,c)
change=max(abs(lo-hi),abs(hi-ind)); norm=min([abs(lo);abs(hi);abs(ind)],[],1);
fraction=ratio(change,c.referenceAllowance*norm+c.referenceAbsoluteAllowance*scale);
relative=ratio(change,norm);
end
function value=ratio(numerator,denominator)
value=numerator./denominator; value(numerator==0 & denominator==0)=0;
end
