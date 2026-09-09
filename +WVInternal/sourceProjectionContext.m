function [context,counts,targetName] = sourceProjectionContext(data,vectorIndex,component,reference)
% Match WVM's wave energy dual and actual inertial/MDA source projections.
arguments
    data (1,1) struct
    vectorIndex (1,1) double
    component (1,1) string
    reference (1,1) string {mustBeMember(reference,["R","Q","H"])}
end
if reference=="R", zRef=data.zR; wRef=data.wR; else, zRef=data.zQ; wRef=data.wQ; end
kl=data.inventory.physicalVectors(vectorIndex,:); kh=hypot(kl(1),kl(2));
[~,page]=min(abs(data.inventory.magnitudes-kh));
if kh==0 && component=="eta"
    context=WVInternal.prepareProductProjection(data.mda.basis,data.mda.transform,"G",zRef,wRef);
    if reference=="H"
        context.referenceValues=data.mda.H.G;
        context.endpointValues=data.mda.J.G;
        context.targetGram=context.referenceValues'*(context.volumeWeights.*context.referenceValues)+context.endpointValues'*(context.endpointMetric.*context.endpointValues);
        context.majorantGram=context.referenceValues'*(context.volumeWeights.*context.referenceValues)+context.endpointValues'*(abs(context.endpointMetric).*context.endpointValues);
    end
    counts=data.config.mdaCount; targetName="mda"; return
end
if kh==0 && component=="w"
    context=[]; counts=[]; targetName="null-mean-w"; return
end
B=data.wave{page}; h=B.basis.h(1:numel(B.labels)); h=h(:); if reference=="H", h=B.checkh; end
if isempty(h)
    context=[]; counts=[]; targetName="null-mean-w"; return
end
if kh==0
    sampleValues=B.S.F; referenceValues=B.(reference).F;
    if component=="v", sampleValues=1i*sampleValues; referenceValues=1i*referenceValues; end
    metric=2*h; counts=data.config.inertialCount;
    if isfield(data.config,"selectInertial"), counts=WVInternal.constructionModeLevels(data.config.inertialCount); end
    targetName="inertial";
else
    fields=WVInternal.sourceStudyFields(data,"wave",vectorIndex);
    sampleValues=fields.S.(component); referenceValues=fields.(reference).(component);
    metric=repelem(2*h,2); counts=2*(1:numel(h));
    if isfield(data.config,"constructionPolicy"), counts=2*WVInternal.constructionModeLevels(numel(h)); end
    targetName="wave";
end
sampleWeight=data.w; referenceWeight=wRef;
if component=="eta"
    sampleWeight=sampleWeight.*data.profile.N2(data.z);
    referenceWeight=referenceWeight.*data.profile.N2(zRef);
end
n=length(metric);
% Zero source in the independent surface component: source pairings have no
% surface contribution. Its contribution to wave energy is already in 2h.
context=struct(sampleValues=sampleValues,sampleMetric=diag(sampleWeight),sampleGram=diag(metric),targetGram=diag(metric),majorantGram=diag(metric),active=true(n,1),referenceValues=referenceValues,volumeWeights=referenceWeight,endpointValues=zeros(2,n),endpointMetric=[0;0],variable=component);
end
