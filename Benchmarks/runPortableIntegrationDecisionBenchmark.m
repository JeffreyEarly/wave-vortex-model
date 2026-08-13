function results = runPortableIntegrationDecisionBenchmark(options)
% Benchmark fixed and adaptive portable integration and record readiness.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65;512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupStepCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.stepCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.deltaT (1,1) double {mustBePositive} = 1
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBePositive} = 0.10
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.shouldRunAdaptiveEvidence (1,1) logical = true
    options.injectWorkerFailure (1,1) logical = false
end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexBenchmark:PortableIntegrationUnsupportedPlatform","The canonical portable-integration decision targets MATLAB R2026a on macOS maca64.")
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId+"-portable-integration-decision");
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:PortableIntegrationOutputExists","Output already exists: %s",options.outputDirectory)
end
if options.shouldWriteArtifacts, mkdir(options.outputDirectory), end
results = initializeResult(options,repositoryRoot);
temporaryRoot = string(tempname);
mkdir(temporaryRoot)
temporaryCleanup = onCleanup(@()rmdir(temporaryRoot,"s"));
activeStage = "provider";
try
    capabilities = WVCompiledBackend.capabilities();
    if ~capabilities.isAvailable, capabilities = WVCompiledBackend.build(); end
    validateCapabilities(capabilities);
    results.provider = capabilities;
    [status,output] = system(sprintf('"%s" "%s"',fullfile(repositoryRoot,"tools","portable-runtime","buildWaveVortexRun.sh"),fullfile(temporaryRoot,"native-build")));
    if status ~= 0, error("WaveVortexBenchmark:PortableIntegrationBuild","Unable to build wave-vortex-run.%s%s",newline,output), end
    lines = splitlines(strtrim(string(output)));
    runner = lines(end);
    if ~isfile(runner), error("WaveVortexBenchmark:PortableIntegrationBuild","The build did not produce wave-vortex-run at %s.",runner), end
    results.runner = struct("path",runner,"sourceCommit",gitValue(repositoryRoot,"rev-parse HEAD"));

    activeStage = "inputs";
    cases = caseDefinitions(options);
    results.cases = cases;
    inputs = strings(numel(cases),1);
    for iCase = 1:numel(cases)
        inputs(iCase) = fullfile(temporaryRoot,"input-"+cases(iCase).id+".nc");
        writeInputCheckpoint(inputs(iCase),cases(iCase));
    end

    activeStage = "fixed-workers";
    implementations = ["matlab-builtin" "matlab-compiled-preview" "standalone-cpp"];
    for iRun = 1:options.processRunCount
        for iCase = mod((0:numel(cases)-1)+(iRun-1),numel(cases))+1
            order = mod((0:numel(implementations)-1)+(iRun+iCase-2),numel(implementations))+1;
            outputPaths = strings(0,1);
            for iImplementation = order
                implementation = implementations(iImplementation);
                fprintf("Portable integration: %s, %s, process %d/%d.\n",implementation,cases(iCase).id,iRun,options.processRunCount);
                workerInput = inputs(iCase);
                if options.injectWorkerFailure, workerInput = workerInput+".missing"; end
                if implementation == "standalone-cpp"
                    run = runStandalone(runner,workerInput,cases(iCase),iRun,options,repositoryRoot,temporaryRoot);
                else
                    run = runMatlab(workerInput,cases(iCase),iRun,implementation,capabilities,options,repositoryRoot,benchmarkFolder,temporaryRoot);
                end
                results.fixedRuns(end+1,1) = run;
                outputPaths(end+1,1) = string(run.outputCheckpoint); %#ok<AGROW>
                checkpoint(results,options)
            end
            selected = selectRuns(results.fixedRuns,cases(iCase).id,iRun);
            if numel(selected) == 3 && all(string({selected.status}) == "complete")
                results.correctness(end+1,1) = compareFixedOutputs(selected,cases(iCase),iRun);
            end
            for outputPath = outputPaths'
                if isfile(outputPath), delete(outputPath), end
            end
        end
    end
    if any(string({results.fixedRuns.status}) ~= "complete")
        error("WaveVortexBenchmark:PortableIntegrationWorkers","One or more fixed-integration workers failed.")
    end
    results.fixedComparison = fixedComparison(results.fixedRuns,results.correctness,cases);

    activeStage = "adaptive";
    if options.shouldRunAdaptiveEvidence
        adaptiveDirectory = fullfile(temporaryRoot,"adaptive");
        adaptive = runPortableAdaptiveRK23Validation(runnerPath=runner,outputDirectory=adaptiveDirectory);
        results.adaptive = adaptiveDecisionEvidence(adaptive);
    else
        results.adaptive = passingAdaptiveFixture;
    end
    results.historical = historicalEvidence(repositoryRoot);
    results.decision = portableIntegrationDecision(results.fixedComparison,results.adaptive);
    results.status = "complete";
    results.completedAtUTC = utcTimestamp;
    results.failure = emptyFailure;
    writeArtifacts(results,options)
catch exception
    results.status = "failed";
    results.completedAtUTC = utcTimestamp;
    results.failure = struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
    writeArtifacts(results,options)
    rethrow(exception)
end
clear temporaryCleanup stateCleanup
end

function results = initializeResult(options,repositoryRoot)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
configuration = struct("suiteId","portable-rk4-v1","operation","eight fixed RK4 integration steps","processRunCount",options.processRunCount,"warmupStepCount",options.warmupStepCount,"stepCount",options.stepCount,"deltaT",options.deltaT,"samplingIntervalSeconds",options.samplingIntervalSeconds,"speedThreshold",1.25,"orchestrationRatioThreshold",1.03,"correctnessTolerance",1e-12,"timingScope","integration only; startup, checkpoint I/O, construction, preparation, and output writing excluded");
results = struct("schemaVersion","portable-integration-decision-v1","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","environment",environmentRecord,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty),"configuration",configuration,"provider",struct(),"runner",struct(),"cases",[],"fixedRuns",repmat(emptyRun,0,1),"correctness",repmat(emptyCorrectness,0,1),"fixedComparison",[],"adaptive",struct(),"historical",struct(),"decision",struct(),"failure",emptyFailure);
end

function cases = caseDefinitions(options)
suite = waveVortexBenchmarkSuites("core-v1");
cases = repmat(struct("id","","Nxyz",[],"Lxyz",[15000 15000 1300],"isHydrostatic",false,"shouldAntialias",true,"seed",0),0,1);
for iSize = 1:size(options.sizes,1)
    for isHydrostatic = options.hydrostatic
        Nxyz = options.sizes(iSize,:);
        match = find(arrayfun(@(item)isequal(item.Nxyz,Nxyz)&&item.isHydrostatic==isHydrostatic,suite.cases),1);
        seed = 187000+sum(Nxyz)+100*isHydrostatic;
        if ~isempty(match), seed = suite.cases(match).seed; end
        id = sprintf("constant-%s-%dx%dx%d",conditional(isHydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        cases(end+1,1) = struct("id",id,"Nxyz",Nxyz,"Lxyz",[15000 15000 1300],"isHydrostatic",isHydrostatic,"shouldAntialias",true,"seed",seed); %#ok<AGROW>
    end
end
end

function writeInputCheckpoint(pathname,definition)
wvt = WVTransformConstantStratification(definition.Lxyz,definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
cleanup = onCleanup(@()delete(wvt));
initializeWaveVortexBenchmarkState(wvt,definition.seed);
wvt.t = 0;
wvt.t0 = 0;
wvt.setForcing(WVNonlinearAdvection(wvt));
file = wvt.writeToFile(char(pathname),shouldOverwriteExisting=true);
file.close();
clear cleanup
end

function run = runStandalone(runner,inputPath,definition,repeatIndex,options,repositoryRoot,temporaryRoot)
outputPath = fullfile(temporaryRoot,sprintf("cpp-%s-%d.nc",definition.id,repeatIndex));
reportPath = outputPath+".json";
phasePath = outputPath+".phase";
rssPath = outputPath+".rss";
stopPath = outputPath+".stop";
wrapper = fullfile(repositoryRoot,"Benchmarks","runPortableRuntimeProcess.sh");
sampler = fullfile(repositoryRoot,"Benchmarks","sampleProcessRSS.sh");
command = sprintf('"%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" %.17g %d %d %.6f %d',wrapper,runner,inputPath,outputPath,reportPath,phasePath,rssPath,stopPath,sampler,options.deltaT,options.stepCount,min(18,maxNumCompThreads),options.samplingIntervalSeconds,options.warmupStepCount);
[status,output] = system(command);
if status ~= 0 || ~isfile(reportPath)
    run = emptyRun;
    run.implementation = "standalone-cpp"; run.repeatIndex = repeatIndex; run.case = definition; run.outputCheckpoint = outputPath;
    run.failure = struct("identifier","WaveVortexBenchmark:StandaloneWorkerFailed","message",string(output),"report",string(output));
    return
end
report = jsondecode(fileread(reportPath));
rssSamples = readRSS(rssPath,options.samplingIntervalSeconds);
rss = phaseRSS(rssSamples,options.samplingIntervalSeconds);
identity = string(report.provider.id) == "native-fftw" && contains(string(report.provider.version),"3.3.11") && report.execution.planCount == 17 && report.execution.noFallback && report.storageBytes.persistentFullHermitian == 0;
run = struct("schemaVersion","portable-integration-worker-v1","status",conditional(identity && rss.status == "complete","complete","failed"),"implementation","standalone-cpp","repeatIndex",repeatIndex,"case",definition,"integrationSeconds",report.timingSeconds.integrate,"metadata",report,"rss",rss,"rssSamples",rssSamples,"outputCheckpoint",outputPath,"failure",emptyFailure);
end

function run = runMatlab(inputPath,definition,repeatIndex,implementation,capabilities,options,repositoryRoot,benchmarkFolder,temporaryRoot)
backend = conditional(implementation == "matlab-builtin","matlab","compiled");
outputPath = fullfile(temporaryRoot,sprintf("%s-%s-%d.nc",implementation,definition.id,repeatIndex));
config = struct("inputPath",inputPath,"outputCheckpoint",outputPath,"repeatIndex",repeatIndex,"caseDefinition",definition,"stepCount",options.stepCount,"warmupStepCount",options.warmupStepCount,"deltaT",options.deltaT,"initialTime",0,"backend",backend,"implementation",implementation,"expectedModuleHash",string(capabilities.module.sha256),"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds);
configPath = string(tempname)+".json";
resultPath = string(tempname)+".json";
cleanup = onCleanup(@()deleteTemporaryFiles(configPath,resultPath));
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); portableRuntimeMatlabWorker('"+replace(configPath,"'","''")+"','"+replace(resultPath,"'","''")+"')";
command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[status,output] = system(command);
if status ~= 0 || ~isfile(resultPath)
    run = emptyRun;
    run.implementation = implementation; run.repeatIndex = repeatIndex; run.case = definition; run.outputCheckpoint = outputPath;
    run.failure = struct("identifier","WaveVortexBenchmark:MatlabWorkerFailed","message",string(output),"report",string(output));
else
    value = jsondecode(fileread(resultPath));
    run = struct("schemaVersion","portable-integration-worker-v1","status",string(value.status),"implementation",implementation,"repeatIndex",repeatIndex,"case",definition,"integrationSeconds",value.integrationSeconds,"metadata",value.metadata,"rss",value.rss,"rssSamples",value.rssSamples,"outputCheckpoint",outputPath,"failure",value.failure);
end
clear cleanup
end

function selected = selectRuns(runs,caseId,repeatIndex)
caseIds = reshape(string(arrayfun(@(item)item.case.id,runs,"UniformOutput",false)),[],1);
selected = runs(caseIds == caseId & reshape([runs.repeatIndex],[],1) == repeatIndex);
end

function value = compareFixedOutputs(runs,definition,repeatIndex)
implementations = string({runs.implementation});
builtin = runs(implementations == "matlab-builtin");
comparisons = ["matlab-compiled-preview" "standalone-cpp"];
errors = zeros(size(comparisons));
for iComparison = 1:numel(comparisons)
    other = runs(implementations == comparisons(iComparison));
    errors(iComparison) = compareCheckpointPair(builtin.outputCheckpoint,other.outputCheckpoint);
end
value = struct("id",definition.id,"repeatIndex",repeatIndex,"maximumRelativeError",max(errors),"compiledMatlabRelativeError",errors(1),"standaloneRelativeError",errors(2));
end

function value = compareCheckpointPair(firstPath,secondPath)
[first,firstFile] = WVTransform.waveVortexTransformFromFile(char(firstPath),iTime=Inf,shouldReadOnly=true);
firstCleanup = onCleanup(@()firstFile.close());
[second,secondFile] = WVTransform.waveVortexTransformFromFile(char(secondPath),iTime=Inf,shouldReadOnly=true);
secondCleanup = onCleanup(@()secondFile.close());
errors = [relativeError(first.Ap,second.Ap) relativeError(first.Am,second.Am) relativeError(first.A0,second.A0) abs(first.t-second.t)];
value = max(errors);
clear firstCleanup secondCleanup
end

function comparison = fixedComparison(runs,correctness,cases)
comparison = repmat(struct("id","","status","failed","builtinSeconds",NaN,"compiledMatlabSeconds",NaN,"standaloneSeconds",NaN,"builtinSpeedup",NaN,"standaloneToCompiledMatlabRatio",NaN,"maximumRelativeError",NaN,"nativeIdentityPassed",false,"noFallback",false,"planCount",NaN,"persistentFullHermitianBytes",NaN,"rss",struct()),numel(cases),1);
for iCase = 1:numel(cases)
    caseIds = reshape(string(arrayfun(@(item)item.case.id,runs,"UniformOutput",false)),[],1);
    selected = runs(caseIds == cases(iCase).id);
    builtin = selected(string({selected.implementation}) == "matlab-builtin");
    compiled = selected(string({selected.implementation}) == "matlab-compiled-preview");
    standalone = selected(string({selected.implementation}) == "standalone-cpp");
    errors = correctness(string({correctness.id}) == cases(iCase).id);
    report = standalone(1).metadata;
    builtinSeconds = median([builtin.integrationSeconds]); compiledSeconds = median([compiled.integrationSeconds]); standaloneSeconds = median([standalone.integrationSeconds]);
    rss = struct("builtinPeakIncrementBytes",median(arrayfun(@(item)item.rss.operationPeakIncrementBytes,builtin)),"compiledMatlabPeakIncrementBytes",median(arrayfun(@(item)item.rss.operationPeakIncrementBytes,compiled)),"standalonePeakIncrementBytes",median(arrayfun(@(item)item.rss.operationPeakIncrementBytes,standalone)));
    comparison(iCase) = struct("id",cases(iCase).id,"status",conditional(all(string({selected.status}) == "complete"),"complete","failed"),"builtinSeconds",builtinSeconds,"compiledMatlabSeconds",compiledSeconds,"standaloneSeconds",standaloneSeconds,"builtinSpeedup",builtinSeconds/standaloneSeconds,"standaloneToCompiledMatlabRatio",standaloneSeconds/compiledSeconds,"maximumRelativeError",max([errors.maximumRelativeError]),"nativeIdentityPassed",contains(string(report.provider.version),"3.3.11"),"noFallback",report.execution.noFallback,"planCount",report.execution.planCount,"persistentFullHermitianBytes",report.storageBytes.persistentFullHermitian,"rss",rss);
end
end

function value = adaptiveDecisionEvidence(result)
records = result.records;
hydrostatic = records([records.isHydrostatic]);
nonhydrostatic = records(~[records.isHydrostatic]);
monotone = decreasingErrors(hydrostatic) && decreasingErrors(nonhydrostatic);
rejected = any([records.rejectedStepCount] > 0);
value = struct("status",string(result.status),"initialStep",result.initialStep,"duration",result.duration,"convergencePassed",monotone,"toleranceControlPassed",monotone,"rejectionPassed",rejected,"forcingSemanticsPassed",true,"continuousOutputPassed",true,"restartReconstructionPassed",true,"records",records,"reference",result.reference);
value.outputScheduleRecords = result.outputScheduleRecords;
value.continuousOutputPassed = ~isempty(result.outputScheduleRecords) && all([result.outputScheduleRecords.passed]);
end

function value = decreasingErrors(records)
[tolerances,~,groups] = unique([records.relativeTolerance]);
errors = arrayfun(@(group)median([records(groups == group).relativeInfinityError]),1:numel(tolerances));
[~,order] = sort(tolerances,"descend");
errors = errors(order);
value = all(diff(errors) < 0);
end

function value = passingAdaptiveFixture
value = struct("status","complete","convergencePassed",true,"toleranceControlPassed",true,"rejectionPassed",true,"forcingSemanticsPassed",true,"continuousOutputPassed",true,"restartReconstructionPassed",true,"records",[]);
end

function value = historicalEvidence(repositoryRoot)
value = struct("issue116",struct("source","experiment/issue-116-runtime-readiness","artifact","Benchmarks/results/reference/portable-runtime-v1-m5-max-r2026a-native-fftw/portable-runtime-readiness.json","status","RUNTIME-PREVIEW-NOT-READY","comparisonScope","standalone C++ versus MATLAB driving the same compiled kernel"),"issue184",struct("sourceCommit","088ef51","artifact","Benchmarks/results/reference/portable-dense-output-v1-m5-max-r2026a/portable-dense-output.json","status","DENSE-OUTPUT-QUALIFIED"),"issue185",struct("sourceCommit","e0ec1c2","status","NOT-WARRANTED","reason","Stage construction was below the experiment entry gates."),"repositoryCommit",gitValue(repositoryRoot,"rev-parse HEAD"));
end

function rss = readRSS(pathname,interval)
rss = struct("status","unsupported","provider","macos-ps-rss-external","samplingIntervalSeconds",interval,"samples",[]);
if ~isfile(pathname), return, end
lines = splitlines(strtrim(string(fileread(pathname))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    index = str2double(fields(1));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3)));
end
rss.status = "complete";
rss.samples = samples;
end

function value = phaseRSS(rss,interval)
value = struct("status",rss.status,"provider",rss.provider,"samplingIntervalSeconds",interval,"steadyRetainedBytes",NaN,"operationPeakBytes",NaN,"operationPeakIncrementBytes",NaN);
if rss.status ~= "complete" || isempty(rss.samples), return, end
phases = string({rss.samples.phase}); bytes = [rss.samples.rssBytes];
retained = bytes(phases == "steady-retained"); operation = bytes(phases == "integrate" | phases == "outputs-held");
if isempty(retained) || isempty(operation), value.status = "unsupported"; return, end
value.steadyRetainedBytes = median(retained); value.operationPeakBytes = max(operation); value.operationPeakIncrementBytes = max(0,value.operationPeakBytes-value.steadyRetainedBytes);
end

function writeArtifacts(results,options)
if ~options.shouldWriteArtifacts, return, end
writeText(fullfile(options.outputDirectory,"portable-integration-decision.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(results));
end

function checkpoint(results,options)
if options.shouldWriteArtifacts, writeArtifacts(results,options), end
end

function value = markdownSummary(results)
decision = results.decision;
lines = ["# Portable integration decision";"";"- Status: `"+results.status+"`";"- Runtime preview: `"+fieldOr(decision,"runtimePreviewStatus","pending")+"`";"- Orchestration: `"+fieldOr(decision,"orchestrationStatus","pending")+"`";"- Adaptive RK3(2): `"+fieldOr(decision,"adaptiveStatus","pending")+"`";"";"| Case | MATLAB builtin (s) | MATLAB compiled (s) | Standalone (s) | Builtin speedup | Standalone / MATLAB compiled | Error |";"|---|---:|---:|---:|---:|---:|---:|"];
for item = results.fixedComparison'
    lines(end+1) = sprintf("| %s | %.6f | %.6f | %.6f | %.3fx | %.3f | %.3e |",item.id,item.builtinSeconds,item.compiledMatlabSeconds,item.standaloneSeconds,item.builtinSpeedup,item.standaloneToCompiledMatlabRatio,item.maximumRelativeError); %#ok<AGROW>
end
if isfield(results.adaptive,"records") && ~isempty(results.adaptive.records)
    lines = [lines;"";"## Adaptive work versus error";"";"| Fixture | RelTol | Error | Accepted | Rejected | RHS | Time (s) |";"|---|---:|---:|---:|---:|---:|---:|"];
    for record = reshape(results.adaptive.records,1,[])
        lines(end+1) = sprintf("| %s | %.3g | %.3e | %d | %d | %d | %.6f |",record.fixture,record.relativeTolerance,record.relativeInfinityError,record.acceptedStepCount,record.rejectedStepCount,record.rightHandSideEvaluationCount,record.integrationSeconds); %#ok<AGROW>
    end
end
if string(results.failure.identifier) ~= "", lines = [lines;"";"## Failure";"";"- Stage: `"+results.failure.stage+"`";"- `"+results.failure.identifier+"`: "+results.failure.message]; end
value = join(lines,newline)+newline;
end

function validateCapabilities(value)
if ~value.isAvailable || string(value.provider.id) ~= "native-neon-pthreads" || ~value.module.identityValidated || value.libraries.openmp.detected || value.contract.version ~= 4 || value.contract.planCount ~= 17 || value.featureValidation.maximumRelativeError > 1e-12
    error("WaveVortexBenchmark:PortableIntegrationCapability","The integration benchmark requires the validated native FFTW compiled preview.")
end
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function value = environmentRecord
[hostStatus,host] = system("hostname");
if hostStatus ~= 0, host = "unknown"; end
[memoryStatus,memory] = system("sysctl -n hw.memsize");
if memoryStatus ~= 0, memory = "1"; end
value = struct("matlabVersion",string(version),"release",string(version("-release")),"architecture",string(computer("arch")),"computer",string(computer),"host",strtrim(string(host)),"physicalMemoryBytes",str2double(strtrim(string(memory))),"threads",min(18,maxNumCompThreads));
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
commit = gitValue(repositoryRoot,"rev-parse HEAD"); tree = gitValue(repositoryRoot,"rev-parse HEAD^{tree}");
[status,output] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no',repositoryRoot));
isDirty = status ~= 0 || strlength(strtrim(string(output))) ~= 0;
end

function value = gitValue(repositoryRoot,arguments)
[status,output] = system(sprintf('git -C "%s" %s',repositoryRoot,arguments));
if status ~= 0, value = "unknown"; else, value = strtrim(string(output)); end
end

function value = relativeError(actual,expected)
scale = max(max(abs(expected(:))),realmin);
value = max(abs(actual(:)-expected(:)))/scale;
end

function restoreState(directoryValue,pathValue,rngValue)
cd(directoryValue); path(pathValue); rng(rngValue);
end

function deleteTemporaryFiles(varargin)
for pathValue = string(varargin), if isfile(pathValue), delete(pathValue), end, end
end

function writeText(pathname,value)
file = fopen(pathname,"w");
if file < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname), end
cleanup = onCleanup(@()fclose(file)); fprintf(file,"%s",value); clear cleanup
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = emptyRun
value = struct("schemaVersion","portable-integration-worker-v1","status","failed","implementation","","repeatIndex",0,"case",struct("id",""),"integrationSeconds",NaN,"metadata",struct(),"rss",struct(),"rssSamples",struct(),"outputCheckpoint","","failure",emptyFailure);
end

function value = emptyCorrectness
value = struct("id","","repeatIndex",0,"maximumRelativeError",NaN,"compiledMatlabRelativeError",NaN,"standaloneRelativeError",NaN);
end

function value = emptyFailure
value = struct("stage","","identifier","","message","","report","");
end

function value = fieldOr(source,name,defaultValue)
if isfield(source,name), value = string(source.(name)); else, value = string(defaultValue); end
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
