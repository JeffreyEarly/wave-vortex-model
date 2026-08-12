function results = runCompiledKernelMemoryReassessmentBenchmark(options)
% Correct the issue #131 MATLAB/C++ memory comparison without rerunning timing.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65; 512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = 18
    options.providerCacheRoot (1,1) string = ""
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.005
    options.plateauSeconds (1,1) double {mustBePositive} = 0.10
    options.outputHoldSeconds (1,1) double {mustBePositive} = 0.03
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.injectWorkerFailure (1,1) logical = false
end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexModel:MemoryReassessmentUnsupportedPlatform","Issue #131 memory reassessment targets MATLAB R2026a on macOS maca64.");
end
repositoryRoot=string(fileparts(fileparts(mfilename("fullpath")))); benchmarkFolder=fullfile(repositoryRoot,"Benchmarks");
originalDirectory=pwd; originalPath=path; originalRng=rng; stateCleanup=onCleanup(@()restoreState(originalDirectory,originalPath,originalRng)); addRepositoryPaths(repositoryRoot,benchmarkFolder);
if options.outputDirectory=="", options.outputDirectory=fullfile(benchmarkFolder,"results","experiments","issue131-memory",options.runId+"-donut"); end
if options.shouldWriteArtifacts&&isfolder(options.outputDirectory), error("WaveVortexModel:MemoryReassessmentOutputExists","Output already exists: %s",options.outputDirectory); end
if options.shouldWriteArtifacts, mkdir(options.outputDirectory); end
temporaryRoot=string(tempname); mkdir(temporaryRoot); temporaryCleanup=onCleanup(@()removeDirectory(temporaryRoot));
results=initializeResult(options,repositoryRoot); activeStage="provider";
try
    cacheRoot=options.providerCacheRoot; if cacheRoot=="", cacheRoot=resolveProviderCache(repositoryRoot); end
    providerResult=buildCompiledKernelNativeFFTWProviders(providerIds="native-neon-pthreads",cacheRoot=cacheRoot,shouldBuildMex=false); provider=providerResult.providers(1);
    providerDescriptor=struct("id",provider.id,"version",provider.version,"threadBackend",provider.threadBackend,"includeDirectory",provider.includeDirectory,"linkLibraries",[provider.threadLibrary provider.baseLibrary],"rpathDirectories",string(fileparts(provider.baseLibrary)));
    module="wv_compiled_kernel_issue131_memory"; [mexPath,build]=buildCompiledKernelTransformMex(outputDirectory=fullfile(temporaryRoot,"mex"),outputName=module,provider=providerDescriptor);
    [dependencyStatus,dependencies]=system("/usr/bin/otool -L "+shellQuote(mexPath)); if dependencyStatus~=0, error("WaveVortexModel:MemoryModuleDependencies","Unable to inspect the corrected memory MEX module."); end
    moduleUsesOpenMP=contains(lower(string(dependencies)),"libomp"); if moduleUsesOpenMP, error("WaveVortexModel:MemoryUnexpectedOpenMP","The corrected memory MEX module links OpenMP."); end
    results.provider=provider; results.module=struct("name",module,"path",string(mexPath),"sha256",build.mexSha256,"dependencies",string(dependencies),"usesOpenMP",moduleUsesOpenMP,"kernelSourceSha256",sha256File(fullfile(repositoryRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp")),"gatewaySourceSha256",sha256File(fullfile(repositoryRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp")));
    if results.module.kernelSourceSha256~=results.priorEvidence.finalKernelSourceSha256 || results.module.gatewaySourceSha256~=results.priorEvidence.finalGatewaySourceSha256
        error("WaveVortexModel:MemorySourceMismatch","The corrected memory benchmark must use the exact final assembled kernel and gateway sources from the frozen issue #131 timing artifact.");
    end
    checkpoint(results,options);

    activeStage="workers"; cases=caseDefinitions(options); results.cases=cases; results.appliedFrozenSpeed=speedRecordsForCases(cases,results.priorEvidence); implementations=["matlab" "compiled"];
    for iRun=1:options.processRunCount
        caseOrder=mod((0:numel(cases)-1)+(iRun-1),numel(cases))+1;
        for iCase=caseOrder
            order=mod((0:1)+(iRun+iCase-2),2)+1;
            for iImplementation=order
                implementation=implementations(iImplementation); fprintf("Issue #131 memory: %s, %s, process %d/%d.\n",implementation,cases(iCase).id,iRun,options.processRunCount);
                results.runs(end+1,1)=runWorker(implementation,iRun,cases(iCase),module,mexPath,moduleUsesOpenMP,provider,options,repositoryRoot,benchmarkFolder);
                checkpoint(results,options);
            end
        end
    end
    failed=results.runs(string({results.runs.status})~="complete");
    if ~isempty(failed), messages=arrayfun(@(item)string(item.implementation)+"/"+string(item.case.id)+": "+string(item.failure.identifier)+" "+string(item.failure.message),failed); error("WaveVortexModel:MemoryWorkerResults","One or more corrected memory workers failed:%s%s",newline,strjoin(messages,newline)); end
    activeStage="aggregation"; results.comparison=comparisonRecords(results.runs,cases,provider); results.decision=compiledKernelMemoryReassessmentDecision(results.comparison,results.appliedFrozenSpeed);
    results.status="complete"; results.completedAtUTC=utcTimestamp; results.failure=emptyFailure; writeArtifacts(results,options);
catch exception
    results.status="failed"; results.completedAtUTC=utcTimestamp; results.failure=struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off"))); writeArtifacts(results,options); rethrow(exception)
end
clear temporaryCleanup stateCleanup
end

function results=initializeResult(options,repositoryRoot)
[commit,tree,isDirty]=gitIdentity(repositoryRoot); prior=priorEvidence;
results=struct("schemaVersion","1.0.0","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","environment",environmentRecord,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty),"configuration",struct("operation","ordinary nonlinearFlux memory only","processRunCount",options.processRunCount,"warmupCount",options.warmupCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"threadCount",options.threadCount,"provider","native-neon-pthreads","samplingIntervalSeconds",options.samplingIntervalSeconds,"rssBaseline","matched common WVT and canonical state","exactScope","active backend retained application arrays and three outputs; shared canonical state excluded","threshold",1.03),"priorEvidence",prior,"appliedFrozenSpeed",[],"provider",struct(),"module",struct(),"cases",[] ,"runs",repmat(emptyRun,0,1),"comparison",[] ,"decision",struct(),"failure",emptyFailure);
end

function value=priorEvidence
ids=["constant-hydrostatic-256x256x65" "constant-nonhydrostatic-256x256x65" "constant-hydrostatic-512x512x129" "constant-nonhydrostatic-512x512x129"];
speedups=[1.669052179108818 1.585524975008965 1.688342428573955 1.689585651215981];
errors=[9.362237910597108e-15 7.878016316190352e-15 2.5495729689559045e-14 1.621144261352762e-14];
records=repmat(struct("id","","compiledSpeedup",NaN,"maximumRelativeError",NaN),numel(ids),1); for i=1:numel(ids), records(i)=struct("id",ids(i),"compiledSpeedup",speedups(i),"maximumRelativeError",errors(i)); end
value=struct("artifactCommit","d023626b6182e382f842595e044c2b87143e0eaa","artifactJsonSha256","9bf05e1d295bfabaa847f9ecaa9d0b42872efa7ca04c824373ede8bc7983e24d","artifactURL","https://github.com/JeffreyEarly/wave-vortex-model/blob/experiment/issue-131-assembly-decision/Benchmarks/results/experiments/issue131/20260812T144707367Z-donut/compiled-kernel-assembly-decision.json","finalKernelSourceSha256","829ac01fa512b1b6dc224ec8178775b12dbec6ad0bc258414bab826b0b9c67c9","finalGatewaySourceSha256","e119b8466d2afed959c9868bfb8a7ff7f809206178efbd470e6a8a772a0cc084","authoritativeFields",["timing" "correctness" "provider identity" "lifecycle"],"supersededFields",["exact memory ratio" "peak RSS ratio" "integration decision"],"defects",["MATLAB exact ledger omitted nonlinearFlux caches and temporaries" "compiled RSS phase included subsequent MATLAB reference call while C++ storage remained resident"],"frozenSpeed",records);
end

function cases=caseDefinitions(options)
suite=waveVortexBenchmarkSuites("core-v1"); cases=repmat(struct("id","","Nxyz",[] ,"isHydrostatic",false,"shouldAntialias",true,"seed",0,"warmupCount",options.warmupCount,"sampleCount",0),0,1);
for iSize=1:size(options.sizes,1)
    for isHydrostatic=options.hydrostatic
        Nxyz=options.sizes(iSize,:); match=find(arrayfun(@(item)isequal(item.Nxyz,Nxyz)&&item.isHydrostatic==isHydrostatic,suite.cases),1); if isempty(match), seed=131500+sum(Nxyz)+100*isHydrostatic; else, seed=suite.cases(match).seed; end
        sampleCount=options.mediumSampleCount; if iSize==size(options.sizes,1)&&size(options.sizes,1)>1, sampleCount=options.largeSampleCount; end
        identifier=sprintf("constant-%s-%dx%dx%d",conditional(isHydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        cases(end+1,1)=struct("id",identifier,"Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"shouldAntialias",true,"seed",seed,"warmupCount",options.warmupCount,"sampleCount",sampleCount); %#ok<AGROW>
    end
end
end

function records=speedRecordsForCases(cases,prior)
records=repmat(struct("id","","compiledSpeedup",NaN,"maximumRelativeError",NaN,"source",""),numel(cases),1);
for iCase=1:numel(cases)
    match=find(string({prior.frozenSpeed.id})==string(cases(iCase).id),1);
    if isempty(match)
        records(iCase)=struct("id",string(cases(iCase).id),"compiledSpeedup",1.25,"maximumRelativeError",0,"source","threshold substitute for reduced noncanonical test case");
    else
        records(iCase)=struct("id",string(cases(iCase).id),"compiledSpeedup",prior.frozenSpeed(match).compiledSpeedup,"maximumRelativeError",prior.frozenSpeed(match).maximumRelativeError,"source","frozen issue #131 artifact d023626");
    end
end
end

function run=runWorker(implementation,repeatIndex,definition,module,mexPath,moduleUsesOpenMP,provider,options,repositoryRoot,benchmarkFolder)
config=struct("implementation",implementation,"sourceCommit",gitValue(repositoryRoot,"rev-parse HEAD"),"repeatIndex",repeatIndex,"caseDefinition",definition,"module",module,"moduleDirectory",string(fileparts(mexPath)),"moduleUsesOpenMP",moduleUsesOpenMP,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"threadCount",options.threadCount,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds,"outputHoldSeconds",options.outputHoldSeconds);
configPath=string(tempname)+".json"; outputPath=string(tempname)+".json"; cleanup=onCleanup(@()deleteTemporaryFiles(configPath,outputPath)); writeText(configPath,jsonencode(config));
if options.injectWorkerFailure, configPath=configPath+".missing"; end
statement="addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelMemoryReassessmentWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
command=sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"')); [exitCode,commandOutput]=system(command);
if exitCode~=0||~isfile(outputPath), run=emptyRun; run.implementation=implementation; run.sourceCommit=config.sourceCommit; run.repeatIndex=repeatIndex; run.case=definition; run.failure=struct("identifier","WaveVortexModel:MemoryWorkerFailed","message",string(commandOutput),"report",string(commandOutput)); else, run=normalizeRun(jsondecode(fileread(outputPath))); end
clear cleanup
end

function run=normalizeRun(value)
run=struct("schemaVersion",string(value.schemaVersion),"status",string(value.status),"implementation",string(value.implementation),"sourceCommit",string(value.sourceCommit),"repeatIndex",value.repeatIndex,"case",value.case,"module",string(value.module),"moduleInfo",value.moduleInfo,"planningSeconds",value.planningSeconds,"referenceCallCount",value.referenceCallCount,"sampledOperation",string(value.sampledOperation),"ledger",value.ledger,"metrics",value.metrics,"metadata",value.metadata,"rss",value.rss,"rssSamples",value.rssSamples,"lifecyclePassed",value.lifecyclePassed,"moduleAfterDelete",value.moduleAfterDelete,"failure",value.failure);
end

function comparison=comparisonRecords(runs,cases,provider)
comparison=repmat(struct("id","","Nxyz",[] ,"isHydrostatic",false,"status","failed","matlabExactRetainedBytes",NaN,"compiledExactRetainedBytes",NaN,"exactRetainedRatio",NaN,"matlabOperationPeakIncrementRSSBytes",NaN,"compiledOperationPeakIncrementRSSBytes",NaN,"operationPeakRSSRatio",NaN,"matlabProcessExactRetainedBytes",[] ,"compiledProcessExactRetainedBytes",[] ,"matlabProcessPeakIncrementRSSBytes",[] ,"compiledProcessPeakIncrementRSSBytes",[] ,"libraryIdentityPassed",false,"nativeExecutionPassed",false,"noFallback",false,"planCount",NaN,"persistentFullHermitianBytes",NaN,"referenceCallsDuringSampling",NaN),numel(cases),1);
for iCase=1:numel(cases)
    selected=runs(string(arrayfun(@(item)item.case.id,runs,"UniformOutput",false))==cases(iCase).id); matlab=selected(string({selected.implementation})=="matlab"); compiled=selected(string({selected.implementation})=="compiled");
    matlabExact=arrayfun(@(item)item.ledger.exactRetainedApplicationBytes,matlab); compiledExact=arrayfun(@(item)item.ledger.exactRetainedApplicationBytes,compiled); matlabRSS=arrayfun(@(item)item.rss.operationPeakIncrementBytes,matlab); compiledRSS=arrayfun(@(item)item.rss.operationPeakIncrementBytes,compiled);
    metadata=compiled(1).metadata; metrics=compiled(1).metrics; identity=all(arrayfun(@(item)string(item.moduleInfo.baseLibrary)==provider.baseLibrary&&string(item.moduleInfo.threadLibrary)==provider.threadLibrary,compiled));
    comparison(iCase)=struct("id",string(cases(iCase).id),"Nxyz",cases(iCase).Nxyz,"isHydrostatic",cases(iCase).isHydrostatic,"status",conditional(all(string({selected.status})=="complete"),"complete","failed"),"matlabExactRetainedBytes",median(matlabExact),"compiledExactRetainedBytes",median(compiledExact),"exactRetainedRatio",median(compiledExact./matlabExact),"matlabOperationPeakIncrementRSSBytes",median(matlabRSS),"compiledOperationPeakIncrementRSSBytes",median(compiledRSS),"operationPeakRSSRatio",median(compiledRSS./matlabRSS),"matlabProcessExactRetainedBytes",matlabExact,"compiledProcessExactRetainedBytes",compiledExact,"matlabProcessPeakIncrementRSSBytes",matlabRSS,"compiledProcessPeakIncrementRSSBytes",compiledRSS,"libraryIdentityPassed",identity,"nativeExecutionPassed",string(metadata.engine)=="fftw","noFallback",~metadata.fallback,"planCount",metrics.planCount,"persistentFullHermitianBytes",metrics.persistentFullHermitianBytes,"referenceCallsDuringSampling",sum([selected.referenceCallCount]));
end
end

function writeArtifacts(results,options)
if ~options.shouldWriteArtifacts, return, end; writeText(fullfile(options.outputDirectory,"memory-reassessment.json"),jsonencode(results,PrettyPrint=true)); writeText(fullfile(options.outputDirectory,"summary.md"),markdownSummary(results));
end
function checkpoint(results,options)
if options.shouldWriteArtifacts, writeArtifacts(results,options); end
end
function value=markdownSummary(results)
lines=["# Issue #131 corrected memory reassessment";"";"- Status: `"+results.status+"`";"- Core: `"+fieldOr(results.decision,"coreStatus","pending")+"`";"- Memory: `"+fieldOr(results.decision,"memoryStatus","pending")+"`";"- Integration: `"+fieldOr(results.decision,"integrationStatus","provisional")+"`";"- Frozen speed evidence: artifact `d023626`, JSON SHA-256 `9bf05e1d...`";"";"The prior artifact's timing, correctness, provider, and lifecycle fields remain authoritative. Its memory fields and integration decision are superseded.";"";"## Corrected comparison";"";"| Case | MATLAB retained (MiB) | C++ retained (MiB) | Retained ratio | MATLAB peak RSS (MiB) | C++ peak RSS (MiB) | RSS ratio | Frozen speedup |";"|---|---:|---:|---:|---:|---:|---:|---:|"];
if ~isempty(results.comparison)
    for item=results.comparison'
        speed=results.appliedFrozenSpeed(string({results.appliedFrozenSpeed.id})==item.id).compiledSpeedup;
        lines(end+1)="| "+item.id+" | "+sprintf('%.3f',item.matlabExactRetainedBytes/2^20)+" | "+sprintf('%.3f',item.compiledExactRetainedBytes/2^20)+" | "+sprintf('%.3f',item.exactRetainedRatio)+" | "+sprintf('%.3f',item.matlabOperationPeakIncrementRSSBytes/2^20)+" | "+sprintf('%.3f',item.compiledOperationPeakIncrementRSSBytes/2^20)+" | "+sprintf('%.3f',item.operationPeakRSSRatio)+" | "+sprintf('%.3fx',speed)+" |"; %#ok<AGROW>
    end
end
lines=[lines;"";"## Accounting correction";"";"- Each backend/case/repeat ran in a separate fresh process.";"- No sampled process invoked the other backend or a correctness reference.";"- Exact retained bytes include reachable application arrays; unobservable MATLAB temporaries and FFT plan storage remain opaque and are covered by operation-only RSS."];
if isfield(results,"failure")&&string(results.failure.identifier)~="", lines=[lines;"";"## Failure";"";"- Stage: `"+results.failure.stage+"`";"- `"+results.failure.identifier+"`: "+results.failure.message]; end
value=join(lines,newline)+newline;
end

function value=fieldOr(record,name,fallback)
if isstruct(record)&&isfield(record,name), value=string(record.(name)); else, value=fallback; end
end
function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json"))); for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end
function cacheRoot=resolveProviderCache(repositoryRoot)
candidates=[fullfile(repositoryRoot,".fftw-cache","issue137"),fullfile(fileparts(repositoryRoot),"wave-vortex-model-issue-137",".fftw-cache","issue137")]; for candidate=candidates, if isfile(fullfile(candidate,"downloads","fftw-3.3.11.tar.gz")), cacheRoot=candidate; return, end, end; error("WaveVortexModel:MemoryProviderCache","The pinned #137 provider cache is unavailable.");
end
function [commit,tree,isDirty]=gitIdentity(root)
commit=gitValue(root,"rev-parse HEAD"); tree=gitValue(root,"rev-parse HEAD^{tree}"); [~,output]=system("git -C "+shellQuote(root)+" status --porcelain --untracked-files=no"); isDirty=strlength(strtrim(string(output)))>0;
end
function value=gitValue(root,arguments)
[status,output]=system("git -C "+shellQuote(root)+" "+arguments); if status~=0, error("WaveVortexModel:MemoryGit","Git command failed: %s",output); end; value=string(strtrim(output));
end
function value=environmentRecord
value=struct("host",string(getenv("HOSTNAME")),"matlabVersion",string(version),"release",string(version("-release")),"architecture",string(computer("arch")),"platform",string(computer));
end
function hash=sha256File(pathname)
[status,output]=system("/usr/bin/shasum -a 256 "+shellQuote(pathname)); if status~=0, error("WaveVortexModel:HashFailure","Unable to hash %s",pathname); end; hash=extractBefore(string(strtrim(output))," ");
end
function quoted=shellQuote(value)
quoted="'"+replace(string(value),"'","'""'""'")+"'";
end
function writeText(pathname,value)
fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexModel:ArtifactWriteFailed","Unable to write %s",pathname); end; cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end
function deleteTemporaryFiles(varargin)
for iFile=1:numel(varargin), if isfile(varargin{iFile}), delete(varargin{iFile}); end, end
end
function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end
function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end
function value=conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end
function value=utcTimestamp
value=string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end
function value=emptyFailure
value=struct("stage","","identifier","","message","","report","");
end
function value=emptyRun
value=struct("schemaVersion","1.0.0","status","failed","implementation","","sourceCommit","","repeatIndex",0,"case",struct(),"module","","moduleInfo",struct(),"planningSeconds",NaN,"referenceCallCount",0,"sampledOperation","","ledger",struct(),"metrics",struct(),"metadata",struct(),"rss",struct(),"rssSamples",struct(),"lifecyclePassed",false,"moduleAfterDelete",struct(),"failure",struct("identifier","","message","","report",""));
end
