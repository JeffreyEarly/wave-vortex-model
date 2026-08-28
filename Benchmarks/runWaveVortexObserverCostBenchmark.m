function results = runWaveVortexObserverCostBenchmark(options)
% Measure observer-state integration and dense-output costs independently.
arguments
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [64 64 33]
    options.Lxyz (1,3) double {mustBePositive} = [150e3 150e3 1300]
    options.deltaT (1,1) double {mustBePositive} = 128
    options.integrationStepCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.denseOutputPointsPerStep (1,1) double {mustBeInteger,mustBePositive} = 3
    options.seed (1,1) double {mustBeInteger,mustBeNonnegative} = 4001
    options.caseIds (1,:) string = strings(1,0)
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBePositive} = 0.05
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
definitions = waveVortexObserverCostBenchmarkCases(caseIds=options.caseIds,deltaT=options.deltaT,integrationStepCount=options.integrationStepCount,denseOutputPointsPerStep=options.denseOutputPointsPerStep);
if options.outputDirectory == ""
    options.outputDirectory = fullfile(benchmarkFolder,"results","runs",options.runId+"-observer-cost-"+computer("arch")+"-"+version("-release"));
end

workFolder = string(tempname);
mkdir(workFolder);
workCleanup = onCleanup(@()removeFolder(workFolder));
runs = repmat(emptyRun,0,1);
for iRepeat = 1:options.processRunCount
    caseOrder = mod((0:numel(definitions)-1)+(iRepeat-1),numel(definitions))+1;
    for iCase = caseOrder
        fprintf("Observer-cost benchmark: %s, repeat %d/%d.\n",definitions(iCase).id,iRepeat,options.processRunCount);
        runs(end+1,1) = runWorker(definitions(iCase),iRepeat,options,benchmarkFolder,workFolder); %#ok<AGROW>
    end
end

caseResults = repmat(emptyCase,0,1);
for iCase = 1:numel(definitions)
    matchingRuns = runs(arrayfun(@(run)string(run.case.id)==string(definitions(iCase).id),runs));
    caseResults(end+1,1) = aggregateCase(definitions(iCase),matchingRuns); %#ok<AGROW>
end
status = conditional(all(string({caseResults.status})=="complete"),"complete","partial");
[commit,tree,isDirty] = sourceIdentity(repositoryRoot);
results = struct( ...
    "schemaVersion","observer-cost-benchmark-v1", ...
    "status",status, ...
    "runId",options.runId, ...
    "generatedAtUTC",utcTimestamp, ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty), ...
    "environment",environmentRecord, ...
    "configuration",struct("studyId","observer-dense-cost-decomposition-v1","Nxyz",options.Nxyz,"Lxyz",options.Lxyz,"deltaT",options.deltaT,"integrationStepCount",options.integrationStepCount,"denseOutputPointsPerStep",options.denseOutputPointsPerStep,"seed",options.seed,"caseIds",string({definitions.id}),"processRunCount",options.processRunCount,"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"timingBoundary","fixed-RK4 integration plus scheduled output delivery; construction, initialization, startup, and cleanup excluded","memoryBoundary","total live-process-tree RSS sampled during the integration phase; steady-retained RSS is the representative baseline"), ...
    "cases",caseResults);
if options.shouldWriteArtifacts
    writeArtifacts(results,options.outputDirectory);
end
clear workCleanup stateCleanup
end

function run = runWorker(definition,repeatIndex,options,benchmarkFolder,workFolder)
sampleFolder = fullfile(workFolder,sprintf('%s-%d',definition.id,repeatIndex));
mkdir(sampleFolder);
configPath = fullfile(sampleFolder,"config.json");
outputPath = fullfile(sampleFolder,"worker.json");
modelOutputPath = fullfile(sampleFolder,"model.nc");
phasePath = fullfile(sampleFolder,"phase.txt");
samplePath = fullfile(sampleFolder,"rss.tsv");
stdoutPath = fullfile(sampleFolder,"stdout.txt");
stderrPath = fullfile(sampleFolder,"stderr.txt");
config = struct("case",definition,"Nxyz",options.Nxyz,"Lxyz",options.Lxyz,"deltaT",options.deltaT,"integrationStepCount",options.integrationStepCount,"denseOutputPointsPerStep",options.denseOutputPointsPerStep,"seed",options.seed,"modelOutputPath",modelOutputPath,"phasePath",phasePath,"plateauSeconds",options.plateauSeconds,"matlabPath",path);
writeText(configPath,jsonencode(config));
statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); waveVortexObserverCostBenchmarkWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
workerCommand = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
command = sampledCommand(workerCommand,samplePath,phasePath,stdoutPath,stderrPath,options,benchmarkFolder);
[exitCode,~] = system(command);
commandOutput = readCommandOutput(stdoutPath,stderrPath);
if exitCode ~= 0 || ~isfile(outputPath)
    run = emptyRun;
    run.repeatIndex = repeatIndex;
    run.case = definition;
    run.failure = struct("identifier","WaveVortexBenchmark:ObserverCostWorkerFailed","message",commandOutput,"report",commandOutput);
    return
end
run = jsondecode(fileread(outputPath));
run.repeatIndex = repeatIndex;
run.memory = processMemory(samplePath,options.samplingIntervalSeconds);
if string(run.status)=="complete" && string(run.memory.status)~="complete"
    run.status = "failed";
    run.failure = struct("identifier","WaveVortexBenchmark:ObserverCostMemoryUnavailable","message",string(run.memory.reason),"report","");
end
end

function value = aggregateCase(definition,runs)
complete = string({runs.status})=="complete";
elapsedSeconds = NaN(1,numel(runs)); totalPeakRSSBytes=elapsedSeconds; baselineRSSBytes=elapsedSeconds; peakIncrementBytes=elapsedSeconds; rhsEvaluationCounts=elapsedSeconds;
for iRun = 1:numel(runs)
    if complete(iRun)
        elapsedSeconds(iRun) = runs(iRun).timing.elapsedSeconds;
        totalPeakRSSBytes(iRun) = runs(iRun).memory.totalPeakRSSBytes;
        baselineRSSBytes(iRun) = runs(iRun).memory.baselineProcessBytes;
        peakIncrementBytes(iRun) = runs(iRun).memory.peakIncrementBytes;
        rhsEvaluationCounts(iRun) = runs(iRun).work.rhsEvaluationCount;
    end
end
value = struct( ...
    "id",definition.id,"label",definition.label,"integrationLabel",definition.integrationLabel,"outputLabel",definition.outputLabel, ...
    "definition",definition,"status",conditional(all(complete),"complete","partial"),"runs",runs, ...
    "elapsedSeconds",elapsedSeconds,"medianElapsedSeconds",median(elapsedSeconds,"omitnan"), ...
    "totalPeakRSSBytes",totalPeakRSSBytes,"medianTotalPeakRSSBytes",median(totalPeakRSSBytes,"omitnan"), ...
    "baselineRSSBytes",baselineRSSBytes,"medianBaselineRSSBytes",median(baselineRSSBytes,"omitnan"), ...
    "peakIncrementBytes",peakIncrementBytes,"medianPeakIncrementBytes",median(peakIncrementBytes,"omitnan"), ...
    "rhsEvaluationCounts",rhsEvaluationCounts);
end

function command = sampledCommand(workerCommand,samplePath,phasePath,stdoutPath,stderrPath,options,benchmarkFolder)
sampler = fullfile(benchmarkFolder,"runProcessWithRSS.sh");
if ~isfile(sampler)
    error("WaveVortexBenchmark:MissingRSSSampler","The process-tree RSS sampler is missing.");
end
command = shellQuote(sampler)+" "+shellQuote(samplePath)+" "+shellQuote(phasePath)+" "+numberText(options.samplingIntervalSeconds)+" "+shellQuote(stdoutPath)+" "+shellQuote(stderrPath)+" -- /bin/sh -c "+shellQuote(workerCommand);
end

function value = processMemory(samplePath,interval)
value = struct("status","failed","provider","macos-ps-process-tree","reason","RSS samples were not available.","boundary","integration-phase-total-live-process-tree-rss","samplingIntervalSeconds",interval,"totalPeakRSSBytes",NaN,"processLifetimePeakRSSBytes",NaN,"baselineProcessBytes",NaN,"peakIncrementBytes",NaN,"integrationSampleCount",0,"samples",repmat(struct("sampleIndex",0,"elapsedSeconds",0,"phase","","rssBytes",0,"processCount",0),0,1));
if ~isfile(samplePath), return, end
lines = splitlines(strtrim(string(fileread(samplePath))));
lines(lines=="") = [];
samples = value.samples;
for iLine = 1:numel(lines)
    fields = split(lines(iLine),sprintf('\t'));
    if numel(fields)<4, continue, end
    index = str2double(fields(1));
    rssBytes = 1024*str2double(fields(3));
    processCount = str2double(fields(4));
    if ~isfinite(index) || ~isfinite(rssBytes) || rssBytes<=0 || ~isfinite(processCount) || processCount<1, continue, end
    samples(end+1,1) = struct("sampleIndex",index,"elapsedSeconds",index*interval,"phase",fields(2),"rssBytes",rssBytes,"processCount",processCount); %#ok<AGROW>
end
bytes = [samples.rssBytes];
phases = string({samples.phase});
integrationBytes = bytes(phases=="integrate");
baselineBytes = bytes(phases=="steady-retained");
value.samples = samples;
if isempty(samples) || isempty(integrationBytes) || isempty(baselineBytes)
    value.reason = "RSS sampling did not capture both steady-retained and integration phases.";
    return
end
value.status = "complete";
value.reason = "";
value.totalPeakRSSBytes = max(integrationBytes);
value.processLifetimePeakRSSBytes = max(bytes);
value.baselineProcessBytes = median(baselineBytes);
value.peakIncrementBytes = max(0,value.totalPeakRSSBytes-value.baselineProcessBytes);
value.integrationSampleCount = numel(integrationBytes);
end

function writeArtifacts(results,outputDirectory)
if isfolder(outputDirectory), error("WaveVortexBenchmark:ObserverCostOutputExists","Output already exists: %s",outputDirectory); end
mkdir(outputDirectory);
writeText(fullfile(outputDirectory,"observer-cost-benchmark.json"),jsonencode(results,PrettyPrint=true));
end

function value = readCommandOutput(stdoutPath,stderrPath)
value = "";
if isfile(stdoutPath), value = string(fileread(stdoutPath)); end
if isfile(stderrPath), value = value+newline+string(fileread(stderrPath)); end
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for item=reshape(metadata.folders,1,[]), folder=fullfile(repositoryRoot,item.path); if isfolder(folder), addpath(folder); end, end
addpath(repositoryRoot);
addpath(benchmarkFolder);
end

function [commit,tree,isDirty] = sourceIdentity(repositoryRoot)
commit = gitValue(repositoryRoot,"rev-parse HEAD");
tree = gitValue(repositoryRoot,"rev-parse HEAD^{tree}");
[status,output] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain");
isDirty = status~=0 || strlength(strtrim(string(output)))>0;
end

function value = gitValue(repositoryRoot,args)
[status,output] = system("git -C "+shellQuote(repositoryRoot)+" "+args);
if status~=0, error("WaveVortexBenchmark:GitIdentity","%s",output); end
value = strtrim(string(output));
end

function value = environmentRecord, [~,processor]=system("/usr/sbin/sysctl -n machdep.cpu.brand_string"); value=struct("processor",strtrim(string(processor)),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"os",string(system_dependent("getos"))); end

function writeText(pathname,contents)
parent = fileparts(pathname);
if ~isfolder(parent), mkdir(parent); end
fileId = fopen(pathname,"w");
if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function value = numberText(value), value = string(sprintf('%.17g',value)); end
function value = shellQuote(value), value = "'"+replace(string(value),"'","'""'""'")+"'"; end
function value = utcTimestamp, value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")); end
function restoreState(directory,originalPath,originalRng), cd(directory); path(originalPath); rng(originalRng); end
function removeFolder(pathname), if isfolder(pathname), rmdir(pathname,"s"); end, end
function value = conditional(condition,trueValue,falseValue), if condition, value=trueValue; else, value=falseValue; end, end
function value = emptyRun, value=struct("schemaVersion","observer-cost-case-v1","status","failed","case",struct(),"timing",struct(),"work",struct(),"finalState",struct(),"failure",struct("identifier","","message","","report",""),"repeatIndex",0,"memory",struct()); end
function value = emptyCase, value=struct("id","","label","","integrationLabel","","outputLabel","","definition",struct(),"status","partial","runs",repmat(emptyRun,0,1),"elapsedSeconds",[],"medianElapsedSeconds",NaN,"totalPeakRSSBytes",[],"medianTotalPeakRSSBytes",NaN,"baselineRSSBytes",[],"medianBaselineRSSBytes",NaN,"peakIncrementBytes",[],"medianPeakIncrementBytes",NaN,"rhsEvaluationCounts",[]); end
