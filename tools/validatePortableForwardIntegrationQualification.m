function validatePortableForwardIntegrationQualification(report,catalog,options)
% Validate executed representative cases without promoting historical coverage.
arguments
    report (1,1) struct
    catalog (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
root = options.repositoryRoot;
validatePortableForwardIntegrationCatalog(catalog,repositoryRoot=root);
requireFields(report,["schema","schemaVersion","scope","status","sourceCommit","provider","matlabRelease","platform","catalogSHA256","sourceSHA256","artifacts","executionBinaries","cases"]);
require(string(report.schema)=="wave-vortex-forward-integration-qualification-v1" && report.schemaVersion==1, ...
    "Unsupported execution receipt identity.");
require(string(report.scope)=="forward-integration" && string(report.status)=="complete","Incomplete or incorrectly scoped execution receipt.");
require(~isempty(regexp(string(report.sourceCommit),'^[a-f0-9]{40}$','once')),"Missing exact source commit.");
provider = string(report.provider);
require(isscalar(provider) && ismember(provider,["reference","native-fftw"]),"Unknown or ambiguous provider.");
require(strlength(string(report.matlabRelease))>0 && strlength(string(report.platform))>0,"Missing execution environment.");
catalogPath = fullfile(root,"PortableRuntime","contracts","portable-forward-integration-v1.json");
require(string(report.catalogSHA256)==portableForwardIntegrationSHA256(catalogPath),"Stale catalog artifact digest.");
requiredSources = ["PortableRuntime/include/WaveVortexRuntime/WVRungeKutta.hpp", ...
    "PortableRuntime/src/WVRungeKutta.cpp","PortableRuntime/src/WVModel.cpp", ...
    "PortableRuntime/src/WVOutputOrchestration.cpp","PortableRuntime/src/WVModelOutputNetCDFWriter.cpp", ...
    "PortableRuntime/tests/WVForwardIntegrationProbe.cpp","UnitTests/TestPortableForwardIntegration.m", ...
    "PortableRuntime/app/WaveVortexRun.cpp","PortableRuntime/include/WaveVortexRuntime/WVIntegrationContracts.hpp", ...
    "CompiledKernel/src/WVTransformConstantStratificationKernel.cpp", ...
    "PortableRuntime/src/WVFieldEvaluationService.cpp","PortableRuntime/src/WVStratifiedFieldEvaluationAdapter.cpp", ...
    "PortableRuntime/src/WVBarotropicQGFieldEvaluationAdapter.cpp"];
runnerSource = fullfile(root,"PortableRuntime/app/WaveVortexRun.cpp");
if isfile(runnerSource) && contains(fileread(runnerSource),"WVRunnerVariablePolicy.hpp")
    requiredSources = [requiredSources,"PortableRuntime/CMakeLists.txt","CompiledKernel/CMakeLists.txt", ...
        "PortableRuntime/app/WVRunnerVariablePolicy.cpp","PortableRuntime/app/WVRunnerVariablePolicy.hpp"];
end
sourcePaths = validateHashes(report.sourceSHA256,root);
require(all(ismember(requiredSources,sourcePaths)),"Missing required runtime, probe or MATLAB source digest.");
require(~isempty(report.artifacts),"Complete qualification requires retained execution evidence.");
validateHashes(report.artifacts,root);
if isfield(report,"inheritedEvidence"), validateInheritedEvidence(report.inheritedEvidence,root); end
binaries = report.executionBinaries;
require(isstruct(binaries) && numel(binaries)==2,"Both executed runner and probe digests are required.");
requireFields(binaries,["role","sha256","sourceCommit"]);
require(isequal(sort(string({binaries.role})),["probe","runner"]),"Missing or duplicate binary role.");
for binary = reshape(binaries,1,[])
    require(~isempty(regexp(string(binary.sha256),'^[a-f0-9]{64}$','once')) && ~isempty(regexp(string(binary.sourceCommit),'^[a-f0-9]{40}$','once')),"Invalid recorded executable provenance.");
end
cases = report.cases;
require(isstruct(cases) && numel(cases)==numel(catalog.cases),"Exactly six representative cases are required per provider.");
require(numel(unique(string({cases.id})))==numel(cases),"Duplicate representative case.");
for definition = reshape(catalog.cases,1,[])
    selected = string({cases.id})==string(definition.id);
    require(sum(selected)==1,"Missing representative case: "+string(definition.id));
    item = cases(selected);
    requireFields(item,["id","configuration","profile","testName","passed","failed","incomplete","provider","scope","checks","controls","evolution","outcomes","denseHeld","stop","runs"]);
    require(string(item.configuration)==string(definition.configuration) && string(item.profile)==string(definition.profile),"Case/configuration/profile mismatch.");
    require(string(item.provider)==provider && string(item.scope)=="forward-integration","Case provider or scope mismatch.");
    require(isequal(item.passed,true) && isequal(item.failed,false) && isequal(item.incomplete,false),"Failed or incomplete representative case.");
    prefix = "TestPortableForwardIntegration/"+string(definition.symbol);
    require(string(item.testName)==prefix+"(configuration="+string(definition.parameter)+")","Unresolved executed test identity or configuration parameter.");
    source = fileread(fullfile(root,string(definition.path)));
    pattern = "(?m)^\s*function\s+"+string(definition.symbol)+"\s*\(";
    require(~isempty(regexp(source,pattern,'once')),"Executed test source no longer resolves.");
    validateMeasurements(item,definition,catalog.acceptance);
    checks = item.checks;
    require(isstruct(checks) && ~isempty(checks),"Missing lifecycle assertions.");
    requireFields(checks,["name","passed"]);
    names = string({checks.name});
    requiredChecks = ["nontrivialEvolution","heldAmplitudes","completeRestartState","allContinuationDirections","twoOutputDestinations","controlledStopResume","denseOutputParity"];
    require(isequal(sort(names),sort(requiredChecks)) && isequal([checks.passed],true(1,numel(requiredChecks))),"Missing, failed or duplicated lifecycle assertion.");
end
stops = [cases.stop];
require(isequal(sort(unique(string({stops.requestedBoundary}))),["accepted-step","output-occurrence"]),"Both accepted-step and output-occurrence stop boundaries require executed evidence.");
validateExecutionArtifacts(report,root);
end

function paths = validateHashes(records,root)
paths = strings(1,0);
if isempty(records), return; end
require(isstruct(records),"Digest records must be path/sha256 objects.");
requireFields(records,["path","sha256"]);
paths = string({records.path});
require(numel(unique(paths))==numel(paths),"Duplicate source or artifact path.");
for record = reshape(records,1,[])
    relative = string(record.path);
    require(~startsWith(relative,"/") && ~contains(relative,"\\") && ~any(split(relative,"/")=="..") && ~contains(relative,newline),"Artifact paths must remain repository-relative.");
    require(~isempty(regexp(string(record.sha256),'^[a-f0-9]{64}$','once')),"Malformed SHA-256 digest.");
    require(string(record.sha256)==portableForwardIntegrationSHA256(fullfile(root,relative)),"Stale source or artifact digest: "+relative);
end
end

function requireFields(value,names)
require(isstruct(value) && all(isfield(value,names)),"Missing required qualification fields.");
end

function require(condition,message)
if ~condition, error("WaveVortexModel:InvalidForwardIntegrationQualification","%s",message); end
end

function validateInheritedEvidence(entries,root)
for entry = reshape(entries,1,[])
    requireFields(entry,["path","sha256","classification"]);
    validateHashes(struct(path=entry.path,sha256=entry.sha256),root);
    classification = string(entry.classification);
    require(ismember(classification,["historical-workload-coverage","production-source-compatible"]),"Unrecognized inherited evidence classification.");
    if classification=="historical-workload-coverage", continue; end
    requireFields(entry,["productionSources","verifiedCorrections"]);
    original = jsondecode(fileread(fullfile(root,string(entry.path))));
    requireFields(original,"sourceSHA256");
    paths = validateHashes(entry.productionSources,root);
    keys = string(matlab.lang.makeValidName(cellstr(paths)));
    recordedKeys = string(fieldnames(original.sourceSHA256));
    production = endsWith(recordedKeys,["_cpp","_hpp","_h","_m"]) & ~startsWith(recordedKeys,["UnitTests_","tools_"]) & ~contains(recordedKeys,"_tests_");
    require(isequal(sort(keys(:)),sort(recordedKeys(production))),"Inherited production proof omits or adds source files.");
    corrections = entry.verifiedCorrections;
    validateHashes(corrections,root);
    for k = 1:numel(paths)
        current = string(entry.productionSources(k).sha256);
        recorded = string(original.sourceSHA256.(keys(k)));
        if current~=recorded
            require(~isempty(corrections) && any(string({corrections.path})==paths(k) & string({corrections.sha256})==current),"Changed inherited production source lacks an explicit verified correction.");
        end
    end
    for correction = reshape(corrections,1,[])
        require(isfield(original,"ciCorrections"),"No original correction supports the claimed inherited digest.");
        matched = false;
        for k = 1:numel(original.ciCorrections)
            if iscell(original.ciCorrections), item = original.ciCorrections{k}; else, item = original.ciCorrections(k); end
            if isfield(item,"file") && string(item.file)==string(correction.path) && isfield(item,"correctedSHA256")
                matched = string(item.correctedSHA256)==string(correction.sha256) && isfield(item,"focusedNativeTest") && isequal(item.focusedNativeTest.passed,true);
            elseif isfield(item,"sourceSHA256")
                key = matlab.lang.makeValidName(char(correction.path));
                if isfield(item.sourceSHA256,key)
                    matched = string(item.sourceSHA256.(key))==string(correction.sha256) && isfield(item,"matlabCatalogTests") && all(item.matlabCatalogTests.passed) && isfield(item,"nativeCatalogTest") && isequal(item.nativeCatalogTest.passed,true);
                end
            end
            if matched, break; end
        end
        require(matched,"Inherited correction is not bound to its original digest and passing checks.");
    end
end
end

function validateMeasurements(item,definition,limits)
controls = item.controls;
requireFields(controls,["initialTime","splitTime","finalTime","initialStep","maximumStep","relativeTolerance","absoluteTolerance","stopBoundary","method"]);
requireFinite([controls.initialTime,controls.splitTime,controls.finalTime,controls.initialStep,controls.maximumStep,controls.relativeTolerance,controls.absoluteTolerance]);
require(controls.initialTime<controls.splitTime && controls.splitTime<controls.finalTime,"Invalid continuation interval.");
require(controls.initialStep>0 && controls.maximumStep>0 && controls.relativeTolerance>0 && controls.absoluteTolerance>0,"Invalid integration controls.");
method = string(definition.profile);
if method=="rk4-cfl", method="fixed-rk4"; end
require(string(controls.method)==method,"Controls do not select the catalog method.");
evolution = item.evolution;
requireFields(evolution,["coefficients","particlePosition","tracer"]);
requireFinite([evolution.coefficients,evolution.particlePosition,evolution.tracer]);
require(evolution.coefficients>limits.coefficientEvolutionMinimum && evolution.particlePosition>limits.particleEvolutionMinimum && evolution.tracer>limits.tracerEvolutionMinimum,"Trivial evolution cannot establish continuation parity.");
directions = ["whole","split","matlabToCpp","cppToMatlab","stoppedCpp","stoppedMatlab"];
require(isequal(sort(string(fieldnames(item.outcomes))),sort(directions(:))),"Missing or unknown continuation direction.");
for direction = directions
    metrics = item.outcomes.(direction);
    require(isstruct(metrics) && numel(metrics)==2,"Each direction must qualify two independent destinations.");
    requireFields(metrics,["coefficients","fields","tracer","savedOutput","particlePosition","heldAmplitude","restoredStateExact"]);
    for measured = reshape(metrics,1,[])
        errors = [measured.coefficients,measured.fields,measured.tracer,measured.savedOutput,measured.particlePosition,measured.heldAmplitude];
        requireFinite(errors);
        require(all(errors>=0) && all(errors(1:4)<=limits.relativeErrorMaximum) && measured.particlePosition<=limits.particlePositionErrorMaximum && measured.heldAmplitude<=limits.heldAmplitudeErrorMaximum && isequal(measured.restoredStateExact,true),"Failed output, state, observer or held-amplitude parity.");
    end
end
dense = item.denseHeld;
requireFields(dense,["recordCount","firstRecordTime","maximumHeldError"]);
requireFinite([dense.recordCount,dense.firstRecordTime,dense.maximumHeldError]);
require(dense.recordCount>0 && dense.recordCount==fix(dense.recordCount) && dense.firstRecordTime>controls.initialTime && dense.firstRecordTime<controls.finalTime && dense.maximumHeldError>=0 && dense.maximumHeldError<=limits.heldAmplitudeErrorMaximum,"Missing or failed interior dense held-amplitude evidence.");
stop = item.stop;
requireFields(stop,["reason","requestedBoundary","requestedAtAcceptedTime","requestedAtOutputTime","finalAcceptedTime","callbackEvaluationCount"]);
requireFinite([stop.requestedAtAcceptedTime,stop.finalAcceptedTime,stop.callbackEvaluationCount]);
require(string(stop.reason)=="stop-requested" && string(stop.requestedBoundary)==string(controls.stopBoundary) && ismember(string(stop.requestedBoundary),["accepted-step","output-occurrence"]),"Stop reason or callback boundary mismatch.");
require(stop.finalAcceptedTime>controls.initialTime && stop.finalAcceptedTime<controls.finalTime && stop.requestedAtAcceptedTime>=controls.initialTime && stop.requestedAtAcceptedTime<=stop.finalAcceptedTime && stop.callbackEvaluationCount>0 && stop.callbackEvaluationCount==fix(stop.callbackEvaluationCount),"Contradictory stop time or callback count.");
if string(stop.requestedBoundary)=="output-occurrence"
    requireFinite(stop.requestedAtOutputTime);
    require(isscalar(stop.requestedAtOutputTime) && stop.requestedAtOutputTime>=controls.initialTime && stop.requestedAtOutputTime<=stop.requestedAtAcceptedTime,"Output stop time is outside its accepted step.");
else
    require(isempty(stop.requestedAtOutputTime),"Accepted-step stop cannot claim an output occurrence.");
end
runNames = ["whole","firstSegment","secondSegment","matlabToCpp","stopped","stoppedResume"];
require(isequal(sort(string(fieldnames(item.runs))),sort(runNames(:))),"Incomplete executed run ledger.");
initial = [controls.initialTime,controls.initialTime,controls.splitTime,controls.splitTime,controls.initialTime,stop.finalAcceptedTime];
final = [controls.finalTime,controls.splitTime,controls.finalTime,controls.finalTime,stop.finalAcceptedTime,controls.finalTime];
for k = 1:numel(runNames)
    run = item.runs.(runNames(k));
    requireFields(run,["status","state","termination","integrationRequest","acceptedStepCount","denseOutputEvaluationCount"]);
    requireFields(run.state,["initialTime","finalTime","stepCount"]);
    requireFields(run.integrationRequest,["activeMethod","stepPolicy"]);
    policy = "adaptive";
    if string(definition.profile)=="rk4-cfl", policy="cfl"; end
    require(string(run.integrationRequest.stepPolicy)==policy,"Run does not establish the declared CFL or adaptive step policy.");
    requireFinite([run.state.initialTime,run.state.finalTime,run.state.stepCount,run.acceptedStepCount,run.denseOutputEvaluationCount]);
    require(run.state.initialTime==initial(k) && run.state.finalTime==final(k) && run.state.stepCount==run.acceptedStepCount && run.acceptedStepCount>0 && string(run.integrationRequest.activeMethod)==method,"Run does not establish its declared continuation interval or method.");
    if runNames(k)=="stopped"
        require(string(run.status)=="stopped" && isequaln(run.termination,stop),"Stopped run contradicts the stop receipt.");
    else
        require(string(run.status)=="complete" && string(run.termination.reason)=="reached-final-time" && run.termination.finalAcceptedTime==final(k),"Continuation did not reach its declared final time.");
    end
end
require(item.runs.whole.denseOutputEvaluationCount>0,"No actual dense integration evaluation occurred.");
end

function requireFinite(values)
require(isnumeric(values) && isreal(values) && all(isfinite(values),"all"),"Nonfinite or nonscalar numerical evidence.");
end

function validateExecutionArtifacts(report,root)
covered = false(1,numel(report.cases));
for artifact = reshape(report.artifacts,1,[])
    path = string(artifact.path);
    text = string(fileread(fullfile(root,path)));
    if endsWith(path,".log")
        for k = 1:numel(report.cases)
            marker = "FORWARD_INTEGRATION_PASS "+string(report.cases(k).configuration)+" provider="+string(report.provider)+" ";
            covered(k) = covered(k) || contains(text,marker);
        end
    elseif endsWith(path,".json")
        retained = jsondecode(text);
        if isfield(retained,"cases")
            for k = 1:numel(report.cases)
                for measured = reshape(retained.cases,1,[])
                    covered(k) = covered(k) || isequaln(measured,jsondecode(jsonencode(report.cases(k))));
                end
            end
        end
    end
end
require(all(covered),"Retained artifacts do not witness every executed case for this provider.");
end
