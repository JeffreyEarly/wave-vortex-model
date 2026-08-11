function results = runCompiledKernelReadinessBenchmark(options)
% Compare ordinary MATLAB and compiled nonlinearFlux in fresh processes.
arguments
    options.caseIds (1,:) string = strings(1,0)
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end

benchmarkFolder=string(fileparts(mfilename("fullpath"))); repositoryRoot=string(fileparts(benchmarkFolder));
originalDirectory=pwd; originalPath=path; originalRng=rng;
stateCleanup=onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
suite=waveVortexBenchmarkSuites("core-v1"); cases=suite.cases;
if ~isempty(options.caseIds), cases=cases(ismember(string({cases.id}),options.caseIds)); end
if isempty(cases), error("WaveVortexBenchmark:NoCompiledKernelCases","No core-v1 cases matched the selection."); end
buildDirectory=fullfile(benchmarkFolder,"build"); buildCompiledKernelTransformMex(outputDirectory=buildDirectory);
if options.outputDirectory=="", options.outputDirectory=fullfile(benchmarkFolder,"results","experiments","issue53",options.runId+"-"+computer("arch")+"-"+version("-release")); end

caseResults=repmat(emptyCase(),0,1);
for iCase=1:numel(cases)
    backendResults=repmat(emptyBackend(),0,1);
    for implementation=["builtin" "compiled"]
        runs=repmat(emptyRun(),0,1);
        for iRun=1:options.processRunCount
            runs(end+1,1)=runWorker(cases(iCase),implementation,iRun,options,benchmarkFolder,repositoryRoot,buildDirectory); %#ok<AGROW>
        end
        backendResults(end+1,1)=aggregateBackend(implementation,runs); %#ok<AGROW>
    end
    caseResults(end+1,1)=aggregateCase(cases(iCase),backendResults); %#ok<AGROW>
end
decision=readinessDecision(caseResults);
[commit,tree,isDirty]=gitIdentity(repositoryRoot);
results=struct("schemaVersion","1.0.0","status",conditional(all(string({caseResults.status})=="complete"),"complete","partial"),"runId",options.runId, ...
    "environment",environmentRecord(options.threadCount),"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty), ...
    "configuration",struct("suiteId","core-v1","operation","ordinary nonlinearFlux","processRunCount",options.processRunCount,"warmupPolicy","core-v1","samplePolicy","7 medium / 3 large","speedThreshold",1.25,"correctnessTolerance",1e-12,"baseline","optimized-builtin"), ...
    "suite",struct("id","core-v1","version",1,"kind","compiled-kernel-readiness","operation","nonlinearAdvection","cases",caseResults),"decision",decision);
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"compiled-kernel-readiness.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function run=runWorker(benchmarkCase,implementation,repeatIndex,options,benchmarkFolder,repositoryRoot,buildDirectory)
configPath=string(tempname)+".json"; outputPath=string(tempname)+".json"; cleanup=onCleanup(@()deleteTemporaryFiles(configPath,outputPath));
config=struct("benchmarkCase",benchmarkCase,"implementation",implementation,"repeatIndex",repeatIndex,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"buildDirectory",buildDirectory,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"threadCount",options.threadCount);
writeText(configPath,jsonencode(config));
statement="addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelReadinessWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
command=sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[exitCode,commandOutput]=system(command);
if exitCode~=0||~isfile(outputPath)
    run=emptyRun(); run.repeatIndex=repeatIndex; run.implementation=implementation; run.failure=struct("identifier","WaveVortexBenchmark:CompiledKernelWorkerFailed","message",string(commandOutput));
else
    decoded=jsondecode(fileread(outputPath));
    run=struct("repeatIndex",repeatIndex,"status",string(decoded.status),"implementation",string(decoded.implementation),"constructionSeconds",decoded.constructionSeconds,"firstCallSeconds",decoded.firstCallSeconds,"rawSeconds",decoded.rawSeconds(:)',"medianSeconds",decoded.medianSeconds,"relativeError",decoded.relativeError,"correctnessPassed",decoded.correctnessPassed,"ledger",decoded.ledger,"rss",decoded.rss,"metrics",decoded.metrics,"metadata",decoded.metadata,"lifecyclePassed",decoded.lifecyclePassed,"failure",decoded.failure);
end
clear cleanup
end

function result=aggregateBackend(implementation,runs)
complete=string({runs.status})=="complete";
processMedians=[runs.medianSeconds]; construction=[runs.constructionSeconds]; first=[runs.firstCallSeconds];
persistentValues=NaN(1,numel(runs)); peakValues=NaN(1,numel(runs));
for iRun=1:numel(runs), persistentValues(iRun)=runs(iRun).rss.persistentIncrementBytes; peakValues(iRun)=runs(iRun).rss.peakIncrementBytes; end
ledger=struct(); metrics=struct(); metadata=struct(); if any(complete), index=find(complete,1); ledger=runs(index).ledger; metrics=runs(index).metrics; metadata=runs(index).metadata; end
result=struct("id",implementation,"status",conditional(all(complete),"complete","partial"),"runs",runs,"constructionSeconds",construction,"medianConstructionSeconds",median(construction,"omitnan"),"firstCallSeconds",first,"medianFirstCallSeconds",median(first,"omitnan"),"processMedianSeconds",processMedians,"medianSeconds",median(processMedians,"omitnan"),"maximumRelativeError",max([runs.relativeError]),"correctnessPassed",all([runs.correctnessPassed]),"lifecyclePassed",all([runs.lifecyclePassed]),"ledger",ledger,"rss",struct("persistentIncrementBytes",persistentValues,"peakIncrementBytes",peakValues,"medianPersistentIncrementBytes",median(persistentValues,"omitnan"),"medianPeakIncrementBytes",median(peakValues,"omitnan")),"metrics",metrics,"metadata",metadata);
end

function result=aggregateCase(definition,backends)
builtin=backends(string({backends.id})=="builtin"); compiled=backends(string({backends.id})=="compiled"); speedup=builtin.medianSeconds/compiled.medianSeconds;
implementationExecuted=string(compiled.metadata.activeImplementation)=="compiled"&&~compiled.metadata.fallback;
storagePassed=compiled.ledger.persistentFullHermitianBytes==0&&isfinite(compiled.ledger.knownMaximumLiveBytes)&&compiled.ledger.knownMaximumLiveBytes>0;
passed=speedup>=1.25&&compiled.correctnessPassed&&compiled.lifecyclePassed&&implementationExecuted&&storagePassed;
result=struct("id",definition.id,"transformId",definition.transformId,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"status",conditional(all(string({backends.status})=="complete"),"complete","partial"),"backends",backends,"speedup",speedup,"implementationExecuted",implementationExecuted,"storagePassed",storagePassed,"thresholdPassed",passed);
end

function decision=readinessDecision(cases)
ready=all([cases.thresholdPassed])&&all(string({cases.status})=="complete");
if ready
    outcome="READY"; reason="All four core-v1 cases passed the fixed speed, correctness, storage, and lifecycle gates.";
else
    outcome="NOT READY"; failed=string({cases(~[cases.thresholdPassed]).id}); reason="The compiled kernel did not reach 1.25x on every case: "+strjoin(failed,", ")+".";
end
decision=struct("outcome",outcome,"ready",ready,"reason",reason,"speedThreshold",1.25,"correctnessTolerance",1e-12,"requiresNoPersistentFullHermitianSpectrum",true,"requiresBoundedScratch",true);
end

function [commit,tree,isDirty]=gitIdentity(root)
[~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree]=system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); [~,status]=system(sprintf('git -C "%s" status --porcelain',root)); commit=string(strtrim(commit)); tree=string(strtrim(tree)); isDirty=strlength(strtrim(string(status)))>0;
end

function record=environmentRecord(threads)
record=struct("os",string(system_dependent("getos")),"processor",string(system_dependent("getcpu")),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"threads",threads,"fftwLibrary",matlabBundledFFTWLibrary);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json"))); for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function writeText(pathname,contents)
fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end; cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteTemporaryFiles(varargin)
for iFile=1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value=conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end

function value=emptyRun()
value=struct("repeatIndex",0,"status","failed","implementation","","constructionSeconds",NaN,"firstCallSeconds",NaN,"rawSeconds",[],"medianSeconds",NaN,"relativeError",NaN,"correctnessPassed",false,"ledger",struct(),"rss",struct("persistentIncrementBytes",NaN,"peakIncrementBytes",NaN),"metrics",struct(),"metadata",struct(),"lifecyclePassed",false,"failure",struct("identifier","","message",""));
end

function value=emptyBackend()
value=struct("id","","status","failed","runs",repmat(emptyRun(),0,1),"constructionSeconds",[],"medianConstructionSeconds",NaN,"firstCallSeconds",[],"medianFirstCallSeconds",NaN,"processMedianSeconds",[],"medianSeconds",NaN,"maximumRelativeError",NaN,"correctnessPassed",false,"lifecyclePassed",false,"ledger",struct(),"rss",struct(),"metrics",struct(),"metadata",struct());
end

function value=emptyCase()
value=struct("id","","transformId","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",0,"warmupCount",0,"sampleCount",0,"status","failed","backends",repmat(emptyBackend(),0,1),"speedup",NaN,"implementationExecuted",false,"storagePassed",false,"thresholdPassed",false);
end

function markdown=summaryMarkdown(results)
lines=["# Compiled-kernel readiness";"";"- Status: `"+results.status+"`";"- Decision: **"+results.decision.outcome+"**";"- Reason: "+results.decision.reason;"";"| Case | MATLAB (ms) | Compiled (ms) | Speedup | Max error | Compiled persistent (MiB) | Compiled peak RSS (MiB) | Pass |";"|---|---:|---:|---:|---:|---:|---:|---:|"];
for item=results.suite.cases'
    builtin=item.backends(string({item.backends.id})=="builtin"); compiled=item.backends(string({item.backends.id})=="compiled");
    lines(end+1)=sprintf("| %s | %.3f | %.3f | %.3fx | %.3g | %.3f | %.3f | %s |",item.id,1e3*builtin.medianSeconds,1e3*compiled.medianSeconds,item.speedup,compiled.maximumRelativeError,compiled.ledger.knownPersistentBytes/2^20,compiled.rss.medianPeakIncrementBytes/2^20,string(item.thresholdPassed)); %#ok<AGROW>
end
markdown=join(lines,newline)+newline;
end
