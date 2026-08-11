function results = runCompiledKernelNativeFFTWBenchmark(options)
% Establish the issue #137 native FFTW baseline for the compiled kernel.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65; 512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.threadCounts (1,:) double {mustBeInteger,mustBePositive} = [1 2 4 6 8 12 18]
    options.providerIds (1,:) string = ["native-plain-pthreads" "native-neon-pthreads" "native-simd128-pthreads" "native-neon-openmp"]
    options.screeningWarmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.screeningMediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.screeningLargeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 1
    options.finalWarmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.finalMediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.finalLargeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.finalProcessRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.12
    options.shouldIncludeBundledControl (1,1) logical = true
    options.shouldRunFinalists (1,1) logical = true
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexModel:NativeFFTWUnsupportedPlatform","Issue #137 targets MATLAB R2026a on macOS maca64.");
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
if options.outputDirectory == "", options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue137",options.runId+"-"+computer("arch")+"-r"+lower(version("-release"))); end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory), error("WaveVortexModel:NativeFFTWOutputExists","Output already exists: %s",options.outputDirectory); end
if options.shouldWriteArtifacts, mkdir(options.outputDirectory); end

results = initializeResult(options,repositoryRoot);
activeStage = "build";
try
    nativeBuild = buildCompiledKernelNativeFFTWProviders(providerIds=options.providerIds);
    bundledBuild = bundledProviderBuild(repositoryRoot);
    results.build = struct("native",nativeBuild,"bundled",bundledBuild);
    checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);

    activeStage = "screening";
    screeningCases = caseDefinitions(options,"screening");
    for iProvider = 1:numel(nativeBuild.providers)
        provider = nativeBuild.providers(iProvider);
        for threadCount = options.threadCounts
            fprintf("Issue #137 screening: %s, %d threads.\n",provider.id,threadCount);
            run = runWorker(provider,threadCount,1,"screening",screeningCases,options,repositoryRoot,benchmarkFolder);
            results.screening(end+1,1) = run;
            checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);
        end
    end
    results.finalists = compiledKernelNativeFFTWFinalists(results.screening,nativeBuild.providers,options.threadCounts);
    checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);

    if options.shouldRunFinalists
        activeStage = "final measurements";
        finalCases = caseDefinitions(options,"final");
        for iFinalist = 1:numel(results.finalists)
            finalist = results.finalists(iFinalist);
            provider = nativeBuild.providers(string({nativeBuild.providers.id})==finalist.providerId);
            for iRun = 1:options.finalProcessRunCount
                fprintf("Issue #137 final: %s, %d threads, process %d/%d.\n",provider.id,finalist.threadCount,iRun,options.finalProcessRunCount);
                results.finalRuns(end+1,1) = runWorker(provider,finalist.threadCount,iRun,"final",finalCases,options,repositoryRoot,benchmarkFolder);
                checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);
            end
        end
        if options.shouldIncludeBundledControl
            bundledThreads = max(options.threadCounts);
            for iRun = 1:options.finalProcessRunCount
                fprintf("Issue #137 bundled control: %d threads, process %d/%d.\n",bundledThreads,iRun,options.finalProcessRunCount);
                results.finalRuns(end+1,1) = runWorker(bundledBuild,bundledThreads,iRun,"final",finalCases,options,repositoryRoot,benchmarkFolder);
                checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);
            end
        end
        results.finalConfigurations = aggregateFinalRuns(results.finalRuns);
        results.selection = selectNativeConfiguration(results.finalConfigurations);
    end
    results.status = conditional(all(string({results.screening.status})=="complete") && (~options.shouldRunFinalists || results.selection.valid),"complete","partial");
    results.completedAtUTC = utcTimestamp;
    results.failure = emptyFailure;
    writeArtifacts(results,options.outputDirectory,options.shouldWriteArtifacts);
catch exception
    results.status = "failed"; results.completedAtUTC = utcTimestamp; results.failure = struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name}));
    writeArtifacts(results,options.outputDirectory,options.shouldWriteArtifacts);
    rethrow(exception)
end
clear stateCleanup
end

function results = initializeResult(options,repositoryRoot)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct("schemaVersion","1.0.0","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","environment",environmentRecord,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty,"engineSha256",sha256File(fullfile(repositoryRoot,"Benchmarks","compiled-kernel","WVFFTWEngine.cpp")),"gatewaySha256",sha256File(fullfile(repositoryRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp")),"kernelSha256",sha256File(fullfile(repositoryRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp"))),"configuration",struct("sizes",options.sizes,"hydrostatic",options.hydrostatic,"threadCounts",options.threadCounts,"providerIds",options.providerIds,"planner","FFTW_MEASURE | FFTW_UNALIGNED","coefficientWorkerCount",1,"screening",struct("processRunCount",1,"warmupCount",options.screeningWarmupCount,"mediumSampleCount",options.screeningMediumSampleCount,"largeSampleCount",options.screeningLargeSampleCount),"final",struct("processRunCount",options.finalProcessRunCount,"warmupCount",options.finalWarmupCount,"mediumSampleCount",options.finalMediumSampleCount,"largeSampleCount",options.finalLargeSampleCount),"selection","one global native build/thread configuration; geometric-mean internal nonlinearFlux; simpler within 3%","correctnessTolerance",1e-12),"build",struct(),"screening",repmat(emptyRun,0,1),"finalists",repmat(struct("providerId","","threadCount",0,"reasons",strings(0,1),"screeningNonlinearFluxScoreSeconds",NaN,"screeningTransformScoreSeconds",NaN),0,1),"finalRuns",repmat(emptyRun,0,1),"finalConfigurations",repmat(emptyConfiguration,0,1),"selection",emptySelection,"failure",emptyFailure);
end

function cases = caseDefinitions(options,stage)
cases = repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",0,"warmupCount",0,"sampleCount",0),0,1);
suite = waveVortexBenchmarkSuites("core-v1");
for iSize = 1:size(options.sizes,1)
    for isHydrostatic = options.hydrostatic
        Nxyz = options.sizes(iSize,:);
        match = find(arrayfun(@(item)isequal(item.Nxyz,Nxyz) && item.isHydrostatic==isHydrostatic,suite.cases),1);
        if isempty(match), seed = 137000+sum(Nxyz)+100*isHydrostatic; else, seed = suite.cases(match).seed; end
        if stage == "screening"
            warmups = options.screeningWarmupCount; mediumSamples = options.screeningMediumSampleCount; largeSamples = options.screeningLargeSampleCount;
        else
            warmups = options.finalWarmupCount; mediumSamples = options.finalMediumSampleCount; largeSamples = options.finalLargeSampleCount;
        end
        sampleCount = mediumSamples;
        if iSize == size(options.sizes,1), sampleCount = largeSamples; end
        identifier = sprintf("constant-%s-%dx%dx%d",conditional(isHydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        cases(end+1,1) = struct("id",identifier,"Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"shouldAntialias",true,"seed",seed,"warmupCount",warmups,"sampleCount",sampleCount); %#ok<AGROW>
    end
end
end

function run = runWorker(provider,threadCount,repeatIndex,stage,cases,options,repositoryRoot,benchmarkFolder)
configPath = string(tempname)+".json"; outputPath = string(tempname)+".json";
cleanup = onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
config = struct("stage",stage,"providerId",provider.id,"threadBackend",provider.threadBackend,"simplicityRank",provider.simplicityRank,"threadCount",threadCount,"repeatIndex",repeatIndex,"module",provider.module,"mexDirectory",string(fileparts(provider.mexPath)),"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"runtimeLibrary",provider.runtimeLibrary,"cases",cases,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds);
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelNativeFFTWWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[exitCode,commandOutput] = system(command);
if exitCode ~= 0 || ~isfile(outputPath)
    run = emptyRun; run.stage = stage; run.providerId = provider.id; run.threadBackend = provider.threadBackend; run.simplicityRank = provider.simplicityRank; run.threadCount = threadCount; run.repeatIndex = repeatIndex; run.failure = struct("identifier","WaveVortexModel:NativeFFTWWorkerFailed","message",string(commandOutput),"stack",strings(0,1),"report",string(commandOutput));
else
    decoded = jsondecode(fileread(outputPath));
    run = normalizeRun(decoded);
end
clear cleanup
end

function run = normalizeRun(decoded)
run = struct("schemaVersion",string(decoded.schemaVersion),"status",string(decoded.status),"stage",string(decoded.stage),"providerId",string(decoded.providerId),"threadBackend",string(decoded.threadBackend),"simplicityRank",decoded.simplicityRank,"threadCount",decoded.threadCount,"repeatIndex",decoded.repeatIndex,"module",string(decoded.module),"moduleInfo",decoded.moduleInfo,"cases",decoded.cases,"rss",decoded.rss,"moduleClearSeconds",decoded.moduleClearSeconds,"failure",decoded.failure);
end

function build = bundledProviderBuild(repositoryRoot)
directory = fullfile(repositoryRoot,".fftw-cache","issue137","bundled","mex");
[mexPath,mexBuild] = buildCompiledKernelTransformMex(outputDirectory=directory,outputName="wv_compiled_transform_mex_matlab_bundled");
library = string(fullfile(matlabroot,"bin",computer("arch"),"libmwfftw3.3.dylib"));
build = struct("id","matlab-bundled","description","MATLAB R2026a bundled FFTW control.","version","3.3.8","threadBackend","pthreads","simplicityRank",0,"buildKey","matlab-r2026a","buildRoot",string(fileparts(directory)),"installDirectory",string(matlabroot),"includeDirectory",string(fullfile(matlabroot,"extern","include")),"baseLibrary",library,"threadLibrary",library,"runtimeLibrary","","configureFlags","MATLAB supplied","compilerFlags","MATLAB MEX defaults","cycleCounterPassed",true,"checkPassed",true,"module","wv_compiled_transform_mex_matlab_bundled","mexPath",string(mexPath),"mexSha256",mexBuild.mexSha256,"baseLibrarySha256",sha256File(library),"threadLibrarySha256",sha256File(library),"logs",struct());
end

function configurations = aggregateFinalRuns(runs)
keys = unique(string({runs.providerId})+"|"+string([runs.threadCount]));
configurations = repmat(emptyConfiguration,numel(keys),1);
for iKey = 1:numel(keys)
    fields = split(keys(iKey),"|"); selected = runs(string({runs.providerId})==fields(1) & [runs.threadCount]==str2double(fields(2)));
    complete = string({selected.status})=="complete";
    caseCount = max(arrayfun(@(item)numel(item.cases),selected));
    cases = repmat(struct("id","","processInternalMedianSeconds",struct(),"medianInternalSeconds",struct(),"processTotalMedianSeconds",struct(),"medianTotalSeconds",struct(),"peakIncrementRSSBytes",[],"medianPeakIncrementRSSBytes",NaN,"maximumRelativeError",NaN,"metrics",struct()),caseCount,1);
    operations = ["forward" "inverse" "fAll" "gAll" "nonlinearFlux"];
    for iCase = 1:caseCount
        cases(iCase).id = string(selected(find(complete,1)).cases(iCase).id);
        for operation = operations
            internal = NaN(1,numel(selected)); total = NaN(1,numel(selected));
            for iRun = 1:numel(selected)
                if ~complete(iRun), continue, end
                record = selected(iRun).cases(iCase).timings(string({selected(iRun).cases(iCase).timings.operation})==operation);
                internal(iRun) = record.internalMedianSeconds; total(iRun) = record.totalMedianSeconds;
            end
            cases(iCase).processInternalMedianSeconds.(operation) = internal;
            cases(iCase).medianInternalSeconds.(operation) = median(internal,"omitnan");
            cases(iCase).processTotalMedianSeconds.(operation) = total;
            cases(iCase).medianTotalSeconds.(operation) = median(total,"omitnan");
        end
        cases(iCase).peakIncrementRSSBytes = arrayfun(@(item)item.cases(iCase).rss.peakIncrementBytes,selected);
        cases(iCase).medianPeakIncrementRSSBytes = median(cases(iCase).peakIncrementRSSBytes,"omitnan");
        cases(iCase).maximumRelativeError = max(arrayfun(@(item)item.cases(iCase).maximumRelativeError,selected));
        cases(iCase).metrics = selected(find(complete,1)).cases(iCase).metrics;
    end
    nonlinearValues = arrayfun(@(item)item.medianInternalSeconds.nonlinearFlux,cases);
    configurations(iKey) = struct("providerId",fields(1),"threadBackend",string(selected(1).threadBackend),"simplicityRank",selected(1).simplicityRank,"threadCount",str2double(fields(2)),"status",conditional(all(complete),"complete","partial"),"runs",selected,"cases",cases,"nonlinearFluxGeometricMeanSeconds",exp(mean(log(nonlinearValues))),"maximumRelativeError",max([cases.maximumRelativeError]),"lifecyclePassed",all(arrayfun(@(item)all([item.cases.lifecyclePassed]),selected(complete))),"libraryIdentityPassed",all(arrayfun(@(item)identityPassed(item),selected(complete))));
end
end

function selection = selectNativeConfiguration(configurations)
native = configurations(string({configurations.providerId})~="matlab-bundled"); bundled = configurations(string({configurations.providerId})=="matlab-bundled");
valid = string({native.status})=="complete" & [native.maximumRelativeError]<=1e-12 & [native.lifecyclePassed] & [native.libraryIdentityPassed];
if ~any(valid), selection = emptySelection; selection.reason = "No native configuration passed correctness, identity, and lifecycle checks."; return, end
validIndices = find(valid); [~,relativeFastest] = min([native(validIndices).nonlinearFluxGeometricMeanSeconds]); fastestIndex = validIndices(relativeFastest);
caseCount = numel(native(fastestIndex).cases); perCaseFastest = Inf(1,caseCount);
for iCase = 1:caseCount, perCaseFastest(iCase) = min(arrayfun(@(item)item.cases(iCase).medianInternalSeconds.nonlinearFlux,native(valid))); end
near = false(size(native));
for index = validIndices
    timeNear = all(arrayfun(@(iCase)native(index).cases(iCase).medianInternalSeconds.nonlinearFlux<=1.03*perCaseFastest(iCase),1:caseCount));
    rssNear = true;
    for iCase = 1:caseCount
        referenceRSS = native(fastestIndex).cases(iCase).medianPeakIncrementRSSBytes; candidateRSS = native(index).cases(iCase).medianPeakIncrementRSSBytes;
        if isfinite(referenceRSS) && referenceRSS > 0 && isfinite(candidateRSS), rssNear = rssNear && candidateRSS <= 1.03*referenceRSS; end
    end
    near(index) = timeNear && rssNear;
end
eligible = find(near);
if isempty(eligible), eligible = fastestIndex; end
ranking = table([native(eligible).simplicityRank]',[native(eligible).threadCount]',string({native(eligible).providerId})',VariableNames=["simplicity" "threads" "provider"]);
[~,order] = sortrows(ranking,["simplicity" "threads" "provider"]); selectedIndex = eligible(order(1)); selected = native(selectedIndex);
ceilings = repmat(struct("caseId","","providerId","","threadCount",0,"internalNonlinearFluxSeconds",NaN),caseCount,1);
for iCase = 1:caseCount
    values = arrayfun(@(item)item.cases(iCase).medianInternalSeconds.nonlinearFlux,native(valid)); [value,relative] = min(values); index = validIndices(relative);
    ceilings(iCase) = struct("caseId",string(native(index).cases(iCase).id),"providerId",string(native(index).providerId),"threadCount",native(index).threadCount,"internalNonlinearFluxSeconds",value);
end
bundledComparison = repmat(struct("caseId","","nativeSeconds",NaN,"bundledSeconds",NaN,"nativeSpeedup",NaN),0,1);
if ~isempty(bundled)
    for iCase = 1:caseCount
        nativeSeconds = selected.cases(iCase).medianInternalSeconds.nonlinearFlux; bundledSeconds = bundled(1).cases(iCase).medianInternalSeconds.nonlinearFlux;
        bundledComparison(end+1,1) = struct("caseId",string(selected.cases(iCase).id),"nativeSeconds",nativeSeconds,"bundledSeconds",bundledSeconds,"nativeSpeedup",bundledSeconds/nativeSeconds); %#ok<AGROW>
    end
end
selection = struct("valid",true,"providerId",string(selected.providerId),"threadBackend",string(selected.threadBackend),"threadCount",selected.threadCount,"simplicityRank",selected.simplicityRank,"nonlinearFluxGeometricMeanSeconds",selected.nonlinearFluxGeometricMeanSeconds,"fastestProviderId",string(native(fastestIndex).providerId),"fastestThreadCount",native(fastestIndex).threadCount,"withinThreePercentOfPerCaseCeilings",near(selectedIndex),"reason","Selected the simplest valid global configuration within 3% of the per-workload speed ceilings and reference peak RSS.","perWorkloadCeilings",ceilings,"bundledComparison",bundledComparison);
end

function passed = identityPassed(run)
passed = string(run.moduleInfo.baseLibrary) ~= "" && string(run.moduleInfo.threadLibrary) ~= "";
if string(run.providerId) ~= "matlab-bundled", passed = passed && ~startsWith(string(run.moduleInfo.baseLibrary),string(matlabroot)); end
end

function checkpoint(results,outputDirectory,enabled)
if ~enabled, return, end
writeText(fullfile(outputDirectory,"native-fftw-baseline.json"),jsonencode(results,PrettyPrint=true));
end

function writeArtifacts(results,outputDirectory,enabled)
if ~enabled, return, end
checkpoint(results,outputDirectory,true); writeText(fullfile(outputDirectory,"summary.md"),summaryMarkdown(results));
end

function markdown = summaryMarkdown(results)
lines = ["# Native FFTW compiled-kernel baseline";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- Platform: `"+results.environment.processor+"`, MATLAB `"+results.environment.matlabRelease+"`";"- Planner: `FFTW_MEASURE | FFTW_UNALIGNED`";""];
if ~isempty(results.screening)
    lines(end+1:end+2) = ["## Screening";""]; lines(end+1:end+2) = ["| Provider | Threads | Geometric-mean internal nonlinearFlux (ms) | Status |";"|---|---:|---:|---|"];
    for run = results.screening'
        score = NaN; if string(run.status)=="complete", score = exp(mean(log(arrayfun(@(item)operationInternalMedian(item,"nonlinearFlux"),run.cases)))); end
        lines(end+1) = sprintf("| %s | %d | %.3f | %s |",run.providerId,run.threadCount,1e3*score,run.status); %#ok<AGROW>
    end
end
if ~isempty(results.finalConfigurations)
    lines(end+1:end+3) = ["";"## Fully sampled configurations";""]; lines(end+1:end+2) = ["| Provider | Threads | Internal nonlinearFlux geometric mean (ms) | Maximum error | Status |";"|---|---:|---:|---:|---|"];
    for item = results.finalConfigurations'
        lines(end+1) = sprintf("| %s | %d | %.3f | %.3g | %s |",item.providerId,item.threadCount,1e3*item.nonlinearFluxGeometricMeanSeconds,item.maximumRelativeError,item.status); %#ok<AGROW>
    end
end
if results.selection.valid
    lines(end+1:end+7) = ["";"## Selected standalone baseline";"";"- Provider: `"+results.selection.providerId+"`";"- Thread backend: `"+results.selection.threadBackend+"`";"- Global thread count: `"+results.selection.threadCount+"`";"- Reason: "+results.selection.reason];
    if ~isempty(results.selection.bundledComparison)
        lines(end+1:end+3) = ["";"| Workload | Native internal (ms) | Bundled internal (ms) | Native speedup |";"|---|---:|---:|---:|"];
        for item = results.selection.bundledComparison'
            lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3fx |",item.caseId,1e3*item.nativeSeconds,1e3*item.bundledSeconds,item.nativeSpeedup); %#ok<AGROW>
        end
    end
end
markdown = join(lines,newline)+newline;
end

function value = operationInternalMedian(caseResult,operation)
record = caseResult.timings(string({caseResult.timings.operation})==operation); value = record.internalMedianSeconds;
end

function record = environmentRecord
[~,processor] = system("/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || /usr/sbin/sysctl -n hw.model");
[~,memory] = system("/usr/sbin/sysctl -n hw.memsize");
record = struct("os",string(system_dependent("getos")),"processor",string(strtrim(processor)),"memoryBytes",str2double(strtrim(memory)),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"hardwareMaximumThreads",maxNumCompThreads);
end

function [commit,tree,isDirty] = gitIdentity(root)
[~,commit] = system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree] = system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); [~,status] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no',root)); commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(status)))>0;
end

function hash = sha256File(pathname)
[status,output] = system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname)); if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end; hash = extractBefore(string(strtrim(output))," ");
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json"))); for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:ArtifactWriteFailed","Unable to write %s.",pathname); end; cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
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

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = emptyFailure
value = struct("stage","","identifier","","message","","stack",strings(0,1));
end

function value = emptyRun
value = struct("schemaVersion","1.0.0","status","failed","stage","","providerId","","threadBackend","","simplicityRank",NaN,"threadCount",0,"repeatIndex",0,"module","","moduleInfo",struct(),"cases",[],"rss",struct(),"moduleClearSeconds",NaN,"failure",struct("identifier","","message","","stack",strings(0,1),"report",""));
end

function value = emptyConfiguration
value = struct("providerId","","threadBackend","","simplicityRank",NaN,"threadCount",0,"status","failed","runs",[],"cases",[],"nonlinearFluxGeometricMeanSeconds",NaN,"maximumRelativeError",NaN,"lifecyclePassed",false,"libraryIdentityPassed",false);
end

function value = emptySelection
value = struct("valid",false,"providerId","","threadBackend","","threadCount",0,"simplicityRank",NaN,"nonlinearFluxGeometricMeanSeconds",NaN,"fastestProviderId","","fastestThreadCount",0,"withinThreePercentOfPerCaseCeilings",false,"reason","","perWorkloadCeilings",[],"bundledComparison",[]);
end
