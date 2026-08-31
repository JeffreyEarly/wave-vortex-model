function results = runFreeSurfaceQGCoefficientStorageBenchmark(options)
% Compare separate and packed free-surface QG integrator backing.
arguments
    options.gridIds (1,:) string = ["small" "representative"]
    options.endpointIds (1,:) string = ["zero" "one" "two"]
    options.strategyIds (1,:) string = ["separate" "packed"]
    options.smallNxyz (1,3) double {mustBeInteger,mustBePositive} = [64 64 33]
    options.representativeNxyz (1,3) double {mustBeInteger,mustBePositive} = [256 256 129]
    options.representativeNj (1,1) double {mustBeInteger,mustBePositive} = 10
    options.Lxyz (1,3) double {mustBePositive} = [150e3 150e3 1000]
    options.seed (1,1) double {mustBeInteger,mustBeNonnegative} = 34322
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 1
    options.sampleCount (1,1) double {mustBeInteger,mustBePositive} = 5
    options.bootstrapCount (1,1) double {mustBeInteger,mustBePositive} = 10000
    options.minimumMeaningfulSpeedup (1,1) double {mustBeGreaterThanOrEqual(options.minimumMeaningfulSpeedup,0),mustBeLessThan(options.minimumMeaningfulSpeedup,1)} = 0.03
    options.shouldUseFreshProcess (1,1) logical = true
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBeNonnegative} = 0.05
    options.phasePath (1,1) string = ""
    options.outputDirectory (1,1) string = ""
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalPath = path;
originalRng = rng;
cleanup = onCleanup(@()restoreState(originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);

definitions = caseDefinitions(options.gridIds,options.endpointIds,options.smallNxyz,options.representativeNxyz,options.representativeNj,options.Lxyz);
validateStrategyIds(options.strategyIds);
configuration = struct( ...
    "gridIds",options.gridIds,"endpointIds",options.endpointIds, ...
    "strategyIds",options.strategyIds,"seed",options.seed, ...
    "smallNxyz",options.smallNxyz, ...
    "representativeNxyz",options.representativeNxyz, ...
    "representativeNj",options.representativeNj,"Lxyz",options.Lxyz, ...
    "warmupCount",options.warmupCount,"sampleCount",options.sampleCount, ...
    "bootstrapCount",options.bootstrapCount, ...
    "minimumMeaningfulSpeedup",options.minimumMeaningfulSpeedup);

cases = repmat(emptyCase(),numel(definitions),1);
if options.shouldUseFreshProcess
    workFolder = string(tempname);
    mkdir(workFolder);
    workCleanup = onCleanup(@()rmdir(workFolder,"s"));
end
for iCase = 1:numel(definitions)
    definition = definitions(iCase);
    strategies = repmat(emptyStrategy(),numel(options.strategyIds),1);
    for iStrategy = 1:numel(options.strategyIds)
        strategyId = options.strategyIds(iStrategy);
        fprintf("Free-surface QG coefficient storage: %s / %s.\n",definition.id,strategyId);
        if options.shouldUseFreshProcess
            strategies(iStrategy) = runFreshStrategy(definition,strategyId,configuration,benchmarkFolder,workFolder,options);
        else
            strategies(iStrategy) = runSingleStrategy(definition,strategyId,configuration,options.phasePath,options.plateauSeconds);
        end
    end
    cases(iCase) = assembleCase(definition,strategies,configuration);
end
if options.shouldUseFreshProcess
    clear workCleanup
end

decision = storageDecision(cases,configuration);
results = struct( ...
    "studyId","free-surface-qg-coefficient-storage-v1", ...
    "environment",environmentDescription(), ...
    "configuration",configuration, ...
    "cases",cases, ...
    "decision",decision);
if options.outputDirectory ~= ""
    writeArtifact(results,options.outputDirectory);
end
clear cleanup
end

function definitions = caseDefinitions(gridIds,endpointIds,smallNxyz,representativeNxyz,representativeNj,Lxyz)
grids = [ ...
    struct("id","small","Nxyz",smallNxyz,"Lxyz",Lxyz,"Nj",zeros(0,1),"modeCountPolicy","automatic-0.1-aliasing"); ...
    struct("id","representative","Nxyz",representativeNxyz,"Lxyz",Lxyz,"Nj",representativeNj,"modeCountPolicy","certified-fixed-prefix")];
endpoints = [ ...
    struct("id","zero","g0",Inf,"gd",Inf,"activeEndpointCount",0); ...
    struct("id","one","g0",0.02,"gd",Inf,"activeEndpointCount",1); ...
    struct("id","two","g0",0.02,"gd",0.03,"activeEndpointCount",2)];
validateSelection(gridIds,string({grids.id}),"grid");
validateSelection(endpointIds,string({endpoints.id}),"endpoint");
definitionCount = numel(gridIds)*numel(endpointIds);
definitions = repmat(struct("id","","gridId","","endpointId","","Nxyz",zeros(1,3),"Lxyz",zeros(1,3),"g0",NaN,"gd",NaN,"activeEndpointCount",0,"Nj",zeros(0,1),"modeCountPolicy",""),definitionCount,1);
iDefinition = 0;
for gridId = gridIds
    grid = grids(find(string({grids.id})==gridId,1));
    for endpointId = endpointIds
        endpoint = endpoints(find(string({endpoints.id})==endpointId,1));
        iDefinition = iDefinition+1;
        definitions(iDefinition) = struct( ...
            "id",grid.id+"-"+endpoint.id+"-endpoint", ...
            "gridId",grid.id,"endpointId",endpoint.id, ...
            "Nxyz",grid.Nxyz,"Lxyz",grid.Lxyz, ...
            "g0",endpoint.g0,"gd",endpoint.gd, ...
            "activeEndpointCount",endpoint.activeEndpointCount, ...
            "Nj",grid.Nj,"modeCountPolicy",grid.modeCountPolicy);
    end
end
end

function validateSelection(requested,known,kind)
if numel(unique(requested,"stable")) ~= numel(requested)
    error("WaveVortexBenchmark:DuplicateCoefficientStorageCase", ...
        "Requested %s IDs must be unique.",kind);
end
unknown = requested(~ismember(requested,known));
if ~isempty(unknown)
    error("WaveVortexBenchmark:UnknownCoefficientStorageCase", ...
        "Unknown %s ID: %s.",kind,strjoin(unknown,", "));
end
end

function validateStrategyIds(strategyIds)
validateSelection(strategyIds,["separate" "packed"],"strategy");
end

function value = runFreshStrategy(definition,strategyId,configuration,benchmarkFolder,workFolder,options)
strategyFolder = fullfile(workFolder,definition.id,strategyId);
mkdir(strategyFolder);
configPath = fullfile(strategyFolder,"config.json");
outputPath = fullfile(strategyFolder,"result.json");
phasePath = fullfile(strategyFolder,"phase.txt");
samplePath = fullfile(strategyFolder,"rss.tsv");
stdoutPath = fullfile(strategyFolder,"stdout.txt");
stderrPath = fullfile(strategyFolder,"stderr.txt");
config = struct( ...
    "gridId",definition.gridId,"endpointId",definition.endpointId, ...
    "strategyId",strategyId,"seed",configuration.seed, ...
    "smallNxyz",configuration.smallNxyz, ...
    "representativeNxyz",configuration.representativeNxyz, ...
    "representativeNj",configuration.representativeNj,"Lxyz",configuration.Lxyz, ...
    "warmupCount",configuration.warmupCount,"sampleCount",configuration.sampleCount, ...
    "bootstrapCount",configuration.bootstrapCount, ...
    "minimumMeaningfulSpeedup",configuration.minimumMeaningfulSpeedup, ...
    "phasePath",phasePath,"plateauSeconds",options.plateauSeconds);
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); freeSurfaceQGCoefficientStorageBenchmarkWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
worker = sprintf('\"%s\" -batch \"%s\"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
sampler = fullfile(benchmarkFolder,"runProcessWithRSS.sh");
command = shellQuote(sampler)+" "+shellQuote(samplePath)+" "+shellQuote(phasePath)+" "+string(sprintf('%.17g',options.samplingIntervalSeconds))+" "+shellQuote(stdoutPath)+" "+shellQuote(stderrPath)+" -- /bin/sh -c "+shellQuote(worker);
[exitCode,~] = system(command);
if exitCode~=0 || ~isfile(outputPath)
    error("WaveVortexBenchmark:CoefficientStorageWorkerFailed", ...
        "Fresh MATLAB failed for %s / %s:\n%s",definition.id,strategyId,commandOutput(stdoutPath,stderrPath));
end
payload = jsondecode(fileread(outputPath));
if string(payload.status) ~= "complete"
    error("WaveVortexBenchmark:CoefficientStorageWorkerFailed", ...
        "Fresh MATLAB failed for %s / %s:\n%s",definition.id,strategyId,payload.failure);
end
value = payload.strategy;
value.memory = processMemory(samplePath,options.samplingIntervalSeconds);
end

function value = runSingleStrategy(definition,strategyId,configuration,phasePath,plateauSeconds)
writePhase(phasePath,"construction");
wvt = WVTransformFreeSurfaceQG(definition.Lxyz,definition.Nxyz, ...
    N2Function=@benchmarkStratification,latitude=45,g0=definition.g0,gd=definition.gd,Nj=definition.Nj);
wvtCleanup = onCleanup(@()closeTransform(wvt));
initializeState(wvt,configuration.seed);
model = WVModel(wvt,shouldUseLinearDynamics=false);
modelCleanup = onCleanup(@()closeModel(model));
observer = installStrategy(model,strategyId);
referenceObserver = WVCoefficients(model);
state = observer.initialConditions();
referenceState = referenceObserver.initialConditions();
[Fq,Fb] = projectionInputs(wvt);
correctness = correctnessGate(observer,referenceObserver,state,referenceState);
stateStorage = stateLedger(state,strategyId,wvt);
scientificConfiguration = scientificConfigurationForTransform(wvt,definition);

operations = operationDefinitions(observer,state,Fq,Fb);
writePhase(phasePath,"steady-retained");
pause(plateauSeconds);
writePhase(phasePath,"operation");
waitForPhaseSample(phasePath);
measurements = repmat(emptyOperation(),numel(operations),1);
for iOperation = 1:numel(operations)
    operation = operations(iOperation);
    for iWarmup = 1:configuration.warmupCount
        operation.functionHandle();
    end
    rawSeconds = zeros(1,configuration.sampleCount);
    for iSample = 1:configuration.sampleCount
        timer = tic;
        operation.functionHandle();
        rawSeconds(iSample) = toc(timer);
    end
    measurements(iOperation) = struct( ...
        "id",operation.id,"rawSeconds",rawSeconds, ...
        "medianSeconds",median(rawSeconds));
end
writePhase(phasePath,"complete");

value = struct( ...
    "id",strategyId,"status","complete", ...
    "operations",measurements, ...
    "stateStorage",stateStorage, ...
    "scientificConfiguration",scientificConfiguration, ...
    "correctness",correctness, ...
    "memory",struct("provider","not-sampled","boundary","in-process mode"));
clear modelCleanup wvtCleanup
end

function observer = installStrategy(model,strategyId)
observer = model.wvCoefficientFluxedObservingSystem();
if strategyId == "separate"
    return
end
model.removeFluxedObservingSystem(observer);
observer = WVFreeSurfaceQGPackedCoefficientAdapter(model);
model.addFluxedCoefficients(observer);
end

function initializeState(wvt,seed)
rng(seed,"twister");
modeWeight = 1./reshape(1:wvt.Nj,[],1);
khScale = max(min(wvt.khNonzero),2*pi/50e3);
horizontalWeight = exp(-(reshape(wvt.khNonzero,1,[])/khScale).^2);
phase = complex(randn(size(wvt.Ag_q)),randn(size(wvt.Ag_q)))/sqrt(2);
wvt.Ag_q = 2e-5*modeWeight.*horizontalWeight.*phase;
if wvt.activeEndpointCount > 0
    endpointWeight = 1./reshape(1:wvt.activeEndpointCount,[],1);
    phase = complex(randn(size(wvt.Ag_0)),randn(size(wvt.Ag_0)))/sqrt(2);
    wvt.Ag_0 = 1e-5*endpointWeight.*horizontalWeight.*phase;
end
wvt.Amda = 0.02*randn(size(wvt.Amda))./reshape(1:wvt.Nj,[],1);
end

function [Fq,Fb] = projectionInputs(wvt)
[q,u,v,b,ub,vb] = wvt.quasigeostrophicSpatialState();
Fq = -(u.*wvt.diffX(q)+v.*wvt.diffY(q));
Fb = -(ub.*wvt.diffX(b)+vb.*wvt.diffY(b));
end

function correctness = correctnessGate(observer,referenceObserver,state,referenceState)
candidateCanonical = canonicalState(observer,state);
stateError = maximumRelativeError(candidateCanonical,referenceState);

referenceFlux = referenceObserver.fluxAtTime(0,referenceState);
candidateFlux = canonicalState(observer,observer.fluxAtTime(0,state));
rhsError = maximumRelativeError(candidateFlux,referenceFlux);

referenceStage = integratorCopyUpdate(referenceObserver,referenceState,referenceFlux,1/64);
candidateStage = integratorCopyUpdate(observer,state,observer.fluxAtTime(0,state),1/64);
stageError = maximumRelativeError(canonicalState(observer,candidateStage),referenceStage);

referenceIntegrator = WVArrayIntegrator(@(t,y)referenceObserver.fluxAtTime(t,y),[0 0],referenceState,1/64);
candidateIntegrator = WVArrayIntegrator(@(t,y)observer.fluxAtTime(t,y),[0 0],state,1/64);
referenceStep = referenceIntegrator.stepForward(referenceState,0,1/64);
candidateStep = canonicalState(observer,candidateIntegrator.stepForward(state,0,1/64));
stepError = maximumRelativeError(candidateStep,referenceStep);

tolerance = 5e-13;
errors = [stateError rhsError stageError stepError];
correctness = struct( ...
    "tolerance",tolerance,"passed",all(errors<=tolerance), ...
    "stateRelativeError",stateError,"rhsRelativeError",rhsError, ...
    "copyUpdateRelativeError",stageError,"fixedRK4RelativeError",stepError);
if ~correctness.passed
    error("WaveVortexBenchmark:CoefficientStorageCorrectness", ...
        "Coefficient storage strategy %s failed its correctness gate with maximum relative error %.3g.",observer.name,max(errors));
end
end

function definitions = operationDefinitions(observer,state,Fq,Fb)
referenceFlux = observer.fluxAtTime(0,state);
integrator = WVArrayIntegrator(@(t,y)observer.fluxAtTime(t,y),[0 0],state,1/64);
definitions = [ ...
    struct("id","reconstruction","functionHandle",@()executeReconstruction(observer.wvt)); ...
    struct("id","projection","functionHandle",@()observer.wvt.projectQuasigeostrophicSpatialTendency(Fq,Fb)); ...
    struct("id","complete-rhs","functionHandle",@()observer.fluxAtTime(0,state)); ...
    struct("id","integrator-copy-update","functionHandle",@()integratorCopyUpdate(observer,state,referenceFlux,1/64)); ...
    struct("id","fixed-rk4-step","functionHandle",@()integrator.stepForward(state,0,1/64))];
end

function executeReconstruction(wvt)
wvt.quasigeostrophicSpatialState();
end

function nextState = integratorCopyUpdate(observer,state,flux,scale)
nextState = cell(size(state));
for iComponent = 1:numel(state)
    nextState{iComponent} = state{iComponent}+scale*flux{iComponent};
end
observer.updateIntegratorValues(scale,nextState);
end

function values = canonicalState(observer,state)
if isa(observer,"WVFreeSurfaceQGPackedCoefficientAdapter")
    values = observer.canonicalStateFromIntegratorState(state);
else
    values = state;
end
end

function errorValue = maximumRelativeError(actual,expected)
errorValue = 0;
for iFamily = 1:numel(expected)
    if isempty(expected{iFamily})
        continue
    end
    denominator = max(1,max(abs(expected{iFamily}(:))));
    familyError = max(abs(actual{iFamily}(:)-expected{iFamily}(:)),[],"all");
    errorValue = max(errorValue,familyError/denominator);
end
end

function value = stateLedger(state,strategyId,wvt)
componentBytes = zeros(1,numel(state));
componentShapes = cell(1,numel(state));
componentComplex = false(1,numel(state));
for iComponent = 1:numel(state)
    item = state{iComponent};
    info = whos("item");
    componentBytes(iComponent) = info.bytes;
    componentShapes{iComponent} = size(item);
    componentComplex(iComponent) = ~isreal(item);
end

annotations = wvt.coefficientStateAnnotations();
canonicalNames = string({annotations.name});
canonicalBytes = zeros(1,numel(canonicalNames));
for iFamily = 1:numel(canonicalNames)
    canonicalBytes(iFamily) = arrayBytes(wvt.(canonicalNames(iFamily)));
end
value = struct( ...
    "strategyId",strategyId,"componentCount",numel(state), ...
    "componentBytes",componentBytes,"componentShapes",{componentShapes}, ...
    "componentIsComplex",componentComplex,"totalIntegratorBytes",sum(componentBytes), ...
    "canonicalFamilyNames",canonicalNames,"canonicalFamilyBytes",canonicalBytes, ...
    "canonicalCoefficientBytes",sum(canonicalBytes), ...
    "scope","exact MATLAB payload bytes from whos; allocator and copy-on-write state unavailable");
end

function value = scientificConfigurationForTransform(wvt,definition)
value = struct( ...
    "modeCountPolicy",definition.modeCountPolicy, ...
    "requestedNj",definition.Nj,"retainedNj",double(wvt.Nj), ...
    "commonCertifiedModeCount",wvt.commonCertifiedModeCount, ...
    "apvCertifiedModeCount",wvt.apvCertifiedModeCount, ...
    "mdaCertifiedModeCount",wvt.mdaCertifiedModeCount, ...
    "quadraticAliasingTolerance",wvt.quadraticAliasingTolerance, ...
    "quadraticAliasingError",wvt.quadraticAliasingError);
end

function value = assembleCase(definition,strategies,configuration)
value = emptyCase();
value.id = definition.id;
value.gridId = definition.gridId;
value.endpointId = definition.endpointId;
value.Nxyz = definition.Nxyz;
value.Lxyz = definition.Lxyz;
value.g0 = definition.g0;
value.gd = definition.gd;
value.activeEndpointCount = definition.activeEndpointCount;
value.strategies = strategies;
value.modeCountPolicy = definition.modeCountPolicy;
value.requestedNj = definition.Nj;
if all(ismember(["separate" "packed"],string({strategies.id})))
    value.comparison = compareStrategies(strategies,configuration);
end
end

function value = compareStrategies(strategies,configuration)
separate = strategies(string({strategies.id})=="separate");
packed = strategies(string({strategies.id})=="packed");
operationIds = string({separate.operations.id});
operations = repmat(struct("id","","packedToSeparateMedianRatio",NaN,"medianSpeedup",NaN,"ratioConfidenceInterval95",[NaN NaN]),numel(operationIds),1);
for iOperation = 1:numel(operationIds)
    id = operationIds(iOperation);
    separateOperation = separate.operations(string({separate.operations.id})==id);
    packedOperation = packed.operations(string({packed.operations.id})==id);
    ratio = packedOperation.medianSeconds/separateOperation.medianSeconds;
    preference = freeSurfaceQGCoefficientStoragePreference( ...
        separateOperation.rawSeconds,packedOperation.rawSeconds, ...
        bootstrapCount=configuration.bootstrapCount, ...
        minimumMeaningfulSpeedup=configuration.minimumMeaningfulSpeedup, ...
        seed=configuration.seed+iOperation);
    interval = preference.ratioConfidenceInterval95;
    operations(iOperation) = struct( ...
        "id",id,"packedToSeparateMedianRatio",ratio, ...
        "medianSpeedup",1/ratio,"ratioConfidenceInterval95",interval);
end
rk4 = operations(operationIds=="fixed-rk4-step");
threshold = 1-configuration.minimumMeaningfulSpeedup;
value = struct( ...
    "operations",operations, ...
    "allCorrectnessPassed",separate.correctness.passed && packed.correctness.passed, ...
    "packedRK4MeaningfullyFaster",rk4.ratioConfidenceInterval95(2)<threshold, ...
    "packedRK4ThresholdRatio",threshold, ...
    "separateIntegratorBytes",separate.stateStorage.totalIntegratorBytes, ...
    "packedIntegratorBytes",packed.stateStorage.totalIntegratorBytes, ...
    "packedToSeparateIntegratorByteRatio",packed.stateStorage.totalIntegratorBytes/separate.stateStorage.totalIntegratorBytes);
end

function decision = storageDecision(cases,configuration)
hasComparisons = arrayfun(@(benchmarkCase)~isempty(fieldnames(benchmarkCase.comparison)),cases);
if ~all(hasComparisons)
    decision = struct("status","incomplete","selectedStrategy","", ...
        "reason","Both strategies are required for a storage decision.", ...
        "minimumMeaningfulSpeedup",configuration.minimumMeaningfulSpeedup);
    return
end
correctnessPassed = arrayfun(@(benchmarkCase)benchmarkCase.comparison.allCorrectnessPassed,cases);
packedFaster = arrayfun(@(benchmarkCase)benchmarkCase.comparison.packedRK4MeaningfullyFaster,cases);
if all(correctnessPassed) && all(packedFaster)
    selected = "packed";
    reason = "Packed backing passed correctness and its fixed-RK4 95% median-ratio interval was wholly below the practical threshold in every case.";
else
    selected = "separate";
    reason = "Separate backing is retained because packed backing did not prove a practically meaningful fixed-RK4 improvement in every case.";
end
decision = struct( ...
    "status","complete","selectedStrategy",selected,"reason",reason, ...
    "minimumMeaningfulSpeedup",configuration.minimumMeaningfulSpeedup, ...
    "confidenceLevel",0.95,"decisionOperation","fixed-rk4-step", ...
    "requiresEveryCase",true);
end

function value = processMemory(samplePath,interval)
if ~isfile(samplePath)
    error("WaveVortexBenchmark:CoefficientStorageMemoryUnavailable","RSS samples are missing.");
end
lines = splitlines(strtrim(string(fileread(samplePath))));
steady = [];
operation = [];
for line = reshape(lines,1,[])
    fields = split(line,sprintf('\t'));
    if numel(fields)<4, continue, end
    bytes = 1024*str2double(fields(3));
    if fields(2)=="steady-retained", steady(end+1)=bytes; end %#ok<AGROW>
    if fields(2)=="operation", operation(end+1)=bytes; end %#ok<AGROW>
end
if isempty(steady) || isempty(operation)
    error("WaveVortexBenchmark:CoefficientStorageMemoryUnavailable", ...
        "RSS sampling did not capture steady-retained and operation phases.");
end
value = struct( ...
    "provider","macos-ps-process-tree", ...
    "boundary","total live-process-tree RSS during benchmark operations", ...
    "samplingIntervalSeconds",interval, ...
    "baselineRSSBytes",median(steady),"peakRSSBytes",max(operation), ...
    "peakIncrementBytes",max(0,max(operation)-median(steady)), ...
    "steadySampleCount",numel(steady),"operationSampleCount",numel(operation));
end

function value = environmentDescription()
value = struct( ...
    "matlabRelease",string(version("-release")), ...
    "architecture",string(computer("arch")), ...
    "computer",string(computer), ...
    "timestampUTC",string(datetime("now",TimeZone="UTC",Format="yyyy-MM-dd'T'HH:mm:ss'Z'")));
end

function writeArtifact(results,outputDirectory)
if isfolder(outputDirectory)
    error("WaveVortexBenchmark:CoefficientStorageOutputExists", ...
        "Output directory already exists: %s",outputDirectory);
end
mkdir(outputDirectory);
writeText(fullfile(outputDirectory,"benchmark.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(outputDirectory,"summary.md"),benchmarkSummary(results));
end

function value = benchmarkSummary(results)
lines = [ ...
    "# Free-Surface QG Coefficient-Storage Benchmark"; ...
    ""; ...
    "Decision: `"+results.decision.selectedStrategy+"`."; ...
    ""; ...
    results.decision.reason; ...
    ""; ...
    "| Case | packed/separate RK4 median | 95% interval | packed/separate state bytes |"; ...
    "| --- | ---: | ---: | ---: |"];
caseRows = strings(numel(results.cases),1);
for iCase = 1:numel(results.cases)
    benchmarkCase = results.cases(iCase);
    comparison = benchmarkCase.comparison;
    rk4 = comparison.operations(string({comparison.operations.id})=="fixed-rk4-step");
    caseRows(iCase) = sprintf("| %s | %.4f | [%.4f, %.4f] | %.4f |", ...
        benchmarkCase.id,rk4.packedToSeparateMedianRatio, ...
        rk4.ratioConfidenceInterval95(1),rk4.ratioConfidenceInterval95(2), ...
        comparison.packedToSeparateIntegratorByteRatio);
end
lines = [lines;caseRows;"";"RSS values are fresh-process total live-process-tree measurements; exact state bytes are MATLAB payload bytes reported by `whos`.";""];
value = strjoin(lines,newline);
end

function bytes = arrayBytes(value)
if ~isnumeric(value)
    error("WaveVortexBenchmark:CoefficientStorageLedgerType", ...
        "The coefficient storage ledger expects numeric arrays.");
end
info = whos("value");
bytes = info.bytes;
end

function value = emptyCase()
value = struct( ...
    "id","","gridId","","endpointId","", ...
    "Nxyz",zeros(1,3),"Lxyz",zeros(1,3), ...
    "g0",NaN,"gd",NaN,"activeEndpointCount",0, ...
    "modeCountPolicy","","requestedNj",zeros(0,1), ...
    "strategies",repmat(emptyStrategy(),0,1),"comparison",struct());
end

function value = emptyStrategy()
value = struct( ...
    "id","","status","", ...
    "operations",repmat(emptyOperation(),0,1), ...
    "stateStorage",struct(),"scientificConfiguration",struct(), ...
    "correctness",struct(),"memory",struct());
end

function value = emptyOperation()
value = struct("id","","rawSeconds",zeros(1,0),"medianSeconds",NaN);
end

function values = benchmarkStratification(z)
values = 1e-4*ones(size(z));
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
folders = strings(numel(metadata.folders)+2,1);
for iFolder = 1:numel(metadata.folders)
    item = metadata.folders(iFolder);
    folder = fullfile(repositoryRoot,item.path);
    if isfolder(folder), folders(iFolder)=folder; end
end
folders(end-1:end) = [repositoryRoot;benchmarkFolder];
folders(folders=="") = [];
currentFolders = string(split(path,pathsep));
for folder = reshape(folders,1,[])
    if ~any(currentFolders==folder)
        addpath(folder,"-end");
        currentFolders(end+1,1) = folder; %#ok<AGROW>
    end
end
end

function writePhase(pathname,phase)
if pathname=="", return, end
writeText(pathname+".tmp",phase);
movefile(pathname+".tmp",pathname,"f");
end

function waitForPhaseSample(phasePath)
if phasePath=="", return, end
acknowledgementPath = string(getenv("WV_RSS_PHASE_ACK"));
timer = tic;
while acknowledgementPath~="" && toc(timer)<5
    if isfile(acknowledgementPath) && strtrim(string(fileread(acknowledgementPath)))=="operation", return, end
    pause(0.001)
end
if acknowledgementPath~=""
    error("WaveVortexBenchmark:RSSPhaseHandshake","The RSS sampler did not acknowledge the operation phase.");
end
end

function closeModel(model)
if isempty(model) || ~isvalid(model), return, end
try
    model.closeNetCDFFile();
catch
end
delete(model);
end

function closeTransform(wvt)
if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
end

function value = commandOutput(stdoutPath,stderrPath)
value = "";
if isfile(stdoutPath), value=string(fileread(stdoutPath)); end
if isfile(stderrPath), value=value+newline+string(fileread(stderrPath)); end
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId<0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end

function restoreState(originalPath,originalRng)
path(originalPath);
rng(originalRng);
end
