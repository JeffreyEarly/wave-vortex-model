function results = runCompiledMemoryRefinementBenchmark(options)
% Reassess compiled-preview memory without rerunning settled provider work.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65; 512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBePositive} = 0.10
    options.outputHoldSeconds (1,1) double {mustBePositive} = 0.03
    options.baselineArtifactPath (1,1) string = ""
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.requireCleanSource (1,1) logical = true
    options.candidateResult (1,1) struct = struct()
    options.pairedControlResult (1,1) struct = struct()
end

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
if options.baselineArtifactPath == ""
    options.baselineArtifactPath = fullfile(benchmarkFolder,"results","reference","compiled-preview-v1-m5-max-r2026a","compiled-preview-benchmark.json");
end
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId+"-compiled-memory-refinement-"+computer("arch")+"-"+version("-release"));
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:MemoryRefinementOutputExists","Output already exists: %s",options.outputDirectory);
end
if options.shouldWriteArtifacts
    mkdir(options.outputDirectory);
end

results = initializeResult(options,repositoryRoot);
activeStage = "baseline";
try
    baseline = jsondecode(fileread(options.baselineArtifactPath));
    validateBaseline(baseline,size(options.sizes,1)*numel(options.hydrostatic));
    results.historicalBaseline = struct("artifactPath",repositoryRelativePath(options.baselineArtifactPath,repositoryRoot),"sha256",sha256File(options.baselineArtifactPath),"source",baseline.source,"comparison",baseline.comparison);
    activeStage = "paired-control";
    pairedControl = options.pairedControlResult;
    if isempty(fieldnames(pairedControl))
        pairedControl = runCompiledPreviewBenchmark( ...
            sizes=options.sizes, ...
            hydrostatic=options.hydrostatic, ...
            processRunCount=options.processRunCount, ...
            warmupCount=options.warmupCount, ...
            mediumSampleCount=options.mediumSampleCount, ...
            largeSampleCount=options.largeSampleCount, ...
            samplingIntervalSeconds=options.samplingIntervalSeconds, ...
            plateauSeconds=options.plateauSeconds, ...
            outputHoldSeconds=options.outputHoldSeconds, ...
            shouldWriteArtifacts=false, ...
            materializeBuiltinBufferForCompiled=true);
    end
    if pairedControl.status ~= "complete"
        error("WaveVortexBenchmark:MemoryRefinementControlFailed","The paired eager-buffer control did not complete.");
    end
    results.pairedControl = pairedControl;
    activeStage = "candidate";
    candidate = options.candidateResult;
    if isempty(fieldnames(candidate))
        candidate = runCompiledPreviewBenchmark( ...
            sizes=options.sizes, ...
            hydrostatic=options.hydrostatic, ...
            processRunCount=options.processRunCount, ...
            warmupCount=options.warmupCount, ...
            mediumSampleCount=options.mediumSampleCount, ...
            largeSampleCount=options.largeSampleCount, ...
            samplingIntervalSeconds=options.samplingIntervalSeconds, ...
            plateauSeconds=options.plateauSeconds, ...
            outputHoldSeconds=options.outputHoldSeconds, ...
            shouldWriteArtifacts=false);
    end
    if candidate.status ~= "complete"
        error("WaveVortexBenchmark:MemoryRefinementCandidateFailed","The candidate compiled-preview benchmark did not complete.");
    end
    if options.requireCleanSource && candidate.source.isDirty
        error("WaveVortexBenchmark:MemoryRefinementDirtySource","The canonical memory reassessment requires a clean candidate source tree.");
    end
    results.candidate = candidate;
    activeStage = "aggregation";
    results.comparison = comparisonRecords(pairedControl.comparison,candidate.comparison);
    results.decision = compiledMemoryRefinementDecision(results.comparison);
    results.status = "complete";
    results.completedAtUTC = utcTimestamp();
    results.failure = emptyFailure();
    writeArtifacts(results,options);
catch exception
    results.status = "partial";
    results.completedAtUTC = utcTimestamp();
    results.failure = struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
    writeArtifacts(results,options);
    rethrow(exception)
end
end

function results = initializeResult(options,repositoryRoot) %#ok<INUSD>
[status,commit] = system(sprintf('git -C "%s" rev-parse HEAD',repositoryRoot));
if status ~= 0
    commit = "";
end
[status,tree] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',repositoryRoot));
if status ~= 0
    tree = "";
end
[status,dirty] = system(sprintf('git -C "%s" status --porcelain',repositoryRoot));
if status ~= 0
    dirty = "unknown";
end
results = struct( ...
    "schemaVersion","compiled-memory-refinement-v1", ...
    "status","running", ...
    "runId",options.runId, ...
    "generatedAtUTC",utcTimestamp(), ...
    "completedAtUTC","", ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",strtrim(string(commit)),"tree",strtrim(string(tree)),"isDirty",strlength(strtrim(string(dirty)))>0), ...
    "configuration",struct("suiteId","core-v1","candidateTimeRatioLimit",1.03,"matlabSpeedFloor",1.25,"correctnessTolerance",1e-12,"localExactReductionThreshold",0.05,"processRunCount",options.processRunCount,"warmupCount",options.warmupCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"samplingIntervalSeconds",options.samplingIntervalSeconds), ...
    "historicalBaseline",struct(), ...
    "pairedControl",struct(), ...
    "candidate",struct(), ...
    "comparison",[], ...
    "decision",struct(), ...
    "failure",emptyFailure());
end

function validateBaseline(baseline,expectedCaseCount)
expectedCommit = "3b762e518bf5ef92681bab7ac48dfe54b10fc708";
if string(baseline.schemaVersion) ~= "compiled-preview-benchmark-v1" || string(baseline.status) ~= "complete" || string(baseline.source.commit) ~= expectedCommit || numel(baseline.comparison) ~= expectedCaseCount
    error("WaveVortexBenchmark:InvalidMemoryRefinementBaseline","The baseline must be the complete canonical public-preview artifact at %s.",expectedCommit);
end
end

function comparison = comparisonRecords(control,candidate)
comparison = repmat(emptyComparison(),numel(candidate),1);
for iCandidate = 1:numel(candidate)
    id = string(candidate(iCandidate).id);
    iControl = find(string({control.id}) == id,1);
    if isempty(iControl)
        error("WaveVortexBenchmark:MemoryRefinementCaseMismatch","The paired control does not contain case %s.",id);
    end
    before = control(iControl);
    after = candidate(iCandidate);
    comparison(iCandidate) = struct( ...
        "id",id, ...
        "Nxyz",after.Nxyz, ...
        "isHydrostatic",after.isHydrostatic, ...
        "baselineCompiledSeconds",before.compiledSeconds, ...
        "candidateCompiledSeconds",after.compiledSeconds, ...
        "candidateRelativeToBaselineTime",after.compiledSeconds/before.compiledSeconds, ...
        "candidateSpeedup",after.compiledSpeedup, ...
        "maximumRelativeError",after.maximumRelativeError, ...
        "baselineCompiledExactRetainedBytes",before.compiledExactRetainedBytes, ...
        "candidateCompiledExactRetainedBytes",after.compiledExactRetainedBytes, ...
        "exactRetainedReduction",1-after.compiledExactRetainedBytes/before.compiledExactRetainedBytes, ...
        "requiredExactRetainedReduction",0.05, ...
        "candidateMatlabExactRetainedBytes",after.matlabExactRetainedBytes, ...
        "candidateExactRetainedRatio",after.compiledExactRetainedBytes/after.matlabExactRetainedBytes, ...
        "baselineCompiledOperationPeakRSSBytes",before.compiledOperationPeakIncrementRSSBytes, ...
        "candidateCompiledOperationPeakRSSBytes",after.compiledOperationPeakIncrementRSSBytes, ...
        "candidateMatlabOperationPeakRSSBytes",after.matlabOperationPeakIncrementRSSBytes, ...
        "candidateOperationPeakRSSRatio",after.compiledOperationPeakIncrementRSSBytes/after.matlabOperationPeakIncrementRSSBytes, ...
        "libraryIdentityPassed",after.libraryIdentityPassed, ...
        "nativeExecutionPassed",after.nativeExecutionPassed, ...
        "noFallback",after.noFallback, ...
        "lifecyclePassed",after.lifecyclePassed, ...
        "planCount",after.planCount, ...
        "persistentFullHermitianBytes",after.persistentFullHermitianBytes);
end
end

function value = emptyComparison()
value = struct("id","","Nxyz",[],"isHydrostatic",false,"baselineCompiledSeconds",NaN,"candidateCompiledSeconds",NaN,"candidateRelativeToBaselineTime",NaN,"candidateSpeedup",NaN,"maximumRelativeError",NaN,"baselineCompiledExactRetainedBytes",NaN,"candidateCompiledExactRetainedBytes",NaN,"exactRetainedReduction",NaN,"requiredExactRetainedReduction",0.05,"candidateMatlabExactRetainedBytes",NaN,"candidateExactRetainedRatio",NaN,"baselineCompiledOperationPeakRSSBytes",NaN,"candidateCompiledOperationPeakRSSBytes",NaN,"candidateMatlabOperationPeakRSSBytes",NaN,"candidateOperationPeakRSSRatio",NaN,"libraryIdentityPassed",false,"nativeExecutionPassed",false,"noFallback",false,"lifecyclePassed",false,"planCount",NaN,"persistentFullHermitianBytes",NaN);
end

function writeArtifacts(results,options)
if ~options.shouldWriteArtifacts
    return
end
writeText(fullfile(options.outputDirectory,"memory-reassessment.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(results));
end

function value = markdownSummary(results)
lines = ["# Compiled preview memory refinement";"";"- Status: `"+results.status+"`";"- Outcome: `"+fieldOr(results.decision,"status","pending")+"`";"- Preview availability retained: `"+fieldOr(results.decision,"previewAvailable",true)+"`";"";"| Case | Baseline compiled (ms) | Candidate compiled (ms) | Time ratio | Exact reduction | Exact / MATLAB | RSS / MATLAB | Speedup | Error |";"|---|---:|---:|---:|---:|---:|---:|---:|---:|"];
for item = results.comparison'
    lines(end+1) = "| "+item.id+" | "+sprintf('%.3f',1e3*item.baselineCompiledSeconds)+" | "+sprintf('%.3f',1e3*item.candidateCompiledSeconds)+" | "+sprintf('%.3f',item.candidateRelativeToBaselineTime)+" | "+sprintf('%.2f%%',100*item.exactRetainedReduction)+" | "+sprintf('%.3f',item.candidateExactRetainedRatio)+" | "+sprintf('%.3f',item.candidateOperationPeakRSSRatio)+" | "+sprintf('%.3fx',item.candidateSpeedup)+" | "+sprintf('%.3e',item.maximumRelativeError)+" |"; %#ok<AGROW>
end
if string(results.failure.identifier) ~= ""
    lines = [lines;"";"## Failure";"";"- Stage: `"+results.failure.stage+"`";"- `"+results.failure.identifier+"`: "+results.failure.message];
end
value = join(lines,newline)+newline;
end

function value = fieldOr(record,name,fallback)
if isstruct(record) && isfield(record,name)
    value = string(record.(name));
else
    value = string(fallback);
end
end

function hash = sha256File(pathname)
[status,output] = system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname));
if status ~= 0
    error("WaveVortexBenchmark:ArtifactHashFailed","Unable to hash %s.",pathname);
end
fields = split(strtrim(string(output)));
hash = fields(1);
end

function value = repositoryRelativePath(pathname,repositoryRoot)
prefix = repositoryRoot+filesep;
value = erase(string(pathname),prefix);
end

function writeText(pathname,value)
file = fopen(pathname,"w");
if file < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to write %s.",pathname);
end
cleanup = onCleanup(@()fclose(file));
fprintf(file,"%s",value);
end

function value = utcTimestamp()
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = emptyFailure()
value = struct("stage","","identifier","","message","","report","");
end
