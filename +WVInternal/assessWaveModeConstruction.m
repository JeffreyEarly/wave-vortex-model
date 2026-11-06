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
candidateCount=requestedCount;
modeConvergence=cell(np,1); prefixGramError=cell(np,1);
modeSummary=cell(np,1); dealiasing=cell(np,1);
candidateLabels=repmat({zeros(0,1)},np,1);
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
    dealiasingReports=cell(size(pages));
    WVInternal.prepareWaveModeConvergenceBatches(bases,reference,z,reportKappa,@acceptPrepared, ...
        candidatePages=pages,referencePages=pages,candidateNEVP=state.nEVP,referenceNEVP=referenceNEVP,nQuadrature=nQuadrature);
end
qualifications=repmat(qualifyPrefix([],0,0,tolerance),np,1);
for p=1:np
    count=candidateCount(p);
    if count==0
        prefixGramError{p}=zeros(0,1);
        continue
    end
    if ~isempty(reference)
        page=find(activePages==p)+1;
        modeConvergence{p}=reports{page};
        candidateLabels{p}=bases.bases{bases.basisIndex(page)}.modeNumber(:);
        dealiasing{p}=dealiasingReports{page};
    end
    G=state.waveG(:,1:count,p);
    errors=prefixErrors(state.waveGForward(1:count,:,p)*G);
    prefixGramError{p}=errors;
    % The full Gram survey informs retries. Qualification uses its converged head.
    rawGridCount=sum(cumprod(errors<=state.gramTolerance));
    [qualifications(p),modeSummary{p}]=qualifyPrefix(modeConvergence{p},rawGridCount,count,tolerance);
end
count=length(state.inertialMode);
errors=prefixErrors(state.inertialFProjection*state.inertialF);
inertialConvergence=[];
inertialDealiasing=[];
inertialLabels=zeros(0,1);
if ~isempty(reference)
    inertialConvergence=reports{1};
    inertialDealiasing=dealiasingReports{1};
    inertialLabels=inertialBasis.modeNumber(:);
end
[inertial,inertialSummary]=qualifyPrefix(inertialConvergence,sum(cumprod(errors<=state.gramTolerance)),count,tolerance);
inertial.requestedCount=count;
inertial.candidateCount=count;
inertial.candidateLabels=inertialLabels;
inertial.gramError=errors(end);
inertial.prefixGramError=errors;
inertial.convergence=inertialConvergence;
inertial.dealiasing=inertialDealiasing;
pages=[table(kappa,requestedCount,candidateCount,candidateLabels,dealiasing) struct2table(qualifications,AsArray=true)];
assessment=struct(pages=pages,modeConvergence={modeConvergence},prefixGramError={prefixGramError},inertial=inertial, ...
    modeConvergenceTolerance=tolerance,gramTolerance=state.gramTolerance,nEVP=state.nEVP,referenceNEVP=referenceNEVP, ...
    comparisonQuadratureCoordinateKind="wkb",quadraticDealiasingSeconds=quadraticDealiasingSeconds, ...
    coverage="The fixed-grid qualification uses the independently converged prefix. Raw candidate Gram diagnostics also guide EVP refinement. Two-resolution agreement is not a rigorous error bound.");
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

function [record,summary]=qualifyPrefix(report,rawGridCount,count,tolerance)
record=struct(convergenceAssessedCount=0,convergedCount=NaN,gridSupportedCount=rawGridCount,gridAssessedCount=0, ...
    fixedGridCount=0,usableCount=NaN,status="reference-not-requested",candidateLimitReached=false, ...
    firstUnassessedCount=NaN,linearCoverage="reference-not-requested",linearLimitingMetric="independent-reference",limitingLabel=NaN);
summary=[];
if count==0
    record.convergedCount=0;
    record.usableCount=0;
    record.status="not-requested";
    record.linearCoverage="not-requested";
    record.linearLimitingMetric="not-requested";
    return
end
if isempty(report)
    record.firstUnassessedCount=1;
    return
end
summary=WVInternal.summarizeModeConvergence(report,count,tolerance);
record.convergenceAssessedCount=nnz(summary.measured);
record.convergedCount=summary.acceptedCount;
record.gridAssessedCount=summary.acceptedCount;
record.fixedGridCount=min(rawGridCount,summary.acceptedCount);
record.usableCount=record.fixedGridCount;
record.status="rejected";
record.linearCoverage="measured-cutoff";
if record.fixedGridCount<count
    record.limitingLabel=str2double(report.identity.columnLabels(record.fixedGridCount+1));
end
if rawGridCount<summary.acceptedCount
    record.linearLimitingMetric="gram";
elseif summary.acceptedCount==count
    record.status="accepted";
    record.candidateLimitReached=true;
    record.firstUnassessedCount=count+1;
    record.linearCoverage="candidate-ceiling";
    record.linearLimitingMetric="candidate-ceiling";
elseif summary.measured(summary.acceptedCount+1)
    record.linearLimitingMetric="mode-convergence";
else
    record.status="reference-inconclusive";
    record.usableCount=NaN;
    record.firstUnassessedCount=summary.acceptedCount+1;
    record.linearCoverage="reference-inconclusive";
end
end

function errors=prefixErrors(gram)
errors=zeros(size(gram,1),1);
for n=1:numel(errors)
    errors(n)=norm(gram(1:n,1:n)-eye(n),2);
end
end
