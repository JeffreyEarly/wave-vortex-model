function [state,assessment] = selectFreeSurfaceWaveCounts(state,bases,reference,vertical,counts,inertialCount,assessment,options,autoWave,autoInertial)
% Test complete maps against one bounded snapshot; never mix pagewise optima.
assessment=withSelectedConvergence(assessment,counts,inertialCount);
if options.shouldCheckQuadraticAliasing && any(counts>0)
    data=WVInternal.prepareConstructionProducts(state,bases,reference,vertical,counts,inertialCount,assessment,options);
    prepared=WVInternal.prepareWaveQuadraticAssessment(data,interactionIndices=1:height(data.inventory.interactions),ensureOutputCoverage=true);
    levels=arrayfun(@WVInternal.constructionModeLevels,counts,UniformOutput=false);
    inertialLevels=WVInternal.constructionModeLevels(inertialCount);
    maxTrials=min(128,sum(counts)+inertialCount+1);
    trials=cell(maxTrials,1);
    for trial=1:maxTrials
        report=WVInternal.assessWaveCountMap(prepared,waveModeKappa=state.khUnique,waveModeCount=counts,inertialModeCount=inertialCount,quadraticTolerance=options.quadraticAliasingTolerance);
        trials{trial}=struct(waveModeCount=counts,inertialModeCount=inertialCount,status=report.status,worstQuadraticError=max(report.pages.quadraticError));
        if report.requestedCountAccepted, break; end
        if report.status~="rejected"
            error('WV:InconclusiveQuadraticAssessment','The bounded interaction check is %s. Increase the reference/grid resolution or extend the measurement inventory; untested or unresolved evidence cannot accept a count map.',report.status)
        end
        next=counts; nextInertial=inertialCount;
        % Reduce only families implicated by the worst sampled interaction.
        % Each decision is retested against the same complete-map snapshot.
        [~,worstPage]=max(report.pages.quadraticError);
        limiting=report.pages.limitingInteraction{worstPage};
        if autoWave
            reduce=zeros(0,1);
            for input=1:2
                if limiting.inputFamilies(input)=="wave"
                    kh=norm(limiting.physicalWavevectors(input,:));
                    [~,page]=min(abs(state.khUnique-kh)); reduce(end+1,1)=page; %#ok<AGROW>
                end
            end
            if limiting.outputFamily=="wave", reduce(end+1,1)=worstPage-1; end %#ok<AGROW>
            reduce=unique(reduce);
            for page=reduce.'
                smaller=levels{page}(levels{page}<counts(page));
                if ~isempty(smaller), next(page)=max(smaller); end
            end
        end
        if autoInertial && limiting.outputFamily=="inertial"
            smaller=inertialLevels(inertialLevels<inertialCount);
            if ~isempty(smaller), nextInertial=max(smaller); end
        end
        if isequal(next,counts) && nextInertial==inertialCount
            error('WV:QuadraticModeCountRejected','No allowed count reduction passes the bounded physical interaction checks (worst error %.3g, tolerance %.3g). Increase Nz; explicit counts and fixed APV/MDA/endpoint families are preserved.',max(report.pages.quadraticError),options.quadraticAliasingTolerance)
        end
        counts=next; inertialCount=nextInertial;
    end
    if ~report.requestedCountAccepted
        error('WV:QuadraticModeCountRejected','The bounded count-map trial budget was exhausted. Increase Nz or choose explicit counts.')
    end
    assessment.quadratic=report;
    assessment.quadratic.trials=vertcat(trials{1:trial});
    assessment.cost.selectionTrials=trial;
    assessment.cost.quadratic=report.cost;
elseif options.shouldCheckQuadraticAliasing
    assessment.quadratic=struct(status="not-applicable",coverage="No propagating wave modes requested; shared APV/zero-APV checks still apply. Mean-family nonlinear interactions are outside this sampled wave policy.");
else
    assessment.quadratic=struct(status="not-requested",coverage="Linear qualification only; no quadratic products were prepared or measured.");
end
assessment.shouldCheckQuadraticAliasing=options.shouldCheckQuadraticAliasing;
assessment=withSelectedConvergence(assessment,counts,inertialCount);
assessment.pages.selectedCount=counts;
assessment.pages.status=repmat("accepted",numel(counts),1);
assessment.pages.status(counts==0)="not-requested";
assessment.pages.candidateLimitReached=counts==assessment.pages.candidateCount & counts>0;
assessment.pages.limitingMetric=repmat("candidate-ceiling",numel(counts),1);
assessment.pages.limitingMetric(assessment.pages.usableCount<assessment.pages.candidateCount)="gram";
assessment.pages.limitingMetric(assessment.pages.convergedCount<assessment.pages.gridSupportedCount)="mode-convergence";
assessment.pages.limitingMetric(counts<assessment.pages.usableCount)="sampled-quadratic";
assessment.pages.limitingMetric(counts==0)="not-requested";
assessment.pages.gramError=zeros(numel(counts),1);
for p=1:numel(counts)
    if counts(p)>0, assessment.pages.gramError(p)=assessment.prefixGramError{p}(counts(p)); end
end
if autoWave, assessment.pages.requestedCount(:)=NaN; end
assessment.inertial.candidateCount=assessment.inertial.requestedCount;
if autoInertial, assessment.inertial.requestedCount=NaN; end
assessment.inertial.selectedCount=inertialCount;
assessment.inertial.candidateGramError=assessment.inertial.gramError;
assessment.inertial.gramError=assessment.inertial.prefixGramError(inertialCount);
assessment.coverage="Selected resolved prefixes. Linear evidence covers every retained mode and kappa. Fixed configured boundary resolution is checked separately.";
if options.shouldCheckQuadraticAliasing
    assessment.coverage=assessment.coverage+" Quadratic evidence covers the stated finite interaction inventory, not every triad or coherent superposition.";
else
    assessment.coverage=assessment.coverage+" Quadratic interactions were not assessed.";
end
state.waveModeCountByKh=counts; nw=max([counts;0]); state.waveMode=(1:nw).';
state.waveModeNumber=state.waveModeNumber(1:nw);
state.waveF=state.waveF(:,1:nw,:); state.waveG=state.waveG(:,1:nw,:);
state.waveGForward=state.waveGForward(1:nw,:,:);
state.waveEquivalentDepth=state.waveEquivalentDepth(1:nw,:); state.waveFrequency=state.waveFrequency(1:nw,:);
for p=1:numel(counts)
    state.waveF(:,counts(p)+1:end,p)=0; state.waveG(:,counts(p)+1:end,p)=0;
    state.waveGForward(counts(p)+1:end,:,p)=0;
    state.waveEquivalentDepth(counts(p)+1:end,p)=0; state.waveFrequency(counts(p)+1:end,p)=0;
    state.waveGramError(p)=0;
    if counts(p)>0, state.waveGramError(p)=assessment.prefixGramError{p}(counts(p)); end
end
state.inertialMode=(1:inertialCount).'; state.inertialModeNumber=state.inertialModeNumber(1:inertialCount);
state.inertialF=state.inertialF(:,1:inertialCount); state.inertialFForward=state.inertialFForward(1:inertialCount,:);
state.inertialEquivalentDepth=state.inertialEquivalentDepth(1:inertialCount);
state.inertialGramError=assessment.inertial.prefixGramError(inertialCount);
end
function value=selectedError(report,count)
rows=ismember(report.measurements.columnLabel,report.identity.columnLabels(1:count)) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
value=max(report.measurements.value(rows));
end

function assessment=withSelectedConvergence(assessment,counts,inertialCount)
assessment.pages.modeConvergenceError=zeros(numel(counts),1);
for p=1:numel(counts)
    if counts(p)>0
        assessment.pages.modeConvergenceError(p)=selectedError(assessment.modeConvergence{p},counts(p));
    end
end
assessment.inertial.modeConvergenceError=selectedError(assessment.inertial.convergence,inertialCount);
end
