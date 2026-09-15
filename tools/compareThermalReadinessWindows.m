function report=compareThermalReadinessWindows(candidatePath,referencePath,outputFolder,options)
% Compare a saved pair that changes only closure or nonlinear advection.
%
% The window files and their parent run-contract.mat files are authoritative.
% Scientific arrays are restored without construction. Field measurements use
% the same common physical maps as qualifyThermalReadiness, with a doubled
% quadrature check. A bias screen is separate from numerical qualification.
% Process work remains signed and separated by its recorded process label.
% Regime maxima sample recorded times and native spatial grids only.
%
% - Topic: Developer utilities
% - Parameter candidatePath: candidate case's saved window.mat
% - Parameter referencePath: companion case's saved window.mat
% - Parameter outputFolder: new destination for immutable comparison tables
% - Parameter options.kind: closure bias or nonlinear activity
% - Parameter options.comparisonCount: initial common physical quadrature count
% - Returns report: bounded bias/activity screen, signed work and sampled regime indicators
arguments (Input)
    candidatePath (1,1) string {mustBeFile}
    referencePath (1,1) string {mustBeFile}
    outputFolder (1,1) string
    options.kind (1,1) string {mustBeMember(options.kind,["closure bias","nonlinear activity"])}
    options.comparisonCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.comparisonCount,65)} = 513
end
arguments (Output)
    report (1,1) struct
end
if ~isfield(options,'kind'), error('WV:ReadinessWindowKind','Declare closure bias or nonlinear activity.'); end
if isfolder(outputFolder) && ~isempty(dir(fullfile(outputFolder,'*.csv')))
    error('WV:ReadinessWindowOutput','Use a new comparison directory to preserve earlier evidence.');
end
[a,ca]=readWindow(candidatePath); [b,cb]=readWindow(referencePath);
validatePair(a,b,ca,cb,options.kind);
criteria=thermalReadinessCriteria();
if options.kind=="closure bias", criteria.relativeAllowance(:)=.05; end
comparisons=table(); activity=table(); regime=table();
for k=1:numel(a.snapshots)
    wa=restoreSnapshot(a,k); candidateCleanup=onCleanup(@()releaseTransform(wa));
    wb=restoreSnapshot(b,k); referenceCleanup=onCleanup(@()releaseTransform(wb));
    coarse=compareThermalReadinessFields(wa,wb,options.comparisonCount,criteria);
    fine=compareThermalReadinessFields(wa,wb,2*options.comparisonCount+1,criteria);
    fine.quadratureUncertainty=abs(fine.error-coarse.error)+fine.relativeAllowance.*abs(fine.referenceNorm-coarse.referenceNorm);
    fine.allowance=fine.absoluteFloor+fine.relativeAllowance.*fine.referenceNorm;
    fine.time=repmat(wa.t,height(fine),1);
    fine.status=repmat("MEASUREMENT",height(fine),1);
    if options.kind=="closure bias"
        resolved=fine.quadratureUncertainty<=.2*fine.allowance;
        fine.status(:)="INCONCLUSIVE SAMPLING";
        fine.status(resolved & fine.error+fine.quadratureUncertainty<=fine.allowance)="WITHIN BIAS SCREEN";
        fine.status(resolved & fine.error-fine.quadratureUncertainty>fine.allowance)="EXCEEDS BIAS SCREEN";
    else
        selected=ismember(fine.observable,["qgpv","velocity"]);
        row=fine(selected,:);
        row.activityThreshold=5*row.allowance;
        row.status(:)="NOT MEASURABLE AT THIS TIME";
        resolved=row.quadratureUncertainty<=.2*row.allowance;
        row.status(~resolved)="INCONCLUSIVE SAMPLING";
        row.status(resolved & row.error-row.quadratureUncertainty>row.activityThreshold)="MEASURABLE";
        activity=[activity;row]; %#ok<AGROW>
    end
    comparisons=[comparisons;fine]; %#ok<AGROW>
    regime=[regime;regimeAtSnapshot(wa,"candidate");regimeAtSnapshot(wb,"reference")]; %#ok<AGROW>
    clear candidateCleanup referenceCleanup wa wb
end
work=[signedWork(a,"candidate");signedWork(b,"reference")];
status="INCONCLUSIVE";
if options.kind=="closure bias"
    if all(comparisons.status=="WITHIN BIAS SCREEN"), status="WITHIN BIAS SCREEN"; end
    if any(comparisons.status=="EXCEEDS BIAS SCREEN"), status="EXCEEDS BIAS SCREEN"; end
elseif any(activity.status=="MEASURABLE")
    status="MEASURABLE NONLINEAR ACTIVITY";
end
report=struct(kind=options.kind,status=status,candidatePath=candidatePath,referencePath=referencePath,candidateInitialCaseId=a.manifest.caseId,referenceInitialCaseId=b.manifest.caseId,candidateExecutionId=ca.executionId,referenceExecutionId=cb.executionId,candidateVariant=a.dampingVariant,referenceVariant=b.dampingVariant,comparisons=comparisons,activity=activity,processWork=work,regime=regime,options=options,scope="matched bounded windows only; temporal/spatial reference qualification remains separate",regimeSampling="maxima on each recorded native spatial grid; not continuous-space or between-observation bounds");
if ~isfolder(outputFolder), mkdir(outputFolder); end
writetable(comparisons,fullfile(outputFolder,'field-comparisons.csv'));
if ~isempty(activity), writetable(activity,fullfile(outputFolder,'nonlinear-activity.csv')); end
writetable(work,fullfile(outputFolder,'signed-process-work.csv'));
writetable(regime,fullfile(outputFolder,'sampled-regime.csv'));
save(fullfile(outputFolder,'comparison.mat'),'report');
end

function [run,execution]=readWindow(path)
loaded=load(path,'run');
if ~isfield(loaded,'run'), error('WV:ReadinessWindowSchema','The saved file lacks run.'); end
run=loaded.run;
required={'manifest','scientificState','snapshots','dampingVariant'};
if ~isscalar(run) || ~all(isfield(run,required)) || ~iscell(run.snapshots) || numel(run.snapshots)<3
    error('WV:ReadinessWindowSchema','Supply a completed qualification window with at least three observations.');
end
manifest=run.manifest;
if thermalReadinessIdentity(rmfield(manifest,'caseId'))~=manifest.caseId || thermalReadinessIdentity(run.scientificState)~=manifest.scientificStateHash || thermalReadinessIdentity(run.snapshots{1}.state)~=manifest.coefficientStateHash
    error('WV:ReadinessWindowIdentity','Stored scientific/initial arrays disagree with the case manifest.');
end
times=cellfun(@(s)s.t,run.snapshots);
if any(~isfinite(times)) || any(diff(times)<=0) || times(1)~=manifest.configuration.t
    error('WV:ReadinessWindowTimes','Recorded times must increase from the declared initial time.');
end
caseFolder=fileparts(path); [parent,name]=fileparts(caseFolder);
contractPath=fullfile(parent,'run-contract.mat');
if ~isfile(contractPath), error('WV:ReadinessWindowContract','Required run contract is missing: %s.',contractPath); end
stored=load(contractPath,'contract'); contract=stored.contract;
if thermalReadinessIdentity(rmfield(contract,'runId'))~=contract.runId
    error('WV:ReadinessWindowIdentity','The stored run contract does not match its identity.');
end
index=find(string({contract.cases.name})==string(name));
if ~isscalar(index), error('WV:ReadinessWindowContract','The window folder must name one declared case.'); end
execution=contract.cases(index); execution.canonicalDamping=contract.options.canonicalDamping;
execution.executionId=thermalReadinessIdentity(struct(runId=contract.runId,caseName=string(name)));
if isfield(contract,'schema') && contract.schema=="thermal-readiness-window-v2" && ~all(isfield(run,{'executionId','initialCaseId','runId'}))
    error('WV:ReadinessWindowIdentity','A v2 window must retain its execution, initial-case and run identities.');
end
for field=["executionId","initialCaseId","runId"]
    expected=execution.executionId;
    if field=="initialCaseId", expected=manifest.caseId; elseif field=="runId", expected=contract.runId; end
    if isfield(run,field) && run.(field)~=expected
        error('WV:ReadinessWindowIdentity','The stored %s disagrees with the authoritative run contract.',field);
    end
end
if execution.dampingVariant~=run.dampingVariant
    error('WV:ReadinessWindowContract','The saved damping variant differs from the declared run contract.');
end
end

function validatePair(a,b,ca,cb,kind)
ac=a.manifest.configuration; bc=b.manifest.configuration;
if kind=="nonlinear activity"
    if ~ac.shouldIncludeAdvection || bc.shouldIncludeAdvection || a.dampingVariant~=b.dampingVariant
        error('WV:ReadinessWindowPair','Activity requires an advection-enabled candidate and disabled companion with the same closure.');
    end
    ac=rmfield(ac,'shouldIncludeAdvection'); bc=rmfield(bc,'shouldIncludeAdvection');
elseif a.dampingVariant==b.dampingVariant
    error('WV:ReadinessWindowPair','A closure-bias comparison must change the optional closure.');
end
if ~isequaln(ac,bc) || ~isequaln(a.scientificState,b.scientificState) || ~isequaln(a.snapshots{1}.state,b.snapshots{1}.state)
    error('WV:ReadinessWindowPair','Mechanism pairs must retain the same geometry, scientific arrays, initial state and other physical configuration.');
end
if ~isequal(cellfun(@(s)s.t,a.snapshots),cellfun(@(s)s.t,b.snapshots))
    error('WV:ReadinessWindowPair','Mechanism pairs must use identical observation times.');
end
for name=["step","adaptive","relTolerance","physicalAbsTolerance"]
    if ~isequaln(ca.(name),cb.(name)), error('WV:ReadinessWindowPair','Mechanism pairs must retain integrator setting %s.',name); end
end
if a.dampingVariant~="none" && b.dampingVariant~="none" && ~isequaln(ca.canonicalDamping,cb.canonicalDamping)
    error('WV:ReadinessWindowPair','A pair with two closures must retain the same frozen canonical closure arrays.');
end
end

function w=restoreSnapshot(run,k)
s=run.snapshots{k};
w=WVTransformFreeSurfaceThermalQG(scientificState=run.scientificState,coefficientState=s.state,t=s.t);
try
    w.t0=run.manifest.configuration.t0;
catch exception
    delete(w);
    rethrow(exception);
end
end

function releaseTransform(w)
if ~isempty(w) && isvalid(w),delete(w);end
end

function row=regimeAtSnapshot(w,role)
fields=w.reconstructFields(["eta","eta_i","u","v","ssu","ssv"]);
displacementDepth=max(abs(fields.eta),[],'all')/w.Lz;
interiorDisplacementDepth=max(abs(fields.eta_i),[],'all')/w.Lz;
relativeVorticity=max(abs(w.diffX(fields.v)-w.diffY(fields.u)),[],'all')/abs(w.f);
surfaceSlope=abs(w.f)/w.g*max(hypot(fields.ssu,fields.ssv),[],'all');
orderOne=max([displacementDepth,interiorDisplacementDepth,relativeVorticity,surfaceSlope])>=1;
row=table(role,w.t,w.Nx,w.Ny,w.Nz,displacementDepth,interiorDisplacementDepth,relativeVorticity,surfaceSlope,orderOne,VariableNames={'role','time','Nx','Ny','Nz','maximumEtaOverDepth','maximumInteriorEtaOverDepth','maximumVorticityOverF','maximumSurfaceSlope','orderOneFlag'});
end

function result=signedWork(run,role)
result=table(); times=cellfun(@(s)s.t,run.snapshots); labels=run.snapshots{1}.processLabels;
for k=1:numel(run.snapshots)
    if ~isequal(run.snapshots{k}.processLabels,labels), error('WV:ReadinessWindowProcesses','Recorded process labels change within a window.'); end
end
for name=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
    rates=cell2mat(cellfun(@(s)reshape(s.inventory.(name+"Tendency"),1,[]),run.snapshots,UniformOutput=false).');
    if any(~isfinite(rates),'all') || size(rates,2)~=numel(labels), error('WV:ReadinessWindowProcesses','Recorded inventory rates must match finite labeled processes.'); end
    work=trapz(times,rates,1); retained=unique([1:2:numel(times),numel(times)]);
    uncertainty=abs(work-trapz(times(retained),rates(retained,:),1));
    positive=trapz(times,max(rates,0),1); negative=trapz(times,min(rates,0),1);
    for j=1:numel(labels)
        result=[result;table(role,run.dampingVariant,name,labels(j),work(j),positive(j),negative(j),uncertainty(j),VariableNames={'role','dampingVariant','inventory','process','signedIntegratedWork','positiveIntegratedWork','negativeIntegratedWork','samplingUncertainty'})]; %#ok<AGROW>
    end
end
end
