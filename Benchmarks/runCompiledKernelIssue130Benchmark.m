function results = runCompiledKernelIssue130Benchmark(options)
% Compare the issue #130 streamed schedule with the frozen #127 control.
arguments
    options.nativeProviderRoot (1,1) string
    options.buildDirectory (1,1) string = fullfile(tempdir,"wave-vortex-issue130-canonical-mex")
    options.outputDirectory (1,1) string = ""
    options.shouldBuild (1,1) logical = true
    options.processCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = 18
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.20
end

repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
provider = nativeProvider(options.nativeProviderRoot);
variants = variantDefinitions(options.buildDirectory);
if options.shouldBuild
    if ~isfolder(options.buildDirectory), mkdir(options.buildDirectory); end
    for iVariant = 1:numel(variants)
        [mexPath,build] = buildCompiledKernelTransformMex(outputDirectory=options.buildDirectory,outputName=variants(iVariant).module,provider=provider,issue130Variant=variants(iVariant).number);
        variants(iVariant).mexPath = string(mexPath);
        variants(iVariant).mexSha256 = string(build.mexSha256);
    end
else
    for iVariant = 1:numel(variants)
        if ~isfile(variants(iVariant).mexPath), error("WaveVortexModel:Issue130MexMissing","Missing issue #130 MEX module: %s",variants(iVariant).mexPath); end
        variants(iVariant).mexSha256 = sha256File(variants(iVariant).mexPath);
    end
end

[sourceCommit,sourceTree,sourceDirty] = gitIdentity(repositoryRoot);
if sourceDirty
    error("WaveVortexModel:Issue130DirtySource","Canonical issue #130 measurements require a clean tracked source tree.");
end
suite = waveVortexBenchmarkSuites("core-v1");
cases = suite.cases;
for iCase = 1:numel(cases)
    cases(iCase).warmupCount = 2;
    cases(iCase).sampleCount = conditional(cases(iCase).Nxyz(1)>=512,3,7);
end
runRoot = string(tempname);
mkdir(runRoot);
runCleanup = onCleanup(@()removeDirectory(runRoot));
matlabExecutable = fullfile(matlabroot,"bin","matlab");
workerRuns = repmat(emptyWorkerRun,0,1);
for iRepeat = 1:options.processCount
    for iCase = 1:numel(cases)
        order = mod((0:numel(variants)-1)+(iRepeat+iCase-2),numel(variants))+1;
        for iOrder = order
            variant = variants(iOrder);
            config = workerConfiguration(repositoryRoot,benchmarkFolder,variant,cases(iCase),provider,options,iRepeat);
            prefix = sprintf("repeat-%d-case-%d-variant-%d",iRepeat,iCase,iOrder);
            configPath = fullfile(runRoot,prefix+"-config.json");
            outputPath = fullfile(runRoot,prefix+"-result.json");
            writeText(configPath,jsonencode(config,PrettyPrint=true));
            expression = "addpath("+matlabString(benchmarkFolder)+"); compiledKernelIssue130Worker("+matlabString(configPath)+","+matlabString(outputPath)+")";
            command = shellQuote(matlabExecutable)+" -batch "+shellQuote(expression);
            fprintf("Issue #130 canonical run: repeat %d/%d, %s, %s.\n",iRepeat,options.processCount,cases(iCase).id,variant.id);
            [status,output] = system(command);
            if status ~= 0 || ~isfile(outputPath)
                error("WaveVortexModel:Issue130WorkerFailed","Fresh-process worker failed for %s/%s.\n%s",cases(iCase).id,variant.id,output);
            end
            worker = jsondecode(fileread(outputPath));
            if string(worker.status) ~= "complete"
                error("WaveVortexModel:Issue130WorkerIncomplete","Fresh-process worker was incomplete for %s/%s: %s",cases(iCase).id,variant.id,worker.failure.message);
            end
            workerRuns(end+1,1) = struct("executionOrdinal",numel(workerRuns)+1,"repeatIndex",iRepeat,"caseIndex",iCase,"variantIndex",iOrder,"result",worker); %#ok<AGROW>
        end
    end
end

comparisons = aggregateComparisons(workerRuns,cases);
decision = adoptionDecision(comparisons);
results = struct("schemaVersion","1.0.0","status","complete","generatedAtUTC",utcTimestamp,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",sourceCommit,"tree",sourceTree,"isDirty",sourceDirty,"baselineCommit","be0f78995c49a2bfe4c43d75827856e3812ac278","files",sourceFiles(repositoryRoot)),"environment",environmentRecord(provider,options),"configuration",struct("suite","core-v1","processCount",options.processCount,"warmupCount",2,"mediumSampleCount",7,"largeSampleCount",3,"correctnessTolerance",1e-12,"localGate",0.05,"architecturalGate",0.10,"maximumOtherMetricRegression",0.03,"executionOrder","rotated separate fresh-process pairs"),"variants",variants,"workerRuns",workerRuns,"comparisons",comparisons,"decision",decision);
if options.outputDirectory == ""
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","experiments","issue130",replace(utcTimestamp,["-" ":" "." "T" "Z"],["" "" "" "T" "Z"])+"-maca64-r"+lower(string(version("-release"))));
end
if isfolder(options.outputDirectory), error("WaveVortexModel:Issue130OutputExists","Output directory already exists: %s",options.outputDirectory); end
mkdir(options.outputDirectory);
writeText(fullfile(options.outputDirectory,"blocked-streamed-schedules.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
fprintf("Issue #130 decision: %s. Artifact: %s\n",decision.outcome,options.outputDirectory);
clear runCleanup stateCleanup
end

function config = workerConfiguration(repositoryRoot,benchmarkFolder,variant,caseDefinition,provider,options,repeatIndex)
config = struct("repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"repeatIndex",repeatIndex,"threadCount",options.threadCount,"providerId",provider.id,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"variant",struct("id",variant.id,"module",variant.module,"mexDirectory",fileparts(variant.mexPath)),"caseDefinition",caseDefinition);
end

function comparisons = aggregateComparisons(workerRuns,cases)
comparisons = repmat(struct("caseId","","Nxyz",[],"isHydrostatic",false,"control",struct(),"candidate",struct(),"pairedSpeedups",[],"medianSpeedup",NaN,"exactMaximumLiveReduction",NaN,"peakIncrementRSSReduction",NaN,"persistentIncrementRSSReduction",NaN,"maximumRelativeError",NaN,"metadataPassed",false,"speedRegressionPassed",false,"memoryRegressionPassed",false,"exactMemoryGatePassed",false,"rssMemoryGatePassed",false),numel(cases),1);
for iCase = 1:numel(cases)
    controlRuns = [workerRuns([workerRuns.caseIndex]==iCase & [workerRuns.variantIndex]==1).result];
    candidateRuns = [workerRuns([workerRuns.caseIndex]==iCase & [workerRuns.variantIndex]==2).result];
    control = aggregateVariant(controlRuns);
    candidate = aggregateVariant(candidateRuns);
    pairedSpeedups = [controlRuns.totalMedianSeconds]./[candidateRuns.totalMedianSeconds];
    exactReduction = 1-candidate.knownMaximumLiveOwnedBytes/control.knownMaximumLiveOwnedBytes;
    peakReduction = 1-candidate.medianPeakIncrementRSSBytes/control.medianPeakIncrementRSSBytes;
    persistentReduction = 1-candidate.medianPersistentIncrementRSSBytes/control.medianPersistentIncrementRSSBytes;
    metadataPassed = all(arrayfun(@(item)string(item.metrics.screeningVariant)=="streamed-target-three-channel" && item.metrics.phaseReservationBytes>0 && item.metrics.persistentFullHermitianBytes==0,candidateRuns));
    comparisons(iCase) = struct("caseId",string(cases(iCase).id),"Nxyz",cases(iCase).Nxyz,"isHydrostatic",cases(iCase).isHydrostatic,"control",control,"candidate",candidate,"pairedSpeedups",pairedSpeedups,"medianSpeedup",median(pairedSpeedups),"exactMaximumLiveReduction",exactReduction,"peakIncrementRSSReduction",peakReduction,"persistentIncrementRSSReduction",persistentReduction,"maximumRelativeError",candidate.maximumRelativeError,"metadataPassed",metadataPassed,"speedRegressionPassed",all(pairedSpeedups>=1/1.03),"memoryRegressionPassed",exactReduction>=-0.03&&peakReduction>=-0.03,"exactMemoryGatePassed",exactReduction>=0.10,"rssMemoryGatePassed",peakReduction>=0.10);
end
end

function aggregate = aggregateVariant(runs)
times = [runs.totalMedianSeconds];
internal = [runs.internalMedianSeconds];
persistentRSS = arrayfun(@(item)item.rss.persistentIncrementBytes,runs);
peak = arrayfun(@(item)item.rss.peakIncrementBytes,runs);
knownBytes = arrayfun(@(item)item.metrics.knownMaximumLiveOwnedBytes,runs);
aggregate = struct("variantId",string(runs(1).variantId),"processMedianSeconds",times,"medianSeconds",median(times),"processInternalMedianSeconds",internal,"medianInternalSeconds",median(internal),"persistentIncrementRSSBytes",persistentRSS,"medianPersistentIncrementRSSBytes",median(persistentRSS),"peakIncrementRSSBytes",peak,"medianPeakIncrementRSSBytes",median(peak),"knownMaximumLiveOwnedBytes",knownBytes(1),"scratchCapacityBytes",runs(1).metrics.scratchCapacityBytes,"planCount",runs(1).metrics.planCount,"planBytes",runs(1).metrics.planBytes,"maximumRelativeError",max([runs.maximumRelativeError]),"lifecyclePassed",all([runs.lifecyclePassed]));
end

function decision = adoptionDecision(comparisons)
sizes = unique(arrayfun(@(item)item.Nxyz(1),comparisons));
regions = repmat(struct("horizontalSize",0,"hydrostaticPassed",false,"nonhydrostaticPassed",false,"speedGatePassed",false,"memoryGatePassed",false,"qualified",false),numel(sizes),1);
for iSize = 1:numel(sizes)
    selected = comparisons(arrayfun(@(item)item.Nxyz(1)==sizes(iSize),comparisons));
    common = numel(selected)==2 && any([selected.isHydrostatic]) && any(~[selected.isHydrostatic]);
    correctness = common && all([selected.maximumRelativeError]<=1e-12) && all([selected.metadataPassed]);
    speedGate = correctness && all([selected.medianSpeedup]>=1.10) && all([selected.memoryRegressionPassed]);
    memoryGate = correctness && all([selected.exactMemoryGatePassed]) && all([selected.rssMemoryGatePassed]) && all([selected.speedRegressionPassed]);
    regions(iSize) = struct("horizontalSize",sizes(iSize),"hydrostaticPassed",common&&selected([selected.isHydrostatic]).metadataPassed,"nonhydrostaticPassed",common&&selected(~[selected.isHydrostatic]).metadataPassed,"speedGatePassed",speedGate,"memoryGatePassed",memoryGate,"qualified",speedGate||memoryGate);
end
qualified = any([regions.qualified]);
decision = struct("outcome",conditional(qualified,"CORE-ADOPT","CORE-REJECT"),"selectedSchedule",conditional(qualified,"streamed-target-three-channel","zero-then-scatter-fused-normalization"),"qualifiedRegions",regions([regions.qualified]),"regions",regions,"rationale",conditional(qualified,"The streamed schedule cleared the 10% speed-or-exact-and-RSS memory gate in a common hydrostatic/nonhydrostatic size region.","The streamed schedule did not clear the 10% speed or exact-and-RSS memory gate without a greater-than-3% regression."));
end

function variants = variantDefinitions(buildDirectory)
variants = [struct("id","control-be0f789","number",0,"module","wv_issue130_canonical_control","mexPath",fullfile(buildDirectory,"wv_issue130_canonical_control."+mexext),"mexSha256",""); struct("id","streamed-target-three-channel","number",3,"module","wv_issue130_canonical_streamed","mexPath",fullfile(buildDirectory,"wv_issue130_canonical_streamed."+mexext),"mexSha256","")];
end

function provider = nativeProvider(root)
includeDirectory = fullfile(root,"install","include");
baseLibrary = fullfile(root,"install","lib","libfftw3.3.dylib");
threadLibrary = fullfile(root,"install","lib","libfftw3_threads.3.dylib");
if ~isfile(fullfile(includeDirectory,"fftw3.h")) || ~isfile(baseLibrary) || ~isfile(threadLibrary), error("WaveVortexModel:Issue130NativeProviderMissing","The pinned FFTW 3.3.11 NEON/pthreads provider is incomplete at %s.",root); end
provider = struct("id","native-neon-pthreads","version","3.3.11","threadBackend","pthreads","includeDirectory",string(includeDirectory),"linkLibraries",[string(threadLibrary) string(baseLibrary)],"rpathDirectories",string(fullfile(root,"install","lib")),"baseLibrary",string(baseLibrary),"threadLibrary",string(threadLibrary),"baseLibrarySha256",sha256File(baseLibrary),"threadLibrarySha256",sha256File(threadLibrary));
end

function record = environmentRecord(provider,options)
[status,host] = system("hostname -s"); if status ~= 0, host = "unknown"; end
record = struct("host",string(strtrim(host)),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"provider",provider.id,"fftwVersion",provider.version,"threadBackend",provider.threadBackend,"threadCount",options.threadCount,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"baseLibrarySha256",provider.baseLibrarySha256,"threadLibrarySha256",provider.threadLibrarySha256,"rssProvider","macos-ps-rss-external","rssSamplingIntervalSeconds",options.samplingIntervalSeconds);
end

function files = sourceFiles(repositoryRoot)
paths = ["CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" "CompiledKernel/include/WaveVortexKernel/WVTransformConstantStratificationKernel.hpp" "Benchmarks/compiled-kernel/WVFFTWEngine.cpp" "Benchmarks/compiled-kernel/wv_compiled_transform_mex.cpp" "Benchmarks/runCompiledKernelIssue130Benchmark.m" "Benchmarks/compiledKernelIssue130Worker.m"];
files = repmat(struct("path","","sha256",""),numel(paths),1);
for iPath = 1:numel(paths)
    files(iPath) = struct("path",paths(iPath),"sha256",sha256File(fullfile(repositoryRoot,paths(iPath))));
end
end

function markdown = summaryMarkdown(results)
lines = ["# Issue #130 — Blocked and streamed scratch schedules";"";"- Decision: `"+results.decision.outcome+"`";"- Selected schedule: `"+results.decision.selectedSchedule+"`";"- Source: `"+results.source.commit+"`";"- Provider: native FFTW 3.3.11 NEON/pthreads, 18 threads";"- Protocol: three fresh processes per implementation and case; 7/3 samples";"";"| Case | Control (ms) | Streamed (ms) | Speedup | Exact live reduction | Peak RSS reduction | Error |";"|---|---:|---:|---:|---:|---:|---:|"];
for comparison = results.comparisons'
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3fx | %.1f%% | %.1f%% | %.3g |",comparison.caseId,1e3*comparison.control.medianSeconds,1e3*comparison.candidate.medianSeconds,comparison.medianSpeedup,100*comparison.exactMaximumLiveReduction,100*comparison.peakIncrementRSSReduction,comparison.maximumRelativeError); %#ok<AGROW>
end
lines = [lines;"";"## Decision";"";results.decision.rationale;"";"The candidate preserves four half-spectrum channels, streams one target at a time through the existing three-channel derivative inverse, and reduces real scratch from `(q+5)R` to `6R`. It retains no persistent full Hermitian spectrum."];
markdown = join(lines,newline)+newline;
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
[status,commit] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve commit identity."); end
[status,tree] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD^{tree}"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve tree identity."); end
[~,dirty] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain --untracked-files=no");
commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(dirty)))>0;
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname)); if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function value = matlabString(text)
value = "'"+replace(string(text),"'","''")+"'";
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyWorkerRun
value = struct("executionOrdinal",0,"repeatIndex",0,"caseIndex",0,"variantIndex",0,"result",struct());
end
