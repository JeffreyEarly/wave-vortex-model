function results = runCompiledKernelBuiltinBaseline(options)
% Record the optimized builtin baseline for the compiled-kernel milestone.
arguments
    options.suiteId (1,1) string = "core-v1"
    options.caseIds (1,:) string = strings(1,0)
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);

if options.runId == ""
    options.runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"));
end
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId + "-compiled-kernel-builtin-" + computer("arch") + "-" + version("-release"));
end

performance = runWaveVortexBenchmark(suites=options.suiteId,backends="builtin",caseIds=options.caseIds,shouldMeasureMemory=false,shouldWriteArtifacts=false,runId=options.runId + "-performance");
storage = runWaveVortexBuiltinStorageBenchmark(suiteId=options.suiteId,caseIds=options.caseIds,processRunCount=options.processRunCount,shouldWriteArtifacts=false,runId=options.runId + "-storage");
[sourceCommit,sourceTree] = sourceIdentity(repositoryRoot);
results = struct( ...
    "schemaVersion","1.0.0", ...
    "status",combinedStatus(performance,storage), ...
    "runId",options.runId, ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",sourceCommit,"tree",sourceTree,"files",sourceRecords(repositoryRoot)), ...
    "configuration",struct("suiteId",options.suiteId,"backend","builtin","caseIds",options.caseIds,"processRunCount",options.processRunCount,"correctnessTolerance",1e-12,"kernelSpeedGate",1.25), ...
    "performance",performance, ...
    "storage",storage, ...
    "reference",referenceRecords(repositoryRoot));

if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory)
        mkdir(options.outputDirectory);
    end
    writeText(fullfile(options.outputDirectory,"compiled-kernel-baseline.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function records = sourceRecords(repositoryRoot)
paths = [ ...
    "@WVTransform/nonlinearFluxWithGradientMasks.m"; ...
    "@WVTransformConstantStratification/transformUVEtaToWaveVortex.m"; ...
    "@WVTransformConstantStratification/transformUVWEtaToWaveVortex.m"; ...
    "@WVGeometryDoublyPeriodicStratifiedConstant/WVGeometryDoublyPeriodicStratifiedConstant.m"; ...
    "FastTransforms/WVFourierStorageLayout.m"];
records = repmat(struct("path","","sha256",""),numel(paths),1);
for iPath = 1:numel(paths)
    pathname = fullfile(repositoryRoot,paths(iPath));
    records(iPath) = struct("path",paths(iPath),"sha256",sha256File(pathname));
end
end

function records = referenceRecords(repositoryRoot)
paths = [ ...
    "Benchmarks/results/reference/core-v1-m5-max-r2026a-builtin/benchmark.json"; ...
    "Benchmarks/results/reference/fftw-retirement-v1-m5-max-r2026a-builtin/retirement-benchmark.json"];
records = repmat(struct("path","","sha256",""),numel(paths),1);
for iPath = 1:numel(paths)
    pathname = fullfile(repositoryRoot,paths(iPath));
    records(iPath) = struct("path",paths(iPath),"sha256",sha256File(pathname));
end
end

function markdown = summaryMarkdown(results)
lines = [ ...
    "# Compiled-kernel builtin baseline"; ...
    ""; ...
    "- Status: `" + results.status + "`"; ...
    "- Source: `" + results.source.commit + "`"; ...
    "- MATLAB: `" + results.performance.environment.matlabRelease + "`"; ...
    "- Architecture: `" + results.performance.environment.architecture + "`"; ...
    ""; ...
    "## Complete nonlinear flux"; ...
    ""; ...
    "| Case | Samples | Median (s) | Relative error | Active backend |"; ...
    "|---|---:|---:|---:|---|"];
performanceSuite = results.performance.suites(1);
for benchmarkCase = performanceSuite.cases
    backend = benchmarkCase.backends(1);
    lines(end+1) = sprintf("| %s | %d | %.6f | %.3g | %s |",benchmarkCase.id,benchmarkCase.sampleCount,backend.medianSeconds,backend.relativeError,backend.id); %#ok<AGROW>
end
lines = [lines; ""; "## Storage and fresh-process RSS"; ""; "| Case | Known persistent (MiB) | Maximum known live (MiB) | Persistent RSS (MiB) | Peak RSS (MiB) |"; "|---|---:|---:|---:|---:|"];
for benchmarkCase = results.storage.cases
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3f | %.3f |",benchmarkCase.id,benchmarkCase.ledger.knownPersistentBytes/2^20,benchmarkCase.ledger.knownMaximumLiveBytes/2^20,benchmarkCase.rss.medianPersistentIncrementBytes/2^20,benchmarkCase.rss.medianPeakIncrementBytes/2^20); %#ok<AGROW>
end
markdown = join(lines,newline) + newline;
end

function hashValue = sha256File(pathname)
bytes = uint8(fileread(pathname));
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
hashValue = lower(join(string(dec2hex(typecast(digest.digest(),'uint8'),2))',""));
end

function [commit,tree] = sourceIdentity(repositoryRoot)
[commitStatus,commitOutput] = system(sprintf('git -C "%s" rev-parse HEAD',repositoryRoot));
[treeStatus,treeOutput] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',repositoryRoot));
commit = conditional(commitStatus == 0,string(strtrim(commitOutput)),"");
tree = conditional(treeStatus == 0,string(strtrim(treeOutput)),"");
end

function status = combinedStatus(performance,storage)
status = "complete";
performanceCases = [performance.suites.cases];
performanceComplete = ~isempty(performanceCases) && all(string({performanceCases.status}) == "complete");
storageComplete = ~isempty(storage.cases) && all(string({storage.cases.status}) == "complete");
if ~performanceComplete || ~storageComplete
    status = "partial";
end
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

function restoreState(originalDirectory,originalPath,originalRng)
cd(originalDirectory);
path(originalPath);
rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end
