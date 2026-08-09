function results = runWVFFTWAdapterBenchmark(options)
% Benchmark compact mapping implementations in the half-x FFTW adapter.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [64 48 17;65 63 17;256 256 65;512 512 129]
    options.antialiasValues (1,:) logical = [false true]
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.sampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.planner (1,1) string {mustBeMember(options.planner,["estimate","measure","patient","exhaustive"])} = "measure"
    options.nCores (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.correctnessTolerance (1,1) double {mustBePositive} = 1e-12
    options.selectionTolerance (1,1) double {mustBeNonnegative} = 0.03
    options.fftwTransformsRoot (1,1) string = ""
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
    options.requireCleanTree (1,1) logical = true
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
workspaceRoot = string(fileparts(repositoryRoot));
if options.fftwTransformsRoot == ""
    options.fftwTransformsRoot = fullfile(workspaceRoot,"fftw-transforms");
end
if ~isfile(fullfile(options.fftwTransformsRoot,"RealToComplexTransform.m"))
    error("WaveVortexBenchmark:FFTWTransformsUnavailable","FFTWTransforms source is unavailable at %s.",options.fftwTransformsRoot);
end
if options.requireCleanTree && strlength(strtrim(gitOutput(repositoryRoot,"status --porcelain"))) > 0
    error("WaveVortexBenchmark:DirtyRepository","Commit the implementation before generating the canonical FFTW adapter artifact.");
end

originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addpath(repositoryRoot,benchmarkFolder,options.fftwTransformsRoot);
if exist("fftw_r2c","file") ~= 3
    error("WaveVortexBenchmark:FFTWMexUnavailable","Build FFTWTransforms before running the FFTW adapter benchmark.");
end
if options.runId == ""
    options.runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"));
end
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId + "-fftw-horizontal-" + computer("arch") + "-" + version("-release"));
end

caseDefinitions = createCases(options.sizes,options.antialiasValues,options.sampleCount,options.largeSampleCount);
results = struct( ...
    "schemaVersion","1.0.0", ...
    "status","complete", ...
    "runId",options.runId, ...
    "environment",environmentRecord(repositoryRoot,options.fftwTransformsRoot), ...
    "configuration",struct("sizes",options.sizes,"antialiasValues",options.antialiasValues,"warmupCount",options.warmupCount,"sampleCount",options.sampleCount,"largeSampleCount",options.largeSampleCount,"planner",options.planner,"nCores",options.nCores,"correctnessTolerance",options.correctnessTolerance,"selectionTolerance",options.selectionTolerance), ...
    "candidateIds",["builtin" "layout-methods" "specialized-rows"], ...
    "operationIds",["forward" "inverse"], ...
    "cases",emptyCases(), ...
    "selection",struct());

for caseDefinition = caseDefinitions
    try
        results.cases(end+1) = runCase(caseDefinition,options); %#ok<AGROW>
    catch exception
        results.cases(end+1) = failedCase(caseDefinition,exception); %#ok<AGROW>
        results.status = "failed";
    end
end
results.selection = selectMappings(results.cases,options.selectionTolerance);
if options.shouldWriteArtifacts
    writeArtifacts(results,options.outputDirectory);
end
clear stateCleanup
end

function caseResult = runCase(definition,options)
Nx = definition.size(1);
Ny = definition.size(2);
Nz = definition.size(3);
rng(definition.seed,"twister");
geometry = WVGeometryDoublyPeriodic([100e3 80e3],[Nx Ny],Nz=Nz,shouldAntialias=definition.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
builtin = geometry.fastTransform;
layoutAdapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz,planner=options.planner,nCores=options.nCores,forwardMappingMethod="layout-methods",inverseMappingMethod="layout-methods");
specializedAdapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz,planner=options.planner,nCores=options.nCores,forwardMappingMethod="specialized-rows",inverseMappingMethod="specialized-rows");
adapterCleanup = onCleanup(@()deleteAdapters(layoutAdapter,specializedAdapter));
spatial = randn(Nx,Ny,Nz);
referenceWV = builtin.transformFromSpatialDomainWithFourier(spatial);
referenceSpatial = builtin.transformToSpatialDomainWithFourier(referenceWV);
adapters = {builtin,layoutAdapter,specializedAdapter};
candidateIds = ["builtin" "layout-methods" "specialized-rows"];
operationIds = ["forward" "inverse"];
errors = NaN(numel(candidateIds),numel(operationIds));
for iCandidate = 1:numel(candidateIds)
    errors(iCandidate,1) = relativeError(adapters{iCandidate}.transformFromSpatialDomainWithFourier(spatial),referenceWV);
    errors(iCandidate,2) = relativeError(adapters{iCandidate}.transformToSpatialDomainWithFourier(referenceWV),referenceSpatial);
end
if max(errors,[],"all") > options.correctnessTolerance
    error("WaveVortexBenchmark:FFTWAdapterCorrectnessFailed","FFTW adapter error %.3g exceeded tolerance %.3g.",max(errors,[],"all"),options.correctnessTolerance);
end

pairs = allPairs(numel(candidateIds),numel(operationIds));
warmupSchedules = strings(options.warmupCount,size(pairs,1));
for iWarmup = 1:options.warmupCount
    order = rotatedOrder(size(pairs,1),iWarmup);
    warmupSchedules(iWarmup,:) = pairIds(pairs(order,:),candidateIds,operationIds);
    for iPair = order
        execute(adapters{pairs(iPair,1)},operationIds(pairs(iPair,2)),spatial,referenceWV);
    end
end

rawSeconds = NaN(numel(candidateIds),numel(operationIds),definition.sampleCount);
sampleSchedules = strings(definition.sampleCount,size(pairs,1));
for iSample = 1:definition.sampleCount
    order = rotatedOrder(size(pairs,1),iSample);
    sampleSchedules(iSample,:) = pairIds(pairs(order,:),candidateIds,operationIds);
    for iPair = order
        iCandidate = pairs(iPair,1);
        iOperation = pairs(iPair,2);
        timer = tic;
        output = execute(adapters{iCandidate},operationIds(iOperation),spatial,referenceWV); %#ok<NASGU>
        rawSeconds(iCandidate,iOperation,iSample) = toc(timer);
    end
end

candidates = repmat(struct("id","","operations",struct([])),1,numel(candidateIds));
for iCandidate = 1:numel(candidateIds)
    operations = repmat(struct("id","","rawSeconds",[],"medianSeconds",NaN,"relativeError",NaN,"correctnessPassed",false),1,numel(operationIds));
    for iOperation = 1:numel(operationIds)
        samples = reshape(rawSeconds(iCandidate,iOperation,:),1,[]);
        operations(iOperation) = struct("id",operationIds(iOperation),"rawSeconds",samples,"medianSeconds",median(samples),"relativeError",errors(iCandidate,iOperation),"correctnessPassed",errors(iCandidate,iOperation) <= options.correctnessTolerance);
    end
    candidates(iCandidate) = struct("id",candidateIds(iCandidate),"operations",operations);
end
layoutDiagnostics = layoutAdapter.storageDiagnostics();
caseResult = struct( ...
    "id",definition.id, ...
    "size",definition.size, ...
    "shouldAntialias",definition.shouldAntialias, ...
    "seed",definition.seed, ...
    "sampleCount",definition.sampleCount, ...
    "isGate",definition.isGate, ...
    "status","complete", ...
    "failure",emptyFailure(), ...
    "warmupSchedules",warmupSchedules, ...
    "sampleSchedules",sampleSchedules, ...
    "storage",struct("fourierStorageSize",layoutDiagnostics.fourierStorageSize,"mappingMemoryBytes",layoutDiagnostics.mappingMemoryBytes,"adapterPersistentArrayBytes",layoutDiagnostics.persistentArrayBytes,"horizontalPlanCount",layoutDiagnostics.horizontalPlanCount), ...
    "candidates",candidates);
clear adapterCleanup
end

function output = execute(adapter,operationId,spatial,coefficients)
if operationId == "forward"
    output = adapter.transformFromSpatialDomainWithFourier(spatial);
else
    output = adapter.transformToSpatialDomainWithFourier(coefficients);
end
end

function selection = selectMappings(cases,tolerance)
operationIds = ["forward" "inverse"];
selection = struct("rule","Select specialized rows when they are over 3% faster on at least one gate case and no more than 3% slower on every gate case.","tolerance",tolerance,"forward","","inverse","","details",struct([]));
details = repmat(struct("operationId","","gateRatios",[],"specializedMateriallyFaster",false,"specializedNeverMateriallySlower",false,"selected",""),1,numel(operationIds));
for iOperation = 1:numel(operationIds)
    ratios = [];
    for benchmarkCase = cases
        if benchmarkCase.status == "complete" && benchmarkCase.isGate
            layoutMedian = operationMedian(benchmarkCase,"layout-methods",operationIds(iOperation));
            specializedMedian = operationMedian(benchmarkCase,"specialized-rows",operationIds(iOperation));
            ratios(end+1) = specializedMedian/layoutMedian; %#ok<AGROW>
        end
    end
    materiallyFaster = any(ratios < 1-tolerance);
    neverMateriallySlower = ~isempty(ratios) && all(ratios <= 1+tolerance);
    selected = "layout-methods";
    if materiallyFaster && neverMateriallySlower
        selected = "specialized-rows";
    end
    selection.(operationIds(iOperation)) = selected;
    details(iOperation) = struct("operationId",operationIds(iOperation),"gateRatios",ratios,"specializedMateriallyFaster",materiallyFaster,"specializedNeverMateriallySlower",neverMateriallySlower,"selected",selected);
end
selection.details = details;
end

function value = operationMedian(benchmarkCase,candidateId,operationId)
candidate = benchmarkCase.candidates(string({benchmarkCase.candidates.id}) == candidateId);
operation = candidate.operations(string({candidate.operations.id}) == operationId);
value = operation.medianSeconds;
end

function cases = createCases(sizes,antialiasValues,sampleCount,largeSampleCount)
cases = repmat(struct("id","","size",[],"shouldAntialias",false,"seed",0,"sampleCount",0,"isGate",false),1,size(sizes,1)*numel(antialiasValues));
index = 0;
for iSize = 1:size(sizes,1)
    for shouldAntialias = antialiasValues
        index = index+1;
        sz = sizes(iSize,:);
        isLarge = isequal(sz,[512 512 129]);
        cases(index) = struct("id",sprintf("fftw-half-x-%dx%dx%d-antialias-%d",sz(1),sz(2),sz(3),shouldAntialias),"size",sz,"shouldAntialias",shouldAntialias,"seed",710000+1000*iSize+double(shouldAntialias),"sampleCount",conditional(isLarge,largeSampleCount,sampleCount),"isGate",isequal(sz,[256 256 65]) || isLarge);
    end
end
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function pairs = allPairs(nCandidates,nOperations)
[candidate,operation] = ndgrid(1:nCandidates,1:nOperations);
pairs = [candidate(:) operation(:)];
end

function order = rotatedOrder(count,roundIndex)
shift = mod(roundIndex-1,count);
order = [shift+1:count 1:shift];
end

function ids = pairIds(pairs,candidateIds,operationIds)
ids = candidateIds(pairs(:,1)) + "/" + operationIds(pairs(:,2));
end

function writeArtifacts(results,outputDirectory)
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
writeText(fullfile(outputDirectory,"benchmark.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(outputDirectory,"summary.md"),summaryText(results));
end

function summary = summaryText(results)
lines = ["# Half-x FFTW adapter benchmark";"";"- Status: `" + results.status + "`";"- Run: `" + results.runId + "`";"- MATLAB: `" + results.environment.matlabRelease + "`";"- Architecture: `" + results.environment.architecture + "`";"- Source commit: `" + results.environment.sourceCommit + "`";"";"## Complete-call timings";"";"| Case | Antialias | Gate | Candidate | Forward (ms) | Inverse (ms) | Forward error | Inverse error |";"|---|---:|---|---|---:|---:|---:|---:|"];
for benchmarkCase = results.cases
    if benchmarkCase.status ~= "complete"
        lines(end+1) = "| " + benchmarkCase.id + " | " + string(benchmarkCase.shouldAntialias) + " | " + yesNo(benchmarkCase.isGate) + " | failed | NaN | NaN | NaN | NaN |"; %#ok<AGROW>
        continue
    end
    for candidate = benchmarkCase.candidates
        forward = candidate.operations(1);
        inverse = candidate.operations(2);
        lines(end+1) = sprintf("| %s | %d | %s | %s | %.3f | %.3f | %.3g | %.3g |",benchmarkCase.id,benchmarkCase.shouldAntialias,yesNo(benchmarkCase.isGate),candidate.id,1e3*forward.medianSeconds,1e3*inverse.medianSeconds,forward.relativeError,inverse.relativeError); %#ok<AGROW>
    end
end
lines = [lines;"";"## Mapping selection";"";"| Direction | Selected | Specialized / layout ratios on gate cases |";"|---|---|---|"];
for detail = results.selection.details
    lines(end+1) = "| " + detail.operationId + " | " + detail.selected + " | " + strjoin(compose("%.3f",detail.gateRatios),", ") + " |"; %#ok<AGROW>
end
lines = [lines;"";"## Persistent adapter storage";"";"Each FFTW adapter owns one plan, compact layout mappings, and zero persistent array-sized transform buffers. Exact repeated-process memory measurement remains issue #75.";""];
summary = strjoin(lines,newline) + newline;
end

function environment = environmentRecord(repositoryRoot,fftwTransformsRoot)
environment = struct( ...
    "matlabVersion",string(version), ...
    "matlabRelease",string(version("-release")), ...
    "architecture",string(computer("arch")), ...
    "sourceCommit",gitOutput(repositoryRoot,"rev-parse HEAD"), ...
    "sourceTree",gitOutput(repositoryRoot,"rev-parse HEAD^{tree}"), ...
    "fftwTransformsCommit",gitOutput(fftwTransformsRoot,"rev-parse HEAD"), ...
    "fftwModule",string(which("fftw_r2c")));
end

function value = gitOutput(repositoryRoot,gitArguments)
command = "git -C " + shellQuote(repositoryRoot) + " " + gitArguments;
[status,output] = system(command);
if status ~= 0
    error("WaveVortexBenchmark:GitFailed","Git command failed: %s",strtrim(output));
end
value = string(strtrim(output));
end

function value = shellQuote(text)
value = "'" + string(text) + "'";
end

function deleteAdapters(varargin)
for iAdapter = 1:numel(varargin)
    adapter = varargin{iAdapter};
    if ~isempty(adapter) && isvalid(adapter)
        delete(adapter);
    end
end
end

function value = relativeError(actual,expected)
value = norm(actual(:)-expected(:),inf)/max(norm(expected(:),inf),eps);
end

function value = yesNo(condition)
if condition
    value = "yes";
else
    value = "no";
end
end

function writeText(pathname,text)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to write %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",text);
clear cleanup
end

function restoreState(originalDirectory,originalPath,originalRng)
cd(originalDirectory);
path(originalPath);
rng(originalRng);
end

function failure = emptyFailure()
failure = struct("identifier","","message","","stack",strings(0,1));
end

function result = failedCase(definition,exception)
result = struct("id",definition.id,"size",definition.size,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"sampleCount",definition.sampleCount,"isGate",definition.isGate,"status","failed","failure",struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name})),"warmupSchedules",strings(0,0),"sampleSchedules",strings(0,0),"storage",struct(),"candidates",struct([]));
end

function cases = emptyCases()
cases = struct("id",{},"size",{},"shouldAntialias",{},"seed",{},"sampleCount",{},"isGate",{},"status",{},"failure",{},"warmupSchedules",{},"sampleSchedules",{},"storage",{},"candidates",{});
end
