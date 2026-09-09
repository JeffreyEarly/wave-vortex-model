function result = assessQGAssembledTendency(data,options)
% Compare WVM's QG RHS with direct Fourier convolution on refined modes.
% The manufactured state uses only the same resolved APV/endpoint families.
arguments (Input)
    data (1,1) struct
    options.stateKind (1,1) string {mustBeMember(options.stateKind,["mixed","apv","surface","bottom","collinear"])} = "mixed"
    options.velocityScale (1,1) double {mustBePositive,mustBeFinite} = .03
end
timer=tic; c=data.config; n=c.apvCount;
w=WVTransformFreeSurfaceQG([c.Lxy c.Lz],[c.Nxy c.Nz],N2Function=data.profile.N2,g=c.g,rotationRate=c.f,latitude=30,apvModeCount=n,mdaModeCount=c.mdaCount,apvGramTolerance=1e30,mdaGramTolerance=1e30,quadraticAliasingTolerance=1e30);
% Deliberately allow unresolved controls to construct; this driver measures
% their error, never changes production admission tolerances or mode counts.
orientation=sign(sum(data.w.*w.apvF.*data.apv.S.F,1));
if any(orientation==0), error('WVStudy:ModeIdentityMismatch','Cannot align the prescribed APV modes.'); end
vectors=round([w.kNonzero(:)*w.Lx/(2*pi),w.lNonzero(:)*w.Ly/(2*pi)]);
selected=[1 0;0 1;1 1];
if options.stateKind=="collinear", selected=[1 0]; end
[present,columns]=ismember(selected,vectors,'rows');
if ~all(present), error('WVStudy:InsufficientHorizontalBand','The manufactured state needs (1,0), (0,1), and (1,1).'); end
for j=1:numel(columns)
    col=columns(j); [~,p]=min(abs(data.inventory.magnitudes-w.khNonzero(col)));
    fields=qgStudyFields(data,p,"Q");
    scale=sqrt(sum(data.wQ.*(w.khNonzero(col)^2*abs(fields.psi).^2+data.profile.N2(data.zQ).*abs(fields.eta).^2),1)/c.Lz);
    amplitude=options.velocityScale./scale(:)./(1:n+2).';
    amplitude=amplitude.*exp(1i*(.37*(1:n+2).'+.61*j));
    switch options.stateKind
        case "apv", amplitude(n+1:end)=0;
        case "surface", amplitude([1:n,n+2])=0;
        case "bottom", amplitude(1:n+1)=0;
    end
    coeff=fields.canonicalScale.*amplitude;
    w.Ag_q(:,col)=orientation(:).*coeff(1:n); w.Ag_0(:,col)=coeff(n+1:end);
end
speedScale=options.velocityScale/w.uvMax; w.Ag_q=speedScale*w.Ag_q; w.Ag_0=speedScale*w.Ag_0;
modelConstructionSeconds=toc(timer); rhsTimer=tic; actual=w.coefficientTendency(); rhsSeconds=toc(rhsTimer);
canonical=[orientation(:).*w.Ag_q;w.Ag_0];
referenceTimer=tic; references=cell(1,3); work=cell(1,3);
for j=1:3
    sets=["R","Q","H"];
    [references{j},work{j}]=convolution(data,vectors,canonical,columns,sets(j));
end
referenceSeconds=toc(referenceTimer);
actualCanonical=[orientation(:).*actual.Ag_q;actual.Ag_0]; reference=references{2};
refEnergy=stateNorm(data,vectors,reference,"Q");
absoluteError=stateNorm(data,vectors,actualCanonical-reference,"Q");
refChange=max(stateNorm(data,vectors,references{1}-reference,"Q"),stateNorm(data,vectors,references{3}-reference,"Q"));
% A sum-of-term energy bound records cancellation and provides an explicit
% absolute reference budget without a denominator floor.
termScale=max(cellfun(@(x)x.termNormBound,work));
naturalScale=stateNorm(data,vectors,canonical,"Q")*w.uvMax*max(w.khNonzero);
relativeError=ratio(absoluteError,refEnergy);
referenceFraction=ratio(refChange,c.referenceAllowance*refEnergy+c.referenceAbsoluteAllowance*termScale);
qNumerator=0; qDenominator=0; bNumerator=zeros(2,1); bDenominator=bNumerator;
for col=1:size(vectors,1)
    [~,p]=min(abs(data.inventory.magnitudes-norm(vectors(col,:).*(2*pi./c.Lxy))));
    fields=qgStudyFields(data,p,"Q");
    a=actualCanonical(:,col)./fields.canonicalScale; r=reference(:,col)./fields.canonicalScale;
    qNumerator=qNumerator+sum(data.wQ.*abs(fields.q*(a-r)).^2); qDenominator=qDenominator+sum(data.wQ.*abs(fields.q*r).^2);
    bNumerator=bNumerator+abs(fields.b*(a-r)).^2; bDenominator=bDenominator+abs(fields.b*r).^2;
end
apvError=ratio(sqrt(qNumerator),sqrt(qDenominator)); endpointErrors=ratio(sqrt(bNumerator),sqrt(bDenominator)).';
referenceTendency=struct(Ag_q=orientation(:).*reference(1:n,:),Ag_0=reference(n+1:end,:),Amda=zeros(size(w.Amda)));
diagnostics=w.quadraticDiagnostics(tendency=[actual referenceTendency]);
result=struct(stateKind=options.stateKind,velocityScale=options.velocityScale,maximumVelocity=w.uvMax,energyNormRelativeError=relativeError,energyNormAbsoluteError=absoluteError,errorOverStateAdvectionScale=ratio(absoluteError,naturalScale),referenceEnergyNorm=refEnergy,referenceFraction=referenceFraction,apvRelativeError=apvError,endpointRelativeError=endpointErrors,cancellationRatio=ratio(refEnergy,termScale),meanSourceNorm=work{2}.meanSourceNorm,diagnostics=diagnostics,referenceWork=work{2},cost=struct(modelConstructionSeconds=modelConstructionSeconds,rhsSeconds=rhsSeconds,referenceSeconds=referenceSeconds),coverage="One manufactured state and instantaneous QG RHS; no trajectory or arbitrary-superposition guarantee");
end

function [coeff,work]=convolution(data,vectors,canonical,columns,setName)
c=data.config; n=c.apvCount; nz=numel(data.zQ); weights=data.wQ;
if setName=="R", nz=numel(data.zR); weights=data.wR; end
signedVectors=[vectors(columns,:);-vectors(columns,:)]; signedCoeff=[canonical(:,columns),conj(canonical(:,columns))];
fields=cell(1,size(signedVectors,1));
for j=1:numel(fields)
    [~,p]=min(abs(data.inventory.magnitudes-norm(signedVectors(j,:).*(2*pi./c.Lxy))));
    values=qgStudyFields(data,p,setName); a=signedCoeff(:,j)./values.canonicalScale;
    fields{j}=struct(psi=values.psi*a,q=values.q*a,b=values.b*a,psiEndpoint=values.psiEndpoint*a);
end
qdot=complex(zeros(nz,size(vectors,1))); bdot=complex(zeros(2,size(vectors,1))); meanQ=zeros(nz,1); meanB=zeros(2,1);
termNormBound=0;
for a=1:numel(fields)
    for b=1:numel(fields)
        output=signedVectors(a,:)+signedVectors(b,:); [present,col]=ismember(output,vectors,'rows');
        if ~present && any(output~=0), continue; end
        k1=signedVectors(a,:).*(2*pi./c.Lxy); k2=signedVectors(b,:).*(2*pi./c.Lxy);
        factor=k1(1)*k2(2)-k1(2)*k2(1);
        qterm=factor*fields{a}.psi.*fields{b}.q; bterm=factor*fields{a}.psiEndpoint.*fields{b}.b;
        if ~present, meanQ=meanQ+qterm; meanB=meanB+bterm; continue; end
        qdot(:,col)=qdot(:,col)+qterm; bdot(:,col)=bdot(:,col)+bterm;
        term=project(data,vectors(col,:),qterm,bterm,setName,weights);
        termNormBound=termNormBound+stateNorm(data,vectors(col,:),term,setName);
    end
end
coeff=complex(zeros(n+2,size(vectors,1)));
for col=1:size(vectors,1), coeff(:,col)=project(data,vectors(col,:),qdot(:,col),bdot(:,col),setName,weights); end
% Horizontal integration of q*q_t and b*b_t vanishes under incompressible
% advection. The direct convolution uses no WVM FFT/differentiation operator.
qWork=0; qWorkBound=0; endpointWork=zeros(2,1); endpointWorkBound=endpointWork;
for j=1:numel(columns)
    col=columns(j); q=fields{j}.q; b=fields{j}.b;
    qWork=qWork+2*real(sum(weights.*conj(q).*qdot(:,col)));
    qWorkBound=qWorkBound+2*sum(weights.*abs(q).*abs(qdot(:,col)));
    endpointWork=endpointWork+2*real(conj(b).*bdot(:,col));
    endpointWorkBound=endpointWorkBound+2*abs(b).*abs(bdot(:,col));
end
work=struct(termNormBound=termNormBound,meanSourceNorm=norm(meanQ)+norm(meanB),enstrophyWorkFraction=ratio(abs(qWork),qWorkBound),endpointWorkFraction=ratio(abs(endpointWork),endpointWorkBound));
end
function coeff=project(data,vector,q,b,setName,weights)
c=data.config; k=norm(vector.*(2*pi./c.Lxy)); [~,p]=min(abs(data.inventory.magnitudes-k));
F=data.apv.(setName).F; a=F'*(weights.*q)/c.Lz;
fields=qgStudyFields(data,p,setName);
coeff=[a;-(c.g/c.f)*k^2*(b-fields.apvEndpointResponse*a)];
end
function value=stateNorm(data,vectors,coeff,setName)
weights=data.wQ; z=data.zQ;
if setName=="R", weights=data.wR; z=data.zR; end
square=0;
for col=1:size(vectors,1)
    k=norm(vectors(col,:).*(2*pi./data.config.Lxy)); [~,p]=min(abs(data.inventory.magnitudes-k));
    fields=qgStudyFields(data,p,setName); a=coeff(:,col)./fields.canonicalScale;
    psi=fields.psi*a; eta=fields.eta*a; surface=fields.psiEndpoint(1,:)*a;
    square=square+sum(weights.*(k^2*abs(psi).^2+data.profile.N2(z).*abs(eta).^2))+(data.config.f^2/data.config.g)*abs(surface)^2;
end
value=sqrt(real(square));
end
function value=ratio(a,b)
value=a./b; value(a==0 & b==0)=0;
end
