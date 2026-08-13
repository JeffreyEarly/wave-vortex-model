function result = runPortableDenseOutputBenchmark(options)
% Compare opt-in fixed-RK4 dense output with its archived no-output baseline.
arguments
    options.baselineCommit (1,1) string = "0876828d4d77727302bc326f8ae03ef999c70ef6"
    options.baselineHarnessCommit (1,1) string = "088ef51"
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65;512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupStepCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.deltaT (1,1) double {mustBePositive} = 1
    options.includeDenseVariants (1,1) logical = true
    options.outputDirectory (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexBenchmark:PortableDenseOutputUnsupportedPlatform","The canonical dense-output benchmark targets MATLAB R2026a on macOS maca64.")
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
candidateCommit = gitValue(repositoryRoot,"rev-parse HEAD");
if gitValue(repositoryRoot,"status --porcelain") ~= ""
    error("WaveVortexBenchmark:DirtyPortableDenseOutputCandidate","The candidate tree must be clean so archived source matches the recorded commit.")
end
if options.outputDirectory == ""
    runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"));
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","runs",runId+"-portable-dense-output");
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:PortableDenseOutputExists","Output directory already exists: %s",options.outputDirectory)
end
temporaryRoot = string(tempname);
mkdir(temporaryRoot)
temporaryCleanup = onCleanup(@()rmdir(temporaryRoot,"s"));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"));

baselineSource = fullfile(temporaryRoot,"baseline-source");
baselineHarnessSource = fullfile(temporaryRoot,"baseline-harness-source");
candidateSource = fullfile(temporaryRoot,"candidate-source");
mkdir(baselineSource); mkdir(baselineHarnessSource); mkdir(candidateSource)
archiveSource(repositoryRoot,options.baselineCommit,baselineSource)
archiveSource(repositoryRoot,options.baselineHarnessCommit,baselineHarnessSource)
archiveSource(repositoryRoot,candidateCommit,candidateSource)
cacheRoot = fullfile(repositoryRoot,".compiled-backend-cache");
candidateRunner = buildCandidateRunner(candidateSource,fullfile(temporaryRoot,"candidate-build"),cacheRoot);
providerRoot = fullfile(cacheRoot,"provider","native-neon-pthreads");
baselineRunner = buildBaselineRunner(baselineSource,baselineHarnessSource,fullfile(temporaryRoot,"baseline-build"),providerRoot,options.baselineCommit);

definitions = caseDefinitions(options);
variants = ["baseline-no-output" "candidate-no-output"];
if options.includeDenseVariants
    variants(end+1:end+2) = ["candidate-dense-1" "candidate-dense-4"];
end
runs = repmat(emptyRun,0,1);
correctness = repmat(struct("caseId","","repeatIndex",0,"variant","","maximumRelativeError",NaN),0,1);
for iCase = 1:numel(definitions)
    inputPath = fullfile(temporaryRoot,"input-"+definitions(iCase).id+".nc");
    writeInputCheckpoint(inputPath,definitions(iCase));
    sampleCount = conditional(all(definitions(iCase).Nxyz == options.sizes(1,:)),options.mediumSampleCount,options.largeSampleCount);
    for iRun = 1:options.processRunCount
        order = mod((0:numel(variants)-1)+(iCase+iRun-2),numel(variants))+1;
        outputs = strings(numel(variants),1);
        for iVariant = order
            variant = variants(iVariant);
            runner = conditional(iVariant == 1,baselineRunner,candidateRunner);
            denseCount = double(variant=="candidate-dense-1")+4*double(variant=="candidate-dense-4");
            outputPath = fullfile(temporaryRoot,sprintf("%s-%s-%d.nc",variant,definitions(iCase).id,iRun));
            reportPath = outputPath+".json";
            command = string(sprintf('"%s" "%s" "%s" --delta-t %.17g --steps %d --fft-provider native-fftw --threads 18 --benchmark-warmup-steps %d --report "%s"',runner,inputPath,outputPath,options.deltaT,sampleCount,options.warmupStepCount,reportPath));
            if denseCount ~= 0, command = command+sprintf(' --benchmark-dense-outputs-per-step %d',denseCount); end
            [status,output] = system(command);
            if status ~= 0 || ~isfile(reportPath), error("WaveVortexBenchmark:PortableDenseOutputWorker","%s",output), end
            report = jsondecode(fileread(reportPath));
            identity = string(report.provider.id) == "native-fftw" && contains(string(report.provider.version),"3.3.11") && report.execution.planCount == 17 && report.execution.noFallback;
            if ~identity, error("WaveVortexBenchmark:PortableDenseOutputIdentity","A worker did not execute the pinned native FFTW implementation."), end
            runs(end+1,1) = struct("variant",variant,"caseId",definitions(iCase).id,"repeatIndex",iRun,"sampleCount",sampleCount,"integrationSeconds",report.timingSeconds.integrate,"secondsPerStep",report.timingSeconds.integrate/sampleCount,"integratorWorkspaceBytes",report.storageBytes.integratorWorkspace,"denseHistoryBytes",report.storageBytes.denseHistory,"driverInterpolationBytes",report.storageBytes.driverInterpolation,"knownMaximumLiveBytes",report.livenessBytes.knownMaximumLive,"rssPeakIncrementLowerBoundBytes",report.rssBytes.peakIncrementLowerBound,"rhsEvaluationCount",report.state.rhsEvaluationCount,"interpolatedOutputCount",report.authorBenchmark.interpolatedOutputCount,"metadata",report); %#ok<AGROW>
            outputs(iVariant) = outputPath;
        end
        for iVariant = 2:numel(variants)
            correctness(end+1,1) = struct("caseId",definitions(iCase).id,"repeatIndex",iRun,"variant",variants(iVariant),"maximumRelativeError",compareCheckpoints(outputs(1),outputs(iVariant))); %#ok<AGROW>
        end
        for output = outputs', if isfile(output), delete(output), end, end
    end
end

comparisons = comparisonRecords(runs,correctness,definitions);
result = struct("schemaVersion","portable-dense-output-v1","status","complete","source",struct("baselineCommit",options.baselineCommit,"candidateCommit",candidateCommit),"environment",struct("release",string(version("-release")),"architecture",string(computer("arch")),"threads",18),"configuration",struct("suite","core-v1","processRunCount",options.processRunCount,"warmupStepCount",options.warmupStepCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"deltaT",options.deltaT,"correctnessTolerance",1e-12,"noOutputRegressionLimit",1.03,"note","Each fresh process executes the requested warmup steps before timing one aggregate sequence of 7 medium or 3 large state-advanced RK4 calls."),"runs",runs,"correctness",correctness,"comparisons",comparisons,"decision",struct("status",conditional(all([comparisons.passed]),"DENSE-OUTPUT-QUALIFIED","DENSE-OUTPUT-NOT-QUALIFIED"),"noOutputRegressionPassed",all([comparisons.noOutputRegressionPassed]),"correctnessPassed",all([comparisons.correctnessPassed])));
if options.shouldWriteArtifacts
    mkdir(options.outputDirectory)
    writeText(fullfile(options.outputDirectory,"portable-dense-output.json"),jsonencode(result,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(result));
end
clear stateCleanup temporaryCleanup
end

function runner = buildCandidateRunner(sourceRoot,buildRoot,cacheRoot)
command = sprintf('WV_RUNTIME_CACHE_ROOT="%s" "%s" "%s"',cacheRoot,fullfile(sourceRoot,"tools","portable-runtime","buildWaveVortexRun.sh"),buildRoot);
[status,output] = system(command);
if status ~= 0, error("WaveVortexBenchmark:PortableDenseOutputBuild","%s",output), end
lines = splitlines(strtrim(string(output)));
runner = lines(end);
end

function runner = buildBaselineRunner(baselineSource,baselineHarnessSource,buildRoot,providerRoot,baselineCommit)
projectRoot = fullfile(buildRoot,"project");
mkdir(projectRoot)
cmake = [
    "cmake_minimum_required(VERSION 3.20)"
    "project(WVDenseBaseline LANGUAGES CXX)"
    "set(WV_RUNTIME_ENABLE_NATIVE_FFTW ON CACHE BOOL """" FORCE)"
    "set(WV_RUNTIME_FFTW_ROOT """+cmakePath(providerRoot)+""" CACHE PATH """" FORCE)"
    "set(BUILD_TESTING OFF CACHE BOOL """" FORCE)"
    "add_subdirectory("""+cmakePath(fullfile(baselineSource,"PortableRuntime"))+""" runtime)"
    "add_executable(wave-vortex-run-dense-baseline """+cmakePath(fullfile(baselineHarnessSource,"PortableRuntime","app","WaveVortexRun.cpp"))+""")"
    "target_compile_features(wave-vortex-run-dense-baseline PRIVATE cxx_std_17)"
    "target_link_libraries(wave-vortex-run-dense-baseline PRIVATE WaveVortex::PortableRuntime WaveVortex::ReferenceFFT WaveVortexNativeFFTW)"
    "target_include_directories(wave-vortex-run-dense-baseline PRIVATE """+cmakePath(fullfile(baselineSource,"CompiledKernel","adapters","native-fftw"))+""")"
    "target_compile_definitions(wave-vortex-run-dense-baseline PRIVATE WV_RUNTIME_SOURCE_COMMIT="""+baselineCommit+""" WV_RUNTIME_HAS_NATIVE_FFTW=1 WV_RUNTIME_HAS_DENSE_OUTPUT=0 WV_RUNTIME_EXPECTED_FFTW_ROOT="""+cmakePath(providerRoot)+""")"
    "set_target_properties(wave-vortex-run-dense-baseline PROPERTIES BUILD_RPATH """+cmakePath(fullfile(providerRoot,"lib"))+""")"
    ];
writeText(fullfile(projectRoot,"CMakeLists.txt"),join(cmake,newline)+newline);
command = sprintf('cmake -S "%s" -B "%s" -DCMAKE_BUILD_TYPE=Release && cmake --build "%s" --parallel --target wave-vortex-run-dense-baseline',projectRoot,fullfile(buildRoot,"cmake"),fullfile(buildRoot,"cmake"));
[status,output] = system(command);
if status ~= 0, error("WaveVortexBenchmark:PortableDenseOutputBaselineBuild","%s",output), end
runner = fullfile(buildRoot,"cmake","wave-vortex-run-dense-baseline");
end

function definitions = caseDefinitions(options)
suite = waveVortexBenchmarkSuites("core-v1");
definitions = repmat(struct("id","","Nxyz",[],"Lxyz",[15000 15000 1300],"isHydrostatic",false,"shouldAntialias",true,"seed",0),0,1);
for iSize = 1:size(options.sizes,1)
    for hydrostatic = options.hydrostatic
        Nxyz = options.sizes(iSize,:);
        match = find(arrayfun(@(item)isequal(item.Nxyz,Nxyz)&&item.isHydrostatic==hydrostatic,suite.cases),1);
        seed = 175000+sum(Nxyz)+100*hydrostatic;
        if ~isempty(match), seed = suite.cases(match).seed; end
        id = sprintf("constant-%s-%dx%dx%d",conditional(hydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        definitions(end+1,1) = struct("id",id,"Nxyz",Nxyz,"Lxyz",[15000 15000 1300],"isHydrostatic",hydrostatic,"shouldAntialias",true,"seed",seed); %#ok<AGROW>
    end
end
end

function writeInputCheckpoint(pathname,definition)
wvt = WVTransformConstantStratification(definition.Lxyz,definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
cleanup = onCleanup(@()delete(wvt));
initializeWaveVortexBenchmarkState(wvt,definition.seed);
wvt.t = 0; wvt.t0 = 0; wvt.setForcing(WVNonlinearAdvection(wvt));
file = wvt.writeToFile(char(pathname),shouldOverwriteExisting=true); file.close();
clear cleanup
end

function comparisons = comparisonRecords(runs,correctness,definitions)
comparisons = repmat(struct("id","","baselineNoOutputSeconds",NaN,"candidateNoOutputSeconds",NaN,"candidateNoOutputRatio",NaN,"denseOneSeconds",NaN,"denseOneOverheadRatio",NaN,"denseFourSeconds",NaN,"denseFourOverheadRatio",NaN,"baselineWorkspaceBytes",NaN,"candidateNoOutputWorkspaceBytes",NaN,"denseMethodWorkspaceBytes",NaN,"denseDriverBytes",NaN,"maximumRelativeError",NaN,"noOutputRegressionPassed",false,"correctnessPassed",false,"passed",false),numel(definitions),1);
for iCase = 1:numel(definitions)
    selected = runs(string({runs.caseId}) == definitions(iCase).id);
    medianTime = @(name)median([selected(string({selected.variant}) == name).secondsPerStep]);
    baseline = selected(string({selected.variant}) == "baseline-no-output");
    candidate = selected(string({selected.variant}) == "candidate-no-output");
    denseOne = selected(string({selected.variant}) == "candidate-dense-1");
    errors = correctness(string({correctness.caseId}) == definitions(iCase).id);
    baselineTime = medianTime("baseline-no-output"); candidateTime = medianTime("candidate-no-output");
    denseOneTime = NaN; denseFourTime = NaN; denseMethodBytes = NaN; denseDriverBytes = NaN;
    if ~isempty(denseOne)
        denseOneTime = medianTime("candidate-dense-1"); denseFourTime = medianTime("candidate-dense-4");
        denseMethodBytes = median([denseOne.integratorWorkspaceBytes]); denseDriverBytes = median([denseOne.driverInterpolationBytes]);
    end
    maximumError = max([errors.maximumRelativeError]);
    noOutputPassed = candidateTime/baselineTime <= 1.03;
    correctnessPassed = maximumError <= 1e-12;
    comparisons(iCase) = struct("id",definitions(iCase).id,"baselineNoOutputSeconds",baselineTime,"candidateNoOutputSeconds",candidateTime,"candidateNoOutputRatio",candidateTime/baselineTime,"denseOneSeconds",denseOneTime,"denseOneOverheadRatio",denseOneTime/candidateTime,"denseFourSeconds",denseFourTime,"denseFourOverheadRatio",denseFourTime/candidateTime,"baselineWorkspaceBytes",median([baseline.integratorWorkspaceBytes]),"candidateNoOutputWorkspaceBytes",median([candidate.integratorWorkspaceBytes]),"denseMethodWorkspaceBytes",denseMethodBytes,"denseDriverBytes",denseDriverBytes,"maximumRelativeError",maximumError,"noOutputRegressionPassed",noOutputPassed,"correctnessPassed",correctnessPassed,"passed",noOutputPassed&&correctnessPassed);
end
end

function value = compareCheckpoints(firstPath,secondPath)
[first,firstFile] = WVTransform.waveVortexTransformFromFile(char(firstPath),iTime=Inf,shouldReadOnly=true); firstCleanup = onCleanup(@()firstFile.close());
[second,secondFile] = WVTransform.waveVortexTransformFromFile(char(secondPath),iTime=Inf,shouldReadOnly=true); secondCleanup = onCleanup(@()secondFile.close());
value = max([relativeError(first.Ap,second.Ap) relativeError(first.Am,second.Am) relativeError(first.A0,second.A0) abs(first.t-second.t)]);
clear firstCleanup secondCleanup
end

function value = relativeError(first,second)
value = max(abs(first-second),[],"all")/max(max(abs(first),[],"all"),realmin);
end

function archiveSource(repositoryRoot,commit,destination)
command = sprintf('git -C "%s" archive --format=tar %s | /usr/bin/tar -xf - -C "%s"',repositoryRoot,commit,destination);
[status,output] = system(command);
if status ~= 0, error("WaveVortexBenchmark:PortableDenseOutputArchive","%s",output), end
end

function value = gitValue(repositoryRoot,arguments)
[status,output] = system(sprintf('git -C "%s" %s',repositoryRoot,arguments));
if status ~= 0, error("WaveVortexBenchmark:PortableDenseOutputGit","%s",output), end
value = strtrim(string(output));
end

function value = cmakePath(pathname)
value = replace(string(pathname),"\\","/");
end

function text = markdownSummary(result)
lines = ["# Portable fixed-RK4 dense output";"";"Decision: **"+result.decision.status+"**";"";"| Case | Baseline no output (s/step) | Candidate no output ratio | One output overhead | Four output overhead | Dense method bytes | Driver bytes | Error |";"|---|---:|---:|---:|---:|---:|---:|---:|"];
for item = reshape(result.comparisons,1,[])
    lines(end+1,1) = sprintf("| %s | %.6f | %.4f | %.4f | %.4f | %d | %d | %.3e |",item.id,item.baselineNoOutputSeconds,item.candidateNoOutputRatio,item.denseOneOverheadRatio,item.denseFourOverheadRatio,item.denseMethodWorkspaceBytes,item.denseDriverBytes,item.maximumRelativeError); %#ok<AGROW>
end
text = strjoin(lines,newline)+newline;
end

function writeText(pathname,value)
file = fopen(pathname,"w");
if file < 0, error("WaveVortexBenchmark:PortableDenseOutputWrite","Unable to write %s.",pathname), end
cleanup = onCleanup(@()fclose(file)); fprintf(file,"%s",value); clear cleanup
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyRun
value = struct("variant","","caseId","","repeatIndex",0,"sampleCount",0,"integrationSeconds",NaN,"secondsPerStep",NaN,"integratorWorkspaceBytes",NaN,"denseHistoryBytes",NaN,"driverInterpolationBytes",NaN,"knownMaximumLiveBytes",NaN,"rssPeakIncrementLowerBoundBytes",NaN,"rhsEvaluationCount",0,"interpolatedOutputCount",0,"metadata",struct());
end
