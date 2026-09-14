function results = qualifyThermalReadinessRestart(initial,outputFolder,options)
% Qualify bounded continuation through the existing committed-output protocol.
% The caller supplies the authoritative physical state and frozen forcings.
% Run restoreOnly in a fresh MATLAB process with all InternalModes paths absent.
% Scientific arrays, output observers and forcing are restored by shared APIs.
% - Topic: Developer utilities
% - Parameter initial: thermal transform, or [] for the fresh-process replay
% - Parameter outputFolder: new artifact directory; repeated phases are rejected
% - Parameter options.duration: simulated seconds, at least six integral steps
% - Parameter options.step: selected fixed maximum step in seconds
% - Parameter options.restoreOnly: replay the stored contract without a provider
% - Returns results: state, field, clock, committed-prefix and I/O measurements
arguments (Input)
    initial
    outputFolder (1,1) string
    options.duration (1,1) double {mustBeFinite,mustBePositive} = 21600
    options.step (1,1) double {mustBeFinite,mustBePositive} = 3600
    options.maximumWallSeconds (1,1) double {mustBeFinite,mustBePositive} = 1800
    options.caseId (1,1) string = "unspecified"
    options.restoreOnly (1,1) logical = false
end
arguments (Output)
    results (1,1) struct
end
clock=tic;
if options.restoreOnly
    if ~isempty(initial) || ~isempty(which('IMInternalModes')) || ~isempty(which('IMSolverSpectral'))
        error('WV:ReadinessRestartProvider','Replay with initial=[] in a fresh process after removing every InternalModes provider.');
    end
    reference=load(fullfile(outputFolder,'restart-reference.mat'));
    contract=reference.contract;
    if thermalReadinessIdentity(rmfield(contract,'runId'))~=contract.runId
        error('WV:ReadinessRestartIdentity','The stored restart contract identity changed.');
    end
    [row,streams]=continueCheckpoint(outputFolder,"fresh",reference,clock,options.maximumWallSeconds);
    results=struct(contract=contract,continuation=row,streams=streams,status="PASS: provider-unavailable bounded continuation");
    save(fullfile(outputFolder,'fresh-results.mat'),'results');
    return
end
if ~isa(initial,'WVTransformFreeSurfaceThermalQG') || ~isscalar(initial) || initial.uvMax<=0
    error('WV:ReadinessRestartInitial','Supply one initialized thermal transform with nonzero horizontal flow and its selected forcings.');
end
stepCount=options.duration/options.step;
if stepCount<6 || abs(stepCount-round(stepCount))>64*eps(max(1,stepCount))
    error('WV:ReadinessRestartWindow','Use at least six integral maximum steps to separate the checkpoint, independent observer and staged tail.');
end
if isfile(fullfile(outputFolder,'restart-contract.mat'))
    error('WV:ReadinessRestartExists','Use a new directory; an existing lifecycle contract is immutable.');
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
initialState=initial.coefficientState(); initialForcing=forcingConfiguration(initial);
contract=struct(schema="thermal-readiness-restart-v1",caseId=options.caseId,initialTime=initial.t,t0=initial.t0,duration=options.duration,step=options.step,finalTime=initial.t+options.duration,checkpointTime=initial.t+2*options.step,interruptedTime=initial.t+3*options.step,coefficientInterval=2*options.step,fieldInitialTime=initial.t+options.step/4,fieldInterval=options.step,inventoryInitialTime=initial.t+options.step/3,inventoryInterval=2*options.step/3,domainSize=initial.domainSize,gridSize=initial.gridSize,thermalCount=initial.thermalModeCount,mdaCount=initial.mdaModeCount,scientificHash=thermalReadinessIdentity(initial.scientificState),initialStateHash=thermalReadinessIdentity(initialState),forcingHash=thermalReadinessIdentity(initialForcing),relativeAllowance=1e-10,absoluteAllowance=1e-12,endpointComparison="surface and bottom independently",integrationBoundarySemantics="all paths stop at interruptedTime and at blocks of at most two requested maximum steps",wallBudgetSemantics="cooperative between setup and integration blocks of two requested maximum steps; no preemption within an RHS or file operation");
contract.runId=thermalReadinessIdentity(contract);
save(fullfile(outputFolder,'restart-contract.mat'),'contract');
writeJSON(fullfile(outputFolder,'restart-contract.json'),contract);

checkBudget(clock,options.maximumWallSeconds);
reportPhase("control: clone and integrator setup start",clock);
control=cloneModel(initial,contract); controlCleanup=onCleanup(@()releaseModel(control));
reportPhase("control: output setup start",clock);
timer=tic; configureOutput(control,fullfile(outputFolder,'control.nc'),contract); controlOutputSetupSeconds=toc(timer);
reportPhase("control: output setup complete; integration start",clock);
timer=tic; controlStats=integrate(control,contract.finalTime,contract,clock,options.maximumWallSeconds); controlSeconds=toc(timer);
final=snapshot(control.wvt,contract); control.closeNetCDFFile(); clear controlCleanup control
reportPhase("control released",clock);

checkBudget(clock,options.maximumWallSeconds);
reportPhase("interrupted: clone and integrator setup start",clock);
model=cloneModel(initial,contract); modelCleanup=onCleanup(@()releaseModel(model));
reportPhase("interrupted: output setup start",clock);
timer=tic; file=configureOutput(model,fullfile(outputFolder,'checkpoint.nc'),contract); checkpointSetupSeconds=toc(timer);
reportPhase("interrupted: output setup complete; integration start",clock);
timer=tic; checkpointStats=integrate(model,contract.checkpointTime,contract,clock,options.maximumWallSeconds); checkpointSeconds=toc(timer);
checkpoint=snapshot(model.wvt,contract);
integrate(model,contract.interruptedTime,contract,clock,options.maximumWallSeconds);
% Commit independent observations later than the last complete coefficient
% state. Then write deliberately wrong payloads without finite time commits.
model.wvt.Ath=3*model.wvt.Ath; model.wvt.Amda=3*model.wvt.Amda;
for group=reshape(file.outputGroups,1,[])
    index=group.stageTimeStepToNetCDFFile(file.ncfile,contract.interruptedTime+options.step);
    if index==0, error('WV:ReadinessRestartTail','Every output group must stage an uncommitted payload.'); end
end
timer=tic; file.ncfile.sync(); model.closeNetCDFFile(); syncAndCloseSeconds=toc(timer); clear modelCleanup model file group
reportPhase("interrupted model released",clock);
prefix=checkStagedPrefix(fullfile(outputFolder,'checkpoint.nc'),contract);
writetable(prefix,fullfile(outputFolder,'staged-prefix.csv'));
save(fullfile(outputFolder,'restart-reference.mat'),'contract','checkpoint','final','prefix','-v7.3');
reference=struct(contract=contract,checkpoint=checkpoint,final=final,prefix=prefix);
[row,streams]=continueCheckpoint(outputFolder,"continued",reference,clock,options.maximumWallSeconds);
checkpointInfo=dir(fullfile(outputFolder,'checkpoint.nc')); controlInfo=dir(fullfile(outputFolder,'control.nc')); referenceInfo=dir(fullfile(outputFolder,'restart-reference.mat'));
setup=table(controlOutputSetupSeconds,controlSeconds,checkpointSetupSeconds,checkpointSeconds,syncAndCloseSeconds,checkpointInfo.bytes,controlInfo.bytes,referenceInfo.bytes,toc(clock),VariableNames={'controlOutputSetupSeconds','controlIntegrationSeconds','checkpointOutputSetupSeconds','checkpointIntegrationSeconds','checkpointSyncAndCloseSeconds','checkpointBytes','controlBytes','referenceMATBytes','totalWallSeconds'});
writetable(setup,fullfile(outputFolder,'restart-setup.csv'));
if ~isequal(initial.coefficientState(),initialState) || initial.t~=contract.initialTime || initial.t0~=contract.t0 || ~isequal(forcingConfiguration(initial),initialForcing)
    error('WV:ReadinessRestartMutation','Lifecycle qualification must leave the authoritative initial transform unchanged.');
end
results=struct(contract=contract,setup=setup,continuation=row,streams=streams,controlStatistics=controlStats,checkpointStatistics=checkpointStats,status="CONDITIONAL: fresh-process provider-unavailable replay required");
save(fullfile(outputFolder,'restart-results.mat'),'results');
end

function model=cloneModel(initial,c)
w=WVTransformFreeSurfaceThermalQG(scientificState=initial.scientificState,coefficientState=initial.coefficientState(),t=initial.t);
model=[];
try
    w.t0=initial.t0;
    if ~isequal(w.scientificState,initial.scientificState) || ~isequal(w.coefficientState(),initial.coefficientState()) || w.t~=initial.t || w.t0~=initial.t0
        error('WV:ReadinessRestartCanonical','Cheap construction must restore scientific arrays, coefficients and clocks exactly.');
    end
    WVInternal.transferFreeSurfaceForcing(initial,w);
    model=WVModel(w); configureIntegrator(model,c);
catch exception
    % Outer cleanup starts only after this helper returns successfully.
    if ~isempty(model), releaseModel(model); end
    if isvalid(w), delete(w); end
    rethrow(exception);
end
end
function configureIntegrator(model,c)
linear=~any(arrayfun(@(f)isa(f,'WVNonlinearAdvection'),model.wvt.forcing));
model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=linear,initialStep=c.step,maximumStep=c.step,exponentialAdaptive=false,physicalAbsTolerance=[1e-14 1e-12 1e-10 1e-10 1e-10],relTolerance=1e-8);
end
function file=configureOutput(model,path,c)
file=model.createNetCDFFileForModelOutput(char(path),outputInterval=c.coefficientInterval,shouldOverwriteExisting=false);
group=file.addNewEvenlySpacedOutputGroup('fields',initialTime=c.fieldInitialTime,outputInterval=c.fieldInterval,finalTime=c.finalTime);
group.addObservingSystem(WVEulerianFields(model,fieldNames={'ssh','endpointAnomalies'}));
group=file.addNewEvenlySpacedOutputGroup('inventory',initialTime=c.inventoryInitialTime,outputInterval=c.inventoryInterval,finalTime=c.finalTime);
group.addObservingSystem(ThermalReadinessInventoryObserver(model));
model.outputTimesForIntegrationPeriod(model.t,c.finalTime);
model.writeTimeStepToNetCDFFile(model.t); file.ncfile.sync();
end
function statistics=integrate(model,target,c,clock,budget)
statistics=struct(acceptedSteps=0,rejectedSteps=0,rhsEvaluations=0,outputRhsEvaluations=0,acceptedStepSeconds=[]);
while model.t<target
    checkBudget(clock,budget);
    boundary=min(target,model.t+2*c.step);
    if model.t<c.interruptedTime, boundary=min(boundary,c.interruptedTime); end
    model.integrateToTime(boundary,shouldShowIntegrationDiagnostics=false);
    s=model.exponentialStatistics;
    for name=["acceptedSteps","rejectedSteps","rhsEvaluations","outputRhsEvaluations"], statistics.(name)=statistics.(name)+s.(name); end
    statistics.acceptedStepSeconds=[statistics.acceptedStepSeconds,s.acceptedStepSeconds];
end
end
function value=snapshot(w,c)
timer=tic;
fprintf('T10 restart snapshot t=%.9g: field reconstruction start\n',w.t);
fields=w.reconstructFields(["u","v","qgpv","buoyancy","ssh","endpointAnomalies"]);
fprintf('T10 restart snapshot t=%.9g: fields complete %.3gs; physical energy start\n',w.t,toc(timer));
energy=w.totalEnergy;
fprintf('T10 restart snapshot t=%.9g: physical energy complete %.3gs\n',w.t,toc(timer));
value=struct(t=w.t,t0=w.t0,coefficients=w.coefficientState(),fields=fields,energy=energy,scientificHash=thermalReadinessIdentity(w.scientificState),forcing={forcingConfiguration(w)});
if value.scientificHash~=c.scientificHash || thermalReadinessIdentity(value.forcing)~=c.forcingHash
    error('WV:ReadinessRestartIdentity','Scientific arrays or frozen forcing changed during the lifecycle run.');
end
end
function value=forcingConfiguration(w)
value=cell(1,numel(w.forcing));
for j=1:numel(w.forcing)
    f=w.forcing(j); entry=struct(class=string(class(f)),name=string(f.name),priority=f.priority);
    for name=string(f.requiredProperties), entry.(name)=f.(name); end
    value{j}=entry;
end
end
function [row,streams]=continueCheckpoint(folder,phase,reference,clock,budget)
c=reference.contract; destination=fullfile(folder,phase+".nc");
if isfile(destination), error('WV:ReadinessRestartExists','The %s replay already has an artifact; use its recorded results or a new lifecycle directory.',phase); end
checkBudget(clock,budget); copyfile(fullfile(folder,'checkpoint.nc'),destination);
reportPhase(phase+": modelFromFile start",clock);
timer=tic; model=WVModel.modelFromFile(char(destination)); readSeconds=toc(timer);
reportPhase(phase+": modelFromFile complete",clock);
cleanup=onCleanup(@()releaseModel(model));
if ~isequal(model.wvt.coefficientState(),reference.checkpoint.coefficients)
    error('WV:ReadinessRestartCanonical','The committed coefficient checkpoint must restore exactly before continuation.');
end
reportPhase(phase+": checkpoint comparison start",clock);
[checkpointCoefficientError,checkpointFieldError,~]=compareSnapshot(model.wvt,reference.checkpoint,c);
reportPhase(phase+": checkpoint comparison complete",clock);
if ~isempty(fieldnames(model.wvt.constructionAssessment)), error('WV:ReadinessRestartConstruction','Annotated restoration must not report scientific construction.'); end
% Restore each group's valid prefix, including independent observations
% later than the coefficient checkpoint. Staged payloads are not commits.
for group=reshape(model.outputFiles(1).outputGroups,1,[])
    index=find(reference.prefix.group==string(group.name));
    if ~isscalar(index) || group.incrementsWrittenToGroup~=reference.prefix.committedRecords(index) || group.timeOfLastIncrementWrittenToGroup~=reference.prefix.lastTime(index)
        error('WV:ReadinessRestartPrefix','The restored output counters differ from the authoritative committed prefix.');
    end
end
reportPhase(phase+": integrator setup start",clock);
configureIntegrator(model,c);
reportPhase(phase+": integrator setup complete; integration start",clock);
timer=tic; statistics=integrate(model,c.finalTime,c,clock,budget); continuationSeconds=toc(timer);
reportPhase(phase+": integration complete; final comparison start",clock);
[coefficientError,fieldError,energyError]=compareSnapshot(model.wvt,reference.final,c);
reportPhase(phase+": final comparison complete",clock);
model.closeNetCDFFile(); clear cleanup model group
reportPhase(phase+": model released; stream comparison start",clock);
streams=compareStreams(destination,fullfile(folder,'control.nc'),c);
reportPhase(phase+": stream comparison complete",clock);
writetable(streams,fullfile(folder,phase+"-streams.csv"));
info=dir(destination);
row=table(phase,checkpointCoefficientError,checkpointFieldError,coefficientError,fieldError,energyError,readSeconds,continuationSeconds,info.bytes,statistics.acceptedSteps,statistics.rhsEvaluations,statistics.outputRhsEvaluations,VariableNames={'phase','checkpointCoefficientError','checkpointFieldError','coefficientError','fieldError','energyError','readSeconds','continuationSeconds','continuedBytes','acceptedSteps','rhsEvaluations','outputRhsEvaluations'});
writetable(row,fullfile(folder,phase+"-restart.csv"));
end
function [coefficientError,fieldError,energyError]=compareSnapshot(w,expected,c)
actual=snapshot(w,c);
if w.t~=expected.t || w.t0~=expected.t0 || ~isequal(actual.forcing,expected.forcing) || actual.scientificHash~=expected.scientificHash
    error('WV:ReadinessRestartIdentity','Restoration must preserve the exact clock, forcing and scientific arrays.');
end
coefficientError=0; fieldError=0;
for name=["Ath","Amda"]
    [relative,accepted]=errorMetric(actual.coefficients.(name),expected.coefficients.(name),c);
    if isfinite(relative), coefficientError=max(coefficientError,relative); end
    if ~accepted, error('WV:ReadinessRestartState','The %s state exceeds the declared restart allowance.',name); end
end
for name=string(fieldnames(actual.fields)).'
    a=actual.fields.(name); b=expected.fields.(name); labels=name;
    if name=="endpointAnomalies", labels=["surfaceAnomaly","bottomAnomaly"]; end
    for endpoint=1:numel(labels)
        av=a; bv=b;
        if name=="endpointAnomalies", av=a(:,:,endpoint); bv=b(:,:,endpoint); end
        [relative,accepted]=errorMetric(av,bv,c);
        if isfinite(relative), fieldError=max(fieldError,relative); end
        if ~accepted, error('WV:ReadinessRestartField','The %s field exceeds the declared restart allowance.',labels(endpoint)); end
    end
end
[energyError,accepted]=errorMetric(actual.energy,expected.energy,c);
if ~accepted, error('WV:ReadinessRestartEnergy','Physical energy exceeds the declared restart allowance.'); end
end
function prefix=checkStagedPrefix(path,c)
file=NetCDFFile(char(path)); cleanup=onCleanup(@()file.close()); prefix=table();
if any(ismember(["Ath","Amda"],string([{file.realVariables.name},{file.complexVariables.name}])))
    error('WV:ReadinessRestartScientificRoot','Root storage must contain scientific state without duplicate coefficient streams.');
end
for name=["thermalToPolynomial","polynomialToThermal","sourceDual","mdaGeneratorPerDiffusivity"]
    if ismember('t',{file.variableWithName(name).dimensions.name}), error('WV:ReadinessRestartScientificRoot','Scientific arrays must not acquire a time dimension.'); end
end
for name=["wave-vortex","fields","inventory"]
    group=file.groupWithName(name); committed=WVModelOutputGroup.committedRecordCountForGroup(group); raw=group.dimensionWithName('t').nPoints;
    times=group.readVariables('t');
    if committed<1 || raw<=committed || any(isfinite(times(committed+1:end))), error('WV:ReadinessRestartTail','Every stream needs a finite committed prefix followed by an uncommitted payload.'); end
    lastTime=times(committed);
    if name=="wave-vortex" && lastTime~=c.checkpointTime, error('WV:ReadinessRestartPrefix','The coefficient checkpoint time is not the declared accepted boundary.'); end
    if name~="wave-vortex" && lastTime<=c.checkpointTime, error('WV:ReadinessRestartPrefix','Independent observations must extend beyond the coefficient checkpoint.'); end
    prefix=[prefix;table(name,committed,raw,lastTime,VariableNames={'group','committedRecords','rawRecords','lastTime'})]; %#ok<AGROW>
end
end
function rows=compareStreams(actualPath,referencePath,c)
actual=NetCDFFile(char(actualPath)); ca=onCleanup(@()actual.close()); reference=NetCDFFile(char(referencePath)); cr=onCleanup(@()reference.close()); rows=table();
for name=["wave-vortex","fields","inventory"]
    A=actual.groupWithName(name); R=reference.groupWithName(name);
    count=WVModelOutputGroup.committedRecordCountForGroup(A); referenceCount=WVModelOutputGroup.committedRecordCountForGroup(R);
    if count~=referenceCount, error('WV:ReadinessRestartPrefix','Resumed and uninterrupted streams differ in committed length.'); end
    aTimes=A.readVariables('t'); rTimes=R.readVariables('t');
    if A.dimensionWithName('t').nPoints~=count || R.dimensionWithName('t').nPoints~=referenceCount, error('WV:ReadinessRestartTail','Completed output must replace every staged tail payload.'); end
    if ~isequal(aTimes(1:count),rTimes(1:count)), error('WV:ReadinessRestartClock','Resumed and uninterrupted observation clocks differ.'); end
    variables=string([{R.realVariables.name},{R.complexVariables.name}]);
    for variableName=variables
        variable=R.variableWithName(variableName);
        if ~ismember('t',{variable.dimensions.name}), continue; end
        labels=variableName;
        if variableName=="endpointAnomalies", labels=["surfaceAnomaly","bottomAnomaly"]; end
        for endpoint=1:numel(labels)
            difference=0; referenceNorm=0;
            for index=1:count
                a=A.readVariablesAtIndexAlongDimension('t',index,char(variableName)); r=R.readVariablesAtIndexAlongDimension('t',index,char(variableName));
                if variableName=="endpointAnomalies", a=a(:,:,endpoint); r=r(:,:,endpoint); end
                if any(~isfinite(a),'all') || any(~isfinite(r),'all'), error('WV:ReadinessRestartFinite','Committed output is nonfinite.'); end
                difference=hypot(difference,norm(a(:)-r(:))); referenceNorm=hypot(referenceNorm,norm(r(:)));
            end
            relativeError=NaN; if referenceNorm>c.absoluteAllowance, relativeError=difference/referenceNorm; end
            if difference>c.absoluteAllowance+c.relativeAllowance*referenceNorm, error('WV:ReadinessRestartOutput','The %s/%s stream exceeds the declared restart allowance.',name,labels(endpoint)); end
            rows=[rows;table(name,labels(endpoint),count,difference,referenceNorm,relativeError,VariableNames={'group','variable','committedRecords','absoluteError','referenceNorm','relativeError'})]; %#ok<AGROW>
        end
    end
end
end
function [relative,accepted]=errorMetric(a,b,c)
difference=norm(a(:)-b(:)); reference=norm(b(:));
relative=NaN; if reference>c.absoluteAllowance, relative=difference/reference; end
accepted=all(isfinite(a),'all') && all(isfinite(b),'all') && difference<=c.absoluteAllowance+c.relativeAllowance*reference;
end
function reportPhase(name,clock)
fprintf('T10 restart elapsed=%.3gs: %s\n',toc(clock),name);
end
function releaseModel(model)
% These clones/restored models are owned by this driver. Their transforms
% can hold large physical-metric caches after files have already closed.
if isempty(model) || ~isvalid(model), return; end
w=model.wvt;
modelCleanup=onCleanup(@()delete(model));
transformCleanup=onCleanup(@()releaseTransform(w));
model.closeNetCDFFile();
end
function releaseTransform(w)
if ~isempty(w) && isvalid(w), delete(w); end
end
function checkBudget(clock,budget)
if toc(clock)>=budget, error('WV:ReadinessRestartWallBudget','The declared cooperative lifecycle wall budget expired.'); end
end
function writeJSON(path,value)
fid=fopen(path,'w'); if fid<0, error('WV:ReadinessRestartWrite','Cannot create %s.',path); end
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,PrettyPrint=true));
end
