function [state,assessment] = selectFreeSurfaceWaveCounts(state,~,~,~,~,~,assessment,convergence,options,autoWave,autoInertial)
% Apply one vertical quadratic-dealiasing policy after independent linear checks.
np=height(assessment.pages);
linearCount=assessment.pages.usableCount;
filteringCount=zeros(np,1);
selectedCount=zeros(np,1);
for p=1:np
    report=limitReport(assessment.pages.dealiasing{p},linearCount(p),options);
    filteringCount(p)=report.filteringCount;
    requested=assessment.pages.requestedCount(p);
    if ~autoWave && requested>filteringCount(p)
        error('WV:QuadraticDealiasingWaveCountRejected', ...
            'The explicit wave count %d at kappa %.17g exceeds the quadratic-dealiasing limit %d under policy %s.', ...
            requested,assessment.pages.kappa(p),filteringCount(p),options.quadraticDealiasing)
    end
    if autoWave
        selectedCount(p)=filteringCount(p);
    else
        selectedCount(p)=requested;
    end
    report.selectedCount=selectedCount(p);
    assessment.pages.dealiasing{p}=report;
end

inertialReport=limitReport(assessment.inertial.dealiasing,assessment.inertial.usableCount,options);
requestedInertial=assessment.inertial.requestedCount;
if ~autoInertial && requestedInertial>inertialReport.filteringCount
    error('WV:QuadraticDealiasingInertialCountRejected', ...
        'The explicit inertial count %d exceeds the quadratic-dealiasing limit %d under policy %s.', ...
        requestedInertial,inertialReport.filteringCount,options.quadraticDealiasing)
end
if autoInertial
    inertialCount=inertialReport.filteringCount;
else
    inertialCount=requestedInertial;
end
if inertialCount<1
    error('WV:NoResolvedInertialModes', ...
        'No inertial mode passes the linear and quadratic-dealiasing limits. Increase Nz/nEVP or change quadraticDealiasing.')
end
inertialReport.selectedCount=inertialCount;

assessment.pages.linearCount=linearCount;
assessment.pages.filteringCount=filteringCount;
assessment.pages.selectedCount=selectedCount;
assessment.pages.status=repmat("accepted",np,1);
explicitZero=~autoWave & assessment.pages.requestedCount==0;
filteredOut=autoWave & selectedCount==0 & filteringCount<linearCount;
assessment.pages.status(explicitZero)="not-requested";
assessment.pages.status(filteredOut)="filtered-out";
assessment.pages.status(selectedCount==0 & ~explicitZero & ~filteredOut)="rejected";
assessment.modeConvergence(explicitZero)=repmat({[]},nnz(explicitZero),1);
assessment.pages.candidateLimitReached=linearCount==assessment.pages.candidateCount & linearCount>0;
assessment.pages.limitingMetric=repmat("candidate-ceiling",np,1);
assessment.pages.limitingMetric(assessment.pages.gridSupportedCount<assessment.pages.candidateCount)="gram";
assessment.pages.limitingMetric(assessment.pages.convergedCount<assessment.pages.gridSupportedCount)="mode-convergence";
assessment.pages.limitingMetric(filteringCount<linearCount)="quadratic-dealiasing";
assessment.pages.limitingMetric(explicitZero)="not-requested";
assessment.pages.gramError=zeros(np,1);
for p=1:np
    if selectedCount(p)>0
        assessment.pages.gramError(p)=assessment.prefixGramError{p}(selectedCount(p));
    end
end
if autoWave, assessment.pages.requestedCount(:)=NaN; end
assessment=withSelectedConvergence(assessment,selectedCount,inertialCount,convergence);

assessment.inertial.linearCount=assessment.inertial.usableCount;
assessment.inertial.filteringCount=inertialReport.filteringCount;
if autoInertial, assessment.inertial.requestedCount=NaN; end
assessment.inertial.selectedCount=inertialCount;
assessment.inertial.candidateGramError=assessment.inertial.gramError;
assessment.inertial.gramError=assessment.inertial.prefixGramError(inertialCount);
assessment.inertial.dealiasing=inertialReport;
assessment.dealiasing=struct(quadraticDealiasing=options.quadraticDealiasing, ...
    retainedFraction=options.retainedFraction,energyFraction=options.energyFraction, ...
    bandwidthFraction=options.bandwidthFraction,gridDegree=state.Nxyz(3)-1, ...
    coordinateKind="wkb-chebyshev-lobatto");
assessment.coverage="Selected contiguous prefixes. Linear convergence and fixed-grid Gram evidence cover every retained mode. The quadratic-dealiasing policy is a stated filtering heuristic, not a rigorous nonlinear qualification. Fixed configured boundary resolution is checked separately.";

state.waveModeCountByKh=selectedCount;
nw=max([selectedCount;0]);
state.waveMode=(1:nw).';
state.waveModeNumber=state.waveModeNumber(1:nw);
state.waveF=state.waveF(:,1:nw,:);
state.waveG=state.waveG(:,1:nw,:);
state.waveGForward=state.waveGForward(1:nw,:,:);
state.waveEquivalentDepth=state.waveEquivalentDepth(1:nw,:);
state.waveFrequency=state.waveFrequency(1:nw,:);
for p=1:np
    state.waveF(:,selectedCount(p)+1:end,p)=0;
    state.waveG(:,selectedCount(p)+1:end,p)=0;
    state.waveGForward(selectedCount(p)+1:end,:,p)=0;
    state.waveEquivalentDepth(selectedCount(p)+1:end,p)=0;
    state.waveFrequency(selectedCount(p)+1:end,p)=0;
    state.waveGramError(p)=0;
    if selectedCount(p)>0
        state.waveGramError(p)=assessment.prefixGramError{p}(selectedCount(p));
    end
end
state.inertialMode=(1:inertialCount).';
state.inertialModeNumber=state.inertialModeNumber(1:inertialCount);
state.inertialF=state.inertialF(:,1:inertialCount);
state.inertialFForward=state.inertialFForward(1:inertialCount,:);
state.inertialEquivalentDepth=state.inertialEquivalentDepth(1:inertialCount);
state.inertialGramError=assessment.inertial.prefixGramError(inertialCount);
end

function report=limitReport(report,linearCount,options)
if isempty(report)
    report=WVInternal.quadraticDealiasingPrefix(zeros(2,0),zeros(2,0),0,options);
end
fields=["accepted","effectiveDegreeF","effectiveDegreeG","effectiveDegree", ...
    "tailEnergyFractionF","tailEnergyFractionG"];
for name=fields
    value=report.(name);
    report.(name)=value(1:linearCount);
end
report.nModes=linearCount;
report.linearCount=linearCount;
switch options.quadraticDealiasing
    case "none"
        report.accepted=true(linearCount,1);
    case "fixedFraction"
        report.accepted=(1:linearCount).'<=floor(options.retainedFraction*linearCount);
end
report.filteringCount=sum(cumprod(report.accepted));
report.selectedCount=report.filteringCount;
end

function assessment=withSelectedConvergence(assessment,counts,inertialCount,convergence)
assessment.pages.modeConvergenceError=zeros(numel(counts),1);
for p=1:numel(counts)
    if counts(p)>0
        assessment.pages.modeConvergenceError(p)=convergence.pages{p}.prefixError(counts(p));
    end
end
assessment.inertial.modeConvergenceError=convergence.inertial.prefixError(inertialCount);
end
