function [state,assessment] = selectFreeSurfaceWaveCounts(state,assessment,convergence,options,autoWave,autoInertial)
% Apply one vertical quadratic-dealiasing policy after independent linear checks.
np=height(assessment.pages);
linearCount=assessment.pages.usableCount;
filteringCount=zeros(np,1);
selectedCount=zeros(np,1);
selectedLabels=cell(np,1);
selectedColumnKind=cell(np,1);
for p=1:np
    [selectedCount(p),report]=selectCount(assessment.pages.requestedCount(p),linearCount(p), ...
        assessment.pages.fixedGridCount(p),assessment.pages.candidateLabels{p},assessment.pages.linearLimitingMetric(p), ...
        assessment.pages.dealiasing{p},options,assessment.pages.kappa(p));
    filteringCount(p)=report.filteringCount;
    assessment.pages.dealiasing{p}=report;
    selectedLabels{p}=assessment.pages.candidateLabels{p}(1:selectedCount(p));
    selectedColumnKind{p}=repmat("internal",size(selectedLabels{p}));
    selectedColumnKind{p}(selectedLabels{p}==1)="external";
end

[inertialCount,inertialReport]=selectCount(assessment.inertial.requestedCount,assessment.inertial.usableCount, ...
    assessment.inertial.fixedGridCount,assessment.inertial.candidateLabels,assessment.inertial.linearLimitingMetric, ...
    assessment.inertial.dealiasing,options,0);
if inertialCount<1
    error('WV:NoResolvedInertialModes', ...
        'No inertial mode passes the linear and quadratic-dealiasing limits. Increase Nz/nEVP or change quadraticDealiasing.')
end
assessment.pages.linearCount=linearCount;
assessment.pages.filteringCount=filteringCount;
assessment.pages.filteringIsLowerBound=isnan(linearCount);
assessment.pages.selectedCount=selectedCount;
assessment.pages.selectedLabels=selectedLabels;
assessment.pages.selectedColumnKind=selectedColumnKind;
assessment.pages.requestKind=repmat(requestKind(autoWave),np,1);
assessment.pages.sampledInversionSpan=repmat("none",np,1);
assessment.pages.sampledInversionSpanCount=zeros(np,1);
assessment.pages.qualificationStatus=assessment.pages.status;
qualified=~isnan(linearCount);
assessment.pages.status(qualified)="accepted";
explicitZero=~autoWave & assessment.pages.requestedCount==0;
filteredOut=autoWave & selectedCount==0 & filteringCount<linearCount;
assessment.pages.status(explicitZero)="not-requested";
assessment.pages.status(filteredOut)="filtered-out";
assessment.pages.status(qualified & selectedCount==0 & ~explicitZero & ~filteredOut)="rejected";
assessment.pages.limitingMetric=assessment.pages.linearLimitingMetric;
assessment.pages.limitingMetric(filteringCount<linearCount)="quadratic-dealiasing";
assessment.pages.gramError=nan(np,1);
for p=1:np
    if selectedCount(p)>0
        assessment.pages.gramError(p)=assessment.prefixGramError{p}(selectedCount(p));
    end
end
assessment=withSelectedConvergence(assessment,selectedCount,inertialCount,convergence);

assessment.inertial.linearCount=assessment.inertial.usableCount;
assessment.inertial.filteringCount=inertialReport.filteringCount;
assessment.inertial.filteringIsLowerBound=isnan(assessment.inertial.linearCount);
assessment.inertial.selectedCount=inertialCount;
assessment.inertial.selectedLabels=assessment.inertial.candidateLabels(1:inertialCount);
assessment.inertial.requestKind=requestKind(autoInertial);
assessment.inertial.sampledInversionSpan="none";
assessment.inertial.sampledInversionSpanCount=0;
assessment.inertial.qualificationStatus=assessment.inertial.status;
if ~isnan(assessment.inertial.usableCount), assessment.inertial.status="accepted"; end
assessment.inertial.limitingMetric=assessment.inertial.linearLimitingMetric;
if assessment.inertial.filteringCount<assessment.inertial.linearCount
    assessment.inertial.limitingMetric="quadratic-dealiasing";
end
assessment.inertial.candidateGramError=assessment.inertial.gramError;
assessment.inertial.gramError=assessment.inertial.prefixGramError(inertialCount);
assessment.inertial.dealiasing=inertialReport;
assessment.dealiasing=struct(quadraticDealiasing=options.quadraticDealiasing, ...
    retainedFraction=options.retainedFraction,energyFraction=options.energyFraction, ...
    bandwidthFraction=options.bandwidthFraction,gridDegree=state.Nxyz(3)-1, ...
    coordinateKind=inertialReport.coordinateKind);
assessment.coverage="Selected contiguous prefixes. Independent convergence and physical Gram evidence cover every retained mode. A passing candidate ceiling leaves larger counts unassessed. The quadratic-dealiasing policy supplies a filtering heuristic. Configured boundary responses are qualified separately.";

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
state.inertialFProjection=state.inertialFProjection(1:inertialCount,:);
state.inertialEquivalentDepth=state.inertialEquivalentDepth(1:inertialCount);
state.inertialGramError=assessment.inertial.prefixGramError(inertialCount);
end

function [selected,report]=selectCount(requested,linearCount,verifiedCount,labels,metric,report,options,kappa)
if kappa==0
    family="inertial";
    identifierFamily="Inertial";
else
    family=compose("wave at kappa %.17g rad/m",kappa);
    identifierFamily="Wave";
end
report=limitReport(report,verifiedCount,options);
if isnan(linearCount) && (isnan(requested) || requested>report.filteringCount)
    error('WV:InconclusiveModeResolution', ...
        'The independent EVP reference did not qualify the %s prefix above %d modes. Increase nEVP/referenceNEVP or reduce the explicit request.', ...
        family,verifiedCount)
end
if isnan(requested)
    selected=report.filteringCount;
else
    if requested>verifiedCount
        error("WV:Strict"+identifierFamily+"ModeCountRejected", ...
            'The explicit %s count %d exceeds the qualified prefix %d. The next mode label %d fails %s. Increase Nz or nEVP, or reduce the request.', ...
            family,requested,verifiedCount,labels(verifiedCount+1),metric)
    end
    if requested>report.filteringCount
        error("WV:QuadraticDealiasing"+identifierFamily+"CountRejected", ...
            'The explicit %s count %d exceeds the quadratic-dealiasing limit %d under policy %s.', ...
            family,requested,report.filteringCount,options.quadraticDealiasing)
    end
    selected=requested;
end
report.selectedCount=selected;
end

function kind=requestKind(automatic)
kind="strict";
if automatic, kind="automatic"; end
end

function report=limitReport(report,linearCount,options)
if isempty(report)
    report=WVInternal.quadraticDealiasingPrefix(zeros(2,0),zeros(2,0),0,options,options.verticalGridRule);
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
assessment.pages.modeConvergenceError=nan(numel(counts),1);
for p=1:numel(counts)
    if counts(p)>0
        assessment.pages.modeConvergenceError(p)=convergence.pages{p}.prefixError(counts(p));
    end
end
assessment.inertial.modeConvergenceError=convergence.inertial.prefixError(inertialCount);
end
