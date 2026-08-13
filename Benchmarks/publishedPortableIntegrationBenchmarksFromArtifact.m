function [fixedDatasets,adaptiveDataset] = publishedPortableIntegrationBenchmarksFromArtifact(rawArtifactPath,options)
% Normalize a portable-integration decision artifact for public reporting.
arguments
    rawArtifactPath (1,1) string
    options.provenancePath (1,1) string
    options.platformId (1,1) string = "m5-max"
    options.platformName (1,1) string = "Apple M5 Max"
    options.processorName (1,1) string = "Apple M5 Max"
    options.implementationVersion (1,1) string = "unreleased"
end
raw = jsondecode(fileread(rawArtifactPath));
if string(raw.schemaVersion) ~= "portable-integration-decision-v1" || string(raw.status) ~= "complete" || raw.source.isDirty
    error("WaveVortexBenchmark:InvalidPortableIntegrationArtifact","A complete clean portable-integration-decision-v1 artifact is required.")
end
[collectedAt,timestamp] = collectionTime(string(raw.runId));
platform = platformRecord(raw,options);
implementations = ["matlab-builtin" "matlab-compiled-preview" "standalone-cpp"];
backends = ["builtin" "compiled-preview" "native-fftw"];
fixedDatasetCells = cell(1,numel(implementations));
for iImplementation = 1:numel(implementations)
    fixedDatasetCells{iImplementation} = fixedDataset(raw,implementations(iImplementation),backends(iImplementation),collectedAt,timestamp,platform,options);
end
fixedDatasets = [fixedDatasetCells{:}];
adaptiveDataset = adaptivePublishedDataset(raw,collectedAt,timestamp,platform,options);
end

function dataset = fixedDataset(raw,implementationId,backend,collectedAt,timestamp,platform,options)
isCpp = implementationId == "standalone-cpp";
id = conditional(isCpp,"cpp","matlab");
displayName = conditional(isCpp,"WaveVortex portable C++","WaveVortexModel MATLAB");
toolchain = matlabToolchain(raw);
if isCpp, toolchain = cppToolchain(raw); end
implementation = struct("id",id,"displayName",displayName,"version",options.implementationVersion,"repository","https://github.com/JeffreyEarly/wave-vortex-model","commit",string(raw.source.commit),"backend",backend,"sourceDirty",false);
benchmark = struct("suiteId","portable-rk4-v1","suiteVersion",1,"operation","integrate","method","fixed-rk4","correctnessTolerance",raw.configuration.correctnessTolerance);
provenance = struct("rawArtifact",options.provenancePath,"rawSchemaVersion",string(raw.schemaVersion));
cases = cell(1,numel(raw.cases));
for iCase = 1:numel(raw.cases)
    definition = raw.cases(iCase);
    mask = reshape(string({raw.fixedRuns.implementation}),[],1) == implementationId & reshape(string(arrayfun(@(item)item.case.id,raw.fixedRuns,"UniformOutput",false)),[],1) == string(definition.id);
    runs = raw.fixedRuns(mask);
    correctnessRecords = raw.correctness(reshape(string({raw.correctness.id}),[],1) == string(definition.id));
    samples = [runs.integrationSeconds];
    rssRetained = arrayfun(@(item)item.rss.steadyRetainedBytes,runs);
    rssPeak = arrayfun(@(item)item.rss.operationPeakBytes,runs);
    rssIncrement = arrayfun(@(item)item.rss.operationPeakIncrementBytes,runs);
    timedInitialTime = raw.configuration.deltaT*raw.configuration.warmupStepCount;
    configuration = struct("Lxyz",double(definition.Lxyz(:)'),"Nxyz",double(definition.Nxyz(:)'),"isHydrostatic",logical(definition.isHydrostatic),"shouldAntialias",logical(definition.shouldAntialias),"seed",double(definition.seed),"warmupCount",double(raw.configuration.warmupStepCount),"sampleCount",numel(samples),"integration",struct("initialTime",timedInitialTime,"finalTime",timedInitialTime+raw.configuration.deltaT*raw.configuration.stepCount,"fixedStepSize",raw.configuration.deltaT,"fixedStepCount",raw.configuration.stepCount,"requestedOutputCount",0));
    timing = struct("medianSeconds",median(samples),"samplesSeconds",double(samples(:)'));
    relativeError = fixedRelativeError(correctnessRecords,implementationId);
    correctness = struct("passed",relativeError<=raw.configuration.correctnessTolerance,"relativeError",relativeError);
    memory = struct("status","complete","provider","macos-ps-rss-external","baselineProcessBytes",median(rssRetained),"peakProcessBytes",median(rssPeak),"peakIncrementBytes",median(rssIncrement));
    work = struct("acceptedSteps",raw.configuration.stepCount,"rejectedSteps",0,"rightHandSideEvaluations",4*raw.configuration.stepCount,"denseEvaluations",0);
    cases{iCase} = struct("id",string(definition.id),"transformId",conditional(definition.isHydrostatic,"constant-hydrostatic","constant-nonhydrostatic"),"scoreFamily",conditional(definition.isHydrostatic,"constant-hydrostatic","constant-nonhydrostatic"),"configuration",configuration,"status","complete","timing",timing,"correctness",correctness,"memory",memory,"work",work);
end
datasetId = "portable-rk4-v1--"+id+"-"+backend+"--"+options.platformId+"--"+timestamp;
dataset = struct("schemaVersion","published-benchmark-v1","datasetId",datasetId,"collectedAt",collectedAt,"benchmark",benchmark,"implementation",implementation,"platform",platform,"toolchain",toolchain,"provenance",provenance,"cases",{cases});
end

function dataset = adaptivePublishedDataset(raw,collectedAt,timestamp,platform,options)
records = raw.adaptive.records;
keys = strings(numel(records),1);
for iRecord = 1:numel(records), keys(iRecord) = string(records(iRecord).fixture)+"|"+sprintf('%.17g',records(iRecord).relativeTolerance); end
uniqueKeys = unique(keys,"stable");
cases = cell(1,numel(uniqueKeys));
for iKey = 1:numel(uniqueKeys)
    selected = records(keys == uniqueKeys(iKey));
    first = selected(1);
    token = replace(sprintf('%.0e',first.relativeTolerance),["+" "-"],["" "m"]);
    id = "constant-"+conditional(first.isHydrostatic,"hydrostatic","nonhydrostatic")+"-adaptive-rtol-"+token;
    configuration = struct("Lxyz",double(first.configuration.Lxyz(:)'),"Nxyz",double(first.configuration.Nxyz(:)'),"isHydrostatic",logical(first.isHydrostatic),"shouldAntialias",logical(first.configuration.shouldAntialias),"seed",double(first.configuration.seed),"warmupCount",0,"sampleCount",numel(selected),"integration",struct("initialTime",first.configuration.initialTime,"finalTime",first.configuration.initialTime+raw.adaptive.duration,"initialStepSize",raw.adaptive.initialStep,"relativeTolerance",first.relativeTolerance,"absoluteTolerance",first.absoluteTolerance,"requestedOutputCount",0));
    samples = [selected.integrationSeconds];
    relativeError = max([selected.relativeInfinityError]);
    timing = struct("medianSeconds",median(samples),"samplesSeconds",double(samples(:)'));
    correctness = struct("passed",relativeError<=first.relativeTolerance,"relativeError",relativeError);
    memory = struct("status","unavailable","reason","Adaptive validation did not sample process RSS.");
    work = struct("acceptedSteps",round(median([selected.acceptedStepCount])),"rejectedSteps",round(median([selected.rejectedStepCount])),"rightHandSideEvaluations",round(median([selected.rightHandSideEvaluationCount])),"denseEvaluations",0);
    transformId = conditional(first.isHydrostatic,"constant-hydrostatic","constant-nonhydrostatic");
    cases{iKey} = struct("id",id,"transformId",transformId,"scoreFamily",transformId,"configuration",configuration,"status","complete","timing",timing,"correctness",correctness,"memory",memory,"work",work);
end
benchmark = struct("suiteId","portable-rk23-v1","suiteVersion",1,"operation","integrate","method","adaptive-rk23","correctnessTolerance",max([records.relativeTolerance]));
implementation = struct("id","cpp","displayName","WaveVortex portable C++","version",options.implementationVersion,"repository","https://github.com/JeffreyEarly/wave-vortex-model","commit",string(raw.source.commit),"backend","native-fftw","sourceDirty",false);
provenance = struct("rawArtifact",options.provenancePath,"rawSchemaVersion",string(raw.schemaVersion));
datasetId = "portable-rk23-v1--cpp-native-fftw--"+options.platformId+"--"+timestamp;
dataset = struct("schemaVersion","published-benchmark-v1","datasetId",datasetId,"collectedAt",collectedAt,"benchmark",benchmark,"implementation",implementation,"platform",platform,"toolchain",cppToolchain(raw),"provenance",provenance,"cases",{cases});
end

function value = fixedRelativeError(records,implementationId)
if implementationId == "matlab-builtin"
    value = 0;
elseif implementationId == "matlab-compiled-preview"
    value = max([records.compiledMatlabRelativeError]);
else
    value = max([records.standaloneRelativeError]);
end
end

function value = platformRecord(raw,options)
physicalMemory = 1;
if isfield(raw.environment,"physicalMemoryBytes"), physicalMemory = raw.environment.physicalMemoryBytes; end
value = struct("id",options.platformId,"displayName",options.platformName,"processor",options.processorName,"physicalMemoryBytes",physicalMemory,"os",string(raw.environment.computer),"architecture",string(raw.environment.architecture),"threadCount",double(raw.environment.threads));
end

function value = matlabToolchain(raw)
value = struct("kind","matlab","name","MATLAB","version",string(raw.environment.matlabVersion),"details",struct("release",string(raw.environment.release)));
end

function value = cppToolchain(raw)
details = struct("provider",string(raw.provider.provider.id),"fftwVersion",string(raw.provider.provider.version),"threads",string(raw.environment.threads));
value = struct("kind","cpp","name","Apple Clang + FFTW","version",string(raw.provider.compiler.mexVersion),"details",details);
end

function [collectedAt,timestamp] = collectionTime(runId)
token = regexp(runId,'^(\d{8}T\d{6})\d{0,3}Z$','tokens','once');
if isempty(token), error("WaveVortexBenchmark:InvalidCollectionTime","runId must use UTC YYYYMMDDTHHmmss[SSS]Z."), end
timestamp = string(token{1})+"Z";
instant = datetime(timestamp,"InputFormat","yyyyMMdd'T'HHmmss'Z'","TimeZone","UTC");
collectedAt = string(instant,"yyyy-MM-dd'T'HH:mm:ss'Z'");
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
