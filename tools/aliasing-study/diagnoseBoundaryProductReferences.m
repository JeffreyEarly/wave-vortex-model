function result = diagnoseBoundaryProductReferences(data,interactionIndex,channelName)
% Isolate four boundary products against an independent analytical solution.
%
% Diagnostic only: preserve the resolved numerical modes and existing gates.
% The quadrature-node factor bound ||a||_inf ||b||_L2 measures product scale;
% it is reported for interpretation and does not replace any error norm.
arguments (Input)
    data (1,1) struct
    interactionIndex (1,1) double {mustBeInteger,mustBePositive}
    channelName (1,1) string
end
arguments (Output)
    result (1,1) struct
end
config=data.config; channels=WVInternal.sourceChannelInventory(); channel=channels(channels.name==channelName,:);
if height(channel)~=1 || ~ismember(channel.factor,["x","y"])
    error('WVStudy:UnsupportedDiagnosticChannel','Choose one horizontal boundary-advection channel from sourceChannelInventory.');
end
switch string(config.profile)
    case "exponential-surface"
        solution=IMExponentialStratificationSolution(N0=.01,b=.4*config.Lz,zDomain=[-config.Lz 0],f0=config.f,g=config.g);
    case "constant"
        solution=IMConstantStratificationSolution(N0=.01,zDomain=[-config.Lz 0],f0=config.f,g=config.g);
    otherwise
        error('WVStudy:UnsupportedDiagnosticProfile','Use the constant or exponential-surface analytical control.');
end
row=data.inventory.interactions(interactionIndex,:); vectors=reshape(table2array(row(:,1:6)),2,3).';
[~,indices]=ismember(vectors,data.inventory.vectors,'rows');
a=WVInternal.sourceStudyFields(data,"boundary",indices(1)); b=WVInternal.sourceStudyFields(data,"boundary",indices(2));
[i,j]=ndgrid(1:2,1:2); i=i(:).'; j=j(:).'; products=struct();
kl=data.inventory.physicalVectors(indices(2),:);
if channel.factor=="x", multiplier=1i*kl(1); else, multiplier=1i*kl(2); end
for name=["S","R","Q","E","H","J"]
    products.(name)=-a.(name).(channel.advecting)(:,i).*(multiplier*b.(name).(channel.advected)(:,j));
end
[context,counts,target]=WVInternal.sourceProjectionContext(data,indices(3),channel.advected,"Q");
assert(target=="wave",'This diagnostic uses a nonzero wave output.');
lowContext=WVInternal.sourceProjectionContext(data,indices(3),channel.advected,"R");
highContext=WVInternal.sourceProjectionContext(data,indices(3),channel.advected,"H");
low=WVInternal.measureProductProjection(lowContext,products.S,products.R,zeros(2,4),counts);
high=WVInternal.measureProductProjection(context,products.S,products.Q,zeros(2,4),counts);
independent=WVInternal.measureProductProjection(highContext,zeros(size(products.S)),products.H,zeros(2,4),counts);
exactA=exactField(solution,data,indices(1),channel.advecting,data.zQ);
exactB=multiplier*exactField(solution,data,indices(2),channel.advected,data.zQ);
exactProduct=-exactA(:,i).*exactB(:,j);
weights=context.volumeWeights;
qNorm=weightedNorm(products.Q,weights); hNorm=weightedNorm(products.H,weights); exactNorm=weightedNorm(exactProduct,weights);
factorBound=max(abs(exactA(:,i)),[],1).*weightedNorm(exactB(:,j),weights);
absoluteChange=weightedNorm(products.Q-products.H,weights);
absoluteExactError=weightedNorm(products.Q-exactProduct,weights);
normalizationChange=abs(qNorm./hNorm-1);
quadratureNormalizationChange=abs(sqrt(low.productNormSquared./high.productNormSquared)-1);
coefficientChange=IMProjection.relativeCoefficientNorm(high.referenceCoefficients{end}-independent.referenceCoefficients{end},context.majorantGram,independent.productNormSquared);
quadratureCoefficientChange=IMProjection.relativeCoefficientNorm(low.referenceCoefficients{end}-high.referenceCoefficients{end},context.majorantGram,high.productNormSquared);
endpointNames=["surface","bottom"];
rows=table(endpointNames(i).',endpointNames(j).',qNorm.',hNorm.',exactNorm.',factorBound.',absoluteChange.',absoluteExactError.',(absoluteExactError./factorBound).',normalizationChange.',coefficientChange.',quadratureNormalizationChange.',quadratureCoefficientChange.',high.error(end,:).', ...
    VariableNames=["endpointA","endpointB","candidateProductNorm","independentProductNorm","analyticalProductNorm","factorBound","absoluteRefinementChange","absoluteAnalyticalError","analyticalErrorOverFactorBound","normalizationChange","coefficientChange","quadratureNormalizationChange","quadratureCoefficientChange","sampledError"]);
fieldErrors=zeros(2,2);
for variableIndex=1:2
    variable=["F","G"]; variable=variable(variableIndex);
    for input=1:2
        kh=norm(data.inventory.physicalVectors(indices(input),:)); [~,page]=min(abs(data.inventory.magnitudes-kh));
        [referenceF,referenceG]=referenceBoundaryValues(solution,kh,data.zQ);
        if variable=="F", reference=referenceF; else, reference=referenceG; end
        fieldErrors(input,variableIndex)=max(weightedNorm(data.boundary{page}.Q.(variable)-reference,data.wQ)./weightedNorm(reference,data.wQ));
    end
end
result=struct(rows=rows,interactionIndex=interactionIndex,channel=channelName,vectors=vectors,configuration=config,referenceStability=WVInternal.compareProductReferences(context,low,high,counts),eigenProductStability=WVInternal.compareProductReferences(context,high,independent,counts),targetGramReciprocalCondition=rcond(context.targetGram),fieldRelativeErrors=fieldErrors,z=data.zQ,candidateProducts=products.Q,independentProducts=products.H,analyticalProducts=exactProduct,interpretation="Unchanged product-relative gates; analytical/factor-scaled quantities diagnose causes only");
end

function values=exactField(solution,data,index,variable,z)
kl=data.inventory.physicalVectors(index,:); [F,G]=referenceBoundaryValues(solution,norm(kl),z);
switch variable
    case "u", values=-1i*kl(2)*F;
    case "v", values=1i*kl(1)*F;
    case "eta", values=(data.config.f/data.config.g)*G;
    otherwise, error('WVStudy:UnsupportedDiagnosticField','Choose u, v or eta.');
end
end

function values=weightedNorm(columns,weights)
% Scale before squaring so physically tiny analytical tails do not underflow.
scale=max(abs(columns),[],1); values=zeros(size(scale)); active=scale>0;
values(active)=scale(active).*sqrt(sum(weights.*abs(columns(:,active)./scale(active)).^2,1));
end

function [F,G]=referenceBoundaryValues(solution,k,z)
if isa(solution,'IMConstantStratificationSolution')
    % Independent localized exponentials avoid subtraction of cosh/sinh tails.
    % For F=a*exp(m*(z-top))+b*exp(-m*(z-bottom)), G=-g*Fz/N0^2.
    m=k*solution.N0/abs(solution.f0); c=solution.g*m/solution.N0^2;
    transmission=exp(-m*diff(solution.zDomain));
    responses=[-(c+1),(c-1)*transmission;-c*transmission,c];
    coefficients=responses\eye(2);
    upward=exp(m*(z-solution.zDomain(2))); downward=exp(-m*(z-solution.zDomain(1)));
    F=[upward downward]*coefficients;
    G=c*[-upward downward]*coefficients;
else
    exact=solution.geostrophicZeroAPVModesAtWavenumber(k,endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
    F=exact.F(z); G=exact.G(z);
end
end
