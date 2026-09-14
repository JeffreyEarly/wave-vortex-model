function [assessment,reference,convergence] = assessWaveModeConstruction(state,bases,activePages,referenceNEVP,tolerance)
% Compare the actual constructed wave bases with an explicitly requested solve.
% Zero-count pages contain no tested waves. A full passing prefix reaches
% the candidate ceiling; it is not a measured maximum available mode count.
arguments (Input)
    state (1,1) struct
    bases (1,1) IMBasisCollection
    activePages (:,1) double
    referenceNEVP (:,1) double
    tolerance (1,1) double
end
np=length(state.khUnique);
kappa=state.khUnique;
requestedCount=state.waveModeCountByKh;
convergedCount=nan(np,1); gridSupportedCount=zeros(np,1); usableCount=nan(np,1);
status=repmat("reference-not-requested",np,1);
candidateLimitReached=false(np,1);
modeConvergence=cell(np,1); prefixGramError=cell(np,1);
modeSummary=cell(np,1);
reference=[];
reports={};
if ~isempty(referenceNEVP)
    f=2*state.rotationRate*sind(state.latitude);
    reference=IMSolverSpectral(nEVP=referenceNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers([0 state.khUnique(activePages).'],N2=state.N2Function,zDomain=[-state.Lxyz(3) 0],f0=f,g=state.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=requestedCount(activePages).',nInertialModes=length(state.inertialMode));
    % All wave and inertial pages share N2 and zDomain, hence WKB quadrature.
    nQuadrature=2*max(state.nEVP,referenceNEVP)+1;
    inertialBasis=bases.bases{bases.basisIndex(1)};
    rule=IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(inertialBasis.evp);
    [z,w]=rule.nativeQuadratureRule(inertialBasis.zDomain);
    pages=1:(numel(activePages)+1);
    reportKappa=[0 state.khUnique(activePages).'];
    reports=cell(size(pages));
    WVInternal.prepareWaveModeConvergenceBatches(bases,reference,z,reportKappa,@acceptPrepared, ...
        candidatePages=pages,referencePages=pages,candidateNEVP=state.nEVP,referenceNEVP=referenceNEVP,nQuadrature=nQuadrature);
end
for p=1:np
    count=requestedCount(p);
    if count==0
        convergedCount(p)=0; usableCount(p)=0; status(p)="not-requested";
        prefixGramError{p}=zeros(0,1);
        continue
    end
    G=state.waveG(:,1:count,p);
    gram=state.waveGForward(1:count,:,p)*G;
    errors=zeros(count,1);
    for n=1:count, errors(n)=norm(gram(1:n,1:n)-eye(n),2); end
    prefixGramError{p}=errors;
    gridSupportedCount(p)=sum(cumprod(errors<=state.gramTolerance));
    if isempty(reference), continue; end
    page=find(activePages==p)+1;
    report=reports{page}; modeConvergence{p}=report;
    modeSummary{p}=WVInternal.summarizeModeConvergence(report,count,tolerance);
    convergedCount(p)=modeSummary{p}.acceptedCount;
    complete=modeSummary{p}.complete;
    usableCount(p)=min(convergedCount(p),gridSupportedCount(p));
    if ~complete
        status(p)="reference-inconclusive"; usableCount(p)=NaN;
    elseif usableCount(p)==count
        status(p)="accepted"; candidateLimitReached(p)=true;
    else
        status(p)="rejected";
    end
end
count=length(state.inertialMode);
gram=state.inertialFForward*state.inertialF;
errors=zeros(count,1);
for n=1:count, errors(n)=norm(gram(1:n,1:n)-eye(n),2); end
inertial=struct(requestedCount=count,gramError=state.inertialGramError,prefixGramError=errors,gridSupportedCount=sum(cumprod(errors<=state.gramTolerance)),convergence=[],convergedCount=NaN,usableCount=NaN);
if ~isempty(reference)
    inertial.convergence=reports{1};
    inertialSummary=WVInternal.summarizeModeConvergence(inertial.convergence,count,tolerance);
    inertial.convergedCount=inertialSummary.acceptedCount;
    complete=inertialSummary.complete;
    if complete, inertial.usableCount=min(inertial.convergedCount,inertial.gridSupportedCount); end
else
    inertialSummary=[];
end
assessment=struct(pages=table(kappa,requestedCount,convergedCount,gridSupportedCount,usableCount,status,candidateLimitReached),modeConvergence={modeConvergence},prefixGramError={prefixGramError},inertial=inertial,modeConvergenceTolerance=tolerance,gramTolerance=state.gramTolerance,nEVP=state.nEVP,referenceNEVP=referenceNEVP,coverage="Actual constructed modes at every supported kappa; linear convergence and fixed-grid Gram evidence only. Quadratic products are assessed separately. Two-resolution agreement is not a rigorous error bound.");
convergence=struct(pages={modeSummary},inertial=inertialSummary);

    function acceptPrepared(candidate,refined,positions,~,~)
        for iPosition=1:numel(positions)
            reports{positions(iPosition)}=assessModeConvergence(candidate{iPosition},refined{iPosition},z,w);
        end
    end
end
