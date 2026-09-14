function [diagnosis,reconstruction] = thermalAPVDecomposition(data,state,tendencies,time,fieldNames)
% Apply prepared maps, retaining physical self and cross contributions.
% Radius batches bound scratch; physical volumes exist only when requested.
% - Topic: Developer utilities
nk=numel(data.klNonzero); nd=numel(tendencies);
coefficients=struct(Ag_q=complex(zeros(data.metadata.apvModeCount,nk)),Ag_0=complex(zeros(2,nk)));
account=emptyAccounting(nk); residual=emptyResidual();
directional=repmat(struct(coefficients=coefficients,byWavenumber=account,residualRateNorms=residual),1,nd);
components=["total","apv","zeroAPV","mean","residual"];
spectral=struct();
for component=components
    for name=fieldNames
        n=data.quadratureCount;
        if name=="ssh", n=1; elseif name=="endpointAnomalies", n=2; end
        spectral.(component).(name)=complex(zeros(n,data.Nkl));
    end
end
for p=1:numel(data.pages)
    page=data.pages{p}; cols=page.columns;
    [fields,aq,a0]=evaluatePage(data,page,p,state.Ath(:,cols));
    coefficients.Ag_q(:,page.targetColumns)=aq; coefficients.Ag_0(:,page.targetColumns)=a0;
    values=pageAccounting(fields,data,page.kh,struct());
    account=assignAccounting(account,values,cols);
    residual=addResidual(residual,pageResidual(fields,data,page.kh));
    for j=1:nd
        [rate,dq,d0]=evaluatePage(data,page,p,tendencies(j).Ath(:,cols));
        directional(j).coefficients.Ag_q(:,page.targetColumns)=dq;
        directional(j).coefficients.Ag_0(:,page.targetColumns)=d0;
        values=pageAccounting(fields,data,page.kh,rate);
        directional(j).byWavenumber=assignAccounting(directional(j).byWavenumber,values,cols);
        directional(j).residualRateNorms=addResidual(directional(j).residualRateNorms,pageResidual(rate,data,page.kh));
    end
    for component=["total","apv","zeroAPV","residual"]
        for name=fieldNames
            value=fields.(component).(fieldSource(name));
            if name=="u", value=(-1i*data.l(cols).').*value; end
            if name=="v", value=(1i*data.k(cols).').*value; end
            spectral.(component).(name)(:,data.klNonzero(cols))=value;
        end
    end
end
mean=meanState(data,state.Amda);
meanInventory=meanAccounting(mean,data,struct());
[inventories,radial]=completeAccounting(data,account,meanInventory);
residual=addMeanReference(residual,mean,data);
residual=finishResidual(residual,inventories);
diagnosis=struct(time=time,coefficients=coefficients,mean=struct(sourceAmda=state.Amda,inventories=meanInventory), ...
    metadata=data.metadata,modalPower=struct(Ag_q=2*abs(coefficients.Ag_q).^2,Ag_0=2*abs(coefficients.Ag_0).^2), ...
    inventories=inventories,byWavenumber=account,radialSpectrum=radial,residuals=residual,directional=struct.empty(1,0));
for j=1:nd
    meanRate=meanState(data,tendencies(j).Amda);
    meanInventoryRate=meanAccounting(mean,data,meanRate);
    [directional(j).inventories,directional(j).radialSpectrum]=completeAccounting(data,directional(j).byWavenumber,meanInventoryRate);
    directional(j).mean=struct(sourceAmda=tendencies(j).Amda,inventories=meanInventoryRate);
    % Rate norms are positive norms of the rate fields, not signed work.
    rateNorm=addMeanReference(directional(j).residualRateNorms,meanRate,data);
    directional(j).residualRateNorms=finishResidual(rateNorm,struct());
    directional(j).modalPowerTendency=struct(Ag_q=4*real(conj(coefficients.Ag_q).*directional(j).coefficients.Ag_q),Ag_0=4*real(conj(coefficients.Ag_0).*directional(j).coefficients.Ag_0));
end
diagnosis.directional=directional;
reconstruction=struct();
if isempty(fieldNames), return; end
for name=fieldNames
    value=mean.(fieldSource(name));
    if ismember(name,["u","v"]), value=zeros(size(value)); end
    spectral.mean.(name)(:,data.meanIndex)=value;
    spectral.total.(name)(:,data.meanIndex)=value;
end
reconstruction=struct(x=(0:data.grid(1)-1)'*data.domain(1)/data.grid(1),y=(0:data.grid(2)-1)'*data.domain(2)/data.grid(2),z=data.z);
counts=unique(cellfun(@(name)size(spectral.total.(name),1),cellstr(fieldNames)));
for count=reshape(counts,1,[])
    geometry=WVGeometryDoublyPeriodic(data.domain,data.grid,Nz=count,shouldAntialias=data.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=data.conjugateDimension);
    for name=fieldNames
        if size(spectral.total.(name),1)~=count, continue; end
        for component=components
            reconstruction.(component).(name)=geometry.transformToSpatialDomainWithFourier(spectral.(component).(name));
        end
    end
end
end

function [fields,aq,a0]=evaluatePage(data,page,p,Ath)
C=data.thermalToPolynomial(:,:,p)*Ath; r=data.polynomial;
total=struct(psi=r.psi*C,eta=r.eta*C,eta_i=r.eta_i*C,buoyancy=r.buoyancy*C, ...
    qgpv=r.qgpv*C-page.kh^2*(r.psi*C),ssh=r.ssh*C,endpointAnomalies=data.endpoint.eta_i*C);
aq=page.Aq*Ath; a0=page.A0*Ath;
pressureCoefficients=-aq./page.mu.';
apv=struct(psi=data.apvF*pressureCoefficients,eta=(data.f/data.g)*data.apvG*pressureCoefficients,qgpv=data.apvF*aq,ssh=(data.f/data.g)*data.apvFSurface*pressureCoefficients,endpointAnomalies=page.apvEndpoint*aq);
zero=struct(psi=page.zeroPsi*a0,eta=page.zeroEta*a0,qgpv=complex(zeros(size(total.qgpv))),ssh=page.zeroSSH*a0,endpointAnomalies=page.zeroEndpoint*a0);
apv.eta_i=apv.eta-(1+data.z/data.depth).*apv.ssh; apv.buoyancy=-data.N2.*apv.eta_i;
zero.eta_i=zero.eta-(1+data.z/data.depth).*zero.ssh; zero.buoyancy=-data.N2.*zero.eta_i;
residual=struct();
for name=string(fieldnames(total)).', residual.(name)=total.(name)-apv.(name)-zero.(name); end
fields=struct(total=total,apv=apv,zeroAPV=zero,residual=residual);
end

function result=emptyAccounting(n)
result=struct();
for name=["kineticEnergy","interiorPotentialEnergy","surfacePotentialEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance","totalEnergy"]
    result.(name)=struct(total=zeros(1,n),apv=zeros(1,n),zeroAPV=zeros(1,n),residual=zeros(1,n),mean=zeros(1,n), ...
        apvZeroAPV=zeros(1,n),apvResidual=zeros(1,n),zeroAPVResidual=zeros(1,n));
end
end

function values=pageAccounting(fields,data,kh,rate)
values=emptyAccounting(size(fields.total.psi,2)); hasRate=~isempty(fieldnames(rate));
for name=["kineticEnergy","interiorPotentialEnergy","surfacePotentialEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
    [field,weight,row]=inventoryRule(name,data,kh);
    for component=["total","apv","zeroAPV","residual"]
        y=fields.(component).(field); if row>0, y=y(row,:); end
        if hasRate
            dy=rate.(component).(field); if row>0, dy=dy(row,:); end
            values.(name).(component)=2*real(sum(weight.*conj(y).*dy,1));
        else
            values.(name).(component)=sum(weight.*abs(y).^2,1);
        end
    end
    pairs=["apv","zeroAPV","apvZeroAPV";"apv","residual","apvResidual";"zeroAPV","residual","zeroAPVResidual"];
    for j=1:3
        a=fields.(pairs(j,1)).(field); b=fields.(pairs(j,2)).(field);
        if row>0, a=a(row,:); b=b(row,:); end
        if hasRate
            da=rate.(pairs(j,1)).(field); db=rate.(pairs(j,2)).(field);
            if row>0, da=da(row,:); db=db(row,:); end
            term=conj(a).*db+conj(da).*b;
        else
            term=conj(a).*b;
        end
        values.(name).(pairs(j,3))=2*real(sum(weight.*term,1));
    end
end
for part=string(fieldnames(values.totalEnergy)).'
    values.totalEnergy.(part)=values.kineticEnergy.(part)+values.interiorPotentialEnergy.(part)+values.surfacePotentialEnergy.(part);
end
end

function [field,weight,row]=inventoryRule(name,data,kh)
row=0;
switch name
    case "kineticEnergy", field="psi"; weight=data.weights*kh^2;
    case "interiorPotentialEnergy", field="eta"; weight=data.weights.*data.N2;
    case "surfacePotentialEnergy", field="ssh"; weight=data.g;
    case "potentialEnstrophy", field="qgpv"; weight=data.weights;
    case "surfaceAnomalyVariance", field="endpointAnomalies"; weight=1; row=1;
    case "bottomAnomalyVariance", field="endpointAnomalies"; weight=1; row=2;
end
end

function account=assignAccounting(account,values,cols)
for name=string(fieldnames(values)).'
    for part=string(fieldnames(values.(name))).'
        account.(name).(part)(cols)=values.(name).(part);
    end
end
end

function mean=meanState(data,Amda)
mean=struct();
for name=string(fieldnames(data.meanFields)).', mean.(name)=data.meanFields.(name)*Amda; end
end

function result=meanAccounting(mean,data,rate)
result=struct(); hasRate=~isempty(fieldnames(rate));
for name=["kineticEnergy","interiorPotentialEnergy","surfacePotentialEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
    [field,weight,row]=inventoryRule(name,data,0); y=mean.(field);
    if row>0, y=y(row,:); end
    if hasRate
        dy=rate.(field); if row>0, dy=dy(row,:); end
        result.(name)=real(sum(weight.*conj(y).*dy));
    else
        result.(name)=sum(weight.*abs(y).^2)/2;
    end
end
result.totalEnergy=result.kineticEnergy+result.interiorPotentialEnergy+result.surfacePotentialEnergy;
end

function [inventories,radial]=completeAccounting(data,account,mean)
inventories=struct(); radial=struct(kRadial=data.kRadial);
for name=string(fieldnames(account)).'
    for part=string(fieldnames(account.(name))).'
        inventories.(name).(part)=sum(account.(name).(part));
        full=zeros(1,data.Nkl); full(data.klNonzero)=account.(name).(part);
        radial.(name).(part)=full*data.radialBinning;
    end
    inventories.(name).mean=mean.(name);
    inventories.(name).total=inventories.(name).total+mean.(name);
end
end

function result=emptyResidual()
result=struct();
for name=["qgpv","buoyancy","velocity","eta","eta_i","ssh","endpointAnomalies","energyNorm"]
    n=1; if name=="endpointAnomalies", n=2; end
    result.(name)=struct(absolute=zeros(n,1),reference=zeros(n,1));
end
end

function result=pageResidual(fields,data,kh)
result=emptyResidual();
for name=string(fieldnames(result)).'
    if name=="energyNorm"
        for component=["total","residual"]
            f=fields.(component);
            energy=sum(data.weights.*(kh^2*abs(f.psi).^2+data.N2.*abs(f.eta).^2),'all')+data.g*sum(abs(f.ssh).^2,'all');
            part="absolute"; if component=="total", part="reference"; end
            result.energyNorm.(part)=energy;
        end
        continue
    end
    field=fieldSource(name); weight=data.weights/data.depth;
    if name=="velocity", field="psi"; weight=kh^2*weight; end
    if ismember(name,["ssh","endpointAnomalies"]), weight=1; end
    result.(name).absolute=2*sum(weight.*abs(fields.residual.(field)).^2,2);
    result.(name).reference=2*sum(weight.*abs(fields.total.(field)).^2,2);
    if name~="endpointAnomalies"
        result.(name).absolute=sum(result.(name).absolute);
        result.(name).reference=sum(result.(name).reference);
    end
end
end

function result=addResidual(result,term)
for name=string(fieldnames(result)).'
    result.(name).absolute=result.(name).absolute+term.(name).absolute;
    result.(name).reference=result.(name).reference+term.(name).reference;
end
end

function result=addMeanReference(result,mean,data)
for name=string(fieldnames(result)).'
    if name=="velocity", continue; end
    if name=="energyNorm"
        result.energyNorm.reference=result.energyNorm.reference+sum(data.weights.*data.N2.*abs(mean.eta).^2)/2;
        continue
    end
    weight=data.weights/data.depth;
    if ismember(name,["ssh","endpointAnomalies"]), weight=1; end
    term=weight.*abs(mean.(name)).^2;
    if name~="endpointAnomalies", term=sum(term); end
    result.(name).reference=result.(name).reference+term;
end
end

function result=finishResidual(result,inventories)
for name=string(fieldnames(result)).'
    result.(name).absolute=sqrt(max(0,result.(name).absolute));
    result.(name).reference=sqrt(max(0,result.(name).reference));
    result.(name).relative=result.(name).absolute./result.(name).reference;
    result.(name).relative(result.(name).reference==0)=NaN;
end
if ~isempty(fieldnames(inventories))
    absolute=sqrt(inventories.totalEnergy.residual); reference=sqrt(inventories.totalEnergy.total);
    relative=absolute/reference; if reference==0, relative=NaN; end
    result.energyNorm=struct(absolute=absolute,reference=reference,relative=relative);
end
end

function name=fieldSource(name)
if ismember(name,["u","v"]), name="psi"; end
end
