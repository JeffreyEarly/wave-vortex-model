function dataset = publishedThreeInterfaceBenchmarkFromArtifact(rawArtifactPath,options)
% Normalize a complete matched three-interface artifact for website publication.
arguments
    rawArtifactPath (1,1) string {mustBeFile}
    options.platformId (1,1) string = "m5-max"
    options.platformName (1,1) string = "Apple M5 Max"
    options.provenancePath (1,1) string
    options.implementationVersion (1,1) string = "unreleased-preview"
end
raw = jsondecode(fileread(rawArtifactPath));
if string(raw.schemaVersion) ~= "three-interface-benchmark-v1" || string(raw.status) ~= "complete" || logical(raw.source.isDirty)
    error("WaveVortexBenchmark:InvalidThreeInterfaceArtifact","Publication requires a complete clean three-interface-benchmark-v1 artifact.");
end
[collectedAt,timestamp] = collectionTime(raw.runId);
datasetId = "three-interface--"+options.platformId+"--"+timestamp;
platform = struct("id",options.platformId,"displayName",options.platformName,"processor",string(raw.environment.processor),"physicalMemoryBytes",double(raw.environment.physicalMemoryBytes),"os",string(raw.environment.os),"architecture",string(raw.environment.architecture),"matlabVersion",string(raw.environment.matlabVersion),"threadCount",double(raw.configuration.threadCount));
provider = struct("id",string(raw.provider.provider.id),"version",string(raw.provider.provider.version),"threadBackend",string(raw.provider.provider.threadBackend),"moduleSHA256",string(raw.provider.module.sha256),"identityValidated",logical(raw.provider.module.identityValidated),"openMPDetected",logical(raw.provider.libraries.openmp.detected));
cases = cell(1,numel(raw.comparison));
for iCase = 1:numel(raw.comparison)
    comparison = raw.comparison(iCase);
    definition = raw.cases(iCase);
    if ~isfield(comparison,"integratorAgreementPassed") || ~logical(comparison.integratorAgreementPassed)
        error("WaveVortexBenchmark:IntegratorMismatch","Publication requires the requested integrator to execute in every interface.");
    end
    if ~isfield(comparison,"memoryAgreementPassed") || ~logical(comparison.memoryAgreementPassed)
        error("WaveVortexBenchmark:IncomparableMemory","Publication requires complete process-tree RSS measurements for every interface.");
    end
    caseRuns = raw.runs(reshape(string(arrayfun(@(run)run.case.id,raw.runs,"UniformOutput",false)),[],1)==string(comparison.id));
    if any(arrayfun(@(run)~logical(run.integrator.matched) || string(run.integrator.requested)~=string(definition.requestedIntegrator) || string(run.integrator.actual)~=string(definition.requestedIntegrator),caseRuns))
        error("WaveVortexBenchmark:IntegratorMismatch","Publication found a requested/actual integrator mismatch.");
    end
    interfaces = cell(1,numel(comparison.interfaces));
    for iInterface = 1:numel(comparison.interfaces)
        item = comparison.interfaces(iInterface);
        selected = raw.runs(reshape(string({raw.runs.interface}),[],1)==string(item.id) & reshape(string(arrayfun(@(run)run.case.id,raw.runs,"UniformOutput",false)),[],1)==string(comparison.id));
        if any(arrayfun(@(run)string(run.memory.status)~="complete" || string(run.memory.provider)~="macos-ps-process-tree" || ~isfinite(run.memory.totalPeakRSSBytes),selected))
            error("WaveVortexBenchmark:IncomparableMemory","Publication found a missing or incomparable primary memory measurement.");
        end
        interfaces{iInterface} = struct("id",string(item.id),"processWallSeconds",double(item.processWallSeconds),"interfaceTotalSeconds",double(item.interfaceTotalSeconds),"integrationSeconds",double(item.integrationSeconds),"totalPeakRSSBytes",double(item.totalPeakRSSBytes),"incrementalPeakRSSBytes",double(item.incrementalPeakRSSBytes),"finalRSSBytes",double(item.finalRSSBytes),"processWallRatio",double(item.processWallRatio),"integrationRatio",double(item.integrationRatio),"totalRSSRatio",double(item.totalRSSRatio),"incrementalRSSRatio",double(item.incrementalRSSRatio),"processWallSamplesSeconds",double([selected.processWallSeconds]),"integrationSamplesSeconds",double([selected.integrationSeconds]));
    end
    contract = struct("Nxyz",double(definition.Nxyz(:)'),"Lxyz",double(raw.configuration.Lxyz(:)'),"forcing",string(definition.forcing),"shouldAntialias",logical(definition.shouldAntialias),"integrator",string(definition.requestedIntegrator),"deltaT",double(definition.deltaT),"finalTime",double(definition.finalTime),"relativeTolerance",double(definition.relativeTolerance),"absoluteTolerance",double(definition.absoluteTolerance),"outputInterval",double(definition.outputInterval),"observerGraph",string(definition.observerGraph),"processRunCount",double(raw.configuration.processRunCount),"warmupCount",double(raw.configuration.warmupCount),"samplesPerProcess",double(raw.configuration.samplesPerProcess));
    correctness = struct("passed",logical(comparison.matchedContractPassed),"maximumRelativeError",double(comparison.maximumRelativeError),"outputAgreementPassed",logical(comparison.outputAgreementPassed));
    cases{iCase} = struct("id",string(comparison.id),"operation",string(definition.operation),"contract",contract,"interfaces",{interfaces},"correctness",correctness);
end
provenance = struct("rawArtifact",options.provenancePath,"rawSchemaVersion",string(raw.schemaVersion));
source = struct("repository","https://github.com/JeffreyEarly/wave-vortex-model","commit",string(raw.source.commit),"tree",string(raw.source.tree),"sourceDirty",false,"version",options.implementationVersion);
dataset = struct("schemaVersion","published-three-interface-v1","datasetId",datasetId,"collectedAt",collectedAt,"source",source,"platform",platform,"provider",provider,"provenance",provenance,"cases",{cases});
end

function [collectedAt,timestamp] = collectionTime(runId)
token = regexp(string(runId),'^(\d{8}T\d{6})\d{0,3}Z$','tokens','once');
if isempty(token), error("WaveVortexBenchmark:InvalidCollectionTime","runId must use UTC YYYYMMDDTHHmmss[SSS]Z."); end
timestamp = string(token{1})+"Z";
instant = datetime(timestamp,"InputFormat","yyyyMMdd'T'HHmmss'Z'","TimeZone","UTC");
collectedAt = string(instant,"yyyy-MM-dd'T'HH:mm:ss'Z'");
end
