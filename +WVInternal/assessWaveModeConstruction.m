function [assessment,reference,convergence] = assessWaveModeConstruction(state,bases,activePages,referenceNEVP,tolerance,dealiasingOptions)
% Compare the actual constructed wave bases with an explicitly requested solve.
% Zero-count pages contain no tested waves. A full passing prefix reaches
% the candidate ceiling; it is not a measured maximum available mode count.
arguments (Input)
    state (1,1) struct
    bases (1,1) IMBasisCollection
    activePages (:,1) double
    referenceNEVP (:,1) double
    tolerance (1,1) double
    dealiasingOptions (1,1) struct = struct(quadraticDealiasing="none",retainedFraction=2/3,energyFraction=.99,bandwidthFraction=2/3)
end
np=length(state.khUnique);
kappa=state.khUnique;
requestedCount=state.waveModeCountByKh;
convergedCount=nan(np,1); gridSupportedCount=zeros(np,1); usableCount=nan(np,1);
status=repmat("reference-not-requested",np,1);
candidateLimitReached=false(np,1);
modeConvergence=cell(np,1); prefixGramError=cell(np,1);
modeSummary=cell(np,1); dealiasing=cell(np,1);
reference=[];
reports={};
dealiasingReports={};
quadraticDealiasingSeconds=0;
gridRule="wkb";
if isfield(dealiasingOptions,"dealiasingGrid")
    gridRule=dealiasingOptions.dealiasingGrid.kind;
end
zFilter=[];
if ~isempty(referenceNEVP)
    inertialBasis=bases.bases{bases.basisIndex(1)};
    reportKappa=[0 state.khUnique(activePages).'];
    counts=[length(state.inertialMode) requestedCount(activePages).'];
    solver=IMSolverSpectral(nEVP=referenceNEVP,coordinateKind="wkb");
    reference=solver.solveWaveModesAtWavenumbers(inertialBasis.evp.background,reportKappa,nModes=counts,normalization="waveEnergy");
    % Convergence compares physical fields with a fine WKB quadrature.
    nQuadrature=2*max(state.nEVP,referenceNEVP)+1;
    rule=IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(inertialBasis.evp);
    [z,w]=rule.nativeQuadratureRule(inertialBasis.zDomain);
    if gridRule~="wkb" && dealiasingOptions.quadraticDealiasing=="effectiveBandwidth"
        zFilter=dealiasingOptions.dealiasingGrid.calculus.lobattoRule(nQuadrature);
    end
    pages=1:(numel(activePages)+1);
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
    dealiasing{p}=dealiasingReports{page};
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
    inertial.dealiasing=dealiasingReports{1};
    inertialSummary=WVInternal.summarizeModeConvergence(inertial.convergence,count,tolerance);
    inertial.convergedCount=inertialSummary.acceptedCount;
    complete=inertialSummary.complete;
    if complete, inertial.usableCount=min(inertial.convergedCount,inertial.gridSupportedCount); end
else
    inertialSummary=[];
end
assessment=struct(pages=table(kappa,requestedCount,convergedCount,gridSupportedCount,usableCount,status,candidateLimitReached,dealiasing),modeConvergence={modeConvergence},prefixGramError={prefixGramError},inertial=inertial,modeConvergenceTolerance=tolerance,gramTolerance=state.gramTolerance,nEVP=state.nEVP,referenceNEVP=referenceNEVP,comparisonQuadratureCoordinateKind="wkb",quadraticDealiasingSeconds=quadraticDealiasingSeconds,coverage="Convergence compares the constructed and reference modes at every supported kappa. Gram checks use the evolution grid. Effective bandwidth measures the constructed modes in the evolution coordinate. Two-resolution agreement is not a rigorous error bound.");
convergence=struct(pages={modeSummary},inertial=inertialSummary);

    function acceptPrepared(candidate,refined,positions,candidatePages,~)
        for iPosition=1:numel(positions)
            reports{positions(iPosition)}=assessModeConvergence(candidate{iPosition},refined{iPosition},z,w);
            timer=tic;
            values=candidate{iPosition}.values;
            if ~isempty(zFilter)
                basis=bases.bases{bases.basisIndex(candidatePages(iPosition))};
                values=struct(F=basis.F(zFilter),G=basis.G(zFilter));
            end
            dealiasingReports{positions(iPosition)}=WVInternal.quadraticDealiasingPrefix( ...
                values.F,values.G,state.Nxyz(3)-1,dealiasingOptions,gridRule);
            quadraticDealiasingSeconds=quadraticDealiasingSeconds+toc(timer);
        end
    end
end
