function results = runThreeInterfaceBenchmark(options)
% Compare matched MATLAB builtin, MATLAB compiled, and standalone compiled work.
arguments
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [256 256 129]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.deltaT (1,1) double {mustBePositive} = 1e-3
    options.relativeTolerance (1,1) double {mustBePositive} = 1e-3
    options.absoluteTolerance (1,1) double {mustBePositive} = 1e-6
    options.caseIds (1,:) string {mustBeMember(options.caseIds,["nonlinear-flux" "fixed-rk4-continuation" "adaptive-rk23-observer-output"])} = "adaptive-rk23-observer-output"
    options.adaptiveStepCount (1,1) double {mustBeInteger,mustBePositive} = 10
    options.adaptiveOutputCount (1,1) double {mustBeInteger,mustBePositive} = 2
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBePositive} = 0.05
    options.outputDirectory (1,1) string = ""
    options.archiveDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.injectWorkerFailure (1,1) logical = false
end
if ~ismac || string(computer("arch")) ~= "maca64" || isMATLABReleaseOlderThan("R2025b")
    error("WaveVortexBenchmark:ThreeInterfaceUnsupportedPlatform","The three-interface benchmark requires MATLAB R2025b or later on Apple silicon.");
end
if numel(options.caseIds) > 1 && any(options.caseIds == "adaptive-rk23-observer-output")
    error("WaveVortexBenchmark:MixedOutputSchedules","The adaptive benchmark uses its own output schedule and must run separately from the frozen nonlinear-flux and fixed-RK4 cases.");
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId+"-three-interface");
end
if options.archiveDirectory == ""
    options.archiveDirectory = fullfile(fileparts(repositoryRoot),"wave-vortex-model-benchmark-artifacts","three-interface");
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:ThreeInterfaceOutputExists","Output already exists: %s",options.outputDirectory);
end
if options.shouldWriteArtifacts
    mkdir(options.outputDirectory);
end
results = initializeResult(options,repositoryRoot);
workFolder = string(tempname);
mkdir(workFolder);
workCleanup = onCleanup(@()removeFolder(workFolder));
verifyTemporaryCapacity(workFolder,options);
activeStage = "provider";
try
    capabilities = WVCompiledBackend.capabilities();
    if ~capabilities.isAvailable
        capabilities = WVCompiledBackend.build();
    end
    validateCapabilities(capabilities);
    results.provider = capabilities;
    activeStage = "build";
    executables = buildStandaloneWorkers(repositoryRoot,capabilities);
    activeStage = "fixture";
    fixturePath = fullfile(workFolder,"matched-model.nc");
    createMatchedFixture(fixturePath,options);
    results.configuration.fixtureSHA256 = sha256File(fixturePath);
    checkpoint(results,options);

    activeStage = "workers";
    definitions = caseDefinitions(options);
    interfaces = ["matlab-builtin" "matlab-compiled" "standalone-compiled"];
    results.cases = definitions;
    for iRepeat = 1:options.processRunCount
        caseOrder = mod((0:numel(definitions)-1)+(iRepeat-1),numel(definitions))+1;
        for iCase = caseOrder
            interfaceOrder = mod((0:2)+(iRepeat+iCase-2),3)+1;
            for iInterface = interfaceOrder
                interface = interfaces(iInterface);
                fprintf("Three-interface benchmark: %s, %s, repeat %d/%d.\n",interface,definitions(iCase).id,iRepeat,options.processRunCount);
                results.runs(end+1,1) = runOne(interface,definitions(iCase),iRepeat,fixturePath,executables,capabilities,options,repositoryRoot,benchmarkFolder,workFolder);
                checkpoint(results,options);
            end
        end
    end
    failures = results.runs(string({results.runs.status})~="complete");
    if ~isempty(failures)
        messages = arrayfun(@(item)string(item.interface)+"/"+string(item.case.id)+": "+string(item.failure.message),failures);
        error("WaveVortexBenchmark:ThreeInterfaceWorkers","One or more workers failed:%s%s",newline,strjoin(messages,newline));
    end
    activeStage = "correctness";
    results.comparison = aggregate(results.runs,definitions,1e-12);
    validateThreeInterfaceBenchmarkContract(results);
    results.status = "complete";
    results.completedAtUTC = utcTimestamp;
    results.failure = emptyFailure;
    writeArtifacts(results,options);
    if options.shouldWriteArtifacts
        activeStage = "archive";
        results.externalArchive = archiveDetailedArtifact(options);
    end
catch exception
    results.status = "failed";
    results.completedAtUTC = utcTimestamp;
    results.failure = struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
    writeArtifacts(results,options);
    rethrow(exception)
end
clear workCleanup stateCleanup
end

function results = initializeResult(options,repositoryRoot)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct( ...
    "schemaVersion","three-interface-benchmark-v1", ...
    "status","running", ...
    "runId",options.runId, ...
    "generatedAtUTC",utcTimestamp, ...
    "completedAtUTC","", ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty), ...
    "environment",environmentRecord, ...
    "configuration",struct("Nxyz",options.Nxyz,"Lxyz",[15000 15000 1300],"processRunCount",options.processRunCount,"warmupCount",0,"samplesPerProcess",1,"deltaT",options.deltaT,"relativeTolerance",options.relativeTolerance,"absoluteTolerance",options.absoluteTolerance,"caseIds",options.caseIds,"adaptiveStepCount",options.adaptiveStepCount,"adaptiveOutputCount",options.adaptiveOutputCount,"threadCount",min(18,maxNumCompThreads),"samplingIntervalSeconds",options.samplingIntervalSeconds,"fixtureSHA256","","correctnessTolerance",1e-12,"timingBoundary","process wall includes interface launch; matched work includes the numerical operation and observer/file work","rssBoundary","external process-tree RSS sampled from worker launch through exit; total peak is primary, increment above steady-retained and final nonzero RSS are secondary"), ...
    "provider",struct(),"cases",[],"runs",repmat(emptyRun,0,1),"comparison",[],"failure",emptyFailure);
end

function definitions = caseDefinitions(options)
fixtureOutputInterval = options.deltaT/2;
if options.caseIds == "adaptive-rk23-observer-output"
    fixtureOutputInterval = options.adaptiveStepCount*options.deltaT/options.adaptiveOutputCount;
end
common = struct("Nxyz",options.Nxyz,"deltaT",options.deltaT,"finalTime",2*options.deltaT,"relativeTolerance",options.relativeTolerance,"absoluteTolerance",options.absoluteTolerance,"initialStep",options.deltaT,"maximumStep",options.deltaT,"outputInterval",fixtureOutputInterval,"observerGraph","cross-group Eulerian u, one mooring, two 3-D particles with tracked u, and one 3-D tracer","forcing","default WVNonlinearAdvection","shouldAntialias",true,"seed",4001);
available = [ ...
    mergeStruct(common,struct("id","nonlinear-flux","operation","nonlinearFlux","requestedIntegrator","none")); ...
    mergeStruct(common,struct("id","fixed-rk4-continuation","operation","model-continuation","requestedIntegrator","fixed-rk4")); ...
    mergeStruct(common,struct("id","adaptive-rk23-observer-output","operation","model-continuation","requestedIntegrator","adaptive-rk23","finalTime",(1+options.adaptiveStepCount)*options.deltaT))];
definitions = available(ismember(string({available.id}),options.caseIds));
end

function run = runOne(interface,definition,repeatIndex,fixturePath,executables,capabilities,options,repositoryRoot,benchmarkFolder,workFolder)
sampleFolder = fullfile(workFolder,sprintf('%s-%s-%d',interface,definition.id,repeatIndex));
mkdir(sampleFolder);
inputPath = fullfile(sampleFolder,"model.nc");
copyfile(fixturePath,inputPath);
comparisonPath = fullfile(sampleFolder,"comparison.bin");
phasePath = fullfile(sampleFolder,"phase.txt");
samplePath = fullfile(sampleFolder,"rss.tsv");
stdoutPath = fullfile(sampleFolder,"stdout.txt");
stderrPath = fullfile(sampleFolder,"stderr.txt");
writeText(phasePath,"launch");
processTimer = tic;
if startsWith(interface,"matlab-")
    backend = extractAfter(interface,"matlab-");
    if backend == "builtin", backend = "matlab"; end
    config = struct("interface",interface,"backend",backend,"sourceCommit",gitValue(repositoryRoot,"rev-parse HEAD"),"case",definition,"inputPath",inputPath,"comparisonPath",comparisonPath,"threadCount",min(18,maxNumCompThreads),"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"phasePath",phasePath,"plateauSeconds",options.plateauSeconds);
    configPath = fullfile(sampleFolder,"config.json");
    outputPath = fullfile(sampleFolder,"worker.json");
    writeText(configPath,jsonencode(config));
    if options.injectWorkerFailure
        configPath = configPath+".missing";
    end
    statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); threeInterfaceMatlabWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
    workerCommand = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
    command = sampledCommand(workerCommand,samplePath,phasePath,stdoutPath,stderrPath,options,benchmarkFolder);
    [exitCode,~] = system(command);
    processWallSeconds = toc(processTimer);
    commandOutput = readCommandOutput(stdoutPath,stderrPath);
    if exitCode ~= 0 || ~isfile(outputPath)
        run = emptyRun;
        run.interface = interface; run.case = definition; run.repeatIndex = repeatIndex;
        run.failure = struct("identifier","WaveVortexBenchmark:MatlabInterfaceWorkerFailed","message",string(commandOutput),"report",string(commandOutput));
        return
    end
    value = jsondecode(fileread(outputPath));
    run = normalizeMatlabRun(value,repeatIndex,processWallSeconds,processMemory(samplePath,options.samplingIntervalSeconds));
else
    if definition.id == "nonlinear-flux"
        workerCommand = shellQuote(executables.kernel)+" "+shellQuote(inputPath)+" "+string(min(18,maxNumCompThreads))+" 0 1 "+shellQuote(comparisonPath)+" --phase-file "+shellQuote(phasePath);
    else
        workerCommand = shellQuote(executables.runner)+" "+shellQuote(inputPath)+" --restart-mode model --output-policy append --delta-t "+numberText(definition.deltaT)+" --final-time "+numberText(definition.finalTime)+" --fft-provider native-fftw --threads "+string(min(18,maxNumCompThreads))+" --phase-file "+shellQuote(phasePath);
        workerCommand = workerCommand+" --integrator "+definition.requestedIntegrator;
        if definition.requestedIntegrator == "adaptive-rk23"
            workerCommand = workerCommand+" --relative-tolerance "+numberText(definition.relativeTolerance)+" --absolute-tolerance "+numberText(definition.absoluteTolerance)+" --initial-step "+numberText(definition.initialStep)+" --maximum-step "+numberText(definition.maximumStep);
        end
    end
    command = sampledCommand(workerCommand,samplePath,phasePath,stdoutPath,stderrPath,options,benchmarkFolder);
    [exitCode,~] = system(command);
    processWallSeconds = toc(processTimer);
    commandOutput = readCommandOutput(stdoutPath,stderrPath);
    if exitCode ~= 0
        run = emptyRun; run.interface = interface; run.case = definition; run.repeatIndex = repeatIndex;
        run.failure = struct("identifier","WaveVortexBenchmark:StandaloneInterfaceWorkerFailed","message",string(commandOutput),"report",string(commandOutput));
        return
    end
    value = jsondecode(fileread(stdoutPath));
    run = normalizeStandaloneRun(value,definition,repeatIndex,processWallSeconds,inputPath,comparisonPath,capabilities,processMemory(samplePath,options.samplingIntervalSeconds));
end
end

function run = normalizeMatlabRun(value,repeatIndex,processWallSeconds,memory)
run = emptyRun;
run.schemaVersion = string(value.schemaVersion); run.status = string(value.status); run.interface = string(value.interface); run.case = value.case; run.repeatIndex = repeatIndex; run.sourceCommit = string(value.sourceCommit); run.processWallSeconds = processWallSeconds; run.failure = value.failure;
if run.status ~= "complete"
    return
end
run.integrationSeconds = value.timing.integrationSeconds; run.interfaceTotalSeconds = value.timing.interfaceTotalSeconds; run.memory = memory; run.provider = value.provider; run.integrator = value.integrator; run.finalState = value.finalState; run.output = value.output;
end

function run = normalizeStandaloneRun(value,definition,repeatIndex,processWallSeconds,inputPath,comparisonPath,capabilities,memory)
run = emptyRun;
sourceCommit = "";
if isfield(value,"sourceCommit"), sourceCommit = string(value.sourceCommit); elseif isfield(value,"source") && isfield(value.source,"commit"), sourceCommit = string(value.source.commit); end
run.schemaVersion = string(value.schemaVersion); run.status = string(value.status); run.interface = "standalone-compiled"; run.case = definition; run.repeatIndex = repeatIndex; run.sourceCommit = sourceCommit; run.processWallSeconds = processWallSeconds;
if definition.id == "nonlinear-flux"
    run.integrationSeconds = value.timing.medianSeconds; run.interfaceTotalSeconds = processWallSeconds;
    run.memory = memory;
    run.integrator = struct("requested","none","actual","none","matched",true); run.finalState = struct(); run.output = struct("kind","flux-binary","path",comparisonPath);
else
    run.integrationSeconds = value.timingSeconds.integrate; run.interfaceTotalSeconds = value.timingSeconds.total;
    run.memory = memory;
    run.integrator = standaloneIntegratorRecord(value,definition,inputPath); run.finalState = value.state; run.output = struct("kind","model-output","path",inputPath);
    if isfield(value,"integrationBreakdownSeconds"), run.diagnostics = value.integrationBreakdownSeconds; end
end
noFallback = true;
if isfield(value.execution,"noFallback"), noFallback = logical(value.execution.noFallback); end
run.provider = struct("id","native-neon-pthreads","version",string(capabilities.provider.version),"threads",double(capabilities.contract.threadCount),"baseLibrary",string(value.provider.baseLibrary),"threadLibrary",string(value.provider.threadLibrary),"noFallback",noFallback);
run.failure = emptyFailure;
end

function comparison = aggregate(runs,definitions,tolerance)
interfaces = ["matlab-builtin" "matlab-compiled" "standalone-compiled"];
comparison = repmat(struct("id","","interfaces",[],"maximumRelativeError",NaN,"outputAgreementPassed",false,"outputGraph",emptyOutputGraph,"integratorAgreementPassed",false,"adaptiveWorkAgreementPassed",false,"memoryAgreementPassed",false,"matchedContractPassed",false),numel(definitions),1);
for iCase = 1:numel(definitions)
    selected = runs(string(arrayfun(@(item)item.case.id,runs,"UniformOutput",false))==definitions(iCase).id);
    records = repmat(struct("id","","processWallSeconds",NaN,"interfaceTotalSeconds",NaN,"integrationSeconds",NaN,"totalPeakRSSBytes",NaN,"incrementalPeakRSSBytes",NaN,"finalRSSBytes",NaN,"processWallRatio",NaN,"integrationRatio",NaN,"totalRSSRatio",NaN,"incrementalRSSRatio",NaN),numel(interfaces),1);
    builtin = selected(string({selected.interface})=="matlab-builtin");
    memoryPassed = all(arrayfun(@(item)string(item.memory.status)=="complete" && isfinite(item.memory.totalPeakRSSBytes) && item.memory.totalPeakRSSBytes>0,selected));
    builtinProcess = median([builtin.processWallSeconds]); builtinIntegration = median([builtin.integrationSeconds]); builtinPeak = median(arrayfun(@(item)item.memory.totalPeakRSSBytes,builtin)); builtinIncrement = median(arrayfun(@(item)item.memory.peakIncrementBytes,builtin));
    maximumError = 0; outputPassed = true; outputGraph = emptyOutputGraph;
    for iInterface = 1:numel(interfaces)
        candidate = selected(string({selected.interface})==interfaces(iInterface));
        processValue = median([candidate.processWallSeconds]); integrationValue = median([candidate.integrationSeconds]); peakValue = median(arrayfun(@(item)item.memory.totalPeakRSSBytes,candidate)); incrementValue = median(arrayfun(@(item)item.memory.peakIncrementBytes,candidate)); finalValue = median(arrayfun(@(item)item.memory.finalRSSBytes,candidate));
        records(iInterface) = struct("id",interfaces(iInterface),"processWallSeconds",processValue,"interfaceTotalSeconds",median([candidate.interfaceTotalSeconds]),"integrationSeconds",integrationValue,"totalPeakRSSBytes",peakValue,"incrementalPeakRSSBytes",incrementValue,"finalRSSBytes",finalValue,"processWallRatio",processValue/builtinProcess,"integrationRatio",integrationValue/builtinIntegration,"totalRSSRatio",peakValue/builtinPeak,"incrementalRSSRatio",safeRatio(incrementValue,builtinIncrement));
        if iInterface > 1
            for iRepeat = 1:numel(candidate)
                reference = builtin([builtin.repeatIndex]==candidate(iRepeat).repeatIndex);
                [errorValue,agreement,details] = compareOutputs(reference,candidate(iRepeat),tolerance);
                maximumError = max(maximumError,errorValue); outputPassed = outputPassed && agreement;
                outputGraph = mergeOutputGraph(outputGraph,details);
            end
        end
    end
    providersPassed = all(arrayfun(@(item)item.provider.noFallback,selected)) && all(arrayfun(@(item)item.interface=="matlab-builtin" || string(item.provider.id)=="native-neon-pthreads",selected));
    integratorsPassed = all(arrayfun(@(item)logical(item.integrator.matched) && string(item.integrator.requested)==definitions(iCase).requestedIntegrator && string(item.integrator.actual)==definitions(iCase).requestedIntegrator,selected));
    adaptiveWorkPassed = definitions(iCase).requestedIntegrator ~= "adaptive-rk23" || adaptiveWorkMatches(selected,definitions(iCase));
    comparison(iCase) = struct("id",definitions(iCase).id,"interfaces",records,"maximumRelativeError",maximumError,"outputAgreementPassed",outputPassed,"outputGraph",outputGraph,"integratorAgreementPassed",integratorsPassed,"adaptiveWorkAgreementPassed",adaptiveWorkPassed,"memoryAgreementPassed",memoryPassed,"matchedContractPassed",providersPassed&&integratorsPassed&&adaptiveWorkPassed&&memoryPassed&&maximumError<=tolerance&&outputPassed);
end
end

function value = standaloneIntegratorRecord(report,definition,pathname)
value = struct("requested",definition.requestedIntegrator,"actual",string(report.integrator.id),"matched",definition.requestedIntegrator==string(report.integrator.id));
if definition.requestedIntegrator ~= "adaptive-rk23"
    return
end
value.controller = string(report.integrator.controller);
value.relativeTolerance = double(report.integrator.relativeTolerance);
value.absoluteToleranceHash = string(report.integrator.toleranceHash);
value.absoluteToleranceHashClearedMantissaBits = double(report.integrator.toleranceHashClearedMantissaBits);
value.absoluteToleranceComponentHashes = string(report.integrator.toleranceComponentHashes(:)');
value.requestedInitialStep = double(report.integrator.requestedInitialStep);
value.effectiveInitialStep = double(report.integrator.effectiveInitialStep);
value.requestedMaximumStep = double(report.integrator.requestedMaximumStep);
value.effectiveMaximumStep = double(report.integrator.effectiveMaximumStep);
value.initialTime = double(report.state.initialTime);
value.finalTime = double(report.state.finalTime);
value.acceptedStepCount = double(report.state.stepCount);
value.rejectedStepCount = double(report.state.rejectedStepCount);
value.rhsEvaluationCount = double(report.state.rhsEvaluationCount);
value.denseOutputEvaluationCount = double(report.integrator.denseOutputEvaluationCount);
value.outputRecordCounts = outputRecordCounts(pathname);
end

function passed = adaptiveWorkMatches(runs,definition)
required = ["controller" "relativeTolerance" "absoluteToleranceHash" "absoluteToleranceHashClearedMantissaBits" "absoluteToleranceComponentHashes" "requestedInitialStep" "effectiveInitialStep" "requestedMaximumStep" "effectiveMaximumStep" "initialTime" "finalTime" "acceptedStepCount" "rejectedStepCount" "rhsEvaluationCount" "denseOutputEvaluationCount" "outputRecordCounts"];
passed = all(arrayfun(@(run)all(isfield(run.integrator,required)),runs));
if ~passed
    return
end
reference = runs(1).integrator;
for run = reshape(runs,1,[])
    current = run.integrator;
    exactFields = ["controller" "absoluteToleranceHash" "absoluteToleranceHashClearedMantissaBits" "acceptedStepCount" "rejectedStepCount" "rhsEvaluationCount" "denseOutputEvaluationCount"];
    passed = passed && all(arrayfun(@(name)string(current.(name))==string(reference.(name)),exactFields));
    passed = passed && isequal(string(current.absoluteToleranceComponentHashes(:)),string(reference.absoluteToleranceComponentHashes(:)));
    numericFields = ["relativeTolerance" "requestedInitialStep" "effectiveInitialStep" "requestedMaximumStep" "effectiveMaximumStep" "initialTime" "finalTime"];
    passed = passed && all(arrayfun(@(name)abs(double(current.(name))-double(reference.(name)))<=8*eps(max([1 abs(double(reference.(name)))])),numericFields));
    passed = passed && isequal(orderfields(current.outputRecordCounts),orderfields(reference.outputRecordCounts));
end
passed = passed && reference.controller == "matlab-ode23-v1" && reference.relativeTolerance == definition.relativeTolerance && reference.requestedInitialStep == definition.initialStep && reference.effectiveInitialStep == definition.initialStep && reference.requestedMaximumStep == definition.maximumStep && reference.effectiveMaximumStep == definition.maximumStep && reference.finalTime == definition.finalTime;
end

function [errorValue,agreement,details] = compareOutputs(reference,candidate,tolerance)
if string(reference.output.kind) == "flux-binary"
    expected = readBinary(reference.output.path); actual = readBinary(candidate.output.path);
    errorValue = max(abs(actual-expected))/max(max(abs(expected)),realmin("double")); agreement = isfinite(errorValue) && errorValue <= tolerance;
    details = struct("kind","flux-arrays","passed",agreement,"maximumRelativeError",errorValue,"maximumAbsoluteError",max(abs(actual-expected)),"variableCount",3,"recordCount",0,"categories",struct("name","coefficients","variableCount",3,"maximumAbsoluteError",max(abs(actual-expected)),"maximumRelativeError",errorValue,"passed",agreement),"differences",strings(0,1));
    return
end
details = compareWaveVortexOutputGraphs(reference.output.path,candidate.output.path);
details.kind = "complete-netcdf-output-graph";
errorValue = details.maximumRelativeError;
agreement = details.passed;
end

function result = mergeOutputGraph(result,value)
if result.kind == "", result = value; return, end
result.passed = result.passed && value.passed;
result.maximumRelativeError = max(result.maximumRelativeError,value.maximumRelativeError);
result.maximumAbsoluteError = max(result.maximumAbsoluteError,value.maximumAbsoluteError);
result.variableCount = max(result.variableCount,value.variableCount);
result.recordCount = max(result.recordCount,value.recordCount);
result.differences = unique([result.differences(:); value.differences(:)],"stable");
for category = reshape(value.categories,1,[])
    index = find(string({result.categories.name})==string(category.name),1);
    if isempty(index)
        result.categories(end+1) = category;
    else
        result.categories(index).variableCount = max(result.categories(index).variableCount,category.variableCount);
        result.categories(index).maximumAbsoluteError = max(result.categories(index).maximumAbsoluteError,category.maximumAbsoluteError);
        result.categories(index).maximumRelativeError = max(result.categories(index).maximumRelativeError,category.maximumRelativeError);
        result.categories(index).passed = result.categories(index).passed && category.passed;
    end
end
end

function createMatchedFixture(pathname,options)
definitions = caseDefinitions(options);
outputInterval = definitions(1).outputInterval;
wvt = WVTransformConstantStratification([15000 15000 1300],options.Nxyz,N0=sqrt(2e-5),latitude=45,isHydrostatic=false,shouldAntialias=true);
state = initializeWaveVortexBenchmarkState(wvt,4001); advanceWaveVortexBenchmarkState(wvt,state,0);
model = WVModel(wvt); cleanup = onCleanup(@()closeModels(model));
model.eulerianObservingSystem.addNetCDFOutputVariables('u');
model.setFloatPositions([1000 7000],[900 6500],[-250 -850],'u',absToleranceXY=1e-8,absToleranceZ=1e-8);
model.addTracer(sin(2*pi*wvt.X/wvt.Lx).*cos(2*pi*wvt.Y/wvt.Ly),"dye");
model.setupIntegrator(integratorType="fixed",deltaT=options.deltaT);
model.integrateToTime(options.deltaT,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
outputFile = model.createNetCDFFileForModelOutput(pathname,outputInterval=outputInterval,shouldOverwriteExisting=true);
group = outputFile.outputGroupWithName(model.defaultOutputGroupName());
particles = model.fluxedObservingSystemWithName("float");
tracer = model.fluxedObservingSystemWithName("dye");
group.removeObservingSystem([particles tracer]);
particleGroup = outputFile.addNewEvenlySpacedOutputGroup("particles",outputInterval=outputInterval);
particleGroup.addObservingSystem(particles);
tracerGroup = outputFile.addNewEvenlySpacedOutputGroup("tracers",outputInterval=outputInterval);
tracerGroup.addObservingSystem(tracer);
group.addObservingSystem(WVMooring(model,name="mooring",x=[0 5000],y=[0 4000],trackedFieldNames={'u'}));
model.outputTimesForIntegrationPeriod(model.t,model.t);
model.writeTimeStepToNetCDFFile(model.t);
model.recordNetCDFFileHistory();
model.closeNetCDFFile();
clear cleanup
end

function executables = buildStandaloneWorkers(repositoryRoot,capabilities)
buildDirectory = fullfile(repositoryRoot,".compiled-backend-cache","three-interface-build"); providerRoot = fullfile(capabilities.cache.root,"provider",capabilities.provider.id);
configure = "cmake -S "+shellQuote(fullfile(repositoryRoot,"PortableRuntime"))+" -B "+shellQuote(buildDirectory)+" -DCMAKE_BUILD_TYPE=Release -DWV_RUNTIME_ENABLE_NATIVE_FFTW=ON -DWV_RUNTIME_BUILD_BENCHMARKS=ON -DWV_RUNTIME_FFTW_ROOT="+shellQuote(providerRoot);
[status,output] = system(configure); if status~=0, error("WaveVortexBenchmark:StandaloneBuild","%s",output); end
[status,output] = system("cmake --build "+shellQuote(buildDirectory)+" --parallel --target wave-vortex-run wv-standalone-nonlinear-flux-benchmark"); if status~=0, error("WaveVortexBenchmark:StandaloneBuild","%s",output); end
executables = struct("runner",fullfile(buildDirectory,"wave-vortex-run"),"kernel",fullfile(buildDirectory,"wv-standalone-nonlinear-flux-benchmark"));
end

function validateCapabilities(value)
if ~value.isAvailable || string(value.provider.id)~="native-neon-pthreads" || ~value.module.identityValidated || value.libraries.openmp.detected || value.contract.planCount~=17 || value.featureValidation.maximumRelativeError>1e-12
    error("WaveVortexBenchmark:ThreeInterfaceCapability","The benchmark requires the validated native FFTW provider.");
end
end

function writeArtifacts(results,options)
if ~options.shouldWriteArtifacts, return, end
writeText(fullfile(options.outputDirectory,"three-interface-benchmark.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end

function checkpoint(results,options)
if options.shouldWriteArtifacts, writeArtifacts(results,options); end
end

function archive = archiveDetailedArtifact(options)
if ~isfolder(options.archiveDirectory)
    mkdir(options.archiveDirectory);
end
rawPath = fullfile(options.outputDirectory,"three-interface-benchmark.json");
archiveName = options.runId+"-three-interface-benchmark.json.gz";
generated = gzip(rawPath,options.archiveDirectory);
generatedPath = string(generated{1});
archivePath = fullfile(options.archiveDirectory,archiveName);
if generatedPath ~= archivePath
    movefile(generatedPath,archivePath,"f");
end
information = dir(archivePath);
archive = struct("fileName",archiveName,"sha256",sha256File(archivePath),"compressedBytes",information.bytes,"location","external author archive; not distributed with source");
end

function markdown = summaryMarkdown(results)
lines = ["# Matched three-interface benchmark"; ""; "Status: `"+results.status+"`."; ""; "| Case | Interface | Process wall (s) | Integration (s) | Peak RSS (GiB) | Increment RSS (GiB) |"; "|---|---|---:|---:|---:|---:|"];
if ~isempty(results.comparison)
    for benchmarkCase = reshape(results.comparison,1,[])
        for item = reshape(benchmarkCase.interfaces,1,[])
            lines(end+1) = sprintf('| %s | %s | %.6f | %.6f | %.3f | %.3f |',benchmarkCase.id,item.id,item.processWallSeconds,item.integrationSeconds,item.totalPeakRSSBytes/2^30,item.incrementalPeakRSSBytes/2^30); %#ok<AGROW>
        end
    end
end
markdown = strjoin(lines,newline)+newline;
end

function value = readBinary(pathname)
fileId=fopen(pathname,"r"); cleanup=onCleanup(@()fclose(fileId)); values=fread(fileId,Inf,"double"); value=complex(values(1:2:end),values(2:2:end)); clear cleanup
end

function command = sampledCommand(workerCommand,samplePath,phasePath,stdoutPath,stderrPath,options,benchmarkFolder)
sampler = fullfile(benchmarkFolder,"runProcessWithRSS.sh");
if ~isfile(sampler)
    error("WaveVortexBenchmark:MissingRSSSampler","The process-tree RSS sampler is missing.");
end
command = shellQuote(sampler)+" "+shellQuote(samplePath)+" "+shellQuote(phasePath)+" "+numberText(options.samplingIntervalSeconds)+" "+shellQuote(stdoutPath)+" "+shellQuote(stderrPath)+" -- /bin/sh -c "+shellQuote(workerCommand);
end

function output = readCommandOutput(stdoutPath,stderrPath)
output = "";
if isfile(stdoutPath), output = string(fileread(stdoutPath)); end
if isfile(stderrPath), output = output+newline+string(fileread(stderrPath)); end
end

function memory = processMemory(samplePath,interval)
memory = struct("status","failed","provider","macos-ps-process-tree","samplingIntervalSeconds",interval,"totalPeakRSSBytes",NaN,"baselineProcessBytes",NaN,"peakIncrementBytes",NaN,"finalRSSBytes",NaN,"maximumProcessCount",0,"samples",[]);
if ~isfile(samplePath)
    return
end
lines = splitlines(strtrim(string(fileread(samplePath))));
lines(lines=="") = [];
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0,"processCount",0),0,1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    if numel(fields) < 4
        continue
    end
    index = str2double(fields(1));
    rssBytes = 1024*str2double(fields(3));
    processCount = str2double(fields(4));
    if ~isfinite(index) || ~isfinite(rssBytes) || rssBytes<=0 || ~isfinite(processCount) || processCount<1
        continue
    end
    samples(end+1,1) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",rssBytes,"processCount",processCount); %#ok<AGROW>
end
bytes = [samples.rssBytes];
phases = string({samples.phase});
baseline = bytes(phases=="steady-retained");
memory.samples = samples;
if isempty(samples)
    return
end
memory.status = "complete";
memory.totalPeakRSSBytes = max(bytes);
if ~isempty(baseline)
    memory.baselineProcessBytes = median(baseline);
    memory.peakIncrementBytes = max(0,memory.totalPeakRSSBytes-memory.baselineProcessBytes);
end
memory.finalRSSBytes = bytes(end);
memory.maximumProcessCount = max([samples.processCount]);
end

function value = mergeStruct(first,second)
value=first; names=fieldnames(second); for iName=1:numel(names), value.(names{iName})=second.(names{iName}); end
end
function value=safeRatio(numerator,denominator), if denominator==0, value=conditional(numerator==0,1,Inf); else, value=numerator/denominator; end, end
function value=numberText(value), value=string(sprintf('%.17g',value)); end
function value=shellQuote(value), value="'"+replace(string(value),"'","'""'""'")+"'"; end
function closeModels(varargin), for i=1:numel(varargin), value=varargin{i}; if ~isempty(value)&&isvalid(value), try, value.closeNetCDFFile(); catch, end; delete(value); end, end, end
function removeFolder(pathname), if isfolder(pathname), rmdir(pathname,"s"); end, end
function verifyTemporaryCapacity(pathname,options)
realGridBytes = prod(double(options.Nxyz))*8;
requiredBytes = max(256*2^20,ceil(360*realGridBytes*options.processRunCount/3));
[status,output] = system("/bin/df -Pk "+shellQuote(pathname));
lines = splitlines(strtrim(string(output)));
if status~=0 || numel(lines)<2
    error("WaveVortexBenchmark:ThreeInterfaceDiskCapacity","Unable to determine free space for the three-interface benchmark temporary directory.");
end
fields = split(strtrim(lines(end)));
fields(fields=="") = [];
availableBytes = 1024*str2double(fields(4));
if ~isfinite(availableBytes) || availableBytes<requiredBytes
    error("WaveVortexBenchmark:ThreeInterfaceDiskCapacity","The canonical benchmark requires approximately %.1f GiB of temporary free space, but %.1f GiB is available.",requiredBytes/2^30,availableBytes/2^30);
end
end
function restoreState(directory,originalPath,originalRng), cd(directory); path(originalPath); rng(originalRng); end
function addRepositoryPaths(root,benchmark), metadata=jsondecode(fileread(fullfile(root,"resources","mpackage.json"))); for item=reshape(metadata.folders,1,[]), folder=fullfile(root,item.path); if isfolder(folder), addpath(folder); end, end, addpath(root); addpath(benchmark); end
function writeText(pathname,contents), parent=fileparts(pathname); if ~isfolder(parent), mkdir(parent); end, fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end, cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup, end
function value=sha256File(pathname), [status,output]=system(sprintf('/usr/bin/shasum -a 256 %s',shellQuote(pathname))); if status~=0, error("WaveVortexBenchmark:HashFailed","%s",output); end, value=string(extractBefore(strtrim(output),65)); end
function [commit,tree,isDirty]=gitIdentity(root), commit=gitValue(root,"rev-parse HEAD"); tree=gitValue(root,"rev-parse HEAD^{tree}"); [status,~]=system("git -C "+shellQuote(root)+" diff --quiet && git -C "+shellQuote(root)+" diff --cached --quiet"); isDirty=status~=0; end
function value=gitValue(root,args), [status,output]=system("git -C "+shellQuote(root)+" "+args); if status~=0,error("WaveVortexBenchmark:GitIdentity","%s",output);end,value=strtrim(string(output));end
function value=environmentRecord, [~,processor]=system("/usr/sbin/sysctl -n machdep.cpu.brand_string"); [~,memory]=system("/usr/sbin/sysctl -n hw.memsize"); value=struct("processor",strtrim(string(processor)),"physicalMemoryBytes",str2double(memory),"os",string(system_dependent("getos")),"matlabVersion",string(version),"release",string(version("-release")),"architecture",string(computer("arch")),"requestedThreads",min(18,maxNumCompThreads)); end
function value=utcTimestamp, value=string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")); end
function value=conditional(condition,a,b), if condition,value=a;else,value=b;end,end
function value=emptyFailure, value=struct("stage","","identifier","","message","","report",""); end
function value=emptyOutputGraph, value=struct("kind","","passed",true,"maximumRelativeError",0,"maximumAbsoluteError",0,"variableCount",0,"recordCount",0,"categories",repmat(struct("name","","variableCount",0,"maximumAbsoluteError",0,"maximumRelativeError",0,"passed",true),0,1),"differences",strings(0,1)); end
function value=emptyRun, value=struct("schemaVersion","three-interface-worker-v1","status","failed","interface","","case",struct(),"repeatIndex",0,"sourceCommit","","processWallSeconds",NaN,"interfaceTotalSeconds",NaN,"integrationSeconds",NaN,"memory",struct(),"provider",struct(),"integrator",struct(),"finalState",struct(),"output",struct(),"diagnostics",struct(),"failure",struct("identifier","","message","","report","")); end
function value=outputRecordCounts(pathname), value=struct("waveVortex",numel(ncread(pathname,"/wave-vortex/t")),"particles",numel(ncread(pathname,"/particles/t")),"tracers",numel(ncread(pathname,"/tracers/t"))); end
