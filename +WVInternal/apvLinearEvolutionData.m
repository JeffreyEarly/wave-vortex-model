function data=apvLinearEvolutionData(w)
% Adapt forcing-owned APV diffusion to the common exponential coordinates.
% Fixed operators and QR factors are local computational caches, not saved state.
% - Topic: Developer utilities
arguments
    w (1,1) WVTransformFreeSurfaceQG
end
if ~w.hasForcingWithName('vertical diffusivity') || ~isa(w.forcingWithName('vertical diffusivity'),'WVVerticalDiffusivity')
    error('WV:DensityDiffusionForcingRequired','Register WVVerticalDiffusivity before selecting exponential integration.');
end
force=w.forcingWithName('vertical diffusivity'); operators=force.densityDiffusionModes();
shape=[w.apvModeCount+w.activeEndpointCount,numel(w.klNonzero)]; count=prod(shape);
lambda=zeros(shape); groups=cell(numel(w.khUnique),1);
for p=1:numel(groups)
    groups{p}=find(w.klNonzeroKhUniqueIndex==p);
    lambda(:,groups{p})=repmat(operators.pages{p}.rates,1,numel(groups{p}));
end
rates=[lambda(:);operators.mda.rates];
widths=cellfun(@numel,groups); uniqueWidths=unique(widths); batches=cell(numel(uniqueWidths),1);
for k=1:numel(batches)
    pageIndices=find(widths==uniqueWidths(k)); pages=[operators.pages{pageIndices}];
    columns=reshape(cell2mat(groups(pageIndices).'),uniqueWidths(k),[]);
    batches{k}=struct(columns=columns,toModes=cat(3,pages.toModes),fromModes=cat(3,pages.fromModes));
end
factors={};
data=struct(familyNames=["Ag_q","Ag_0","Amda"],familyShapes={{size(w.Ag_q),size(w.Ag_0),size(w.Amda)}},rates=rates,operators=operators, ...
    toModes=@toModes,fromModes=@fromModes,physicalErrorNorms=@physicalNorms,projectSource=@(q,b)w.projectQuasigeostrophicSpatialTendency(q,b), ...
    explicitRHS=@explicitRHS,validateConfiguration=@validateConfiguration,errorScaleUsesTotal=false);
    function c=toModes(state)
        balanced=applyBatches([state.Ag_q;state.Ag_0],"toModes");
        c=[balanced(:);operators.mda.toModes*state.Amda];
    end
    function state=fromModes(c)
        [balanced,meanState]=unpack(c);
        balanced=applyBatches(balanced,"fromModes");
        state=struct(Ag_q=balanced(1:w.apvModeCount,:),Ag_0=balanced(w.apvModeCount+1:end,:),Amda=meanState);
    end
    function [tendency,speed]=explicitRHS(excluded)
        [tendency,speed]=w.coefficientTendency(excludingForcing=[string(force.name),excluded]);
    end
    function validateConfiguration()
        if ~w.hasForcingWithName(force.name) || w.forcingWithName(force.name)~=force || force.kappa_z~=operators.kappa_z || force.shouldForceMeanDensityAnomaly~=operators.shouldForceMeanDensityAnomaly
            error('WV:DensityDiffusionConfigurationChanged','Density diffusion changed; call model.setupIntegrator(integratorType="exponential") again.');
        end
    end
    function out=applyBatches(in,direction)
        out=zeros(size(in),'like',in);
        for index=1:numel(batches)
            batch=batches{index};
            values=reshape(in(:,batch.columns(:)),size(in,1),size(batch.columns,1),[]);
            transformed=pagemtimes(batch.(direction),values);
            out(:,batch.columns(:))=reshape(transformed,size(in,1),[]);
        end
    end
    function [balanced,meanState]=unpack(c)
        if ~iscolumn(c) || numel(c)~=numel(rates) || any(~isfinite(c))
            error('WV:DensityDiffusionState','Supply one finite packed diffusion-coordinate column.');
        end
        balanced=reshape(c(1:count),shape);
        meanState=operators.mda.fromModes*c(count+1:end);
        if norm(imag(meanState))>1e-12*max(norm(meanState),realmin)
            error('WV:DensityDiffusionMeanReality','MDA coordinates must reconstruct a real horizontal mean.');
        end
        meanState=real(meanState);
    end
    function values=physicalNorms(c)
        [balanced,meanState]=unpack(c);
        if isempty(factors)
            weights=sqrt(operators.weights/w.Lz); factors=cell(numel(groups)+1,4);
            for page=1:numel(groups)
                r=operators.reconstruction{page}; A=operators.pages{page}.fromModes;
                maps={weights.*(r.q*A),weights.*(r.buoyancy*A),w.khUnique(page)*weights.*(r.phi*A),r.endpoint*A};
                for field=1:4, [~,factors{page,field}]=qr(maps{field},0); end
            end
            r=operators.mda.reconstruction; maps={weights.*r.q,weights.*r.buoyancy,[],r.endpoint};
            for field=[1 2 4], [~,factors{end,field}]=qr(maps{field},0); end
        end
        variance=zeros(1,4);
        for page=1:numel(groups)
            a=balanced(:,groups{page});
            for field=1:4, variance(field)=variance(field)+2*sum(abs(factors{page,field}*a).^2,'all'); end
        end
        for field=[1 2 4], variance(field)=variance(field)+sum(abs(factors{end,field}*meanState).^2); end
        values=sqrt(variance);
    end
end
