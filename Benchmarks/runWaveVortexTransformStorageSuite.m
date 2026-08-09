function suiteResult = runWaveVortexTransformStorageSuite(suite,backends,options,benchmarkFolder,repositoryRoot)
% Measure exact transform storage and repeated externally sampled RSS.
arguments
    suite (1,1) struct
    backends (1,:) struct
    options (1,1) struct
    benchmarkFolder (1,1) string
    repositoryRoot (1,1) string
end

backendIds = string({backends.id});
if ~all(ismember(["builtin" "fftw"],backendIds))
    error("WaveVortexBenchmark:TransformStorageBackendsRequired","transform-storage-v1 requires both builtin and fftw backends.");
end
samplerPath = fullfile(benchmarkFolder,"sampleProcessRSS.sh");
metadata = struct("schema","transform-storage-v1","backendIds",["builtin" "fftw"],"processRunCount",options.memoryRunCount,"samplingIntervalSeconds",options.memorySamplingIntervalSeconds,"plateauSeconds",options.memoryPlateauSeconds,"samplerPath","Benchmarks/sampleProcessRSS.sh","samplerSHA256",sha256(samplerPath),"matlabInternalStorage","unresolved","opaqueFFTWPlanStorage","included-in-rss-only");
suiteResult = struct("id",suite.id,"version",suite.version,"kind",suite.kind,"description",suite.description,"operation",suite.operation,"isScored",suite.isScored,"selectionIsComplete",suite.selectionIsComplete,"status","complete","cases",emptyCases(),"familyScores",emptyScores(),"suiteScores",emptyScores(),"referenceArtifact","","metadata",metadata);
for iCase = 1:numel(suite.cases)
    try
        caseResult = runCase(suite.cases(iCase),backends,options,benchmarkFolder,repositoryRoot,samplerPath,iCase);
        suiteResult.cases(end+1) = caseResult;
        if caseResult.status ~= "complete"
            suiteResult.status = "partial";
        end
    catch exception
        suiteResult.cases(end+1) = failedCase(suite.cases(iCase),exception);
        suiteResult.status = "partial";
    end
end
end

function result = runCase(definition,backends,options,benchmarkFolder,repositoryRoot,samplerPath,caseIndex)
runs = emptyRuns();
executionOrder = strings(options.memoryRunCount,numel(backends));
for iRepeat = 1:options.memoryRunCount
    order = 1:numel(backends);
    if mod(caseIndex+iRepeat,2) == 1
        order = fliplr(order);
    end
    executionOrder(iRepeat,:) = string({backends(order).id});
    for iBackend = order
        runs(end+1) = runWorker(definition,backends(iBackend).id,iRepeat,options,benchmarkFolder,repositoryRoot,samplerPath); %#ok<AGROW>
    end
end
backendResults = emptyBackends();
for backend = backends
    selectedRuns = runs(string({runs.backendId}) == backend.id);
    backendResults(end+1) = aggregateBackend(backend.id,selectedRuns); %#ok<AGROW>
end
comparison = waveVortexTransformStorageComparison(definition.Nxyz,backendResults);
status = "complete";
if any(string({runs.status}) ~= "complete")
    status = "partial";
end
result = struct("id",definition.id,"transformId",definition.transformId,"scoreFamily",definition.scoreFamily,"operation",definition.operation,"Lxyz",definition.Lxyz,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"warmupCount",definition.warmupCount,"processRunCount",options.memoryRunCount,"status",status,"failure",emptyFailure(),"executionOrder",executionOrder,"backends",backendResults,"comparison",comparison);
end

function result = runWorker(definition,backendId,repeatIndex,options,benchmarkFolder,repositoryRoot,samplerPath)
configPath = string(tempname) + ".json";
outputPath = string(tempname) + ".json";
config = struct("benchmarkCase",definition,"backendId",backendId,"repeatIndex",repeatIndex,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",samplerPath,"samplingIntervalSeconds",options.memorySamplingIntervalSeconds,"plateauSeconds",options.memoryPlateauSeconds);
writeText(configPath,jsonencode(config));
cleanup = onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
matlabExecutable = fullfile(matlabroot,"bin","matlab");
statement = "addpath('" + replace(benchmarkFolder,"'","''") + "'); waveVortexTransformStorageWorker('" + replace(configPath,"'","''") + "','" + replace(outputPath,"'","''") + "')";
command = sprintf('"%s" -batch "%s"',matlabExecutable,replace(statement,'"','\"'));
[exitCode,commandOutput] = system(command);
if exitCode ~= 0 || ~isfile(outputPath)
    result = failedRun(backendId,repeatIndex,"WaveVortexBenchmark:TransformStorageWorkerFailed",commandOutput);
    return
end
decoded = jsondecode(fileread(outputPath));
result = struct("backendId",backendId,"repeatIndex",repeatIndex,"status",string(decoded.status),"activeBackend",string(decoded.activeBackend),"ledger",decoded.ledger,"rss",decoded.rss,"lifecycle",decoded.lifecycle,"metadata",decoded.metadata,"failure",decoded.failure);
clear cleanup
end

function result = aggregateBackend(backendId,runs)
complete = string({runs.status}) == "complete";
rssComplete = complete & arrayfun(@(run)isfield(run.rss,"status") && string(run.rss.status) == "complete",runs);
persistentValues = NaN(1,numel(runs));
peak = NaN(1,numel(runs));
for iRun = 1:numel(runs)
    if rssComplete(iRun)
        persistentValues(iRun) = runs(iRun).rss.persistentIncrementBytes;
        peak(iRun) = runs(iRun).rss.peakIncrementBytes;
    end
end
ledger = struct();
if any(complete)
    ledger = runs(find(complete,1)).ledger;
end
rssStatus = "complete";
if ~all(rssComplete)
    rssStatus = "unsupported";
end
result = struct("id",backendId,"status",conditional(all(complete),"complete","partial"),"runs",runs,"ledger",ledger,"rss",struct("status",rssStatus,"persistentIncrementBytes",persistentValues,"peakIncrementBytes",peak,"medianPersistentIncrementBytes",median(persistentValues,"omitnan"),"minimumPersistentIncrementBytes",min(persistentValues,[],"omitnan"),"maximumPersistentIncrementBytes",max(persistentValues,[],"omitnan"),"medianPeakIncrementBytes",median(peak,"omitnan"),"minimumPeakIncrementBytes",min(peak,[],"omitnan"),"maximumPeakIncrementBytes",max(peak,[],"omitnan")));
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
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

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin)
    if isfile(varargin{iFile})
        delete(varargin{iFile});
    end
end
end

function value = failedRun(backendId,repeatIndex,identifier,message)
value = struct("backendId",backendId,"repeatIndex",repeatIndex,"status","failed","activeBackend","","ledger",struct(),"rss",struct(),"lifecycle",struct(),"metadata",struct(),"failure",struct("identifier",identifier,"message",string(message),"stack",strings(0,1)));
end

function value = emptyRuns()
value = struct("backendId",{},"repeatIndex",{},"status",{},"activeBackend",{},"ledger",{},"rss",{},"lifecycle",{},"metadata",{},"failure",{});
end

function value = emptyBackends()
value = struct("id",{},"status",{},"runs",{},"ledger",{},"rss",{});
end

function value = emptyCases()
value = struct("id",{},"transformId",{},"scoreFamily",{},"operation",{},"Lxyz",{},"Nxyz",{},"isHydrostatic",{},"shouldAntialias",{},"seed",{},"warmupCount",{},"processRunCount",{},"status",{},"failure",{},"executionOrder",{},"backends",{},"comparison",{});
end

function value = emptyScores()
value = struct("id",{},"backendId",{},"score",{});
end

function value = emptyFailure()
value = struct("identifier","","message","","stack",strings(0,1));
end

function value = failedCase(definition,exception)
value = struct("id",definition.id,"transformId",definition.transformId,"scoreFamily",definition.scoreFamily,"operation",definition.operation,"Lxyz",definition.Lxyz,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"warmupCount",definition.warmupCount,"processRunCount",0,"status","failed","failure",struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name})),"executionOrder",strings(0,0),"backends",emptyBackends(),"comparison",struct());
end
