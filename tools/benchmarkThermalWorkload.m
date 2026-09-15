function results = benchmarkThermalWorkload(initial,outputDirectory,options)
% Measure a bounded WVModel workload with explicitly recorded output overhead.
% The caller supplies the initialized state and frozen forcing configuration.
% Short sample cadences are recorded separately from production estimates.
% This utility measures throughput; it does not establish numerical accuracy.
% - Topic: Developer utilities
% - Parameter initial: authoritative initial transform; left unchanged
% - Parameter outputDirectory: empty destination for tables and checkpoints
% - Parameter options.duration: simulated seconds per repeated sample
% - Parameter options.maximumWallSeconds: soft wall budget checked between blocks
% - Returns results: setup, thread, integration, I/O and cadence measurements
arguments (Input)
    initial (1,1) WVTransformFreeSurfaceThermalQG
    outputDirectory (1,1) string
    options.duration (1,1) double {mustBePositive,mustBeFinite} = 3600
    options.step (1,1) double {mustBePositive,mustBeFinite} = 600
    options.maximumWallSeconds (1,1) double {mustBePositive,mustBeFinite} = 600
    options.repetitions (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCounts (1,:) double {mustBeInteger,mustBePositive} = [1 2 4]
    options.shouldWriteOutput (1,1) logical = true
    options.shouldMeasureWithoutOutput (1,1) logical = true
    options.shouldScreenThreads (1,1) logical = true
    options.exponentialAdaptive (1,1) logical = false
    options.relTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-5
    options.physicalAbsTolerance (1,5) double {mustBePositive,mustBeFinite} = [1e-13 1e-11 1e-8 1e-8 1e-9]
    options.caseId (1,1) string = "unspecified"
end
arguments (Output)
    results (1,1) struct
end
if isfolder(outputDirectory) && ~isempty(dir(fullfile(outputDirectory,'*.csv')))
    error('WV:ReadinessBenchmarkOutput','Use a new output directory to retain independent timing samples.');
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
timer = tic;
originalThreads = maxNumCompThreads;
threadCleanup = onCleanup(@()maxNumCompThreads(originalThreads));
clock = tic;
w = WVTransformFreeSurfaceThermalQG(scientificState=initial.scientificState,coefficientState=initial.coefficientState(),t=initial.t);
transformCleanup = onCleanup(@()releaseTransform(w));
w.t0 = initial.t0;
WVInternal.transferFreeSurfaceForcing(initial,w);
restorationSeconds = toc(clock);
clock = tic; model = WVModel(w); modelCleanup = onCleanup(@()closeModel(model));
configureIntegrator(model,options); integratorSetupSeconds = toc(clock);
clock = tic; model.explicitFlux(); firstRhsSeconds = toc(clock);
threadSamples = table(); integration = table(); io = table();
threadCounts = originalThreads;
if options.shouldScreenThreads, threadCounts = options.threadCounts; end
for count = threadCounts
    maxNumCompThreads(count);
    model.explicitFlux();
    for repeat = 1:options.repetitions
        if toc(timer) >= options.maximumWallSeconds, break; end
        clock = tic; model.explicitFlux(); seconds = toc(clock);
        threadSamples = [threadSamples;table(count,repeat,seconds)]; %#ok<AGROW>
        writetable(threadSamples,fullfile(outputDirectory,'threads.csv'));
    end
end
selectedThreads = originalThreads;
if ~isempty(threadSamples)
    counts = unique(threadSamples.count);
    medians = arrayfun(@(count)median(threadSamples.seconds(threadSamples.count==count)),counts);
    [~,best] = min(medians); selectedThreads = counts(best);
end
maxNumCompThreads(selectedThreads);
for withOutput = [false true]
    if withOutput && ~options.shouldWriteOutput, continue; end
    if ~withOutput && ~options.shouldMeasureWithoutOutput, continue; end
    for repeat = 1:options.repetitions
        if toc(timer) >= options.maximumWallSeconds, break; end
        clear modelCleanup model file group
        restoreInitial(w,initial);
        model = WVModel(w); modelCleanup = onCleanup(@()closeModel(model));
        configureIntegrator(model,options);
        path = fullfile(outputDirectory,sprintf('sample-output-%d.nc',repeat));
        setupOutputSeconds = 0; initialFileBytes = 0; scalarInterval = NaN; coefficientInterval = NaN;
        if withOutput
            clock = tic;
            coefficientInterval = options.duration/2; scalarInterval = options.duration/4;
            file = model.createNetCDFFileForModelOutput(char(path),outputInterval=coefficientInterval,shouldOverwriteExisting=false);
            group = file.addNewEvenlySpacedOutputGroup('scalar',initialTime=w.t,outputInterval=scalarInterval,finalTime=w.t+options.duration);
            group.addObservingSystem(ThermalReadinessInventoryObserver(model));
            model.outputTimesForIntegrationPeriod(w.t,w.t+options.duration);
            model.writeTimeStepToNetCDFFile(w.t);
            file.ncfile.sync();
            setupOutputSeconds = toc(clock);
            initialInfo = dir(path); initialFileBytes = initialInfo.bytes;
        end
        start = w.t; target = start+options.duration; accepted = 0; rejected = 0; rhs = 0; outputRhs = 0;
        steps = []; maximumCFL = 0; maximumDampingNumber = 0; clock = tic;
        while w.t < target && toc(timer) < options.maximumWallSeconds
            model.integrateToTime(min(target,w.t+2*options.step),shouldShowIntegrationDiagnostics=false);
            stats = model.exponentialStatistics;
            accepted = accepted+stats.acceptedSteps; rejected = rejected+stats.rejectedSteps;
            rhs = rhs+stats.rhsEvaluations; outputRhs = outputRhs+stats.outputRhsEvaluations;
            steps = [steps stats.acceptedStepSeconds]; %#ok<AGROW>
            maximumCFL = max(maximumCFL,stats.maximumCFL);
            maximumDampingNumber = max(maximumDampingNumber,stats.maximumDampingNumber);
        end
        simulated = w.t-start;
        closeClock = tic; model.closeNetCDFFile(); closeSeconds = toc(closeClock);
        seconds = toc(clock);
        clear modelCleanup model file group
        minimumStep = NaN; maximumStep = NaN;
        if ~isempty(steps), minimumStep = min(steps); maximumStep = max(steps); end
        status = "complete"; if w.t < target, status = "wall-budget"; end
        integration = [integration;table(withOutput,repeat,selectedThreads,simulated,seconds,simulated/max(seconds,realmin),accepted,rejected,rhs,outputRhs,minimumStep,maximumStep,maximumCFL,maximumDampingNumber,setupOutputSeconds,closeSeconds,scalarInterval,coefficientInterval,status,VariableNames={'withOutput','repeat','threads','simulatedSeconds','wallSeconds','simulatedSecondsPerWallSecond','acceptedSteps','rejectedSteps','rhsEvaluations','outputRhsEvaluations','minimumStep','maximumStep','maximumCFL','maximumDampingNumber','outputSetupSeconds','outputCloseSeconds','scalarInterval','coefficientInterval','status'})]; %#ok<AGROW>
        writetable(integration,fullfile(outputDirectory,'integration.csv'));
        if withOutput && isfile(path)
            info = dir(path); clock = tic;
            restored = WVModel.modelFromFile(char(path));
            restoredCleanup = onCleanup(@()releaseOwnedModel(restored));
            readSeconds = toc(clock); restoredTime = restored.t; restored.closeNetCDFFile();
            clear restoredCleanup restored
            coefficientPayloadBytes = 16*numel(w.Ath)+8*numel(w.Amda)+8;
            scalarPayloadBytes = 5*8;
            io = [io;table(repeat,info.bytes,initialFileBytes,info.bytes-initialFileBytes,coefficientPayloadBytes,scalarPayloadBytes,readSeconds,restoredTime,VariableNames={'repeat','sampleFileBytes','initialFileBytesIncludingFirstRecords','additionalSampleBytes','coefficientRecordPayloadBytes','scalarRecordPayloadBytes','restorationSeconds','restoredTime'})]; %#ok<AGROW>
            writetable(io,fullfile(outputDirectory,'io.csv'));
        end
        fprintf('T10 workload output=%d repeat=%d simulated=%.3g wall=%.3g status=%s\n',withOutput,repeat,simulated,seconds,status);
    end
end
clear modelCleanup model file group
% These are sampled current RSS values. External process accounting is the
% authoritative process peak; MATLAB allocation statistics are different.
[rssStatus,rssText] = system(sprintf('/bin/ps -o rss= -p %d',matlabProcessID));
currentRSSBytes = NaN;
if rssStatus==0, currentRSSBytes = 1024*str2double(strtrim(rssText)); end
setup = table(options.caseId,restorationSeconds,integratorSetupSeconds,firstRhsSeconds,originalThreads,selectedThreads,currentRSSBytes,toc(timer),string(version),string(which('IMInternalModes')),VariableNames={'caseId','restorationSeconds','integratorSetupSeconds','firstRhsSeconds','setupThreads','selectedThreads','finalCurrentRSSBytes','totalWallSeconds','matlab','providerPath'});
writetable(setup,fullfile(outputDirectory,'setup.csv'));
results = struct(setup=setup,threads=threadSamples,integration=integration,io=io,options=options);
save(fullfile(outputDirectory,'measurements.mat'),'results');
end

function configureIntegrator(model,o)
hasAdvection = any(arrayfun(@(force)isa(force,'WVNonlinearAdvection'),model.wvt.forcing));
model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=~hasAdvection,initialStep=o.step,maximumStep=o.step,exponentialAdaptive=o.exponentialAdaptive,physicalAbsTolerance=o.physicalAbsTolerance,relTolerance=o.relTolerance);
end

function restoreInitial(w,initial)
w.t = initial.t; w.t0 = initial.t0;
state = initial.coefficientState(); w.Ath = state.Ath; w.Amda = state.Amda;
end

function closeModel(model)
% Repetition models share this driver's one warm transform.
if isempty(model) || ~isvalid(model), return; end
cleanup = onCleanup(@()delete(model));
model.closeNetCDFFile();
end

function releaseOwnedModel(model)
% A restored model owns a separate transform and its derived caches.
if isempty(model) || ~isvalid(model), return; end
w = model.wvt;
cleanup = onCleanup(@()releaseTransform(w));
closeModel(model);
end

function releaseTransform(w)
if ~isempty(w) && isvalid(w), delete(w); end
end
