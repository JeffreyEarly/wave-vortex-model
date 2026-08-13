function result = runPortableAffineEntryAudit(options)
% Measure whether materialized RK stage construction warrants affine execution.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65;512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupStepCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.deltaT (1,1) double {mustBePositive} = 1
    options.entryFraction (1,1) double {mustBePositive} = 0.05
    options.instrumentationOverheadLimit (1,1) double {mustBePositive} = 1.01
    options.outputDirectory (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexBenchmark:PortableAffineAuditUnsupportedPlatform","The canonical affine-state entry audit targets MATLAB R2026a on macOS maca64.")
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
candidateCommit = gitValue(repositoryRoot,"rev-parse HEAD");
if gitValue(repositoryRoot,"status --porcelain") ~= ""
    error("WaveVortexBenchmark:DirtyPortableAffineAudit","The audit tree must be clean so both runners use the recorded source commit.")
end
if options.outputDirectory == ""
    runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"));
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","runs",runId+"-portable-affine-entry-audit");
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:PortableAffineAuditOutputExists","Output directory already exists: %s",options.outputDirectory)
end

temporaryRoot = string(tempname);
mkdir(temporaryRoot)
temporaryCleanup = onCleanup(@()rmdir(temporaryRoot,"s"));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"));

sourceRoot = fullfile(temporaryRoot,"source");
mkdir(sourceRoot)
archiveSource(repositoryRoot,candidateCommit,sourceRoot)
cacheRoot = fullfile(repositoryRoot,".compiled-backend-cache");
controlRunner = buildRunner(sourceRoot,fullfile(temporaryRoot,"control-build"),cacheRoot,false);
instrumentedRunner = buildRunner(sourceRoot,fullfile(temporaryRoot,"instrumented-build"),cacheRoot,true);

definitions = caseDefinitions(options);
variants = ["control" "stage-timed"];
runs = repmat(emptyRun,0,1);
correctness = repmat(struct("caseId","","repeatIndex",0,"maximumRelativeError",NaN),0,1);
for iCase = 1:numel(definitions)
    inputPath = fullfile(temporaryRoot,"input-"+definitions(iCase).id+".nc");
    writeInputCheckpoint(inputPath,definitions(iCase));
    sampleCount = conditional(all(definitions(iCase).Nxyz == options.sizes(1,:)),options.mediumSampleCount,options.largeSampleCount);
    for iRun = 1:options.processRunCount
        order = mod((0:1)+(iCase+iRun-2),2)+1;
        outputs = strings(2,1);
        for iVariant = order
            runner = [controlRunner instrumentedRunner];
            outputPath = fullfile(temporaryRoot,sprintf("%s-%s-%d.nc",variants(iVariant),definitions(iCase).id,iRun));
            reportPath = outputPath+".json";
            command = sprintf('"%s" "%s" "%s" --delta-t %.17g --steps %d --fft-provider native-fftw --threads 18 --benchmark-warmup-steps %d --report "%s"',runner(iVariant),inputPath,outputPath,options.deltaT,sampleCount,options.warmupStepCount,reportPath);
            [status,output] = system(command);
            if status ~= 0 || ~isfile(reportPath), error("WaveVortexBenchmark:PortableAffineAuditWorker","%s",output), end
            report = jsondecode(fileread(reportPath));
            identity = string(report.provider.id) == "native-fftw" && contains(string(report.provider.version),"3.3.11") && report.execution.planCount == 17 && report.execution.noFallback;
            if ~identity, error("WaveVortexBenchmark:PortableAffineAuditIdentity","An audit worker did not execute the pinned native FFTW implementation."), end
            stageSeconds = report.timingSeconds.stageStateConstruction;
            stateElementCount = 3*prod(report.state.shape);
            runs(end+1,1) = struct("variant",variants(iVariant),"caseId",definitions(iCase).id,"repeatIndex",iRun,"sampleCount",sampleCount,"integrationSeconds",report.timingSeconds.integrate,"secondsPerStep",report.timingSeconds.integrate/sampleCount,"stageStateConstructionSeconds",stageSeconds,"stageFraction",stageSeconds/report.timingSeconds.integrate,"stageStateReads",report.authorBenchmark.sampledStageStateConstructionReads,"stageStateWrites",report.authorBenchmark.sampledStageStateConstructionWrites,"stateElementCount",stateElementCount,"knownMaximumLiveBytes",report.livenessBytes.knownMaximumLive,"provider",report.provider,"execution",report.execution); %#ok<AGROW>
            outputs(iVariant) = outputPath;
        end
        correctness(end+1,1) = struct("caseId",definitions(iCase).id,"repeatIndex",iRun,"maximumRelativeError",compareCheckpoints(outputs(1),outputs(2))); %#ok<AGROW>
        for output = outputs', if isfile(output), delete(output), end, end
    end
end

comparisons = comparisonRecords(runs,correctness,definitions,options);
controlIntegrationSeconds = sum([runs(string({runs.variant}) == "control").integrationSeconds]);
instrumentedIntegrationSeconds = sum([runs(string({runs.variant}) == "stage-timed").integrationSeconds]);
aggregateInstrumentationOverheadRatio = instrumentedIntegrationSeconds/controlIntegrationSeconds;
overheadValid = aggregateInstrumentationOverheadRatio <= options.instrumentationOverheadLimit;
commonSizePassed = false(size(options.sizes,1),1);
for iSize = 1:size(options.sizes,1)
    selected = comparisons(arrayfun(@(item)all(item.Nxyz == options.sizes(iSize,:)),comparisons));
    commonSizePassed(iSize) = numel(selected) == 2 && all([selected.entryFractionPassed]);
end
if ~overheadValid
    decision = "INVALID-INSTRUMENTATION";
elseif any(commonSizePassed)
    decision = "ADVANCE";
else
    decision = "NOT-WARRANTED";
end
result = struct("schemaVersion","portable-affine-entry-audit-v1","status","complete","source",struct("commit",candidateCommit),"environment",struct("release",string(version("-release")),"architecture",string(computer("arch")),"threads",18),"configuration",struct("suite","core-v1","processRunCount",options.processRunCount,"warmupStepCount",options.warmupStepCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"deltaT",options.deltaT,"entryFraction",options.entryFraction,"instrumentationOverheadLimit",options.instrumentationOverheadLimit,"instrumentationOverheadScope","aggregate integration time across every paired case and process","theoreticalEliminatedIntegratorComplexValuesPerStateElement",3),"runs",runs,"correctness",correctness,"comparisons",comparisons,"decision",struct("status",decision,"instrumentationValid",overheadValid,"aggregateInstrumentationOverheadRatio",aggregateInstrumentationOverheadRatio,"commonSizePassed",commonSizePassed));
if options.shouldWriteArtifacts
    mkdir(options.outputDirectory)
    writeText(fullfile(options.outputDirectory,"affine-entry-audit.json"),jsonencode(result,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(result));
end
clear stateCleanup temporaryCleanup
end

function definitions = caseDefinitions(options)
suite = waveVortexBenchmarkSuites("core-v1");
definitions = repmat(struct("id","","Nxyz",[],"Lxyz",[15000 15000 1300],"isHydrostatic",false,"shouldAntialias",true,"seed",0),0,1);
for iSize = 1:size(options.sizes,1)
    for hydrostatic = options.hydrostatic
        Nxyz = options.sizes(iSize,:);
        match = find(arrayfun(@(item)isequal(item.Nxyz,Nxyz)&&item.isHydrostatic==hydrostatic,suite.cases),1);
        seed = 185000+sum(Nxyz)+100*hydrostatic;
        if ~isempty(match), seed = suite.cases(match).seed; end
        id = sprintf("constant-%s-%dx%dx%d",conditional(hydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        definitions(end+1,1) = struct("id",id,"Nxyz",Nxyz,"Lxyz",[15000 15000 1300],"isHydrostatic",hydrostatic,"shouldAntialias",true,"seed",seed); %#ok<AGROW>
    end
end
end

function comparisons = comparisonRecords(runs,correctness,definitions,options)
comparisons = repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"controlSecondsPerStep",NaN,"instrumentedSecondsPerStep",NaN,"instrumentationOverheadRatio",NaN,"medianStageFraction",NaN,"stageFractionRange",[NaN NaN],"stageStateReads",0,"stageStateWrites",0,"theoreticalEliminatedBytes",0,"knownMaximumLiveBytes",0,"theoreticalMaximumLiveReduction",NaN,"maximumRelativeError",NaN,"instrumentationOverheadPassed",false,"entryFractionPassed",false),numel(definitions),1);
for iCase = 1:numel(definitions)
    selected = runs(string({runs.caseId}) == definitions(iCase).id);
    control = selected(string({selected.variant}) == "control");
    instrumented = selected(string({selected.variant}) == "stage-timed");
    errors = correctness(string({correctness.caseId}) == definitions(iCase).id);
    controlSeconds = median([control.secondsPerStep]);
    instrumentedSeconds = median([instrumented.secondsPerStep]);
    fractions = [instrumented.stageFraction];
    stageBufferBytes = median([instrumented.stateElementCount])*sizeofComplex();
    knownBytes = median([instrumented.knownMaximumLiveBytes]);
    comparisons(iCase) = struct("id",definitions(iCase).id,"Nxyz",definitions(iCase).Nxyz,"isHydrostatic",definitions(iCase).isHydrostatic,"controlSecondsPerStep",controlSeconds,"instrumentedSecondsPerStep",instrumentedSeconds,"instrumentationOverheadRatio",instrumentedSeconds/controlSeconds,"medianStageFraction",median(fractions),"stageFractionRange",[min(fractions) max(fractions)],"stageStateReads",median([instrumented.stageStateReads]),"stageStateWrites",median([instrumented.stageStateWrites]),"theoreticalEliminatedBytes",stageBufferBytes,"knownMaximumLiveBytes",knownBytes,"theoreticalMaximumLiveReduction",stageBufferBytes/knownBytes,"maximumRelativeError",max([errors.maximumRelativeError]),"instrumentationOverheadPassed",instrumentedSeconds/controlSeconds <= options.instrumentationOverheadLimit,"entryFractionPassed",median(fractions) >= options.entryFraction && max([errors.maximumRelativeError]) <= 1e-12);
end
end

function value = sizeofComplex
value = 16;
end

function writeInputCheckpoint(pathname,definition)
wvt = WVTransformConstantStratification(definition.Lxyz,definition.Nxyz,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
cleanup = onCleanup(@()delete(wvt));
initializeWaveVortexBenchmarkState(wvt,definition.seed);
wvt.t = 0; wvt.t0 = 0; wvt.setForcing(WVNonlinearAdvection(wvt));
file = wvt.writeToFile(char(pathname),shouldOverwriteExisting=true); file.close();
clear cleanup
end

function runner = buildRunner(sourceRoot,buildRoot,cacheRoot,shouldTimeStages)
timing = conditional(shouldTimeStages,"ON","OFF");
command = sprintf('WV_RUNTIME_CACHE_ROOT="%s" WV_RUNTIME_ENABLE_STAGE_TIMING=%s "%s" "%s"',cacheRoot,timing,fullfile(sourceRoot,"tools","portable-runtime","buildWaveVortexRun.sh"),buildRoot);
[status,output] = system(command);
if status ~= 0, error("WaveVortexBenchmark:PortableAffineAuditBuild","%s",output), end
lines = splitlines(strtrim(string(output)));
runner = lines(end);
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
if status ~= 0, error("WaveVortexBenchmark:PortableAffineAuditArchive","%s",output), end
end

function value = gitValue(repositoryRoot,arguments)
[status,output] = system(sprintf('git -C "%s" %s',repositoryRoot,arguments));
if status ~= 0, error("WaveVortexBenchmark:PortableAffineAuditGit","%s",output), end
value = strtrim(string(output));
end

function text = markdownSummary(result)
lines = ["# Portable affine-state entry audit";"";"Decision: **"+result.decision.status+"**";"";"| Case | Control (s/step) | Instrumented ratio | Stage fraction | Theoretical live reduction | Error |";"|---|---:|---:|---:|---:|---:|"];
for item = reshape(result.comparisons,1,[])
    lines(end+1,1) = sprintf("| %s | %.6f | %.4f | %.4f | %.4f | %.3e |",item.id,item.controlSecondsPerStep,item.instrumentationOverheadRatio,item.medianStageFraction,item.theoreticalMaximumLiveReduction,item.maximumRelativeError); %#ok<AGROW>
end
text = strjoin(lines,newline)+newline;
end

function writeText(pathname,value)
file = fopen(pathname,"w");
if file < 0, error("WaveVortexBenchmark:PortableAffineAuditWrite","Unable to write %s.",pathname), end
cleanup = onCleanup(@()fclose(file)); fprintf(file,"%s",value); clear cleanup
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function value = emptyRun
value = struct("variant","","caseId","","repeatIndex",0,"sampleCount",0,"integrationSeconds",NaN,"secondsPerStep",NaN,"stageStateConstructionSeconds",NaN,"stageFraction",NaN,"stageStateReads",0,"stageStateWrites",0,"stateElementCount",0,"knownMaximumLiveBytes",0,"provider",struct(),"execution",struct());
end
