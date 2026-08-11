function results = runMatlabNonlinearFluxOptimizationBenchmark(options)
% Benchmark author-only MATLAB nonlinear-flux scheduling experiments.
arguments
    options.suiteId (1,1) string = "core-v1"
    options.caseIds (1,:) string = strings(1,0)
    options.variants (1,:) string = WVMatlabNonlinearFluxExperiment.variantIdentifiers()
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.correctnessTolerance (1,1) double {mustBePositive} = 1e-12
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = ""
    options.shouldMeasureRSS (1,1) logical = true
    options.shouldWriteArtifacts (1,1) logical = true
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);

knownVariants = WVMatlabNonlinearFluxExperiment.variantIdentifiers();
unknownVariants = setdiff(options.variants,knownVariants);
if ~isempty(unknownVariants)
    error("WaveVortexBenchmark:UnknownMATLABOptimizationVariant","Unknown MATLAB nonlinear-flux optimization variant: %s.",strjoin(unknownVariants,", "));
end
if ~ismember("current",options.variants)
    options.variants = ["current" options.variants];
end

suite = waveVortexBenchmarkSuites(options.suiteId);
cases = suite.cases(startsWith(string({suite.cases.transformId}),"constant-"));
if ~isempty(options.caseIds)
    unknownCases = setdiff(options.caseIds,string({cases.id}));
    if ~isempty(unknownCases)
        error("WaveVortexBenchmark:UnknownCase","Unknown constant-stratification benchmark case: %s.",strjoin(unknownCases,", "));
    end
    cases = cases(ismember(string({cases.id}),options.caseIds));
end
if isempty(cases)
    error("WaveVortexBenchmark:NoMATLABOptimizationCases","No constant-stratification cases matched the issue #125 benchmark selection.");
end

if options.runId == ""
    options.runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"));
end
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue125",options.runId + "-" + computer("arch") + "-" + version("-release"));
end

correctness = measureCorrectness(cases,options.variants,options.correctnessTolerance);
caseResults = emptyCases();
executionSchedule = strings(0,1);
for iCase = 1:numel(cases)
    allocationControls = measureAllocationControls(cases(iCase));
    variantRuns = repmat(emptyRuns(),1,numel(options.variants));
    for iRepeat = 1:options.processRunCount
        order = rotateOrder(options.variants,iRepeat+iCase-2);
        executionSchedule(end+1,1) = cases(iCase).id + ":repeat-" + iRepeat + ":" + strjoin(order,","); %#ok<AGROW>
        for variant = order
            iVariant = find(options.variants == variant,1);
            run = runWorker(cases(iCase),variant,iRepeat,options,benchmarkFolder,repositoryRoot);
            variantRuns(iVariant).runs(end+1,1) = run;
        end
    end
    caseResults(end+1,1) = aggregateCase(cases(iCase),options.variants,variantRuns,correctness(iCase),allocationControls); %#ok<AGROW>
end

decisions = classifyVariants(caseResults,options.variants,options.correctnessTolerance);
status = "complete";
if any(string({caseResults.status}) ~= "complete")
    status = "partial";
end
[sourceCommit,sourceTree,sourceDirty] = sourceIdentity(repositoryRoot);
sourceFiles = sourceFileRecords(repositoryRoot);
results = struct( ...
    "schemaVersion","issue125-v1", ...
    "status",status, ...
    "runId",options.runId, ...
    "environment",environmentRecord(), ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","branch","experiment/issue-125-matlab-scheduling","commit",sourceCommit,"tree",sourceTree,"dirty",sourceDirty,"files",sourceFiles), ...
    "configuration",struct("suiteId",options.suiteId,"caseIds",options.caseIds,"variants",options.variants,"processRunCount",options.processRunCount,"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"correctnessTolerance",options.correctnessTolerance,"warmupPolicy","suite-defined","samplePolicy","suite-defined","executionSchedule",executionSchedule), ...
    "variantDefinitions",variantDefinitions(), ...
    "cases",caseResults, ...
    "decisions",decisions);

if options.shouldWriteArtifacts
    writeArtifacts(results,options.outputDirectory);
end
clear stateCleanup
end

function correctness = measureCorrectness(cases,variants,tolerance)
correctness = repmat(struct("caseId","","variants",emptyCorrectnessVariants()),numel(cases),1);
for iCase = 1:numel(cases)
    wvt = createWaveVortexBenchmarkTransform(cases(iCase),"builtin");
    transformCleanup = onCleanup(@()deleteIfValid(wvt));
    state = initializeWaveVortexBenchmarkState(wvt,cases(iCase).seed);
    advanceWaveVortexBenchmarkState(wvt,state,1);
    [Fp,Fm,F0] = wvt.nonlinearFlux();
    reference = {Fp,Fm,F0};
    records = emptyCorrectnessVariants();
    for variant = variants
        advanceWaveVortexBenchmarkState(wvt,state,1);
        experiment = WVMatlabNonlinearFluxExperiment(wvt,variant);
        experimentCleanup = onCleanup(@()deleteIfValid(experiment));
        [candidateFp,candidateFm,candidateF0] = experiment.execute();
        relativeError = waveVortexBenchmarkRelativeError(reference,{candidateFp,candidateFm,candidateF0});
        records(end+1,1) = struct("variant",variant,"relativeError",relativeError,"passed",relativeError <= tolerance,"workspaceLedger",experiment.storageLedger(),"metadata",experiment.executionMetadata()); %#ok<AGROW>
        clear experimentCleanup
    end
    correctness(iCase) = struct("caseId",cases(iCase).id,"variants",records);
    clear transformCleanup
end
end

function run = runWorker(benchmarkCase,variant,repeatIndex,options,benchmarkFolder,repositoryRoot)
configPath = string(tempname) + ".json";
outputPath = string(tempname) + ".json";
cleanup = onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
config = struct("benchmarkCase",benchmarkCase,"variant",variant,"repeatIndex",repeatIndex,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"shouldMeasureRSS",options.shouldMeasureRSS);
writeText(configPath,jsonencode(config));
matlabExecutable = fullfile(matlabroot,"bin","matlab");
statement = "addpath('" + replace(benchmarkFolder,"'","''") + "'); waveVortexMatlabOptimizationWorker('" + replace(configPath,"'","''") + "','" + replace(outputPath,"'","''") + "')";
command = sprintf('"%s" -batch "%s"',matlabExecutable,replace(statement,'"','\"'));
[exitCode,commandOutput] = system(command);
if exitCode ~= 0 || ~isfile(outputPath)
    run = failedRun(variant,repeatIndex,"WaveVortexBenchmark:MATLABOptimizationWorkerFailed",string(commandOutput));
    return
end
decoded = jsondecode(fileread(outputPath));
run = normalizeRun(decoded);
clear cleanup
end

function result = aggregateCase(definition,variants,variantRuns,correctness,allocationControls)
aggregates = emptyVariantAggregates();
for iVariant = 1:numel(variants)
    runs = variantRuns(iVariant).runs;
    complete = string({runs.status}) == "complete";
    rawSeconds = vertcat(runs(complete).rawSeconds);
    processMedians = [runs(complete).medianSeconds];
    rssComplete = complete & arrayfun(@(run)isfield(run.rss,"status") && string(run.rss.status) == "complete",runs);
    peakRSS = NaN(1,numel(runs));
    persistentRSS = NaN(1,numel(runs));
    for iRun = 1:numel(runs)
        if rssComplete(iRun)
            peakRSS(iRun) = runs(iRun).rss.peakIncrementBytes;
            persistentRSS(iRun) = runs(iRun).rss.persistentIncrementBytes;
        end
    end
    correctnessRecord = correctness.variants(string({correctness.variants.variant}) == variants(iVariant));
    aggregateStatus = conditional(all(complete),"complete","partial");
    aggregates(end+1,1) = struct( ...
        "variant",variants(iVariant), ...
        "status",aggregateStatus, ...
        "runs",runs, ...
        "rawSeconds",rawSeconds, ...
        "processMedianSeconds",processMedians, ...
        "medianSeconds",median(processMedians,"omitnan"), ...
        "relativeError",correctnessRecord.relativeError, ...
        "correctnessPassed",correctnessRecord.passed, ...
        "workspaceLedger",correctnessRecord.workspaceLedger, ...
        "metadata",correctnessRecord.metadata, ...
        "rss",struct("status",conditional(all(rssComplete),"complete","partial"),"persistentIncrementBytes",persistentRSS,"peakIncrementBytes",peakRSS,"medianPersistentIncrementBytes",median(persistentRSS,"omitnan"),"medianPeakIncrementBytes",median(peakRSS,"omitnan")), ...
        "speedup",NaN, ...
        "peakRSSRatio",NaN); %#ok<AGROW>
end
current = aggregates(string({aggregates.variant}) == "current");
for iVariant = 1:numel(aggregates)
    aggregates(iVariant).speedup = current.medianSeconds/aggregates(iVariant).medianSeconds;
    aggregates(iVariant).peakRSSRatio = current.rss.medianPeakIncrementBytes/aggregates(iVariant).rss.medianPeakIncrementBytes;
end
status = conditional(all(string({aggregates.status}) == "complete"),"complete","partial");
result = struct("id",definition.id,"transformId",definition.transformId,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"status",status,"allocationControls",allocationControls,"variants",aggregates);
end

function controls = measureAllocationControls(definition)
fieldCount = 3 + double(~definition.isHydrostatic);
shape = double(definition.Nxyz);
sampleCount = definition.sampleCount;
warmupCount = definition.warmupCount;
buffers = cell(1,fieldCount);
for iField = 1:fieldCount
    buffers{iField} = zeros(shape);
end
for iWarmup = 1:warmupCount
    temporary = cell(1,fieldCount);
    for iField = 1:fieldCount
        temporary{iField} = zeros(shape);
    end
    clear temporary
    for iField = 1:fieldCount
        buffers{iField}(:) = 0;
    end
end
allocationSeconds = zeros(sampleCount,1);
resetSeconds = zeros(sampleCount,1);
overwriteSeconds = zeros(sampleCount,1);
for iSample = 1:sampleCount
    timer = tic;
    temporary = cell(1,fieldCount);
    for iField = 1:fieldCount
        temporary{iField} = zeros(shape);
    end
    allocationSeconds(iSample) = toc(timer);
    clear temporary

    timer = tic;
    for iField = 1:fieldCount
        buffers{iField}(:) = 0;
    end
    resetSeconds(iSample) = toc(timer);

    timer = tic;
    for iField = 1:fieldCount
        buffers{iField}(:) = iField;
    end
    overwriteSeconds(iSample) = toc(timer);
end
controls = struct( ...
    "fieldCount",fieldCount, ...
    "bytes",8*fieldCount*prod(shape), ...
    "allocationSeconds",allocationSeconds, ...
    "resetSeconds",resetSeconds, ...
    "overwriteSeconds",overwriteSeconds, ...
    "medianAllocationSeconds",median(allocationSeconds), ...
    "medianResetSeconds",median(resetSeconds), ...
    "medianOverwriteSeconds",median(overwriteSeconds), ...
    "copyOnWriteEvidence","unavailable-supported-api");
end

function decisions = classifyVariants(cases,variants,tolerance)
definitions = variantDefinitions();
decisions = repmat(struct("variant","","complexity","","productionEligible",false,"requiredImprovement",NaN,"outcome","","qualifyingSize",[],"speedQualified",false,"memoryQualified",false,"reason",""),0,1);
for variant = variants(variants ~= "current")
    definition = definitions(string({definitions.id}) == variant);
    outcome = "NOT_ADOPTED";
    qualifyingSize = [];
    speedQualified = false;
    memoryQualified = false;
    reason = "No common hydrostatic/nonhydrostatic size passed the issue #125 5% gate.";
    sizes = unique(arrayfun(@(item)item.Nxyz(1),cases));
    for horizontalSize = sizes
        selectedCases = cases(arrayfun(@(item)item.Nxyz(1) == horizontalSize,cases));
        if numel(selectedCases) ~= 2 || numel(unique([selectedCases.isHydrostatic])) ~= 2
            continue
        end
        candidate = arrayfun(@(item)item.variants(string({item.variants.variant}) == variant),selectedCases);
        errorsPass = all([candidate.relativeError] <= tolerance);
        speedPass = errorsPass && all([candidate.speedup] >= definition.requiredImprovement) && all([candidate.peakRSSRatio] >= 1/1.03 | ~isfinite([candidate.peakRSSRatio]));
        memoryPass = errorsPass && all([candidate.peakRSSRatio] >= definition.requiredImprovement) && all([candidate.speedup] >= 1/1.03);
        if speedPass || memoryPass
            qualifyingSize = selectedCases(1).Nxyz;
            speedQualified = speedPass;
            memoryQualified = memoryPass;
            if definition.productionEligible
                outcome = "QUALIFIED_LOCAL";
                reason = "A few-line local candidate passed the 5% adoption gate.";
            else
                outcome = "PROTOTYPE_ONLY";
                reason = "The prototype cleared the numerical 5% screen but is not a few-line stateless production change under issue #125.";
            end
            break
        end
    end
    decisions(end+1,1) = struct("variant",variant,"complexity",definition.complexity,"productionEligible",definition.productionEligible,"requiredImprovement",definition.requiredImprovement,"outcome",outcome,"qualifyingSize",qualifyingSize,"speedQualified",speedQualified,"memoryQualified",memoryQualified,"reason",reason); %#ok<AGROW>
end
end

function definitions = variantDefinitions()
definitions = [ ...
    struct("id","current","description","Unchanged production nonlinearFlux path","complexity","control","productionEligible",false,"requiredImprovement",1.00); ...
    struct("id","scalar-zero","description","Scalar accumulation seed instead of allocating zero arrays","complexity","local","productionEligible",true,"requiredImprovement",1.05); ...
    struct("id","reusable-reset","description","Persistent spatial flux arrays reset before forcing","complexity","persistent-state prototype","productionEligible",false,"requiredImprovement",1.05); ...
    struct("id","reusable-overwrite","description","Persistent spatial flux arrays fully overwritten for default nonlinear advection","complexity","persistent-state prototype","productionEligible",false,"requiredImprovement",1.05); ...
    struct("id","forward-batch-cat","description","Concatenated 4-D batched forward horizontal projection","complexity","contained prototype","productionEligible",false,"requiredImprovement",1.05); ...
    struct("id","forward-batch-preallocated","description","Preallocated 4-D batched forward horizontal projection","complexity","persistent-state prototype","productionEligible",false,"requiredImprovement",1.05); ...
    struct("id","full-batch-cat","description","Concatenated batched inverse reconstruction and forward projection","complexity","architectural prototype","productionEligible",false,"requiredImprovement",1.05); ...
    struct("id","full-batch-preallocated","description","Preallocated batched inverse reconstruction and forward projection","complexity","architectural persistent-state prototype","productionEligible",false,"requiredImprovement",1.05)];
end

function writeArtifacts(results,outputDirectory)
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
writeText(fullfile(outputDirectory,"matlab-optimization-benchmark.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(outputDirectory,"summary.md"),summaryMarkdown(results));
end

function text = summaryMarkdown(results)
lines = [ ...
    "# MATLAB nonlinear-flux optimization benchmark"; ...
    ""; ...
    "- Status: `" + results.status + "`"; ...
    "- Source: `" + results.source.commit + "`"; ...
    "- MATLAB: `" + results.environment.matlabRelease + "`"; ...
    "- Architecture: `" + results.environment.architecture + "`"; ...
    "- Fresh processes per variant/case: `" + results.configuration.processRunCount + "`"; ...
    ""; ...
    "## Complete nonlinearFlux timing and memory"; ...
    ""; ...
    "| Case | Variant | Median (ms) | Speedup | Peak RSS ratio | Error | Workspace (MiB) |"; ...
    "|---|---|---:|---:|---:|---:|---:|"];
for benchmarkCase = results.cases'
    for variant = benchmarkCase.variants'
        lines(end+1) = sprintf("| %s | %s | %.3f | %.3fx | %.3fx | %.3g | %.3f |",benchmarkCase.id,variant.variant,1e3*variant.medianSeconds,variant.speedup,variant.peakRSSRatio,variant.relativeError,variant.workspaceLedger.knownPersistentBytes/2^20); %#ok<AGROW>
    end
end
lines = [lines;"";"## Issue #125 adoption decisions";"";"| Variant | Complexity | Production eligible | Required improvement | Outcome | Qualifying size |";"|---|---|---|---:|---|---|"];
for decision = results.decisions'
    sizeText = "—";
    if ~isempty(decision.qualifyingSize)
        sizeText = strjoin(string(decision.qualifyingSize),"x");
    end
    lines(end+1) = sprintf("| %s | %s | %s | %.0f%% | %s | %s |",decision.variant,decision.complexity,string(decision.productionEligible),100*(decision.requiredImprovement-1),decision.outcome,sizeText); %#ok<AGROW>
end
lines = [lines;"";"## Diagnostic component medians";"";"| Case | Variant | Inverse batch (ms) | Spatial forcing (ms) | Projection (ms) |";"|---|---|---:|---:|---:|"];
for benchmarkCase = results.cases'
    for variant = benchmarkCase.variants'
        metrics = [variant.runs.componentMetrics];
        lines(end+1) = sprintf("| %s | %s | %.3f | %.3f | %.3f |",benchmarkCase.id,variant.variant,1e3*median([metrics.inverseBatchSeconds],"omitnan"),1e3*median([metrics.spatialForcingSeconds],"omitnan"),1e3*median([metrics.projectionSeconds],"omitnan")); %#ok<AGROW>
    end
end
lines = [lines;"";"## Allocation controls";"";"| Case | Bytes (MiB) | Allocate zeros (ms) | Reset to zero (ms) | Overwrite (ms) |";"|---|---:|---:|---:|---:|"];
for benchmarkCase = results.cases'
    controls = benchmarkCase.allocationControls;
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3f | %.3f |",benchmarkCase.id,controls.bytes/2^20,1e3*controls.medianAllocationSeconds,1e3*controls.medianResetSeconds,1e3*controls.medianOverwriteSeconds); %#ok<AGROW>
end
text = join(lines,newline) + newline;
end

function run = normalizeRun(decoded)
run = struct( ...
    "variant",string(decoded.variant), ...
    "repeatIndex",decoded.repeatIndex, ...
    "status",string(decoded.status), ...
    "rawSeconds",double(decoded.rawSeconds(:)), ...
    "medianSeconds",double(decoded.medianSeconds), ...
    "firstCallSeconds",double(decoded.firstCallSeconds), ...
    "componentMetrics",decoded.componentMetrics, ...
    "workspaceLedger",decoded.workspaceLedger, ...
    "transformLedger",decoded.transformLedger, ...
    "rss",decoded.rss, ...
    "metadata",decoded.metadata, ...
    "failure",decoded.failure);
end

function run = failedRun(variant,repeatIndex,identifier,message)
run = struct("variant",variant,"repeatIndex",repeatIndex,"status","failed","rawSeconds",NaN,"medianSeconds",NaN,"firstCallSeconds",NaN,"componentMetrics",emptyComponentMetrics(),"workspaceLedger",struct(),"transformLedger",struct(),"rss",struct("status","failed"),"metadata",struct(),"failure",struct("identifier",identifier,"message",message,"stack",strings(0,1)));
end

function order = rotateOrder(values,offset)
offset = mod(offset,numel(values));
order = circshift(values,[0 -offset]);
end

function environment = environmentRecord()
environment = struct("matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"os",string(system_dependent("getos")),"processor",processorName(),"memoryBytes",physicalMemoryBytes());
end

function value = processorName()
[status,output] = system("/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null");
value = conditional(status == 0,string(strtrim(output)),"");
end

function value = physicalMemoryBytes()
[status,output] = system("/usr/sbin/sysctl -n hw.memsize 2>/dev/null");
value = conditional(status == 0,str2double(strtrim(output)),NaN);
end

function [commit,tree,dirty] = sourceIdentity(repositoryRoot)
[commitStatus,commitOutput] = system(sprintf('git -C "%s" rev-parse HEAD',repositoryRoot));
[treeStatus,treeOutput] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',repositoryRoot));
[dirtyStatus,dirtyOutput] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no',repositoryRoot));
commit = conditional(commitStatus == 0,string(strtrim(commitOutput)),"");
tree = conditional(treeStatus == 0,string(strtrim(treeOutput)),"");
dirty = dirtyStatus ~= 0 || strlength(strtrim(string(dirtyOutput))) > 0;
end

function records = sourceFileRecords(repositoryRoot)
paths = [ ...
    "@WVTransformConstantStratification/WVTransformConstantStratification.m"; ...
    "Forcing/WVNonlinearAdvection.m"; ...
    "FastTransforms/@WVFastTransformDoublyPeriodicMatlab/transformToSpatialDomainWithFourier.m"; ...
    "FastTransforms/@WVFastTransformDoublyPeriodicMatlab/transformFromSpatialDomainWithFourier.m"; ...
    "Benchmarks/WVMatlabNonlinearFluxExperiment.m"; ...
    "Benchmarks/runMatlabNonlinearFluxOptimizationBenchmark.m"; ...
    "Benchmarks/waveVortexMatlabOptimizationWorker.m"];
records = repmat(struct("path","","sha256",""),numel(paths),1);
for iPath = 1:numel(paths)
    records(iPath) = struct("path",paths(iPath),"sha256",sha256File(fullfile(repositoryRoot,paths(iPath))));
end
end

function hash = sha256File(pathname)
fileId = fopen(pathname,"r");
if fileId < 0
    error("WaveVortexBenchmark:SourceHashFailed","Unable to open %s for hashing.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
bytes = fread(fileId,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
hashBytes = typecast(digest.digest(),"uint8");
hash = lower(string(reshape(dec2hex(hashBytes,2).',1,[])));
clear cleanup
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder)
        addpath(folder);
    end
end
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s for writing.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin)
    if isfile(varargin{iFile})
        delete(varargin{iFile});
    end
end
end

function restoreState(originalDirectory,originalPath,originalRng)
cd(originalDirectory);
path(originalPath);
rng(originalRng);
end

function deleteIfValid(value)
if ~isempty(value) && isvalid(value)
    delete(value);
end
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function value = emptyRuns()
value = struct("runs",repmat(failedRun("",0,"",""),0,1));
end

function value = emptyCorrectnessVariants()
value = repmat(struct("variant","","relativeError",NaN,"passed",false,"workspaceLedger",struct(),"metadata",struct()),0,1);
end

function value = emptyVariantAggregates()
value = repmat(struct("variant","","status","","runs",repmat(failedRun("",0,"",""),0,1),"rawSeconds",[],"processMedianSeconds",[],"medianSeconds",NaN,"relativeError",NaN,"correctnessPassed",false,"workspaceLedger",struct(),"metadata",struct(),"rss",struct(),"speedup",NaN,"peakRSSRatio",NaN),0,1);
end

function value = emptyCases()
value = repmat(struct("id","","transformId","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",false,"seed",0,"warmupCount",0,"sampleCount",0,"status","","allocationControls",struct(),"variants",emptyVariantAggregates()),0,1);
end

function value = emptyComponentMetrics()
value = struct("variant","","totalSeconds",NaN,"inverseBatchSeconds",NaN,"spatialForcingSeconds",NaN,"projectionSeconds",NaN);
end
