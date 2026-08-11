function results = runCompiledKernelPhaseOnceBenchmark(options)
% Compare the phase-once nonlinear-flux schedule with its parent commit.
arguments
    options.baselineCommit (1,1) string = "199c9b8240a46fae8babbce413ee948ac4f89d38"
    options.caseIds (1,:) string = strings(1,0)
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.requireCleanCandidate (1,1) logical = false
end

benchmarkFolder=string(fileparts(mfilename("fullpath"))); repositoryRoot=string(fileparts(benchmarkFolder));
[candidateCommit,candidateTree,candidateDirty]=gitIdentity(repositoryRoot);
if options.requireCleanCandidate&&candidateDirty, error("WaveVortexBenchmark:DirtyPhaseOnceCandidate","The canonical phase-once benchmark requires a clean candidate commit."); end
baselineRoot=string(tempname); temporaryRoot=string(tempname); mkdir(temporaryRoot);
[status,output]=system(sprintf('git -C "%s" worktree add --detach "%s" "%s"',repositoryRoot,baselineRoot,options.baselineCommit));
if status~=0, rmdir(temporaryRoot,"s"); error("WaveVortexBenchmark:PhaseOnceBaselineCheckoutFailed","Unable to create the baseline worktree: %s",output); end
cleanup=onCleanup(@()removeTemporaryWorktree(repositoryRoot,baselineRoot,temporaryRoot));

cleanMatlabPath=benchmarkMatlabPath(repositoryRoot,baselineRoot);
baseline=runReadinessSnapshot(baselineRoot,"baseline",options,temporaryRoot,cleanMatlabPath);
candidate=runReadinessSnapshot(repositoryRoot,"phase-once",options,temporaryRoot,cleanMatlabPath);
cases=compareCases(baseline,candidate);
decision=compiledKernelPhaseOnceDecision(cases);
results=struct("schemaVersion","1.0.0","status",conditional(all(string({cases.status})=="complete"),"complete","partial"),"runId",options.runId, ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","baselineCommit",options.baselineCommit,"candidateCommit",candidateCommit,"candidateTree",candidateTree,"candidateDirty",candidateDirty), ...
    "configuration",struct("suiteId","core-v1","operation","ordinary nonlinearFlux","processRunCount",options.processRunCount,"warmupPolicy","core-v1","samplePolicy","7 medium / 3 large","speedThreshold",1.05,"maximumRegression",0.03,"correctnessTolerance",1e-12), ...
    "cases",cases,"decision",decision);
if options.outputDirectory=="", options.outputDirectory=fullfile(benchmarkFolder,"results","experiments","issue123",options.runId+"-"+computer("arch")+"-"+version("-release")); end
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"phase-once-benchmark.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear cleanup
end

function result=runReadinessSnapshot(sourceRoot,identifier,options,temporaryRoot,cleanMatlabPath)
outputDirectory=fullfile(temporaryRoot,identifier); if ~isfolder(outputDirectory), mkdir(outputDirectory); end
caseExpression="strings(1,0)"; if ~isempty(options.caseIds), caseExpression="["+strjoin(string(compose('"%s"',options.caseIds))," ")+"]"; end
statement="path('"+replace(cleanMatlabPath,"'","''")+"'); addpath('"+replace(fullfile(sourceRoot,"Benchmarks"),"'","''")+"'); runCompiledKernelReadinessBenchmark(caseIds="+caseExpression+",processRunCount="+options.processRunCount+",samplingIntervalSeconds="+options.samplingIntervalSeconds+",plateauSeconds="+options.plateauSeconds+",threadCount="+options.threadCount+",outputDirectory='"+replace(outputDirectory,"'","''")+"',runId='"+identifier+"');";
command=sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[status,output]=system(command);
artifact=fullfile(outputDirectory,"compiled-kernel-readiness.json");
if status~=0||~isfile(artifact), error("WaveVortexBenchmark:PhaseOnceSnapshotFailed","The %s snapshot benchmark failed: %s",identifier,output); end
result=jsondecode(fileread(artifact));
end

function cases=compareCases(baseline,candidate)
candidateCases=candidate.suite.cases; baselineCases=baseline.suite.cases;
cases=repmat(emptyCase(),numel(candidateCases),1);
for iCase=1:numel(candidateCases)
    candidateCase=candidateCases(iCase); baselineIndex=find(string({baselineCases.id})==string(candidateCase.id),1);
    if isempty(baselineIndex), error("WaveVortexBenchmark:MissingPhaseOnceBaselineCase","Baseline result is missing case %s.",candidateCase.id); end
    baselineCase=baselineCases(baselineIndex);
    baselineCompiled=backend(baselineCase,"compiled"); candidateCompiled=backend(candidateCase,"compiled"); builtin=backend(candidateCase,"builtin");
    speedup=baselineCompiled.medianSeconds/candidateCompiled.medianSeconds;
    exactStorageRatio=candidateCompiled.ledger.knownMaximumLiveBytes/baselineCompiled.ledger.knownMaximumLiveBytes;
    peakRSSRatio=candidateCompiled.rss.medianPeakIncrementBytes/baselineCompiled.rss.medianPeakIncrementBytes;
    metrics=candidateCompiled.metrics; expectedPhaseEvaluations=metrics.nonlinearFluxCallCount*metrics.Nj*metrics.Nkl;
    phaseCountPassed=metrics.nonlinearFluxCallCount>0&&metrics.nonlinearFluxPhaseEvaluationCount==expectedPhaseEvaluations&&metrics.phaseWorkspaceBytes==0&&string(metrics.nonlinearFluxSchedule)=="sequential-phase-once";
    correctnessPassed=candidateCompiled.maximumRelativeError<=1e-12&&candidateCompiled.correctnessPassed;
    noSpeedRegression=speedup>=1/1.03; noMemoryRegression=exactStorageRatio<=1&&peakRSSRatio<=1.03;
    cases(iCase)=struct("id",string(candidateCase.id),"Nxyz",candidateCase.Nxyz(:)',"isHydrostatic",candidateCase.isHydrostatic,"status",conditional(string(baselineCase.status)=="complete"&&string(candidateCase.status)=="complete","complete","partial"), ...
        "builtin",builtin,"baseline",baselineCompiled,"candidate",candidateCompiled,"speedup",speedup,"exactStorageRatio",exactStorageRatio,"peakRSSRatio",peakRSSRatio, ...
        "phaseCountPassed",phaseCountPassed,"correctnessPassed",correctnessPassed,"noSpeedRegression",noSpeedRegression,"noMemoryRegression",noMemoryRegression,"fivePercentSpeedPassed",speedup>=1.05);
end
end

function value=backend(caseResult,identifier)
index=find(string({caseResult.backends.id})==identifier,1); if isempty(index), error("WaveVortexBenchmark:MissingPhaseOnceBackend","Case %s is missing backend %s.",caseResult.id,identifier); end; value=caseResult.backends(index);
end

function markdown=summaryMarkdown(results)
lines=["# Compiled-kernel phase-once benchmark";"";"- Status: `"+results.status+"`";"- Decision: **"+results.decision.outcome+"**";"- Reason: "+results.decision.reason;"";"| Case | Baseline (ms) | Phase once (ms) | Speedup | Phase count | Live storage ratio | Peak RSS ratio |";"|---|---:|---:|---:|---:|---:|---:|"];
for item=results.cases'
    lines(end+1)=sprintf("| %s | %.3f | %.3f | %.3fx | %s | %.3f | %.3f |",item.id,1e3*item.baseline.medianSeconds,1e3*item.candidate.medianSeconds,item.speedup,string(item.phaseCountPassed),item.exactStorageRatio,item.peakRSSRatio); %#ok<AGROW>
end
markdown=join(lines,newline)+newline;
end

function value=benchmarkMatlabPath(repositoryRoot,baselineRoot)
entries=string(strsplit(path,pathsep)); normalized=lower(entries); selected=~contains(normalized,"wave-vortex-model")&~contains(normalized,"wavevortexmodel-")&~startsWith(entries,baselineRoot)&~startsWith(entries,repositoryRoot); value=strjoin(entries(selected),pathsep);
end

function [commit,tree,isDirty]=gitIdentity(root)
[~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree]=system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); [~,status]=system(sprintf('git -C "%s" status --porcelain',root)); commit=string(strtrim(commit)); tree=string(strtrim(tree)); isDirty=strlength(strtrim(string(status)))>0;
end

function removeTemporaryWorktree(repositoryRoot,baselineRoot,temporaryRoot)
system(sprintf('git -C "%s" worktree remove --force "%s"',repositoryRoot,baselineRoot));
if isfolder(temporaryRoot), rmdir(temporaryRoot,"s"); end
end

function writeText(pathname,contents)
fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end; cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function value=conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end

function value=emptyCase()
value=struct("id","","Nxyz",[],"isHydrostatic",false,"status","failed","builtin",struct(),"baseline",struct(),"candidate",struct(),"speedup",NaN,"exactStorageRatio",NaN,"peakRSSRatio",NaN,"phaseCountPassed",false,"correctnessPassed",false,"noSpeedRegression",false,"noMemoryRegression",false,"fivePercentSpeedPassed",false);
end
