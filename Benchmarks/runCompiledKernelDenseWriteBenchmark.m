function results = runCompiledKernelDenseWriteBenchmark(options)
% Evaluate issue #127 dense half-spectrum write schedules.
arguments
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = 18
    options.nativeCacheRoot (1,1) string = defaultNativeCacheRoot
    options.screenWarmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 1
    options.screenSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.finalProcessCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.finalWarmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.finalMediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.finalLargeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.shouldRunFinal (1,1) logical = true
    options.requireCleanSource (1,1) logical = true
    options.caseDefinitions struct = struct([])
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
end
benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
if options.shouldRunFinal && options.requireCleanSource && isDirty, error("WaveVortexBenchmark:DirtyDenseWriteCandidate","The canonical issue #127 run requires a clean implementation commit."); end
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);

issue126Artifact = fullfile(benchmarkFolder,"results","experiments","issue126-native-clean","20260811T221301615Z-maca64-r2026a","coefficient-assembly-confirmation.json");
if ~isfile(issue126Artifact), error("WaveVortexBenchmark:MissingIssue126Artifact","The frozen #126 clean artifact is missing: %s",issue126Artifact); end
issue126 = struct("path",erase(issue126Artifact,repositoryRoot+filesep),"sha256",sha256File(issue126Artifact),"featureCommit","e9e0a1c","status","frozen control evidence; not rerun");

nativeBuild = buildCompiledKernelNativeFFTWProviders(providerIds="native-neon-pthreads",cacheRoot=options.nativeCacheRoot,shouldBuildMex=false);
provider = nativeBuild.providers(1);
providerDescriptor = struct("id",provider.id,"version",provider.version,"threadBackend",provider.threadBackend,"includeDirectory",provider.includeDirectory,"linkLibraries",[provider.threadLibrary provider.baseLibrary],"rpathDirectories",string(fileparts(provider.baseLibrary)));
mexDirectory = fullfile(repositoryRoot,".fftw-cache","issue127","mex");
if ~isfolder(mexDirectory), mkdir(mexDirectory); end
definitions = variantDefinitions;
builds = repmat(emptyBuild(),numel(definitions),1);
for iVariant = 1:numel(definitions)
    definition = definitions(iVariant); module = "wv127_"+replace(definition.id,"-","_");
    [~,build] = buildCompiledKernelTransformMex(outputDirectory=mexDirectory,outputName=module,provider=providerDescriptor,denseWriteStrategy=definition.denseWriteStrategy,fuseInverseNormalization=definition.fuseInverseNormalization);
    builds(iVariant) = struct("id",definition.id,"module",module,"mexPath",string(build.mexPath),"mexSha256",string(build.mexSha256),"denseWriteStrategy",definition.denseWriteStrategy,"fuseInverseNormalization",definition.fuseInverseNormalization,"simplicityRank",definition.simplicityRank);
end

suite = waveVortexBenchmarkSuites("core-v1");
if isempty(options.caseDefinitions), sourceCases = suite.cases; else, sourceCases = options.caseDefinitions; end
medium = sourceCases(arrayfun(@(item)item.Nxyz(1)<512,sourceCases));
screenCases = benchmarkCases(medium,options.screenWarmupCount,options.screenSampleCount,options.screenSampleCount);
screenRun = runWorker(builds,screenCases,1,"screen",options,repositoryRoot,benchmarkFolder,provider);
screen = screenComparisons(screenRun,definitions);
selection = selectScreenWinner(screen,definitions);

finalRuns = repmat(emptyRun(),0,1); finalComparisons = repmat(emptyComparison(),0,1); decision = emptyDecision();
if options.shouldRunFinal && selection.advanced
    selectedBuilds = builds(ismember(string({builds.id}),["baseline" selection.variantId]));
    finalCases = benchmarkCases(sourceCases,options.finalWarmupCount,options.finalMediumSampleCount,options.finalLargeSampleCount);
    finalRuns = repmat(emptyRun(),options.finalProcessCount,1);
    for iRun = 1:options.finalProcessCount
        fprintf("Issue #127 final paired process %d/%d: baseline vs %s.\n",iRun,options.finalProcessCount,selection.variantId);
        finalRuns(iRun) = runWorker(selectedBuilds,finalCases,iRun,"final",options,repositoryRoot,benchmarkFolder,provider);
    end
    finalComparisons = aggregateFinal(finalRuns,selection.variantId);
    decision = compiledKernelDenseWriteDecision(finalComparisons);
elseif ~selection.advanced
    decision.status = "CORE-REJECT"; decision.reason = "No bounded candidate cleared the 3% affected-inverse screening threshold without a greater-than-3% complete-call regression.";
end

results = struct("schemaVersion","1.0.0","status",conditional(options.shouldRunFinal,conditional(selection.advanced && all(string({finalRuns.status})=="complete"),"complete","screened"),"screened"),"runId",options.runId,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty,"kernelSha256",sha256File(fullfile(repositoryRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp")),"gatewaySha256",sha256File(fullfile(repositoryRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp")),"issue126",issue126),"environment",environmentRecord,"provider",struct("id",provider.id,"version",provider.version,"threadBackend",provider.threadBackend,"threadCount",options.threadCount,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"baseLibrarySha256",provider.baseLibrarySha256),"configuration",struct("screen","one process; one warmup; three medium samples","final","three paired fresh processes; two warmups; 7 medium / 3 large samples","correctnessTolerance",1e-12,"screenThreshold",0.03,"adoptionThreshold",0.05,"maximumRegression",0.03),"builds",builds,"screenRun",screenRun,"screenComparisons",screen,"selection",selection,"finalRuns",finalRuns,"finalComparisons",finalComparisons,"decision",decision);
if options.outputDirectory == "", options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue127",options.runId+"-"+computer("arch")+"-"+lower(version("-release"))); end
if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
writeText(fullfile(options.outputDirectory,"dense-half-spectrum-writes.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
clear stateCleanup
end

function definitions = variantDefinitions
definitions = [variant("baseline","baseline",false,0); variant("row-classified","row-classified",false,1); variant("segmented","segmented",false,2); variant("fused-normalization","baseline",true,1); variant("row-classified-fused","row-classified",true,2); variant("segmented-fused","segmented",true,3)];
end

function value = variant(id,strategy,fuse,simplicity)
value = struct("id",id,"denseWriteStrategy",strategy,"fuseInverseNormalization",fuse,"simplicityRank",simplicity);
end

function cases = benchmarkCases(source,warmups,mediumSamples,largeSamples)
cases = repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",0,"warmupCount",warmups,"sampleCount",mediumSamples),numel(source),1);
for iCase = 1:numel(source)
    sampleCount = mediumSamples; if source(iCase).Nxyz(1) >= 512, sampleCount = largeSamples; end
    cases(iCase) = struct("id",string(source(iCase).id),"Nxyz",source(iCase).Nxyz,"isHydrostatic",source(iCase).isHydrostatic,"shouldAntialias",source(iCase).shouldAntialias,"seed",source(iCase).seed,"warmupCount",warmups,"sampleCount",sampleCount);
end
end

function run = runWorker(builds,cases,repeatIndex,stage,options,repositoryRoot,benchmarkFolder,provider)
configPath = string(tempname)+".json"; outputPath = string(tempname)+".json"; cleanup = onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
variants = arrayfun(@(item)struct("id",item.id,"module",item.module,"mexDirectory",string(fileparts(item.mexPath))),builds);
config = struct("stage",stage,"repeatIndex",repeatIndex,"providerId",provider.id,"threadCount",options.threadCount,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"variants",variants,"cases",cases,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds);
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelDenseWriteWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[exitCode,output] = system(command);
if exitCode ~= 0 || ~isfile(outputPath), run = emptyRun(); run.failure = struct("identifier","WaveVortexBenchmark:DenseWriteWorkerFailed","message",string(output),"stack",strings(0,1),"report",string(output)); else, run = normalizeRun(jsondecode(fileread(outputPath))); end
clear cleanup
end

function run = normalizeRun(decoded)
run = struct("schemaVersion",string(decoded.schemaVersion),"status",string(decoded.status),"repeatIndex",decoded.repeatIndex,"providerId",string(decoded.providerId),"threadCount",decoded.threadCount,"moduleInfo",decoded.moduleInfo,"cases",decoded.cases,"rss",decoded.rss,"failure",decoded.failure);
end

function comparisons = screenComparisons(run,definitions)
comparisons = repmat(struct("variantId","","caseId","","isHydrostatic",false,"inverseSpeedup",NaN,"completeCallSpeedup",NaN,"denseWriteReduction",NaN,"maximumRelativeError",NaN,"advanced",false),0,1);
for definition = definitions(2:end)'
    for caseResult = run.cases'
        baseline = caseResult.variants(string({caseResult.variants.id})=="baseline"); candidate = caseResult.variants(string({caseResult.variants.id})==definition.id);
        inverseSpeedup = timing(baseline,"inverse").totalMedianSeconds/timing(candidate,"inverse").totalMedianSeconds;
        completeSpeedup = timing(baseline,"nonlinearFlux").totalMedianSeconds/timing(candidate,"nonlinearFlux").totalMedianSeconds;
        denseReduction = 1-candidate.diagnosticMetrics.denseBytesWritten/baseline.diagnosticMetrics.denseBytesWritten;
        advanced = inverseSpeedup >= 1.03 && completeSpeedup >= 1/1.03 && candidate.maximumRelativeError <= 1e-12;
        comparisons(end+1,1) = struct("variantId",definition.id,"caseId",string(caseResult.id),"isHydrostatic",logical(caseResult.isHydrostatic),"inverseSpeedup",inverseSpeedup,"completeCallSpeedup",completeSpeedup,"denseWriteReduction",denseReduction,"maximumRelativeError",candidate.maximumRelativeError,"advanced",advanced); %#ok<AGROW>
    end
end
end

function selection = selectScreenWinner(comparisons,definitions)
ids = string({definitions(2:end).id}); passed = false(size(ids)); scores = Inf(size(ids));
for iId = 1:numel(ids)
    selected = comparisons(string({comparisons.variantId})==ids(iId)); passed(iId) = numel(selected)==2 && all([selected.advanced]);
    if passed(iId), scores(iId) = exp(mean(log(1./[selected.completeCallSpeedup]))); end
end
if ~any(passed), selection = struct("advanced",false,"variantId","","reason","No candidate advanced from the medium screen.","screenedVariantIds",ids); return, end
fastest = min(scores(passed)); near = passed & scores <= 1.03*fastest; candidates = definitions(2:end); candidates = candidates(near);
[~,index] = min([candidates.simplicityRank]); winner = candidates(index);
selection = struct("advanced",true,"variantId",winner.id,"reason","Selected the simplest candidate within 3% of the fastest advanced complete-call screen result.","screenedVariantIds",ids);
end

function comparisons = aggregateFinal(runs,candidateId)
caseIds = string({runs(1).cases.id}); comparisons = repmat(emptyComparison(),numel(caseIds),1);
for iCase = 1:numel(caseIds)
    baselineTimes = NaN(1,numel(runs)); candidateTimes = baselineTimes; errors = baselineTimes; executed = false(1,numel(runs)); maxLiveRatios = baselineTimes; denseRatios = baselineTimes;
    for iRun = 1:numel(runs)
        item = runs(iRun).cases(iCase); baseline = item.variants(string({item.variants.id})=="baseline"); candidate = item.variants(string({item.variants.id})==candidateId);
        baselineTimes(iRun) = timing(baseline,"nonlinearFlux").totalMedianSeconds; candidateTimes(iRun) = timing(candidate,"nonlinearFlux").totalMedianSeconds; errors(iRun) = candidate.maximumRelativeError;
        maxLiveRatios(iRun) = candidate.metrics.knownMaximumLiveOwnedBytes/baseline.metrics.knownMaximumLiveOwnedBytes; denseRatios(iRun) = candidate.diagnosticMetrics.denseBytesWritten/baseline.diagnosticMetrics.denseBytesWritten;
        executed(iRun) = string(candidate.diagnosticMetrics.denseWriteStrategy) ~= "" && string(candidate.diagnosticMetrics.inverseNormalizationPlacement) ~= "";
    end
    definition = runs(1).cases(iCase);
    comparisons(iCase) = struct("id",caseIds(iCase),"Nxyz",definition.Nxyz(:)',"isHydrostatic",logical(definition.isHydrostatic),"baselineProcessMedianSeconds",baselineTimes,"candidateProcessMedianSeconds",candidateTimes,"pairedProcessSpeedups",baselineTimes./candidateTimes,"baselineMedianSeconds",median(baselineTimes),"candidateMedianSeconds",median(candidateTimes),"completeCallSpeedup",median(baselineTimes)/median(candidateTimes),"maximumLiveRatio",median(maxLiveRatios),"denseWriteRatio",median(denseRatios),"maximumRelativeError",max(errors),"selectedScheduleExecuted",all(executed));
end
end

function record = timing(variant,operation)
record = variant.timings(string({variant.timings.operation})==operation);
end

function markdown = summaryMarkdown(results)
lines = ["# Dense half-spectrum write benchmark";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- Provider: `"+results.provider.id+"`, "+results.provider.threadCount+" threads";"- Screen winner: `"+conditional(results.selection.advanced,results.selection.variantId,"none")+"`";"- Decision: `"+results.decision.status+"`";""]; 
lines(end+1:end+2) = ["| Variant | Case | Inverse speedup | nonlinearFlux speedup | Dense-write reduction | Advanced |";"|---|---|---:|---:|---:|---|"];
for item = results.screenComparisons', lines(end+1) = sprintf("| %s | %s | %.3fx | %.3fx | %.1f%% | %s |",item.variantId,item.caseId,item.inverseSpeedup,item.completeCallSpeedup,100*item.denseWriteReduction,conditional(item.advanced,"yes","no")); end %#ok<AGROW>
if ~isempty(results.finalComparisons)
    lines(end+1:end+3) = ["";"| Final case | Baseline (ms) | Candidate (ms) | Speedup | Dense-write reduction | Error |";"|---|---:|---:|---:|---:|---:|"];
    for item = results.finalComparisons', lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3fx | %.1f%% | %.3g |",item.id,1e3*item.baselineMedianSeconds,1e3*item.candidateMedianSeconds,item.completeCallSpeedup,100*(1-item.denseWriteRatio),item.maximumRelativeError); end %#ok<AGROW>
end
lines(end+1:end+3) = ["";"## Disposition";""]; lines(end+1) = results.decision.reason;
markdown = join(lines,newline)+newline;
end

function record = environmentRecord
[~,processor] = system("/usr/sbin/sysctl -n machdep.cpu.brand_string"); [~,memory] = system("/usr/sbin/sysctl -n hw.memsize"); record = struct("os",string(system_dependent("getos")),"processor",string(strtrim(processor)),"memoryBytes",str2double(strtrim(memory)),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")));
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json"))); for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function [commit,tree,isDirty] = gitIdentity(root)
[~,commit] = system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); [~,status] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no',root)); commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(status)))>0;
end

function hash = sha256File(pathname)
[status,output] = system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname)); if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end; hash = extractBefore(string(strtrim(output))," ");
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to write %s.",pathname); end; cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyBuild
value = struct("id","","module","","mexPath","","mexSha256","","denseWriteStrategy","","fuseInverseNormalization",false,"simplicityRank",NaN);
end

function value = emptyRun
value = struct("schemaVersion","1.0.0","status","failed","repeatIndex",NaN,"providerId","","threadCount",NaN,"moduleInfo",struct([]),"cases",struct([]),"rss",struct(),"failure",struct("identifier","","message","","stack",strings(0,1),"report",""));
end

function value = emptyComparison
value = struct("id","","Nxyz",[],"isHydrostatic",false,"baselineProcessMedianSeconds",[],"candidateProcessMedianSeconds",[],"pairedProcessSpeedups",[],"baselineMedianSeconds",NaN,"candidateMedianSeconds",NaN,"completeCallSpeedup",NaN,"maximumLiveRatio",NaN,"denseWriteRatio",NaN,"maximumRelativeError",NaN,"selectedScheduleExecuted",false);
end

function value = emptyDecision
value = struct("status","NOT-RUN","adopted",false,"qualifyingSize","","regressionPassed",false,"correctnessPassed",false,"reason","Final confirmation was not run.");
end

function root = defaultNativeCacheRoot
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
local = fullfile(repositoryRoot,".fftw-cache","issue137");
sibling = fullfile(fileparts(repositoryRoot),"wave-vortex-model-issue-137",".fftw-cache","issue137");
if isfile(fullfile(local,"downloads","fftw-3.3.11.tar.gz")), root = local;
elseif isfile(fullfile(sibling,"downloads","fftw-3.3.11.tar.gz")), root = sibling;
else, root = local;
end
end
