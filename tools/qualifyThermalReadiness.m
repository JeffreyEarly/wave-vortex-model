function report = qualifyThermalReadiness(outputFolder,cases,options)
% Run bounded authoring windows and explicitly named one-axis comparisons.
% Every case uses hard interval boundaries at observations and at most two
% requested maximum steps; the wall budget is checked between these blocks.
% Ordinary WVModel observers instead use interpolated output with extra RHSs.
% This driver reports measured subsets; unrun axes never become passing gates.
% Initial representations and held scientific arrays are checked before any
% trajectory. Initial comparison quadrature uses the declared tighter allowance.
% - Topic: Developer utilities
% - Parameter outputFolder: new immutable run directory; existing runs are never overwritten
% - Parameter cases: name/configuration records with optional step, adaptive and scientificState
% - Parameter options.pairs: candidate/reference/axis records; optional refinement names a third case
% - Parameter options.wallTimeBudgetSeconds: cooperative total wall budget, including setup
% - Returns report: case, field, budget, coverage and incomplete-readiness evidence
arguments (Input)
    outputFolder (1,1) string
    cases (1,:) struct = struct(name="candidate",configuration=struct())
    options.durationSeconds (1,1) double {mustBeFinite,mustBePositive} = 6*3600
    options.observationOffsets (1,:) double = []
    options.pairs (1,:) struct = struct('candidate',{},'reference',{},'axis',{},'refinement',{})
    options.wallTimeBudgetSeconds (1,1) double {mustBeFinite,mustBeNonnegative} = 4*3600
    options.caseWallTimeBudgetSeconds (1,1) double {mustBeFinite,mustBePositive} = 30*60
    options.comparisonCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.comparisonCount,65)} = 513
    options.canonicalDamping (1,1) struct = struct()
end
arguments (Output)
    report (1,1) struct
end
clock = tic;
if isempty(options.observationOffsets), options.observationOffsets = linspace(0,options.durationSeconds,5); end
if numel(options.observationOffsets)<3 || options.observationOffsets(1)~=0 || options.observationOffsets(end)~=options.durationSeconds || any(~isfinite(options.observationOffsets)) || any(diff(options.observationOffsets)<=0)
    error('WV:ReadinessObservationTimes','Supply strictly increasing offsets from zero to the declared duration.');
end
if isfile(fullfile(outputFolder,'run-contract.mat'))
    error('WV:ReadinessRunExists','Use a new directory for a changed or repeated qualification; existing trajectories and ledgers are immutable.');
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
cases = completeCases(cases);
validatePairs(options.pairs,cases);
contractCases = rmfield(cases,'scientificState');
for j = 1:numel(cases)
    contractCases(j).scientificCacheHash = thermalReadinessIdentity(cases(j).scientificState);
    contractCases(j).gravity=9.81;
    if isfield(cases(j).scientificState,'g'), contractCases(j).gravity=cases(j).scientificState.g; end
end
criteria=thermalReadinessCriteria();
contract = struct(schema="thermal-readiness-window-v2",cases=contractCases,options=options,observationSemantics="hard boundaries at observations and blocks of at most twice the requested maximum step",energyNormDefinition="sqrt(2*positive physical energy)",readinessScope="bounded windows; missing reference/regime/resource gates remain conditional");
contract.fieldCriteria=criteria;
contract.initialAndTemporalAllowanceFraction=.1; contract.maximumUncertaintyFraction=.2;
contract.inventoryRelativeAllowance=.002;
contract.inventoryFloorRecipe="E_floor = D*u_floor^2/2 + (sqrt(D/min(N2))*b_floor + sqrt(integral(N2*(1+z/D)^2 dz))*ssh_floor)^2/2 + g*ssh_floor^2/2; Z_floor = D*q_floor^2/2; endpoint floors = displacement_floor^2/2. The energy bound retains the affine SSH lift and is conservative for volume RMS buoyancy error.";
contract.executionIdentity="thermalReadinessIdentity(struct(runId=contract.runId,caseName=caseName)); manifest.caseId identifies the initial case only";
contract.runId = thermalReadinessIdentity(contract);
executionIds=strings(numel(cases),1);
for j=1:numel(cases), executionIds(j)=thermalReadinessIdentity(struct(runId=contract.runId,caseName=cases(j).name)); end
executions=table(reshape([cases.name],[],1),executionIds,VariableNames={'caseName','executionId'});
save(fullfile(outputFolder,'run-contract.mat'),'contract','executions');
writetable(executions,fullfile(outputFolder,'executions.csv'));
writeJSON(fullfile(outputFolder,'run-contract.json'),contract);
windowFiles = strings(1,numel(cases));
summary = table(); budgets = table(); processWork = table(); authoritative = []; authoritativeConfiguration = struct();
initialRuns=cell(size(windowFiles)); usesSource=false(size(windowFiles)); initialComparisons=table();
initialCaseIds=strings(size(windowFiles));
preparationStatus=repmat("NOT RUN",size(windowFiles)); preparationReason=repmat("wall budget exhausted before initial preparation",size(windowFiles));
preparationSeconds=zeros(size(windowFiles)); authoritativeIndex=0;
% Prepare and verify immutable initial states before any trajectory work.
for j=1:numel(cases)
    caseClock=tic;
    if toc(clock)>=options.wallTimeBudgetSeconds, continue; end
    try
        folder=fullfile(outputFolder,cases(j).name); if ~isfolder(folder), mkdir(folder); end
        source=[];
        if cases(j).sharedInitialState && ~isempty(authoritative), source=authoritative; usesSource(j)=true; end
        [w,manifest]=thermalReadinessCase(cases(j).configuration,scientificState=cases(j).scientificState,source=source,cacheFile=fullfile(folder,'initial-case.mat'));
        transformCleanup=onCleanup(@()releaseTransform(w));
        initialCaseIds(j)=manifest.caseId;
        if ~isempty(source)
            for parameter=["kind","seedRMS","velocityRMS","meanAmplitude","normalizationCount"]
                if ~isequaln(manifest.configuration.(parameter),authoritativeConfiguration.(parameter))
                    error('WV:ReadinessSharedInitialState','Shared initial states must retain the declared %s; start a separate run for another initial condition.',parameter);
                end
            end
            checkBudget(clock,caseClock,options);
            measured=initialComparison(w,source,options.comparisonCount,criteria,contract);
            measured=labelInitialComparison(measured,cases(j).name,cases(authoritativeIndex).name,"source transfer",executionIds(j),executionIds(authoritativeIndex));
            appendTable(fullfile(outputFolder,'initial-comparisons.csv'),measured); initialComparisons=[initialComparisons;measured]; %#ok<AGROW>
            requireInitialRepresentation(measured);
        end
        checkBudget(clock,caseClock,options);
        if isempty(authoritative)
            authoritativeConfiguration=manifest.configuration; authoritativeIndex=j;
            authoritative=WVTransformFreeSurfaceThermalQG(scientificState=w.scientificState,coefficientState=w.coefficientState(),t=w.t);
            authoritative.t0=w.t0; authoritativeCleanup=onCleanup(@()releaseTransform(authoritative));
        end
        initialRuns{j}=struct(manifest=manifest,scientificState=w.scientificState,snapshots={{struct(state=w.coefficientState(),t=w.t)}},acceptedStepSeconds=[]);
        preparationStatus(j)="PREPARED"; preparationReason(j)="initial state prepared";
    catch exception
        preparationStatus(j)="FAILED";
        if exception.identifier=="WV:ReadinessWallBudget", preparationStatus(j)="BUDGET STOP"; end
        if exception.identifier=="WV:ReadinessInitialQuadrature", preparationStatus(j)="INCONCLUSIVE"; end
        preparationReason(j)=string(exception.identifier)+": "+string(exception.message);
    end
    clear transformCleanup w source
    preparationSeconds(j)=toc(caseClock);
end
for pair=options.pairs
    names=[string(pair.candidate),string(pair.reference)];
    if isfield(pair,'refinement') && string(pair.refinement)~="", names=[names,string(pair.refinement)]; end %#ok<AGROW> At most three names.
    [~,indices]=ismember(names,[cases.name]);
    if any(preparationStatus(indices)~="PREPARED"), continue; end
    pairClock=tic;
    try
        for edge=1:numel(indices)-1
            ia=indices(edge); ib=indices(edge+1);
            validateAxis(cases(ia),cases(ib),initialRuns{ia},initialRuns{ib},string(pair.axis),false);
            checkBudget(clock,pairClock,options,max(preparationSeconds(indices)));
            a=restoredSnapshot(initialRuns{ia},1); aCleanup=onCleanup(@()releaseTransform(a));
            b=restoredSnapshot(initialRuns{ib},1); bCleanup=onCleanup(@()releaseTransform(b));
            measured=initialComparison(a,b,options.comparisonCount,criteria,contract);
            measured=labelInitialComparison(measured,names(edge),names(edge+1),string(pair.axis),executionIds(ia),executionIds(ib));
            appendTable(fullfile(outputFolder,'initial-comparisons.csv'),measured); initialComparisons=[initialComparisons;measured]; %#ok<AGROW>
            requireInitialRepresentation(measured);
            clear aCleanup bCleanup a b
        end
    catch exception
        preparationStatus(indices)="FAILED";
        if exception.identifier=="WV:ReadinessWallBudget", preparationStatus(indices)="BUDGET STOP"; end
        if exception.identifier=="WV:ReadinessInitialQuadrature", preparationStatus(indices)="INCONCLUSIVE"; end
        preparationReason(indices)=string(exception.identifier)+": "+string(exception.message);
        clear aCleanup bCleanup a b
    end
    preparationSeconds(indices)=preparationSeconds(indices)+toc(pairClock)/numel(indices);
end
% A trajectory whose required initial reference failed cannot qualify its pair.
% Propagate that dependency through any shared pairs without replacing the
% original failure or its measurements.
for pass=1:numel(cases)
    changed=false;
    for pair=options.pairs
        names=[string(pair.candidate),string(pair.reference)];
        if isfield(pair,'refinement') && string(pair.refinement)~="", names=[names,string(pair.refinement)]; end %#ok<AGROW> At most three names.
        [~,indices]=ismember(names,[cases.name]);
        if any(preparationStatus(indices)~="PREPARED")
            pending=indices(preparationStatus(indices)=="PREPARED");
            preparationStatus(pending)="NOT RUN";
            preparationReason(pending)="paired initial representation or held-axis validation did not pass";
            changed=changed || ~isempty(pending);
        end
    end
    if ~changed, break; end
end
clear initialRuns
initialPreparation=table(reshape([cases.name],[],1),executionIds,initialCaseIds.',preparationStatus.',preparationReason.',preparationSeconds.',VariableNames={'caseName','executionId','initialCaseId','status','reason','wallSeconds'});
writetable(initialPreparation,fullfile(outputFolder,'initial-preparation.csv'));
for j = 1:numel(cases)
    name = cases(j).name; executionId=executionIds(j); initialCaseId=initialCaseIds(j);
    status = "NOT RUN"; reason = "wall budget exhausted before case";
    elapsed = preparationSeconds(j); finalTime = NaN; accepted = 0; rejected = 0; rhs = 0; outputRhs = 0;
    caseClock = tic;
    if preparationStatus(j)~="PREPARED"
        status=preparationStatus(j); reason=preparationReason(j);
        elapsed=preparationSeconds(j);
    elseif toc(clock)<options.wallTimeBudgetSeconds
        try
            folder = fullfile(outputFolder,name); if ~isfolder(folder), mkdir(folder); end
            source = []; if usesSource(j), source = authoritative; end
            [w,manifest] = thermalReadinessCase(cases(j).configuration,scientificState=cases(j).scientificState,source=source,cacheFile=fullfile(folder,'initial-case.mat'));
            transformCleanup=onCleanup(@()releaseTransform(w));
            initialCaseId=manifest.caseId;
            if cases(j).dampingVariant ~= "none"
                w.addForcing(thermalReadinessDamping(w,options.canonicalDamping,variant=cases(j).dampingVariant));
            end
            checkBudget(clock,caseClock,options,preparationSeconds(j));
            if w.g~=contractCases(j).gravity, error('WV:ReadinessGravity','Constructed gravity differs from the predeclared canonical/factory value.'); end
            floors=inventoryFloors(w,criteria,options.comparisonCount);
            caseContract=struct(executionId=executionId,initialCaseId=initialCaseId,gravity=w.g,inventoryFloors=floors,inventoryNames=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"],fieldCriteria=criteria);
            writeJSON(fullfile(folder,'integration-contract.json'),caseContract);
            model = WVModel(w);
            modelCleanup=onCleanup(@()releaseModel(model));
            model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=~manifest.configuration.shouldIncludeAdvection,initialStep=cases(j).step,maximumStep=cases(j).step,exponentialAdaptive=cases(j).adaptive,relTolerance=cases(j).relTolerance,physicalAbsTolerance=cases(j).physicalAbsTolerance);
            snapshots = cell(1,numel(options.observationOffsets)); steps = [];
            for k = 1:numel(snapshots)
                checkBudget(clock,caseClock,options,preparationSeconds(j));
                targetTime = manifest.configuration.t+options.observationOffsets(k);
                while w.t<targetTime
                    checkBudget(clock,caseClock,options,preparationSeconds(j));
                    model.integrateToTime(min(targetTime,w.t+2*cases(j).step),shouldShowIntegrationDiagnostics=false);
                    statistics = model.exponentialStatistics;
                    accepted = accepted+statistics.acceptedSteps; rejected = rejected+statistics.rejectedSteps;
                    rhs = rhs+statistics.rhsEvaluations; outputRhs = outputRhs+statistics.outputRhsEvaluations;
                    steps = [steps,reshape(statistics.acceptedStepSeconds,1,[])]; %#ok<AGROW>
                    if statistics.maximumCFL>.6+1e-12 || statistics.maximumDampingNumber>1.2+1e-12
                        error('WV:ReadinessStabilityBound','An accepted step exceeded its existing CFL or explicit-damping allowance.');
                    end
                end
                snapshots{k} = observe(w,manifest.configuration);
                s = snapshots{k};
                row = table(name,executionId,initialCaseId,w.t,s.inventory.totalEnergy,s.inventory.potentialEnstrophy,s.inventory.surfaceAnomalyVariance,s.inventory.bottomAnomalyVariance,s.mean.totalEnergy,VariableNames={'caseName','executionId','initialCaseId','time','energy','enstrophy','surfaceVariance','bottomVariance','meanEnergy'});
                appendTable(fullfile(outputFolder,'observations.csv'),row);
            end
            finalTime = w.t;
            run = struct(executionId=executionId,initialCaseId=initialCaseId,runId=contract.runId,manifest=manifest,scientificState=w.scientificState,snapshots={snapshots},acceptedStepSeconds=steps,dampingVariant=cases(j).dampingVariant,inventoryFloors=floors,inventoryRelativeAllowance=contract.inventoryRelativeAllowance,maximumUncertaintyFraction=contract.maximumUncertaintyFraction);
            save(fullfile(folder,'window.mat'),'run','-v7.3');
            windowFiles(j) = fullfile(folder,'window.mat');
            [budget,work] = budgetReport(name,run);
            appendTable(fullfile(outputFolder,'process-work.csv'),work); processWork = [processWork;work]; %#ok<AGROW>
            appendTable(fullfile(outputFolder,'budgets.csv'),budget); budgets = [budgets;budget]; %#ok<AGROW>
            status = "COMPLETE"; reason = "finite bounded window; readiness gates remain separate";
            if rejected/max(accepted+rejected,1)>.2, reason = reason+"; rejected-attempt fraction exceeds 20%"; end
            if any(budget.status=="FAIL"), status = "BUDGET FAIL"; end
        catch exception
            if exception.identifier=="WV:ReadinessWallBudget", status="BUDGET STOP"; else, status="FAILED"; end
            reason = string(exception.identifier)+": "+string(exception.message);
        end
        clear modelCleanup transformCleanup model w run snapshots s steps
        elapsed = preparationSeconds(j)+toc(caseClock);
    end
    row = table(name,executionId,initialCaseId,status,reason,elapsed,finalTime,accepted,rejected,rhs,outputRhs,VariableNames={'caseName','executionId','initialCaseId','status','reason','wallSeconds','finalTime','acceptedSteps','rejectedSteps','rhsEvaluations','outputRhsEvaluations'});
    appendTable(fullfile(outputFolder,'cases.csv'),row); summary = [summary;row]; %#ok<AGROW>
end
clear authoritativeCleanup authoritative source
comparisons = table();
for pair = options.pairs
    if toc(clock)>=options.wallTimeBudgetSeconds, break; end
    checkNames = [string(pair.candidate),string(pair.reference)];
    indices = zeros(1,2);
    for k = 1:2, indices(k)=find([cases.name]==checkNames(k),1); end
    if any(windowFiles(indices)==""), continue; end
    % Completed cases retain only paths while subsequent models are live.
    % Load at most this pair and its reference after releasing every model.
    loaded=load(windowFiles(indices(1)),'run'); runA=loaded.run;
    loaded=load(windowFiles(indices(2)),'run'); runB=loaded.run;
    runReference=[];
    effectiveRefinement=validateAxis(cases(indices(1)),cases(indices(2)),runA,runB,string(pair.axis));
    if isfield(pair,'refinement') && string(pair.refinement)~=""
        referenceIndex=find([cases.name]==string(pair.refinement),1);
        if ~isempty(referenceIndex) && windowFiles(referenceIndex)~=""
            loaded=load(windowFiles(referenceIndex),'run'); runReference=loaded.run;
            referenceIsFiner=validateAxis(cases(indices(2)),cases(referenceIndex),runB,runReference,string(pair.axis));
            effectiveRefinement=effectiveRefinement && referenceIsFiner;
        end
    end
    clear loaded
    for k = 1:numel(options.observationOffsets)
        if toc(clock)>=options.wallTimeBudgetSeconds, break; end
        a = restoredSnapshot(runA,k); aCleanup=onCleanup(@()releaseTransform(a));
        b = restoredSnapshot(runB,k); bCleanup=onCleanup(@()releaseTransform(b));
        coarse = compareThermalReadinessFields(a,b,options.comparisonCount,criteria);
        fine = compareThermalReadinessFields(a,b,2*options.comparisonCount+1,criteria);
        referenceError = NaN(height(fine),1); referenceQuadratureUncertainty=referenceError;
        if ~isempty(runReference)
            reference = restoredSnapshot(runReference,k); referenceCleanup=onCleanup(@()releaseTransform(reference));
            refinedCoarse=compareThermalReadinessFields(b,reference,options.comparisonCount,criteria);
            refined = compareThermalReadinessFields(b,reference,2*options.comparisonCount+1,criteria);
            referenceError = refined.error;
            referenceQuadratureUncertainty=abs(refined.error-refinedCoarse.error)+refined.relativeAllowance.*abs(refined.referenceNorm-refinedCoarse.referenceNorm);
        end
        fine.quadratureUncertainty = abs(fine.error-coarse.error)+fine.relativeAllowance.*abs(fine.referenceNorm-coarse.referenceNorm);
        fine.referenceError = referenceError; fine.referenceQuadratureUncertainty=referenceQuadratureUncertainty;
        fine.allowance = fine.absoluteFloor+fine.relativeAllowance.*fine.referenceNorm;
        fraction = 1; if string(pair.axis)=="time" || k==1, fraction=contract.initialAndTemporalAllowanceFraction; end
        fine.effectiveAllowance = fraction*fine.allowance;
        fine.errorRatio = fine.error./fine.effectiveAllowance;
        fine.status = repmat("INCONCLUSIVE",height(fine),1);
        measured = isfinite(referenceError) & fine.quadratureUncertainty<=contract.maximumUncertaintyFraction*fine.effectiveAllowance & referenceQuadratureUncertainty<=contract.maximumUncertaintyFraction*fine.effectiveAllowance & referenceError<=contract.maximumUncertaintyFraction*fine.effectiveAllowance;
        fine.status(measured & fine.errorRatio<=1) = "PASS";
        fine.status(measured & fine.errorRatio>1) = "FAIL";
        if ~effectiveRefinement
            fine.status(:) = "INCONCLUSIVE";
        end
        fine.executionId = repmat(executionIds(indices(1)),height(fine),1); fine.referenceExecutionId = repmat(executionIds(indices(2)),height(fine),1);
        fine.caseName = repmat(checkNames(1),height(fine),1); fine.referenceName = repmat(checkNames(2),height(fine),1);
        fine.axis = repmat(string(pair.axis),height(fine),1); fine.time = repmat(a.t,height(fine),1);
        appendTable(fullfile(outputFolder,'field-comparisons.csv'),fine); comparisons = [comparisons;fine]; %#ok<AGROW>
        clear referenceCleanup aCleanup bCleanup reference a b
    end
    clear runA runB runReference
end
axes = ["time";"product sampling";"thermal bandwidth";"native sampling";"horizontal bandwidth";"mean bandwidth";"diagnostic sampling";"restart";"nonlinear activity";"closure bias";"resource feasibility"];
coverage = table(axes,repmat("NOT RUN",numel(axes),1),VariableNames={'axis','status'});
if ~isempty(comparisons)
    for j = 1:height(coverage)
        selected = comparisons.axis==coverage.axis(j);
        if any(selected)
            coverage.status(j)="INCONCLUSIVE";
            if all(comparisons.status(selected)=="PASS"), coverage.status(j)="MEASURED SUBSET"; end
            if any(comparisons.status(selected)=="FAIL"), coverage.status(j)="FAIL"; end
        end
    end
end
writetable(coverage,fullfile(outputFolder,'coverage.csv'));
readiness = "CONDITIONAL";
if any(ismember(summary.status,["FAILED","BUDGET FAIL"])) || any(coverage.status=="FAIL"), readiness="NOT READY"; end
report = struct(runId=contract.runId,readiness=readiness,resourceReadiness="CONDITIONAL: production time/disk limits not supplied",executions=executions,initialPreparation=initialPreparation,initialComparisons=initialComparisons,cases=summary,budgets=budgets,processWork=processWork,comparisons=comparisons,coverage=coverage,wallSeconds=toc(clock),wallBudgetSemantics="cooperative between integration blocks of at most two requested maximum steps and between setup/comparison blocks; an in-flight construction or RHS can finish after the deadline",consecutiveRejectionGate="NOT MEASURED",lifecycleGate="NOT RUN: use the existing T8 fresh-process continuation gate");
save(fullfile(outputFolder,'report.mat'),'report');
writeJSON(fullfile(outputFolder,'summary.json'),struct(runId=report.runId,readiness=report.readiness,resourceReadiness=report.resourceReadiness,wallSeconds=report.wallSeconds));
end

function cases = completeCases(given)
default = struct(name="",configuration=struct(),step=600,adaptive=false,relTolerance=1e-6,physicalAbsTolerance=[1e-13 1e-11 1e-8 1e-8 1e-9],scientificState=struct(),sharedInitialState=true,dampingVariant="none");
cases = repmat(default,size(given));
for j = 1:numel(given)
    if ~all(isfield(given(j),{'name','configuration'})) || ~isempty(setdiff(fieldnames(given(j)),fieldnames(default)))
        error('WV:ReadinessCases','Cases require name/configuration and only declared execution overrides.');
    end
    for name=string(fieldnames(given(j))).', cases(j).(name)=given(j).(name); end
    cases(j).name=string(cases(j).name); cases(j).dampingVariant=string(cases(j).dampingVariant);
    if isempty(regexp(cases(j).name,'^[A-Za-z0-9_-]+$','once')) || ~ismember(cases(j).dampingVariant,["none","horizontal","apv"])
        error('WV:ReadinessCases','Use a simple unique case name and a declared damping variant.');
    end
    validateattributes(cases(j).step,{'double'},{'scalar','finite','positive'});
    validateattributes(cases(j).adaptive,{'logical'},{'scalar'});
    validateattributes(cases(j).sharedInitialState,{'logical'},{'scalar'});
    validateattributes(cases(j).relTolerance,{'double'},{'scalar','finite','positive'});
    validateattributes(cases(j).physicalAbsTolerance,{'double'},{'size',[1 5],'finite','positive'});
    validateattributes(cases(j).configuration,{'struct'},{'scalar'});
    validateattributes(cases(j).scientificState,{'struct'},{'scalar'});
end
if numel(unique([cases.name]))~=numel(cases), error('WV:ReadinessCases','Case names must be unique.'); end
end
function validatePairs(pairs,cases)
for pair=pairs
    if ~all(isfield(pair,{'candidate','reference','axis'})) || ~isempty(setdiff(fieldnames(pair),{'candidate','reference','axis','refinement'}))
        error('WV:ReadinessPair','Each comparison requires candidate, reference and axis, with only an optional refinement case.');
    end
    names=[string(pair.candidate),string(pair.reference)];
    if isfield(pair,'refinement') && string(pair.refinement)~="", names=[names,string(pair.refinement)]; end %#ok<AGROW> At most three names.
    if ~all(ismember(names,[cases.name])) || numel(unique(names))~=numel(names)
        error('WV:ReadinessPair','Each comparison must name distinct declared cases.');
    end
    if ~ismember(string(pair.axis),["time","product sampling","thermal bandwidth","native sampling","horizontal bandwidth","mean bandwidth"])
        error('WV:ReadinessAxis','This driver does not implement axis %s.',string(pair.axis));
    end
end
end
function releaseModel(model)
if isempty(model) || ~isvalid(model), return; end
w=model.wvt;
modelCleanup=onCleanup(@()delete(model));
transformCleanup=onCleanup(@()releaseTransform(w));
model.closeNetCDFFile();
end
function releaseTransform(w)
if ~isempty(w) && isvalid(w), delete(w); end
end
function checkBudget(clock,caseClock,options,alreadyElapsed)
if nargin<4, alreadyElapsed=0; end
if toc(clock)>=options.wallTimeBudgetSeconds || alreadyElapsed+toc(caseClock)>=options.caseWallTimeBudgetSeconds
    error('WV:ReadinessWallBudget','The declared cooperative wall-time budget has expired.');
end
end
function measured=initialComparison(candidate,reference,count,criteria,contract)
coarse=compareThermalReadinessFields(candidate,reference,count,criteria);
measured=compareThermalReadinessFields(candidate,reference,2*count+1,criteria);
measured.quadratureUncertainty=abs(measured.error-coarse.error)+measured.relativeAllowance.*abs(measured.referenceNorm-coarse.referenceNorm);
measured.allowance=measured.absoluteFloor+measured.relativeAllowance.*measured.referenceNorm;
measured.effectiveAllowance=contract.initialAndTemporalAllowanceFraction*measured.allowance;
measured.errorRatio=measured.error./measured.effectiveAllowance;
measured.status=repmat("INCONCLUSIVE",height(measured),1);
resolved=measured.quadratureUncertainty<=contract.maximumUncertaintyFraction*measured.effectiveAllowance;
measured.status(resolved & measured.errorRatio<=1)="PASS";
measured.status(resolved & measured.errorRatio>1)="FAIL";
end
function measured=labelInitialComparison(measured,candidate,reference,axis,executionId,referenceExecutionId)
measured.caseName=repmat(candidate,height(measured),1);
measured.referenceName=repmat(reference,height(measured),1);
measured.axis=repmat(axis,height(measured),1);
measured.executionId=repmat(executionId,height(measured),1);
measured.referenceExecutionId=repmat(referenceExecutionId,height(measured),1);
end
function requireInitialRepresentation(measured)
failed=measured.status=="FAIL";
if any(failed)
    error('WV:ReadinessInitialRepresentation','Initial physical representation exceeds one tenth of the complete spatial allowance for %s; see initial-comparisons.csv.',join(measured.observable(failed),', '));
end
if any(measured.status~="PASS")
    error('WV:ReadinessInitialQuadrature','Initial comparison quadrature is unresolved within one fifth of the initial allowance; see initial-comparisons.csv.');
end
end
function snapshot = observe(w,c)
state = w.coefficientState();
if any(~isfinite(state.Ath),'all') || any(~isfinite(state.Amda),'all'), error('WV:ReadinessFiniteState','Canonical state is nonfinite.'); end
physical=w.reconstructFields(["qgpv","u","v","buoyancy","ssh","endpointAnomalies"]);
for name=string(fieldnames(physical)).'
    if any(~isfinite(physical.(name)),'all'), error('WV:ReadinessFiniteState','A reconstructed physical field is nonfinite.'); end
end
[~,~,processes] = w.coefficientTendency(linearDynamics=~c.shouldIncludeAdvection);
[inventory,~,meanInventory] = w.quadraticDiagnostics(tendency=processes.tendencies);
for name=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
    if ~isfinite(inventory.(name)), error('WV:ReadinessFiniteState','A physical inventory is nonfinite.'); end
end
snapshot = struct(t=w.t,state=state,inventory=inventory,mean=meanInventory,processLabels=processes.labels);
end
function w = restoredSnapshot(run,k)
snapshot = run.snapshots{k};
w = WVTransformFreeSurfaceThermalQG(scientificState=run.scientificState,coefficientState=snapshot.state,t=snapshot.t);
w.t0 = run.manifest.configuration.t0;
end
function [result,processWork] = budgetReport(name,run)
fields=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"];
times=cellfun(@(s)s.t,run.snapshots);
floors=run.inventoryFloors;
result=table(); processWork=table();
labels=run.snapshots{1}.processLabels;
for k=1:numel(run.snapshots)
    if ~isequal(run.snapshots{k}.processLabels,labels), error('WV:ReadinessBudgetProcesses','The registered process labels changed during the window.'); end
end
for j=1:numel(fields)
    values=cellfun(@(s)s.inventory.(fields(j)),run.snapshots);
    rates=cell2mat(cellfun(@(s)reshape(s.inventory.(fields(j)+"Tendency"),1,[]),run.snapshots,UniformOutput=false).');
    work=trapz(times,rates,1); retained=unique([1:2:numel(times),numel(times)]);
    coarseWork=trapz(times(retained),rates(retained,:),1);
    meanRates=cell2mat(cellfun(@(s)reshape(s.mean.(fields(j)+"Tendency"),1,[]),run.snapshots,UniformOutput=false).');
    meanWork=trapz(times,meanRates,1);
    for p=1:numel(labels)
        row=table(name,run.executionId,run.initialCaseId,fields(j),labels(p),work(p),meanWork(p),abs(work(p)-coarseWork(p)),VariableNames={'caseName','executionId','initialCaseId','inventory','process','integratedWork','meanIntegratedWork','samplingUncertainty'});
        processWork=[processWork;row]; %#ok<AGROW>
    end
    change=values(end)-values(1); residual=change-sum(work);
    scale=max([abs(values(1)),abs(change),sum(abs(work))]);
    allowance=floors(j)+run.inventoryRelativeAllowance*scale; samplingUncertainty=sum(abs(work-coarseWork));
    relativeResidual=NaN; if scale>floors(j), relativeResidual=abs(residual)/scale; end
    status="INCONCLUSIVE";
    if numel(times)>=5 && samplingUncertainty<=run.maximumUncertaintyFraction*allowance
        if abs(residual)<=allowance, status="PASS"; else, status="FAIL"; end
    end
    row=table(name,run.executionId,run.initialCaseId,fields(j),residual,relativeResidual,scale,floors(j),allowance,samplingUncertainty,status,VariableNames={'caseName','executionId','initialCaseId','inventory','residual','relativeResidual','scale','absoluteFloor','allowance','samplingUncertainty','status'});
    result=[result;row]; %#ok<AGROW>
end
end
function effective = validateAxis(a,b,runA,runB,axis,checkActualSteps)
if nargin<6, checkActualSteps=true; end
allowed=struct(time=strings(1,0),product_sampling="productCount",thermal_bandwidth="thermalCount",native_sampling="Nz",horizontal_bandwidth=["Nx","Ny"],mean_bandwidth="mdaCount");
key=replace(axis," ","_");
if ~isfield(allowed,key), error('WV:ReadinessAxis','This driver does not implement axis %s.',axis); end
a.configuration=runA.manifest.configuration; b.configuration=runB.manifest.configuration;
names=string(fieldnames(a.configuration));
effective=true; changed=false;
for name=allowed.(key)
    if b.configuration.(name)<a.configuration.(name)
        error('WV:ReadinessReferenceOrder','The %s reference must be at least as fine in %s.',axis,name);
    end
    changed=changed || b.configuration.(name)>a.configuration.(name);
end
if axis=="time"
    if b.step>=a.step, error('WV:ReadinessReferenceOrder','A temporal reference must request a smaller maximum step.'); end
    if checkActualSteps
        effective=~isempty(runA.acceptedStepSeconds) && ~isempty(runB.acceptedStepSeconds) && max(runB.acceptedStepSeconds)<max(runA.acceptedStepSeconds)*(1-32*eps);
    end
end
if ismember(axis,["time","product sampling"])
    scienceA=runA.scientificState; scienceB=runB.scientificState;
    if axis=="product sampling"
        changing={'nonlinearQuadratureCount','nonlinearQuadratureResidual','nonlinearReferenceResidual'};
        scienceA=rmfield(scienceA,changing); scienceB=rmfield(scienceB,changing);
    end
    if ~isequaln(scienceA,scienceB)
        error('WV:ReadinessHeldScientificState','The %s comparison changes authoritative scientific arrays outside its declared axis.',axis);
    end
end
if runA.manifest.actualAssemblyCount~=runB.manifest.actualAssemblyCount
    error('WV:ReadinessAxis','A one-axis trajectory comparison must hold the actual assembly quadrature fixed, including automatically selected counts.');
end
if axis=="product sampling"
    if a.configuration.productCount==0 || b.configuration.productCount==0 || runB.manifest.actualProductCount<=runA.manifest.actualProductCount
        error('WV:ReadinessReferenceOrder','Product sampling references require explicitly declared and actually increasing counts.');
    end
elseif runA.manifest.actualProductCount~=runB.manifest.actualProductCount
    error('WV:ReadinessAxis','A one-axis trajectory comparison must hold the actual product quadrature fixed, including automatically selected counts.');
end
for name=names.'
    if ismember(name,allowed.(key)), continue; end
    if ~isfield(a.configuration,name) || ~isfield(b.configuration,name) || ~isequaln(a.configuration.(name),b.configuration.(name))
        error('WV:ReadinessAxis','The %s comparison also changes %s.',axis,name);
    end
end
if axis~="time" && (a.step~=b.step || a.adaptive~=b.adaptive || a.relTolerance~=b.relTolerance || ~isequal(a.physicalAbsTolerance,b.physicalAbsTolerance))
    error('WV:ReadinessAxis','A spatial comparison must hold the integrator settings fixed.');
end
if axis~="time" && ~changed, error('WV:ReadinessAxis','The named %s axis does not change.',axis); end
if a.dampingVariant~=b.dampingVariant, error('WV:ReadinessAxis','Closure changes require a separately labeled physics comparison.'); end
end

function floors=inventoryFloors(w,criteria,count)
[x,weights]=legpts(count); z=(x-1)*w.Lz/2; weights=weights(:)*w.Lz/2;
floorFor=@(name)criteria.absoluteFloor(criteria.observable==name);
minimumN2=min(w.N2Function([-w.Lz;0]));
liftNorm=sqrt(sum(weights.*w.N2Function(z).*(1+z/w.Lz).^2));
energy=.5*w.Lz*floorFor("velocity")^2+.5*(sqrt(w.Lz/minimumN2)*floorFor("buoyancy")+liftNorm*floorFor("ssh"))^2+.5*w.g*floorFor("ssh")^2;
floors=[energy,.5*w.Lz*floorFor("qgpv")^2,.5*floorFor("surfaceAnomaly")^2,.5*floorFor("bottomAnomaly")^2];
end
function appendTable(path,row)
if isempty(row), return; end
if isfile(path)
    existing=readtable(path,TextType='string');
    if ~isequal(existing.Properties.VariableNames,row.Properties.VariableNames), error('WV:ReadinessLedgerSchema','Existing ledger columns changed.'); end
    writetable(row,path,WriteMode='append',WriteVariableNames=false);
else
    writetable(row,path);
end
end
function writeJSON(path,value)
fid=fopen(path,'w'); if fid<0, error('WV:ReadinessWrite','Cannot create %s.',path); end
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,PrettyPrint=true));
end
