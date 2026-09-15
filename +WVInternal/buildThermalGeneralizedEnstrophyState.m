function state = buildThermalGeneralizedEnstrophyState(w,boundaryWeightMultiplier)
% Assemble the native thermal energy/generalized-enstrophy coordinate state.
% Construction works one horizontal radius at a time and retains only the
% fine-quadrature polynomial eigenbasis, dual, spectrum and compact evidence.
arguments (Input)
    w (1,1) WVTransformFreeSurfaceThermalQG
    boundaryWeightMultiplier (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1
end
n=w.thermalModeCount;
qCoarse=max(w.assemblyQuadratureCount,2*n+1);
qFine=2*qCoarse;
if w.inverseScale==0
    effectiveBoundaryDepth=w.Lz/4;
else
    effectiveBoundaryDepth=tanh(w.inverseScale*w.Lz/2)/(2*w.inverseScale);
end
boundaryWeights=boundaryWeightMultiplier*(w.f^2/effectiveBoundaryDepth)*ones(2,1);
pCount=numel(w.khUnique);
polynomialEigenvectors=zeros(n,n,pCount);
polynomialDuals=zeros(n,n,pCount);
generalizedEigenvalues=zeros(n,pCount);
singularValueUncertainty=zeros(n,pCount);
eigenvalueUncertainty=zeros(n,pCount);
clusterUpperOrdinal=zeros(n,pCount);
eigenvalueNormalization=zeros(pCount,1);
energyFormDrift=zeros(pCount,1);
generalizedFormDrift=zeros(pCount,1);
generalizedOperatorDrift=zeros(pCount,1);
energyOrthogonalityResidual=zeros(pCount,1);
generalizedDiagonalizationResidual=zeros(pCount,1);
factorizationResidual=zeros(pCount,1);
energyFactorReciprocalCondition=zeros(pCount,1);
for p=1:pCount
    kh=w.khUnique(p);
    [energyCoarse,generalizedCoarse]=physicalFactors(w,kh,boundaryWeights,qCoarse);
    [energyFine,generalizedFine]=physicalFactors(w,kh,boundaryWeights,qFine);
    page=WVInternal.thermalGeneralizedEnstrophyFactors(energyCoarse,generalizedCoarse,energyFine,generalizedFine,kh);
    polynomialEigenvectors(:,:,p)=page.polynomialEigenvectors;
    polynomialDuals(:,:,p)=page.polynomialDuals;
    generalizedEigenvalues(:,p)=page.generalizedEigenvalues;
    singularValueUncertainty(:,p)=page.singularValueUncertainty;
    eigenvalueUncertainty(:,p)=page.eigenvalueUncertainty;
    clusterUpperOrdinal(:,p)=page.clusterUpperOrdinal;
    eigenvalueNormalization(p)=page.eigenvalueNormalization;
    energyFormDrift(p)=page.energyFormDrift;
    generalizedFormDrift(p)=page.generalizedFormDrift;
    generalizedOperatorDrift(p)=page.generalizedOperatorDrift;
    energyOrthogonalityResidual(p)=page.energyOrthogonalityResidual;
    generalizedDiagonalizationResidual(p)=page.generalizedDiagonalizationResidual;
    factorizationResidual(p)=page.factorizationResidual;
    energyFactorReciprocalCondition(p)=page.energyFactorReciprocalCondition;
end
state=struct(schemaVersion=1,generalizedPolynomialDegree=(0:n-1)',generalizedDirection=(1:n)',generalizedRadius=w.khUnique(:),generalizedEndpoint=[1;2],generalizedHorizontalAxis=[1;2], ...
    sourceN20=w.N20,sourceInverseScale=w.inverseScale,sourceDepth=w.Lz,sourceLatitude=w.latitude,sourceCoriolis=w.f,sourceGravity=w.g,sourceHorizontalDomain=[w.Lx;w.Ly], ...
    boundaryWeightMultiplier=boundaryWeightMultiplier,effectiveBoundaryDepth=effectiveBoundaryDepth,boundaryWeights=boundaryWeights, ...
    constructionQuadratureCount=qFine,polynomialEigenvectors=polynomialEigenvectors,polynomialDuals=polynomialDuals, ...
    generalizedEigenvalues=generalizedEigenvalues,singularValueUncertainty=singularValueUncertainty,eigenvalueUncertainty=eigenvalueUncertainty, ...
    clusterUpperOrdinal=clusterUpperOrdinal,eigenvalueNormalization=eigenvalueNormalization,energyFormDrift=energyFormDrift, ...
    generalizedFormDrift=generalizedFormDrift,generalizedOperatorDrift=generalizedOperatorDrift, ...
    energyOrthogonalityResidual=energyOrthogonalityResidual,generalizedDiagonalizationResidual=generalizedDiagonalizationResidual, ...
    factorizationResidual=factorizationResidual, ...
    energyFactorReciprocalCondition=energyFactorReciprocalCondition);
end

function [energy,generalized]=physicalFactors(w,kh,boundaryWeights,count)
[x,weights]=legpts(count);
z=w.Lz*(x-1)/2;
weights=weights(:)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
endpoint=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
N2=w.N20*exp(2*w.inverseScale*z);
energy=[sqrt(weights)*kh.*r.psi;sqrt(weights.*N2).*r.eta;sqrt(w.g)*r.ssh];
q=r.qgpv-kh^2*r.psi;
generalized=[sqrt(weights).*q;sqrt(boundaryWeights).*endpoint.eta_i];
end
