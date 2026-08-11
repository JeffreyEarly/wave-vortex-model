function results = runCompiledKernelCoefficientAssemblyBenchmark(options)
% Evaluate issue #126 coefficient storage, arithmetic, and bounded execution.
arguments
    options.baselineCommit (1,1) string = "678c1f19ee78147dce1892b2fa35025385c0b651"
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = 18
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.nativeCacheRoot (1,1) string = defaultNativeCacheRoot
    options.caseIds (1,:) string = strings(1,0)
    options.caseDefinitions struct = struct([])
    options.variantIds (1,:) string = strings(1,0)
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.requireCleanCandidate (1,1) logical = false
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
[candidateCommit,candidateTree,candidateDirty] = gitIdentity(repositoryRoot);
if options.requireCleanCandidate && candidateDirty
    error("WaveVortexBenchmark:DirtyCoefficientAssemblyCandidate","The canonical issue #126 benchmark requires a clean implementation commit.");
end
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
suite = waveVortexBenchmarkSuites("core-v1");
if isempty(options.caseDefinitions), cases = suite.cases; else, cases = options.caseDefinitions; end
if ~isempty(options.caseIds), cases = cases(ismember(string({cases.id}),options.caseIds)); end
if isempty(cases), error("WaveVortexBenchmark:NoCoefficientAssemblyCases","No core-v1 cases matched the requested identifiers."); end

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
temporaryCleanup = onCleanup(@()removeTemporaryRoot(temporaryRoot));
baselineRoot = fullfile(temporaryRoot,"baseline-source");
mkdir(baselineRoot);
archiveSource(repositoryRoot,options.baselineCommit,baselineRoot);
mexDirectory = fullfile(temporaryRoot,"mex");
mkdir(mexDirectory);

providerBuild = buildCompiledKernelNativeFFTWProviders( ...
    providerIds="native-neon-pthreads", ...
    cacheRoot=options.nativeCacheRoot, ...
    shouldBuildMex=false);
provider = providerBuild.providers(1);
providerDescriptor = struct( ...
    "id",provider.id, ...
    "version",provider.version, ...
    "threadBackend",provider.threadBackend, ...
    "includeDirectory",provider.includeDirectory, ...
    "linkLibraries",[provider.baseLibrary provider.threadLibrary], ...
    "rpathDirectories",string(fileparts(provider.baseLibrary)));

baselineBuild = buildFromSource(baselineRoot,mexDirectory,"wv126_native_baseline",providerDescriptor,struct());
definitions = variantDefinitions;
if ~isempty(options.variantIds), definitions = definitions(ismember(string({definitions.id}),options.variantIds)); end
if isempty(definitions), error("WaveVortexBenchmark:NoCoefficientAssemblyVariants","No issue #126 candidate matched the requested identifiers."); end
builds = repmat(emptyBuildRecord,0,1);
for definition = definitions'
    module = "wv126_"+replace(definition.id,"-","_");
    [~,build] = buildCompiledKernelTransformMex( ...
        outputDirectory=mexDirectory, ...
        outputName=module, ...
        provider=providerDescriptor, ...
        coefficientArithmeticMode=definition.coefficientArithmeticMode, ...
        controlFlowMode=definition.controlFlowMode, ...
        optimizationLevel=definition.optimizationLevel, ...
        coefficientWorkerCount=definition.coefficientWorkerCount, ...
        shouldReportVectorization=definition.shouldReportVectorization);
    builds(end+1,1) = buildRecord(definition,build); %#ok<AGROW>
end

baseline = runVariant(baselineBuild.variant,baselineBuild,options,cases,repositoryRoot,benchmarkFolder,mexDirectory,provider);
screens = repmat(emptyVariantResult,0,1);
for iBuild = 1:numel(builds)
    screens(end+1,1) = runVariant(builds(iBuild).variant,builds(iBuild),options,cases,repositoryRoot,benchmarkFolder,mexDirectory,provider); %#ok<AGROW>
end
decisions = componentDecisions(baseline,screens);
cumulativeDefinition = cumulativeVariant(decisions);
cumulativeModule = "wv126_cumulative";
[~,cumulativeRawBuild] = buildCompiledKernelTransformMex( ...
    outputDirectory=mexDirectory, ...
    outputName=cumulativeModule, ...
    provider=providerDescriptor, ...
    coefficientArithmeticMode=cumulativeDefinition.coefficientArithmeticMode, ...
    controlFlowMode=cumulativeDefinition.controlFlowMode, ...
    optimizationLevel=cumulativeDefinition.optimizationLevel, ...
    coefficientWorkerCount=cumulativeDefinition.coefficientWorkerCount);
cumulativeBuild = buildRecord(cumulativeDefinition,cumulativeRawBuild);
cumulative = runVariant(cumulativeDefinition,cumulativeBuild,options,cases,repositoryRoot,benchmarkFolder,mexDirectory,provider);
decisions = finalizeDecisions(decisions,baseline,cumulative);

accelerateAssessment = acceleratePointwiseAssessment;
vectorization = vectorizationEvidence(builds);
threadAssessment = persistentExecutorAssessment(cumulative);
source = struct( ...
    "repository","JeffreyEarly/wave-vortex-model", ...
    "baselineCommit",options.baselineCommit, ...
    "candidateCommit",candidateCommit, ...
    "candidateTree",candidateTree, ...
    "candidateDirty",candidateDirty, ...
    "sourceHashes",sourceHashRecords(repositoryRoot), ...
    "historicalIssue126",struct( ...
        "implementationCommit","839eb6723455212af4c2ee5d039f69eee88dc774", ...
        "artifactCommit","dd7d4f4b2c2f753d53f95a663e48328d803773e6", ...
        "status","historical evidence; unchanged"));
results = struct( ...
    "schemaVersion","2.0.0", ...
    "status",conditional(baseline.status=="complete" && all(string({screens.status})=="complete") && cumulative.status=="complete","complete","partial"), ...
    "runId",options.runId, ...
    "source",source, ...
    "environment",environmentRecord(options.threadCount), ...
    "provider",providerIdentity(provider,baseline), ...
    "configuration",struct( ...
        "suiteId","core-v1", ...
        "operation","ordinary nonlinearFlux", ...
        "processRunCount",options.processRunCount, ...
        "warmups",2, ...
        "samplePolicy","7 medium / 3 large", ...
        "correctnessTolerance",1e-12, ...
        "maximumRegression",0.03, ...
        "compactStorageThreshold",0.10, ...
        "localStageThreshold",0.05, ...
        "localCompleteCallThreshold",0.01, ...
        "boundedWorkerThreshold",0.05, ...
        "persistentExecutorThreshold",0.10), ...
    "baseline",baseline, ...
    "componentScreens",screens, ...
    "componentDecisions",decisions, ...
    "acceleratePointwise",accelerateAssessment, ...
    "vectorizationEvidence",vectorization, ...
    "cumulative",cumulative, ...
    "persistentExecutorAssessment",threadAssessment);

if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue126-native",options.runId+"-"+computer("arch")+"-"+lower(version("-release")));
end
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"coefficient-assembly-benchmark.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear temporaryCleanup stateCleanup
end

function definitions = variantDefinitions
definitions = [ ...
    variant("compact-storage","compact","generic","default",1,false,1); ...
    variant("prescaled-arithmetic","prescaled","generic","default",1,false,2); ...
    variant("specialized-straight-line","compact","specialized","default",1,false,2); ...
    variant("compiler-vectorized","compact","generic","native",1,true,2); ...
    variant("bounded-workers-2","compact","generic","default",2,false,3); ...
    variant("bounded-workers-4","compact","generic","default",4,false,3); ...
    variant("bounded-workers-8","compact","generic","default",8,false,3)];
end

function value = variant(id,arithmetic,controlFlow,optimization,workers,vectorReport,simplicity)
value = struct( ...
    "id",id, ...
    "coefficientStorageMode","natural-dimensional", ...
    "coefficientArithmeticMode",arithmetic, ...
    "controlFlowMode",controlFlow, ...
    "optimizationLevel",optimization, ...
    "coefficientWorkerCount",workers, ...
    "shouldReportVectorization",vectorReport, ...
    "simplicityRank",simplicity);
end

function record = buildFromSource(sourceRoot,mexDirectory,module,providerDescriptor,variantOptions)
oldPath = path;
cleanup = onCleanup(@()path(oldPath));
addpath(fullfile(sourceRoot,"Benchmarks"),"-begin");
clear buildCompiledKernelTransformMex
if isempty(fieldnames(variantOptions))
    [~,build] = buildCompiledKernelTransformMex(outputDirectory=mexDirectory,outputName=module,provider=providerDescriptor);
    baselineVariant = variant("native-baseline","replicated","generic","default",1,false,0);
else
    error("WaveVortexBenchmark:UnsupportedBaselineBuildOptions","Baseline build options are not supported.");
end
clear buildCompiledKernelTransformMex
record = buildRecord(baselineVariant,build);
clear cleanup
end

function record = buildRecord(definition,build)
record = emptyBuildRecord;
record.variant = definition;
record.module = string(build.module);
record.mexPath = string(build.mexPath);
record.mexSha256 = string(build.mexSha256);
record.providerId = string(build.id);
record.vectorizationReport = conditional(isfield(build,"vectorizationReport"),string(fieldOr(build,"vectorizationReport","")),"");
end

function result = runVariant(definition,build,options,cases,repositoryRoot,benchmarkFolder,mexDirectory,provider)
runs = repmat(emptyWorkerResult,options.processRunCount,1);
for iRun = 1:options.processRunCount
    configPath = string(tempname)+".json";
    outputPath = string(tempname)+".json";
    cleanup = onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
    config = struct( ...
        "variant",definition, ...
        "providerId",provider.id, ...
        "threadBackend",provider.threadBackend, ...
        "threadCount",options.threadCount, ...
        "repeatIndex",iRun, ...
        "module",build.module, ...
        "baseLibrary",provider.baseLibrary, ...
        "threadLibrary",provider.threadLibrary, ...
        "runtimeLibrary",provider.runtimeLibrary, ...
        "supportsDiagnostics",definition.id~="native-baseline", ...
        "cases",cases, ...
        "repositoryRoot",repositoryRoot, ...
        "benchmarkFolder",benchmarkFolder, ...
        "mexDirectory",mexDirectory, ...
        "matlabPath",path, ...
        "samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"), ...
        "samplingIntervalSeconds",options.samplingIntervalSeconds, ...
        "plateauSeconds",options.plateauSeconds);
    writeText(configPath,jsonencode(config));
    statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelCoefficientAssemblyWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
    command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
    [exitCode,commandOutput] = system(command);
    if exitCode ~= 0 || ~isfile(outputPath)
        runs(iRun) = emptyWorkerResult;
        runs(iRun).repeatIndex = iRun;
        runs(iRun).failure = struct("identifier","WaveVortexBenchmark:CoefficientAssemblyWorkerFailed","message",string(commandOutput),"stack",strings(0,1),"report","");
    else
        runs(iRun) = normalizeWorkerResult(jsondecode(fileread(outputPath)));
    end
    clear cleanup
end
result = aggregateVariant(definition,build,runs);
end

function result = aggregateVariant(definition,build,runs)
caseIds = unique(string({runs(1).cases.id}));
aggregatedCases = repmat(emptyAggregatedCase,numel(caseIds),1);
for iCase = 1:numel(caseIds)
    selected = arrayfun(@(run)run.cases(find(string({run.cases.id})==caseIds(iCase),1)),runs);
    complete = string({selected.status})=="complete";
    processTotal = arrayfun(@(item)item.timing.totalMedianSeconds,selected);
    processInternal = arrayfun(@(item)item.timing.internalMedianSeconds,selected);
    peakRSS = arrayfun(@(item)item.rss.peakIncrementBytes,selected);
    persistentRSS = arrayfun(@(item)item.rss.persistentIncrementBytes,selected);
    representative = selected(find(complete,1));
    aggregatedCases(iCase) = struct( ...
        "id",caseIds(iCase), ...
        "Nxyz",representative.Nxyz(:)', ...
        "isHydrostatic",logical(representative.isHydrostatic), ...
        "status",conditional(all(complete),"complete","partial"), ...
        "processTotalMedianSeconds",processTotal, ...
        "processInternalMedianSeconds",processInternal, ...
        "totalMedianSeconds",median(processTotal), ...
        "internalMedianSeconds",median(processInternal), ...
        "maximumRelativeError",max([selected.maximumRelativeError]), ...
        "lifecyclePassed",all([selected.lifecyclePassed]), ...
        "metrics",representative.metrics, ...
        "diagnosticMetrics",representative.diagnosticMetrics, ...
        "workerLifecycle",representative.workerLifecycle, ...
        "rss",struct("peakIncrementBytes",peakRSS,"persistentIncrementBytes",persistentRSS,"medianPeakIncrementBytes",median(peakRSS),"medianPersistentIncrementBytes",median(persistentRSS)));
end
result = struct( ...
    "id",definition.id, ...
    "status",conditional(all(string({runs.status})=="complete") && all(string({aggregatedCases.status})=="complete"),"complete","partial"), ...
    "variant",definition, ...
    "build",build, ...
    "runs",runs, ...
    "cases",aggregatedCases);
end

function decisions = componentDecisions(baseline,screens)
compact = screen(screens,"compact-storage");
compactComparison = compareVariants(baseline,compact);
compactAdopt = all([compactComparison.descriptorReduction] >= 0.10) && all([compactComparison.speedup] >= 1/1.03) && all([compactComparison.correctnessPassed]);
decisions = repmat(emptyDecision,0,1);
decisions(end+1,1) = decision("compact-coefficient-storage",compactAdopt,compactComparison,conditional(compactAdopt,"Natural-dimensional coefficient arrays reduce exact descriptor storage by at least 10% without a greater-than-3% slowdown.","The compact representation missed its storage, correctness, or regression gate."));

for id = ["prescaled-arithmetic" "specialized-straight-line" "compiler-vectorized"]
    candidate = screen(screens,id);
    comparison = compareVariants(compact,candidate);
    [passed,qualifiedSize] = localChangePassed(comparison);
    decisions(end+1,1) = decision(id,passed,comparison,conditional(passed,"The local change improved its coefficient stage by at least 5% and complete nonlinearFlux by at least 1% for both physical configurations at "+qualifiedSize+".","The local change missed its paired stage/complete-call gate or regression rule.")); %#ok<AGROW>
end

workerCandidates = strings(1,0);
for id = ["bounded-workers-2" "bounded-workers-4" "bounded-workers-8"]
    candidate = screen(screens,id);
    comparison = compareVariants(compact,candidate);
    [passed,qualifiedSize] = boundedWorkersPassed(comparison);
    decisions(end+1,1) = decision(id,passed,comparison,conditional(passed,"Transient bounded execution improved complete nonlinearFlux by at least 5% for both physical configurations at "+qualifiedSize+".","Transient bounded execution missed the complete-call, process-direction, or regression gate.")); %#ok<AGROW>
    if passed, workerCandidates(end+1) = id; end %#ok<AGROW>
end
if numel(workerCandidates) > 1
    workerSpeeds = arrayfun(@(id)geomeanPositive([decisionById(decisions,id).comparisons.speedup]),workerCandidates);
    fastest = max(workerSpeeds);
    simple = find(workerSpeeds >= fastest/1.03,1,"first");
    selected = workerCandidates(simple);
    for id = workerCandidates
        item = find(string({decisions.id})==id,1);
        decisions(item).selected = id==selected;
        if id~=selected, decisions(item).reason = decisions(item).reason+" Rejected in favor of the simpler within-3% worker count."; end
    end
elseif isscalar(workerCandidates)
    item = find(string({decisions.id})==workerCandidates,1);
    decisions(item).selected = true;
end
end

function definition = cumulativeVariant(decisions)
definition = variant("cumulative","compact","generic","default",1,false,1);
if decisionById(decisions,"prescaled-arithmetic").adopted, definition.coefficientArithmeticMode = "prescaled"; definition.simplicityRank = max(definition.simplicityRank,2); end
if decisionById(decisions,"specialized-straight-line").adopted, definition.controlFlowMode = "specialized"; definition.simplicityRank = max(definition.simplicityRank,2); end
if decisionById(decisions,"compiler-vectorized").adopted, definition.optimizationLevel = "native"; definition.simplicityRank = max(definition.simplicityRank,2); end
workers = decisions(startsWith(string({decisions.id}),"bounded-workers-") & [decisions.adopted] & [decisions.selected]);
if ~isempty(workers), definition.coefficientWorkerCount = str2double(extractAfter(workers(1).id,"bounded-workers-")); definition.simplicityRank = 3; end
end

function decisions = finalizeDecisions(decisions,baseline,cumulative)
comparison = compareVariants(baseline,cumulative);
regressionPassed = all([comparison.speedup]>=1/1.03) && all([comparison.maximumLiveRatio]<=1.03) && all([comparison.correctnessPassed]);
for iDecision = 1:numel(decisions)
    decisions(iDecision).cumulativeConfirmationPassed = regressionPassed;
    if decisions(iDecision).adopted && ~regressionPassed
        decisions(iDecision).adopted = false;
        decisions(iDecision).outcome = "CORE-REJECT";
        decisions(iDecision).reason = decisions(iDecision).reason+" The cumulative clean candidate exceeded the 3% regression limit.";
    end
end
end

function comparison = compareVariants(control,candidate)
comparison = repmat(emptyComparison,numel(candidate.cases),1);
for iCase = 1:numel(candidate.cases)
    test = candidate.cases(iCase);
    reference = control.cases(string({control.cases.id})==test.id);
    pairedSpeedups = reference.processTotalMedianSeconds ./ test.processTotalMedianSeconds;
    controlStage = coefficientStageSeconds(reference.diagnosticMetrics);
    candidateStage = coefficientStageSeconds(test.diagnosticMetrics);
    comparison(iCase) = struct( ...
        "id",test.id, ...
        "Nxyz",test.Nxyz, ...
        "isHydrostatic",test.isHydrostatic, ...
        "controlSeconds",reference.totalMedianSeconds, ...
        "candidateSeconds",test.totalMedianSeconds, ...
        "speedup",reference.totalMedianSeconds/test.totalMedianSeconds, ...
        "pairedProcessSpeedups",pairedSpeedups, ...
        "allProcessComparisonsBeneficial",all(pairedSpeedups>1), ...
        "targetedStageSpeedup",controlStage/max(candidateStage,realmin), ...
        "descriptorReduction",1-test.metrics.descriptorBytes/reference.metrics.descriptorBytes, ...
        "maximumLiveRatio",test.metrics.knownMaximumLiveOwnedBytes/reference.metrics.knownMaximumLiveOwnedBytes, ...
        "peakRSSRatio",test.rss.medianPeakIncrementBytes/reference.rss.medianPeakIncrementBytes, ...
        "correctnessPassed",test.maximumRelativeError<=1e-12, ...
        "lifecyclePassed",test.lifecyclePassed);
end
end

function value = coefficientStageSeconds(metrics)
value = metrics.coefficientAssemblySeconds + metrics.derivativeCoefficientAssemblySeconds + metrics.coefficientProjectionSeconds;
end

function [passed,sizeKey] = localChangePassed(comparisons)
[passed,sizeKey] = commonSizePassed(comparisons,@(items)all([items.targetedStageSpeedup]>=1.05) && all([items.speedup]>=1.01) && all([items.allProcessComparisonsBeneficial]));
passed = passed && all([comparisons.speedup]>=1/1.03) && all([comparisons.correctnessPassed]) && all([comparisons.lifecyclePassed]);
end

function [passed,sizeKey] = boundedWorkersPassed(comparisons)
[passed,sizeKey] = commonSizePassed(comparisons,@(items)all([items.speedup]>=1.05) && all([items.allProcessComparisonsBeneficial]));
passed = passed && all([comparisons.speedup]>=1/1.03) && all([comparisons.maximumLiveRatio]<=1.03) && all([comparisons.peakRSSRatio]<=1.03) && all([comparisons.correctnessPassed]) && all([comparisons.lifecyclePassed]);
end

function [passed,sizeKey] = commonSizePassed(comparisons,predicate)
keys = string(arrayfun(@(item)sprintf('%dx%dx%d',item.Nxyz),comparisons,UniformOutput=false));
passed = false;
sizeKey = "";
for key = unique(keys(:))'
    selected = comparisons(keys==key);
    if numel(selected)==2 && numel(unique([selected.isHydrostatic]))==2 && predicate(selected)
        passed = true;
        sizeKey = key;
        return
    end
end
end

function assessment = persistentExecutorAssessment(cumulative)
ratios = NaN(1,numel(cumulative.cases));
for iCase = 1:numel(cumulative.cases)
    item = cumulative.cases(iCase);
    lifecycle = item.workerLifecycle;
    callsPerFlux = conditional(item.isHydrostatic,5,6);
    lifecycleSeconds = callsPerFlux*(lifecycle.creationSeconds+lifecycle.synchronizationSeconds+lifecycle.joinSeconds)/max(lifecycle.repetitions,1);
    ratios(iCase) = lifecycleSeconds/item.internalMedianSeconds;
end
required = cumulative.variant.coefficientWorkerCount>1 && any(ratios>=0.05);
assessment = struct( ...
    "status",conditional(required,"required","not-required"), ...
    "workerLifecycleShare",ratios, ...
    "prototypeRequired",required, ...
    "threshold",0.05, ...
    "productionAdoptionThreshold",0.10, ...
    "reason",conditional(required,"Measured transient worker lifecycle exceeds 5% of complete internal time; a persistent-executor ablation is required.","Transient worker lifecycle is not material, or bounded workers were not selected."));
end

function assessment = acceleratePointwiseAssessment
assessment = struct( ...
    "status","CORE-REJECT", ...
    "tested",false, ...
    "reason","No Accelerate primitive matches the fused interleaved complex coefficient assembly/projection without split-complex conversion, extra full-array passes, or an array-sized temporary. BLAS zaxpy supplies only scalar-vector multiplication; vDSP complex vector products require split-complex views. The no-pack eligibility condition is therefore false.", ...
    "evidence",["Accelerate/vecLib/cblas.h: cblas_zaxpy scalar-vector interface" "Accelerate/vDSP/Complex.h: split-complex vector interface"], ...
    "packingAllowed",false);
end

function evidence = vectorizationEvidence(builds)
item = builds(string(arrayfun(@(value)value.variant.id,builds,UniformOutput=false))=="compiler-vectorized");
report = "";
if ~isempty(item), report = item(1).vectorizationReport; end
lines = splitlines(report);
relevant = lines(contains(lines,"WVTransformConstantStratificationKernel.cpp") | contains(lines,"remark:"));
evidence = struct( ...
    "status",conditional(strlength(report)>0,"complete","unavailable"), ...
    "flags","-O3 -mcpu=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize -Rpass-analysis=loop-vectorize", ...
    "vectorizedRemarkCount",sum(contains(relevant,"vectorized loop")), ...
    "missedRemarkCount",sum(contains(relevant,"loop not vectorized")), ...
    "report",join(relevant,newline));
end

function markdown = summaryMarkdown(results)
lines = [ ...
    "# Native-FFTW coefficient assembly and projection"; ...
    ""; ...
    "- Status: `"+results.status+"`"; ...
    "- Baseline: #137 native FFTW 3.3.11 NEON/pthreads, 18 FFT threads"; ...
    "- Candidate source: `"+results.source.candidateCommit+"`"; ...
    ""; ...
    "## Component decisions"; ...
    ""; ...
    "| Component | Decision | Reason |"; ...
    "|---|---|---|"];
for item = results.componentDecisions'
    lines(end+1) = "| "+item.id+" | **"+item.outcome+"** | "+item.reason+" |"; %#ok<AGROW>
end
lines = [lines;"";"## Component timing";"";"| Variant | Case | Complete (ms) | Internal (ms) | Descriptor (MiB) | Peak RSS (MiB) | Error |";"|---|---|---:|---:|---:|---:|---:|"];
variants = [results.baseline; results.componentScreens; results.cumulative];
for candidate = variants'
    for item = candidate.cases'
        lines(end+1) = sprintf("| %s | %s | %.3f | %.3f | %.3f | %.3f | %.3g |",candidate.id,item.id,1e3*item.totalMedianSeconds,1e3*item.internalMedianSeconds,item.metrics.descriptorBytes/2^20,item.rss.medianPeakIncrementBytes/2^20,item.maximumRelativeError); %#ok<AGROW>
    end
end
lines = [lines;"";"## Other findings";"";"- Accelerate pointwise path: **"+results.acceleratePointwise.status+"** — "+results.acceleratePointwise.reason;"- Persistent executor: `"+results.persistentExecutorAssessment.status+"` — "+results.persistentExecutorAssessment.reason;"- Compiler vectorized-loop remarks: "+results.vectorizationEvidence.vectorizedRemarkCount+"; missed-loop remarks: "+results.vectorizationEvidence.missedRemarkCount];
markdown = join(lines,newline)+newline;
end

function build = emptyBuildRecord
build = struct("variant",struct(),"module","","mexPath","","mexSha256","","providerId","","vectorizationReport","");
end

function value = emptyWorkerResult
value = struct("schemaVersion","1.0.0","status","failed","variant",struct(),"providerId","","threadBackend","","threadCount",NaN,"repeatIndex",NaN,"module","","moduleInfo",struct(),"cases",repmat(emptyWorkerCase,0,1),"rss",struct(),"moduleClearSeconds",NaN,"failure",struct());
end

function value = emptyWorkerCase
value = struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",NaN,"warmupCount",0,"sampleCount",0,"constructionSeconds",NaN,"planningSeconds",NaN,"firstExecution",struct(),"timing",struct(),"errors",struct(),"maximumRelativeError",NaN,"metrics",struct(),"diagnosticMetrics",struct(),"workerLifecycle",struct(),"rss",struct(),"status","failed","lifecyclePassed",false);
end

function value = emptyVariantResult
value = struct("id","","status","failed","variant",struct(),"build",emptyBuildRecord(),"runs",repmat(emptyWorkerResult,0,1),"cases",repmat(emptyAggregatedCase,0,1));
end

function value = emptyAggregatedCase
value = struct("id","","Nxyz",[],"isHydrostatic",false,"status","failed","processTotalMedianSeconds",[],"processInternalMedianSeconds",[],"totalMedianSeconds",NaN,"internalMedianSeconds",NaN,"maximumRelativeError",NaN,"lifecyclePassed",false,"metrics",struct(),"diagnosticMetrics",struct(),"workerLifecycle",struct(),"rss",struct());
end

function value = emptyComparison
value = struct("id","","Nxyz",[],"isHydrostatic",false,"controlSeconds",NaN,"candidateSeconds",NaN,"speedup",NaN,"pairedProcessSpeedups",[],"allProcessComparisonsBeneficial",false,"targetedStageSpeedup",NaN,"descriptorReduction",NaN,"maximumLiveRatio",NaN,"peakRSSRatio",NaN,"correctnessPassed",false,"lifecyclePassed",false);
end

function value = emptyDecision
value = struct("id","","outcome","CORE-REJECT","adopted",false,"selected",false,"comparisons",repmat(emptyComparison,0,1),"reason","","cumulativeConfirmationPassed",false);
end

function value = decision(id,adopted,comparisons,reason)
value = emptyDecision;
value.id = id;
value.outcome = conditional(adopted,"CORE-ADOPT","CORE-REJECT");
value.adopted = adopted;
value.selected = adopted;
value.comparisons = comparisons;
value.reason = reason;
end

function value = decisionById(decisions,id)
value = decisions(string({decisions.id})==id);
if isempty(value), value = emptyDecision; end
value = value(1);
end

function value = screen(screens,id)
value = screens(string({screens.id})==id);
if isempty(value), error("WaveVortexBenchmark:MissingCoefficientScreen","Missing issue #126 screen %s.",id); end
value = value(1);
end

function result = normalizeWorkerResult(decoded)
result = emptyWorkerResult;
fields = fieldnames(decoded);
for iField = 1:numel(fields), result.(fields{iField}) = decoded.(fields{iField}); end
end

function identity = providerIdentity(provider,baseline)
identity = struct( ...
    "id",provider.id, ...
    "version",provider.version, ...
    "threadBackend",provider.threadBackend, ...
    "baseLibrary",provider.baseLibrary, ...
    "threadLibrary",provider.threadLibrary, ...
    "baseLibrarySha256",provider.baseLibrarySha256, ...
    "threadLibrarySha256",provider.threadLibrarySha256, ...
    "loadedModuleIdentity",baseline.runs(1).moduleInfo);
end

function record = environmentRecord(threads)
record = struct("os",string(system_dependent("getos")),"processor",string(system_dependent("getcpu")),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"fftThreads",threads);
end

function records = sourceHashRecords(repositoryRoot)
paths = ["CompiledKernel/include/WaveVortexKernel/WVKernelTypes.hpp" "CompiledKernel/src/WVKernelTypes.cpp" "CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" "Benchmarks/compiled-kernel/wv_compiled_transform_mex.cpp"];
records = repmat(struct("path","","sha256",""),numel(paths),1);
for iPath = 1:numel(paths)
    pathname = fullfile(repositoryRoot,paths(iPath));
    [status,output] = system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname));
    if status ~= 0, error("WaveVortexBenchmark:SourceHashFailed","Unable to hash %s.",pathname); end
    records(iPath) = struct("path",paths(iPath),"sha256",extractBefore(string(strtrim(output))," "));
end
end

function archiveSource(repositoryRoot,commit,destination)
command = sprintf('git -C "%s" archive "%s" | /usr/bin/tar -x -C "%s"',repositoryRoot,commit,destination);
[status,output] = system(command);
if status ~= 0, error("WaveVortexBenchmark:BaselineArchiveFailed","Unable to archive the #137 baseline: %s",output); end
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function [commit,tree,isDirty] = gitIdentity(root)
[~,commit] = system(sprintf('git -C "%s" rev-parse HEAD',root));
[~,tree] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root));
[~,status] = system(sprintf('git -C "%s" status --porcelain',root));
commit = string(strtrim(commit));
tree = string(strtrim(tree));
isDirty = strlength(strtrim(string(status)))>0;
end

function value = fieldOr(record,name,defaultValue)
if isfield(record,name), value = record.(name); else, value = defaultValue; end
end

function value = geomeanPositive(values)
selected = values(values>0 & isfinite(values));
value = exp(mean(log(selected)));
end

function root = defaultNativeCacheRoot
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
local = fullfile(repositoryRoot,".fftw-cache","issue137");
sibling = fullfile(fileparts(repositoryRoot),"wave-vortex-model-issue-137",".fftw-cache","issue137");
if isfile(fullfile(local,"downloads","fftw-3.3.11.tar.gz")), root = string(local);
elseif isfile(fullfile(sibling,"downloads","fftw-3.3.11.tar.gz")), root = string(sibling);
else, root = string(local);
end
end

function removeTemporaryRoot(root)
if isfolder(root), rmdir(root,"s"); end
end

function deleteTemporaryFiles(varargin)
for iFile = 1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory);
path(originalPath);
rng(originalRng);
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
