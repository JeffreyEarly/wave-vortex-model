function page=thermalGeneralizedEnstrophyFactors(energyCoarse,generalizedCoarse,energyFine,generalizedFine,kh)
% Solve and qualify one native generalized-enstrophy radius page.
% Inputs are physical energy and generalized-enstrophy row factors at the
% prescribed coarse and fine quadratures in common polynomial coordinates.
arguments (Input)
    energyCoarse double {mustBeReal,mustBeFinite}
    generalizedCoarse double {mustBeReal,mustBeFinite}
    energyFine double {mustBeReal,mustBeFinite}
    generalizedFine double {mustBeReal,mustBeFinite}
    kh (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 0
end
n=size(energyFine,2);
if n==0 || size(energyCoarse,2)~=n || size(generalizedCoarse,2)~=n || size(generalizedFine,2)~=n || ...
        size(energyCoarse,1)<n || size(energyFine,1)<n || size(generalizedCoarse,1)<n || size(generalizedFine,1)<n
    error('WV:ThermalGeneralizedEnstrophyShape','All physical factors must have the same nonzero polynomial width and enough rows.');
end
[~,RCoarse]=qr(energyCoarse,0); [~,RFine]=qr(energyFine,0);
energyFactorReciprocalCondition=min(rcond(RCoarse),rcond(RFine));
if energyFactorReciprocalCondition<eps
    error('WV:ThermalGeneralizedEnstrophyEnergy','The physical energy factor is numerically singular at radius %.16g.',kh);
end
ACoarse=generalizedCoarse/RCoarse; AFine=generalizedFine/RFine;
[UCoarse,SCoarse,WCoarse]=svd(ACoarse,'econ');
[UFine,SFine,WFine]=svd(AFine,'econ');
[sigmaCoarse,UCoarse,WCoarse]=ascendingSVD(SCoarse,UCoarse,WCoarse); %#ok<ASGLU>
[sigmaFine,UFine,WFine]=ascendingSVD(SFine,UFine,WFine);
[UFine,WFine]=canonicalizeSigns(UFine,WFine);
rows=size(AFine,1); gamma=(rows+n)*eps/(1-(rows+n)*eps);
etaFactor=norm(AFine-UFine*diag(sigmaFine)*WFine',2)+norm(AFine,2)*(norm(UFine'*UFine-eye(n),2)+norm(WFine'*WFine-eye(n),2)+gamma);
delta=zeros(n,1);
for j=1:n
    leftResidual=AFine*WFine(:,j)-sigmaFine(j)*UFine(:,j);
    rightResidual=AFine'*UFine(:,j)-sigmaFine(j)*WFine(:,j);
    delta(j)=hypot(norm(leftResidual),norm(rightResidual))/sqrt(2);
end
uncertainty=max(etaFactor,delta)+abs(sigmaFine-sigmaCoarse);
lower=sigmaFine-uncertainty;
if any(~isfinite(uncertainty)) || any(lower<=0)
    error('WV:ThermalGeneralizedEnstrophySpectrum','The generalized spectrum is not positively resolved at radius %.16g.',kh);
end
lambda=sigmaFine.^2;
upperOrdinal=connectedClusters(lower,sigmaFine+uncertainty,lambda,kh);
V=RFine\WFine; P=WFine'*RFine;
normalizedEnergyCoarse=energyCoarse/RFine; normalizedEnergyFine=energyFine/RFine;
normalizedGeneralizedCoarse=generalizedCoarse/RFine; normalizedGeneralizedFine=generalizedFine/RFine;
energyFormDrift=relativeDifference(normalizedEnergyCoarse'*normalizedEnergyCoarse,normalizedEnergyFine'*normalizedEnergyFine);
generalizedFormDrift=relativeDifference(normalizedGeneralizedCoarse'*normalizedGeneralizedCoarse,normalizedGeneralizedFine'*normalizedGeneralizedFine);
coarseMap=RFine/RCoarse;
coarseOperator=coarseMap*(ACoarse'*ACoarse)/coarseMap;
fineOperator=AFine'*AFine;
generalizedOperatorDrift=relativeDifference(coarseOperator,fineOperator);
energyOrthogonalityResidual=max(norm((energyFine*V)'*(energyFine*V)-eye(n),2),norm(P*V-eye(n),2));
generalizedDiagonalizationResidual=norm((generalizedFine*V)'*(generalizedFine*V)-diag(lambda),2)/max(lambda(end),realmin);
factorizationResidual=etaFactor/max(norm(AFine,2),realmin);
if max([energyFormDrift,generalizedFormDrift,generalizedOperatorDrift,energyOrthogonalityResidual,generalizedDiagonalizationResidual,factorizationResidual])>1e-8
    error('WV:ThermalGeneralizedEnstrophyConvergence','Radius %.16g failed the 1e-8 energy-normalized construction gate.',kh);
end
page=struct(polynomialEigenvectors=real(V),polynomialDuals=real(P),generalizedEigenvalues=lambda, ...
    singularValueUncertainty=uncertainty,eigenvalueUncertainty=2*sigmaFine.*uncertainty+uncertainty.^2, ...
    clusterUpperOrdinal=upperOrdinal,eigenvalueNormalization=lambda(end),energyFormDrift=energyFormDrift, ...
    generalizedFormDrift=generalizedFormDrift,generalizedOperatorDrift=generalizedOperatorDrift, ...
    energyOrthogonalityResidual=energyOrthogonalityResidual,generalizedDiagonalizationResidual=generalizedDiagonalizationResidual, ...
    factorizationResidual=factorizationResidual, ...
    energyFactorReciprocalCondition=energyFactorReciprocalCondition);
end

function value=relativeDifference(a,b)
value=norm(b-a,2)/max(norm(b,2),realmin);
end

function [sigma,U,W]=ascendingSVD(S,U,W)
sigma=diag(S); [sigma,index]=sort(sigma,'ascend'); U=U(:,index); W=W(:,index);
end

function [U,W]=canonicalizeSigns(U,W)
for j=1:size(W,2)
    [~,index]=max(abs(W(:,j)));
    if W(index,j)<0, W(:,j)=-W(:,j); U(:,j)=-U(:,j); end
end
end

function upperOrdinal=connectedClusters(lower,upper,lambda,kh)
n=numel(lambda); upperOrdinal=zeros(n,1); first=1; right=upper(1);
for j=2:n+1
    if j<=n && lower(j)<=right, right=max(right,upper(j)); continue; end
    last=j-1; lambdaA=lambda(first); lambdaB=lambda(last);
    if last>first && (lambdaB-lambdaA)/lambdaB>1e-8
        error('WV:ThermalGeneralizedEnstrophyCluster','The uncertainty-connected cluster %d:%d at radius %.16g spans more than 1e-8 in lambda.',first,last,kh);
    end
    upperOrdinal(first:last)=last;
    if j<=n, first=j; right=upper(j); end
end
end
