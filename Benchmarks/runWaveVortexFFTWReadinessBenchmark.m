function results = runWaveVortexFFTWReadinessBenchmark(options)
% Run the final layout-neutral FFTW WaveVortex readiness benchmark.
arguments
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
    options.shouldRequireCleanSource (1,1) logical = true
    options.requiredTag (1,1) string = "v4.2.1"
    options.correctnessTolerance (1,1) double {mustBePositive} = 1e-12
    options.speedThreshold (1,1) double {mustBeGreaterThan(options.speedThreshold,1)} = 1.10
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addpath(repositoryRoot,benchmarkFolder);
addPackagePaths(repositoryRoot);
addFFTWTransformsPath(repositoryRoot);

if options.runId == ""
    options.runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"));
end
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId + "-fftw-readiness");
end

source = sourceIdentity(repositoryRoot,options.requiredTag);
if ~source.requiredTagIsAncestor
    error("WaveVortexBenchmark:ReleaseBoundaryMissing","%s must be an ancestor of the readiness benchmark source.",options.requiredTag);
end
if options.shouldRequireCleanSource && source.isDirty
    error("WaveVortexBenchmark:DirtyReadinessSource","Commit the readiness implementation before generating the canonical result.");
end

capabilities = FFTWBackend.capabilities();
core = runWaveVortexBenchmark(suites="core-v1",backends=["builtin" "fftw"],shouldMeasureMemory=false,shouldWriteArtifacts=false,correctnessTolerance=options.correctnessTolerance);
[historicalStorage,storageRecord] = historicalStorageEvidence(benchmarkFolder,repositoryRoot);
storage = historicalStorage;
if ~storageRecord.runtimeSourcesUnchanged
    currentStorage = runWaveVortexBenchmark(suites="transform-storage-v1",backends=["builtin" "fftw"],shouldWriteArtifacts=false,correctnessTolerance=options.correctnessTolerance);
    storage = currentStorage;
    storageRecord.currentSourceRerun = true;
else
    storageRecord.currentSourceRerun = false;
end

decision = waveVortexFFTWReadinessDecision(core.suites(1),storage.suites(1),capabilities,speedThreshold=options.speedThreshold,correctnessTolerance=options.correctnessTolerance);
status = "complete";
if decision.outcome == "INCOMPLETE"
    status = "partial";
end
results = struct( ...
    "schemaVersion","fftw-readiness-v1", ...
    "status",status, ...
    "runId",options.runId, ...
    "environment",core.environment, ...
    "source",source, ...
    "thresholds",struct("speedup",options.speedThreshold,"correctnessTolerance",options.correctnessTolerance,"mediumRSSBytes",16.125*2^20,"largeRSSBytes",128.496*2^20), ...
    "capabilities",capabilityRecord(capabilities), ...
    "core",core.suites(1), ...
    "storageEvidence",storageRecord, ...
    "storage",storage.suites(1), ...
    "decision",decision);

if options.shouldWriteArtifacts
    writeArtifacts(results,options.outputDirectory);
end
clear stateCleanup
end

function [storage,record] = historicalStorageEvidence(benchmarkFolder,repositoryRoot)
artifactDirectory = fullfile(benchmarkFolder,"results","reference","transform-storage-v1-m5-max-r2026a-fftw");
jsonPath = fullfile(artifactDirectory,"benchmark.json");
summaryPath = fullfile(artifactDirectory,"summary.md");
if ~isfile(jsonPath) || ~isfile(summaryPath)
    error("WaveVortexBenchmark:StorageEvidenceMissing","The canonical issue #75 storage artifact is missing.");
end
jsonHash = sha256(jsonPath);
summaryHash = sha256(summaryPath);
expectedJSONHash = "0210a3c0a8e54c891c0cd2935a812c3e2d598f35162e3f73d7aab979c4e76690";
expectedSummaryHash = "f61efd9cdd5c75d6ae666743e24dbbffc78e059bf089e70662ff440bf544f18c";
if jsonHash ~= expectedJSONHash || summaryHash ~= expectedSummaryHash
    error("WaveVortexBenchmark:StorageEvidenceHashMismatch","The canonical issue #75 storage artifact does not match its fixed SHA-256 record.");
end
storage = jsondecode(fileread(jsonPath));
historicalCommit = string(storage.environment.sourceCommit);
runtimePaths = ["FastTransforms" "@WVTransformConstantStratification" "@WVGeometryDoublyPeriodic" "@WVGeometryDoublyPeriodicStratifiedConstant"];
quotedPaths = join('"' + runtimePaths + '"'," ");
command = sprintf('git -C "%s" diff --quiet %s HEAD -- %s',char(repositoryRoot),char(historicalCommit),char(quotedPaths));
runtimeSourcesUnchanged = system(command) == 0;
record = struct( ...
    "issue",75, ...
    "relativePath",relativePath(artifactDirectory,repositoryRoot), ...
    "jsonSHA256",jsonHash, ...
    "summarySHA256",summaryHash, ...
    "historicalSourceCommit",historicalCommit, ...
    "runtimePaths",runtimePaths, ...
    "runtimeSourcesUnchanged",runtimeSourcesUnchanged, ...
    "currentSourceRerun",false);
end

function value = capabilityRecord(capabilities)
value = struct( ...
    "packageRoot",string(fileparts(which("FFTWBackend"))), ...
    "status",string(capabilities.status), ...
    "providerId",string(capabilities.provider.id), ...
    "providerIdentityValidated",logical(capabilities.provider.identityValidated), ...
    "libraryPath",string(capabilities.library.resolvedPath), ...
    "libraryVersion",string(capabilities.library.version), ...
    "libraryIdentityValidated",logical(capabilities.library.identityValidated), ...
    "r2cIdentityValidated",logical(capabilities.modules.r2c.identityValidated), ...
    "r2rIdentityValidated",logical(capabilities.modules.r2r.identityValidated), ...
    "r2cAvailable",logical(capabilities.features.r2c.isAvailable), ...
    "c2rAvailable",logical(capabilities.features.c2r.isAvailable), ...
    "dct1Available",logical(capabilities.features.dct1.isAvailable), ...
    "dst1Available",logical(capabilities.features.dst1.isAvailable));
end

function addFFTWTransformsPath(repositoryRoot)
if exist("FFTWBackend","class") == 8
    return
end
workspaceRoot = string(fileparts(repositoryRoot));
candidates = [fullfile(workspaceRoot,"fftw-transforms") fullfile(workspaceRoot,"OceanKit","FFTWTransforms-1.0.2")];
for candidate = candidates
    manifestPath = fullfile(candidate,"resources","mpackage.json");
    if ~isfile(manifestPath)
        continue
    end
    manifest = jsondecode(fileread(manifestPath));
    if string(manifest.name) ~= "FFTWTransforms" || string(manifest.version) ~= "1.0.2"
        continue
    end
    addpath(candidate);
    if isfield(manifest,"folders")
        for iFolder = 1:numel(manifest.folders)
            folder = fullfile(candidate,manifest.folders(iFolder).path);
            if isfolder(folder)
                addpath(folder);
            end
        end
    end
    return
end
error("WaveVortexBenchmark:FFTWTransformsMissing","FFTWTransforms 1.0.2 was not found beside the repository or in the OceanKit snapshot.");
end

function source = sourceIdentity(repositoryRoot,requiredTag)
[commitStatus,commit] = system(sprintf('git -C "%s" rev-parse HEAD',repositoryRoot));
[treeStatus,tree] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',repositoryRoot));
[~,dirty] = system(sprintf('git -C "%s" status --porcelain',repositoryRoot));
tagStatus = system(sprintf('git -C "%s" merge-base --is-ancestor %s HEAD',repositoryRoot,requiredTag));
if commitStatus ~= 0 || treeStatus ~= 0
    error("WaveVortexBenchmark:GitIdentityFailed","Unable to identify the readiness benchmark source commit and tree.");
end
source = struct("repository","JeffreyEarly/wave-vortex-model","commit",strtrim(string(commit)),"tree",strtrim(string(tree)),"isDirty",strlength(strtrim(string(dirty))) > 0,"requiredTag",requiredTag,"requiredTagIsAncestor",tagStatus == 0);
end

function writeArtifacts(results,outputDirectory)
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
writeText(fullfile(outputDirectory,"benchmark.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(outputDirectory,"summary.md"),waveVortexFFTWReadinessSummary(results));
end

function addPackagePaths(repositoryRoot)
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder)
        addpath(folder);
    end
end
end

function value = relativePath(pathname,repositoryRoot)
prefix = char(repositoryRoot + filesep);
value = string(erase(char(pathname),prefix));
end

function digest = sha256(pathname)
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(uint8(fileread(pathname)));
digest = lower(join(compose("%02x",typecast(engine.digest(),"uint8")),""));
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
