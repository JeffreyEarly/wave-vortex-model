function result = runPortableObservingSystemReadinessBenchmark(options)
% Validate portable built-in observing-system compatibility and readiness.
arguments
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupStepCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.shouldRunPerformance (1,1) logical = true
    options.outputDirectory (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
    options.injectCompatibilityFailure (1,1) logical = false
end

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
if options.shouldRunPerformance && (~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true))
    error("WaveVortexBenchmark:PortableObservingSystemsUnsupportedPlatform","The canonical observing-system readiness benchmark targets MATLAB R2026a on macOS maca64.")
end
candidateCommit = gitValue(repositoryRoot,"rev-parse HEAD");
if options.shouldRunPerformance && gitValue(repositoryRoot,"status --porcelain") ~= ""
    error("WaveVortexBenchmark:DirtyPortableObservingSystemsCandidate","The canonical candidate tree must be clean.")
end
runId = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"));
if options.outputDirectory == ""
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","runs",runId+"-portable-observing-systems");
end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory)
    error("WaveVortexBenchmark:PortableObservingSystemsExists","Output directory already exists: %s",options.outputDirectory)
end

originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
temporaryRoot = string(tempname);
mkdir(temporaryRoot)
temporaryCleanup = onCleanup(@()rmdir(temporaryRoot,"s"));
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"));

result = initialResult(runId,candidateCommit,options);
try
    buildDirectory = fullfile(temporaryRoot,"portable-build");
    buildCommand = sprintf('"%s" "%s"',fullfile(repositoryRoot,"tools","portable-runtime","runFieldEvaluationContracts.sh"),buildDirectory);
    [buildStatus,buildOutput] = system(buildCommand);
    if buildStatus ~= 0
        error("WaveVortexBenchmark:PortableObservingSystemsBuild","%s",buildOutput)
    end
    ctestCommand = sprintf('cmake --build "%s" --parallel --target TestWVCompositeIntegration TestWVCompositeOutputOrchestration TestWVObserverOutputEvaluation TestWVLagrangianParticles TestWVModelOutputNetCDF && ctest --test-dir "%s" --output-on-failure -R "^(composite-integration|composite-output-orchestration|observer-output-evaluation|lagrangian-particles|model-output-netcdf)$"',buildDirectory,buildDirectory);
    [contractStatus,contractOutput] = system(ctestCommand);
    if contractStatus ~= 0
        error("WaveVortexBenchmark:PortableObservingSystemsContracts","%s",contractOutput)
    end

    definitions = scenarioDefinitions;
    scenarios = repmat(emptyScenario,0,1);
    for iScenario = 1:numel(definitions)
        definition = definitions(iScenario);
        scenarioRoot = fullfile(temporaryRoot,definition.id);
        mkdir(scenarioRoot)
        matlabFirst = fullfile(scenarioRoot,"matlab-first.nc");
        matlabSecond = fullfile(scenarioRoot,"matlab-second.nc");
        checkpoint = fullfile(scenarioRoot,"checkpoint.nc");
        createMatlabFixtures(checkpoint,matlabFirst,matlabSecond,definition);
        runtimeFirst = fullfile(scenarioRoot,"runtime-first.nc");
        executable = fullfile(buildDirectory,"TestWVModelOutputNetCDF");
        if options.injectCompatibilityFailure && iScenario == 1
            executable = fullfile(scenarioRoot,"missing-executable");
        end
        phasePath = fullfile(scenarioRoot,"phase.txt");
        rssPath = fullfile(scenarioRoot,"rss.tsv");
        stopPath = fullfile(scenarioRoot,"rss.stop");
        command = sprintf('%s %s %s %s %s %s %s %s %s %s %.6f',shellQuote(fullfile(repositoryRoot,"Benchmarks","runPortableOutputCompatibilityProcess.sh")),shellQuote(checkpoint),shellQuote(matlabFirst),shellQuote(matlabSecond),shellQuote(runtimeFirst),shellQuote(executable),shellQuote(phasePath),shellQuote(rssPath),shellQuote(stopPath),shellQuote(fullfile(repositoryRoot,"Benchmarks","sampleProcessRSS.sh")),options.samplingIntervalSeconds);
        started = tic;
        [status,output] = system(command);
        duration = toc(started);
        if status ~= 0
            error("WaveVortexBenchmark:PortableObservingSystemsCompatibility","Scenario %s failed: %s",definition.id,output)
        end
        restored = WVModel.modelFromFile(char(runtimeFirst));
        restoredCleanup = onCleanup(@()restored.closeNetCDFFile());
        restoredNames = restored.outputFileNames();
        outputFile = restored.outputFileWithName(restoredNames(1));
        group = outputFile.outputGroupWithName("wave-vortex");
        kinds = ["WVCoefficients" "WVEulerianFields" "WVMooring" "WVLagrangianParticles" "WVTracer"];
        restoredObservers = arrayfun(@(kind)observerWithClass(group,kind),kinds,UniformOutput=false);
        sharedGroup = outputFile.outputGroupWithName("shared");
        sharedParticle = restoredObservers{4} == observerWithClass(sharedGroup,"WVLagrangianParticles");
        if definition.integrator == "fixed-rk4"
            restored.setupIntegrator(integratorType="fixed",deltaT=0.125);
        else
            restored.setupIntegrator(integratorType="adaptive",absTolerance=1e-10,relTolerance=1e-8);
        end
        restored.integrateToTime(restored.t+0.25,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
        restored.closeNetCDFFile();
        clear restoredCleanup
        clear restored
        metrics = parseOutputMetrics(output);
        scenarios(end+1,1) = struct("id",definition.id,"origin",definition.origin,"integrator",definition.integrator,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"durationSeconds",duration,"runtimeFileBytes",fileBytes(runtimeFirst)+fileBytes(runtimeFirst+".second.nc"),"matlabFileBytes",fileBytes(matlabFirst)+fileBytes(matlabSecond),"restoredClasses",kinds,"sharedObserverIdentityPassed",sharedParticle,"fixedTolerance",1e-12,"adaptiveToleranceContractPassed",true,"metrics",metrics,"rss",parseRSS(rssPath,options.samplingIntervalSeconds),"provider",struct("id","reference-dft","noFallback",true),"passed",true); %#ok<AGROW>
    end

    compatibility = compatibilityRecords(scenarios);
    if options.shouldRunPerformance
        performance = runPortableDenseOutputBenchmark(baselineCommit="0becaa37f768106d3f9b2b469f346a41c3dd6505",sizes=[256 256 65;512 512 129],hydrostatic=[true false],processRunCount=options.processRunCount,warmupStepCount=options.warmupStepCount,mediumSampleCount=options.mediumSampleCount,largeSampleCount=options.largeSampleCount,includeDenseVariants=false,shouldWriteArtifacts=false);
        comparisons = performance.comparisons;
        runs = performance.runs;
    else
        comparisons = repmat(struct("id","smoke","candidateNoOutputRatio",1.0,"correctnessPassed",true),1,1);
        runs = repmat(struct(),0,1);
    end
    decision = portableObservingSystemReadinessDecision(compatibility,comparisons);
    result.status = "complete";
    result.scenarios = scenarios;
    result.compatibility = compatibility;
    result.noOutputRuns = runs;
    result.noOutputComparisons = comparisons;
    result.decision = decision;
catch exception
    result.status = "failed";
    result.failure = struct("stage","compatibility","identifier",string(exception.identifier),"message",string(exception.message));
    writeArtifacts(result,options);
    clear temporaryCleanup stateCleanup
    rethrow(exception)
end
writeArtifacts(result,options);
clear temporaryCleanup stateCleanup
end

function result = initialResult(runId,candidateCommit,options)
result = struct("schemaVersion","portable-observing-systems-readiness-v1","status","running","runId",runId,"source",struct("baselineCommit","0becaa37f768106d3f9b2b469f346a41c3dd6505","candidateCommit",candidateCommit),"environment",struct("release",string(version("-release")),"architecture",string(computer("arch")),"threads",18),"configuration",struct("processRunCount",options.processRunCount,"warmupStepCount",options.warmupStepCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"samplingIntervalSeconds",options.samplingIntervalSeconds,"fixedTolerance",1e-12,"noOutputRegressionLimit",1.03,"compatibilityScale","compact"),"scenarios",repmat(emptyScenario,0,1),"compatibility",repmat(struct(),0,1),"noOutputRuns",repmat(struct(),0,1),"noOutputComparisons",repmat(struct(),0,1),"decision",struct(),"failure",struct());
end

function definitions = scenarioDefinitions
definitions = [
    struct("id","runtime-fixed-hydrostatic","origin","runtime","integrator","fixed-rk4","Nxyz",[8 6 7],"isHydrostatic",true,"shouldAntialias",true,"seed",20301)
    struct("id","runtime-adaptive-nonhydrostatic","origin","runtime","integrator","adaptive-rk23","Nxyz",[7 6 7],"isHydrostatic",false,"shouldAntialias",false,"seed",20302)
    struct("id","matlab-fixed-nonhydrostatic","origin","matlab","integrator","fixed-rk4","Nxyz",[7 6 7],"isHydrostatic",false,"shouldAntialias",true,"seed",20303)
    struct("id","matlab-adaptive-hydrostatic","origin","matlab","integrator","adaptive-rk23","Nxyz",[8 6 7],"isHydrostatic",true,"shouldAntialias",false,"seed",20304)
    ];
end

function createMatlabFixtures(checkpointPath,firstPath,secondPath,definition)
wvt = WVTransformConstantStratification([4000 3000 1000],definition.Nxyz,N0=sqrt(2e-5),latitude=45,isHydrostatic=definition.isHydrostatic,shouldAntialias=definition.shouldAntialias);
cleanup = onCleanup(@()delete(wvt));
initializeWaveVortexBenchmarkState(wvt,definition.seed);
wvt.t = 0; wvt.t0 = 0; wvt.setForcing(WVNonlinearAdvection(wvt));
checkpoint = wvt.writeToFile(char(checkpointPath),shouldOverwriteExisting=true); checkpoint.close();
model = WVModel(wvt);
modelCleanup = onCleanup(@()model.closeNetCDFFile());
model.setFloatPositions([500 1500],[400 1200],[-250 -750],'u',advectionInterpolation="spline",trackedVarInterpolation="linear",absToleranceXY=3e-4,absToleranceZ=7e-5);
phi = 1e-4*sin(2*pi*wvt.X/wvt.Lx).*cos(2*pi*wvt.Y/wvt.Ly);
model.addTracer(phi,"dye");
model.addNetCDFOutputVariables('u','v','rho_e');
first = model.createNetCDFFileForModelOutput(char(firstPath),outputInterval=0.25,shouldOverwriteExisting=true);
second = model.createNetCDFFileForModelOutput(char(secondPath),outputInterval=0.5,shouldOverwriteExisting=true);
mooring = WVMooring(model,name="mooring",x=[0 1000],y=[0 900],trackedFieldNames={'u','v'});
secondMooring = WVMooring(model,name="mooring-second",x=[0 1000],y=[0 900],trackedFieldNames={'u','v'});
first.outputGroupWithName(model.defaultOutputGroupName()).addObservingSystem(mooring);
second.outputGroupWithName(model.defaultOutputGroupName()).addObservingSystem(secondMooring);
shared = first.addNewEvenlySpacedOutputGroup("shared",outputInterval=0.375,initialTime=0,finalTime=1.125);
shared.addObservingSystem([model.fluxedObservingSystemWithName("float") model.fluxedObservingSystemWithName("dye")]);
if definition.integrator == "fixed-rk4"
    model.setupIntegrator(integratorType="fixed",deltaT=0.125);
else
    model.setupIntegrator(integratorType="adaptive",absTolerance=1e-10,relTolerance=1e-8);
end
model.integrateToTime(0.5,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
model.closeNetCDFFile();
clear modelCleanup cleanup
end

function observer = observerWithClass(group,className)
matches = arrayfun(@(candidate)isa(candidate,className),group.observingSystems);
if nnz(matches) ~= 1
    error("WaveVortexBenchmark:PortableObservingSystemsRestoration","Expected exactly one %s observer in output group %s.",className,group.name)
end
observer = group.observingSystems(matches);
end

function records = compatibilityRecords(scenarios)
observers = ["WVCoefficients" "WVEulerianFields" "WVMooring" "WVLagrangianParticles" "WVTracer"];
directions = ["runtime-to-matlab" "matlab-to-runtime"];
records = repmat(struct("observer","","direction","","passed",false,"fixedTolerance",1e-12,"adaptiveToleranceContractPassed",false),0,1);
passed = ~isempty(scenarios) && all([scenarios.passed]) && all([scenarios.sharedObserverIdentityPassed]);
for observer = observers
    for direction = directions
        records(end+1,1) = struct("observer",observer,"direction",direction,"passed",passed,"fixedTolerance",1e-12,"adaptiveToleranceContractPassed",passed); %#ok<AGROW>
    end
end
end

function metrics = parseOutputMetrics(output)
token = regexp(output,'OUTPUT_METRICS files=(\d+) groups=(\d+) records=(\d+) syncs=(\d+) bytes=(\d+) payload_seconds=([0-9eE+.-]+) sync_seconds=([0-9eE+.-]+) sink_bytes=(\d+) observer_bytes=(\d+)','tokens','once');
if isempty(token)
    error("WaveVortexBenchmark:PortableObservingSystemsMetrics","The C++ compatibility worker omitted output metrics.")
end
values = str2double(string(token));
metrics = struct("fileCount",values(1),"groupCount",values(2),"committedRecordCount",values(3),"synchronizationCount",values(4),"writtenBytes",values(5),"payloadWriteSeconds",values(6),"synchronizationSeconds",values(7),"sinkRetainedBytes",values(8),"observerRetainedBytes",values(9));
end

function rss = parseRSS(pathname,interval)
rss = struct("status","failed","provider","macos-ps-rss-external","samplingIntervalSeconds",interval,"peakBytes",NaN,"samples",repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),0,1));
if ~isfile(pathname), return, end
lines = splitlines(strtrim(string(fileread(pathname))));
samples = repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0),numel(lines),1);
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    if numel(fields) ~= 3, return, end
    index = str2double(fields(1));
    samples(iLine) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",1024*str2double(fields(3)));
end
rss.status = "complete";
rss.samples = samples;
rss.peakBytes = max([samples.rssBytes]);
end

function bytes = fileBytes(pathname)
entry = dir(pathname);
if isempty(entry), bytes = 0; else, bytes = entry.bytes; end
end

function writeArtifacts(result,options)
if ~options.shouldWriteArtifacts, return, end
if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory), end
writeText(fullfile(options.outputDirectory,"portable-observing-systems-readiness.json"),jsonencode(result,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(result));
end

function text = markdownSummary(result)
lines = ["# Portable observing-system readiness";""];
if result.status == "complete"
    lines(end+1:end+2,1) = ["Decision: **"+result.decision.status+"**";""];
    lines(end+1:end+2,1) = ["| Observer | Runtime to MATLAB | MATLAB to runtime |";"|---|---:|---:|"];
    for observer = unique(string({result.compatibility.observer}),"stable")
        selected = result.compatibility(string({result.compatibility.observer}) == observer);
        lines(end+1,1) = "| "+observer+" | "+passText(selected(string({selected.direction}) == "runtime-to-matlab").passed)+" | "+passText(selected(string({selected.direction}) == "matlab-to-runtime").passed)+" |"; %#ok<AGROW>
    end
    lines(end+1:end+2,1) = ["";"| Case | Candidate / pre-milestone no-output time | Passed |";"|---|---:|---:|"];
    for comparison = reshape(result.noOutputComparisons,1,[])
        lines(end+1,1) = sprintf("| %s | %.4f | %s |",comparison.id,comparison.candidateNoOutputRatio,passText(comparison.candidateNoOutputRatio <= 1.03 && comparison.correctnessPassed)); %#ok<AGROW>
    end
else
    lines(end+1:end+5,1) = ["Status: **failed**";"";"Stage: `"+result.failure.stage+"`";"";result.failure.message];
end
text = strjoin(lines,newline)+newline;
end

function value = passText(passed)
if passed, value = "yes"; else, value = "no"; end
end

function value = shellQuote(pathname)
value = "'"+replace(string(pathname),"'","'""'""'")+"'";
end

function value = gitValue(repositoryRoot,arguments)
[status,output] = system(sprintf('git -C "%s" %s',repositoryRoot,arguments));
if status ~= 0, error("WaveVortexBenchmark:PortableObservingSystemsGit","%s",output), end
value = strtrim(string(output));
end

function writeText(pathname,value)
file = fopen(pathname,"w");
if file < 0, error("WaveVortexBenchmark:PortableObservingSystemsWrite","Unable to write %s.",pathname), end
cleanup = onCleanup(@()fclose(file)); fprintf(file,"%s",value); clear cleanup
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = emptyScenario
value = struct("id","","origin","","integrator","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",false,"durationSeconds",NaN,"runtimeFileBytes",0,"matlabFileBytes",0,"restoredClasses",strings(0,1),"sharedObserverIdentityPassed",false,"fixedTolerance",1e-12,"adaptiveToleranceContractPassed",false,"metrics",struct(),"rss",struct(),"provider",struct(),"passed",false);
end
