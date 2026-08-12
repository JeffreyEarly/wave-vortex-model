function results = runCompiledKernelAssemblyDecisionBenchmark(options)
% Assemble the adopted core and make the issue #131 MATLAB-integration decision.
arguments
    options.references (1,:) string = ["52de161" "be0f789" "3af6b83" "HEAD"]
    options.implementationIds (1,:) string = ["original-compiled" "native-foundation" "preceding-adopted" "final-assembled"]
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65; 512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.processRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = 18
    options.providerCacheRoot (1,1) string = ""
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.12
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmssSSS'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end
if numel(options.references) ~= numel(options.implementationIds), error("WaveVortexModel:AssemblyReferences","references and implementationIds must have the same length."); end
if ~ismac || string(computer("arch")) ~= "maca64" || ~startsWith(string(version("-release")),"2026a",IgnoreCase=true)
    error("WaveVortexModel:AssemblyUnsupportedPlatform","Issue #131 targets MATLAB R2026a on macOS maca64.");
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath")))); benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd; originalPath = path; originalRng = rng; stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
if options.outputDirectory == "", options.outputDirectory = fullfile(benchmarkFolder,"results","experiments","issue131",options.runId+"-donut"); end
if options.shouldWriteArtifacts && isfolder(options.outputDirectory), error("WaveVortexModel:AssemblyOutputExists","Output already exists: %s",options.outputDirectory); end
if options.shouldWriteArtifacts, mkdir(options.outputDirectory); end
temporaryRoot = string(tempname); mkdir(temporaryRoot); temporaryCleanup = onCleanup(@()removeDirectory(temporaryRoot));
results = initializeResult(options,repositoryRoot); activeStage = "provider";
try
    providerCacheRoot=options.providerCacheRoot; if providerCacheRoot=="", providerCacheRoot=resolveProviderCache(repositoryRoot); end
    providerResult = buildCompiledKernelNativeFFTWProviders(providerIds="native-neon-pthreads",cacheRoot=providerCacheRoot,shouldBuildMex=false);
    provider = providerResult.providers(1); results.provider = provider;
    if provider.threadBackend ~= "pthreads" || options.threadCount ~= 18, error("WaveVortexModel:AssemblyProvider","The canonical run requires native-neon-pthreads with 18 threads."); end
    activeStage = "snapshots";
    snapshots = prepareSnapshots(repositoryRoot,temporaryRoot,options.references,options.implementationIds,provider);
    results.snapshots = snapshots; checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);
    activeStage = "benchmark"; cases = caseDefinitions(options); results.cases = cases;
    implementations = ["matlab" options.implementationIds];
    for iRun = 1:options.processRunCount
        caseOrder=mod((0:numel(cases)-1)+(iRun-1),numel(cases))+1;
        for iCase=caseOrder
            order = mod((0:numel(implementations)-1)+(iRun+iCase-2),numel(implementations))+1;
            for iImplementation = order
                implementation = implementations(iImplementation);
                fprintf("Issue #131: %s, %s, process %d/%d.\n",implementation,cases(iCase).id,iRun,options.processRunCount);
                results.runs(end+1,1) = runWorker(implementation,iRun,cases(iCase),snapshots,provider,options,repositoryRoot,benchmarkFolder);
                checkpoint(results,options.outputDirectory,options.shouldWriteArtifacts);
            end
        end
    end
    failedRuns=results.runs(string({results.runs.status})~="complete");
    if ~isempty(failedRuns)
        messages=arrayfun(@(item)string(item.implementation)+": "+string(item.failure.identifier)+" "+string(item.failure.message),failedRuns);
        error("WaveVortexModel:AssemblyWorkerResults","One or more assembly workers failed:%s%s",newline,strjoin(messages,newline));
    end
    activeStage = "aggregation";
    results.implementations = aggregateRuns(results.runs,implementations,cases);
    results.comparison = comparisonRecords(results.implementations,cases,options.implementationIds(end),provider);
    results.decision = compiledKernelAssemblyDecision(results.comparison);
    results.status = conditional(all(string({results.runs.status})=="complete") && results.decision.coreComplete,"complete","failed");
    results.completedAtUTC = utcTimestamp; results.failure = emptyFailure;
    writeArtifacts(results,options.outputDirectory,options.shouldWriteArtifacts);
catch exception
    results.status="failed"; results.completedAtUTC=utcTimestamp; results.failure=struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
    writeArtifacts(results,options.outputDirectory,options.shouldWriteArtifacts); rethrow(exception)
end
clear temporaryCleanup stateCleanup
end

function results = initializeResult(options,repositoryRoot)
[commit,tree,isDirty] = gitIdentity(repositoryRoot);
results = struct("schemaVersion","1.0.0","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","environment",environmentRecord,"source",struct("repository","JeffreyEarly/wave-vortex-model","candidateCommit",commit,"candidateTree",tree,"isDirty",isDirty),"configuration",struct("suite","core-v1","operation","ordinary nonlinearFlux","references",options.references,"implementationIds",options.implementationIds,"processRunCount",options.processRunCount,"warmupCount",options.warmupCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"threadCount",options.threadCount,"provider","native-neon-pthreads","planner","FFTW_MEASURE | FFTW_UNALIGNED","samplingIntervalSeconds",options.samplingIntervalSeconds,"comparisonMemoryScope","exclude shared canonical inputs; include three flux outputs and exact backend-owned storage; opaque FFT/plan memory through RSS","correctnessTolerance",1e-12),"provider",struct(),"snapshots",repmat(emptySnapshot,0,1),"cases",[],"runs",repmat(emptyRun,0,1),"implementations",[],"comparison",[],"stageCorrespondence",stageCorrespondence,"decision",struct(),"failure",emptyFailure);
end

function cases = caseDefinitions(options)
suite = waveVortexBenchmarkSuites("core-v1");
cases = repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"shouldAntialias",true,"seed",0,"warmupCount",options.warmupCount,"sampleCount",0),0,1);
for iSize=1:size(options.sizes,1)
    for isHydrostatic=options.hydrostatic
        Nxyz=options.sizes(iSize,:); match=find(arrayfun(@(item)isequal(item.Nxyz,Nxyz)&&item.isHydrostatic==isHydrostatic,suite.cases),1);
        if isempty(match), seed=131000+sum(Nxyz)+100*isHydrostatic; else, seed=suite.cases(match).seed; end
        sampleCount=options.mediumSampleCount; if iSize==size(options.sizes,1)&&size(options.sizes,1)>1, sampleCount=options.largeSampleCount; end
        identifier=sprintf("constant-%s-%dx%dx%d",conditional(isHydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        cases(end+1,1)=struct("id",identifier,"Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"shouldAntialias",true,"seed",seed,"warmupCount",options.warmupCount,"sampleCount",sampleCount); %#ok<AGROW>
    end
end
end

function snapshots = prepareSnapshots(repositoryRoot,temporaryRoot,references,ids,provider)
snapshots = repmat(emptySnapshot,numel(references),1);
for iReference=1:numel(references)
    commit = gitValue(repositoryRoot,"rev-parse "+references(iReference)); tree=gitValue(repositoryRoot,"rev-parse "+commit+"^{tree}"); sourceRoot=fullfile(temporaryRoot,ids(iReference)+"-"+extractBefore(commit,9)); mkdir(sourceRoot);
    command="git -C "+shellQuote(repositoryRoot)+" archive "+commit+" | /usr/bin/tar -x -C "+shellQuote(sourceRoot);
    [status,output]=system(command); if status~=0, error("WaveVortexModel:AssemblySnapshot","Unable to archive %s: %s",commit,output); end
    instrumentationOverlay="none";
    if startsWith(commit,"52de161"), addHistoricalInstrumentation(sourceRoot); instrumentationOverlay="issue131-timing-and-dladdr-only"; end
    module="wv_compiled_kernel_issue131_"+replace(ids(iReference),"-","_"); outputDirectory=fullfile(temporaryRoot,"mex",ids(iReference));
    [mexPath,mexHash]=buildSnapshotMex(sourceRoot,outputDirectory,module,provider);
    [dependencyStatus,moduleDependencies]=system("/usr/bin/otool -L "+shellQuote(mexPath)); if dependencyStatus~=0, error("WaveVortexModel:AssemblyModuleDependencies","Unable to inspect %s.",mexPath); end
    moduleUsesOpenMP=contains(lower(string(moduleDependencies)),"libomp");
    snapshots(iReference)=struct("id",ids(iReference),"requestedReference",references(iReference),"commit",commit,"tree",tree,"sourceRoot",sourceRoot,"module",module,"mexPath",mexPath,"mexSha256",mexHash,"kernelSha256",sha256File(fullfile(sourceRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp")),"gatewaySha256",sha256File(fullfile(sourceRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp")),"instrumentationOverlay",instrumentationOverlay,"moduleDependencies",string(moduleDependencies),"moduleUsesOpenMP",moduleUsesOpenMP);
end
end

function addHistoricalInstrumentation(sourceRoot)
gateway=fullfile(sourceRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp"); engineDirectory=fullfile(sourceRoot,"Benchmarks","compiled-kernel");
% The be0f789 engine adds only planning counters and dladdr identity support.
root=fileparts(fileparts(mfilename("fullpath")));
writeGitFile(root,"be0f789:Benchmarks/compiled-kernel/WVFFTWEngine.hpp",fullfile(engineDirectory,"WVFFTWEngine.hpp"));
writeGitFile(root,"be0f789:Benchmarks/compiled-kernel/WVFFTWEngine.cpp",fullfile(engineDirectory,"WVFFTWEngine.cpp"));
text=string(fileread(gateway)); text=replaceOnce(text,"#include <cstdint>","#include <cstdint>"+newline+"#include <chrono>");
anchor="class InjectedFailureEngine final : public WVFFTEngine {";
helper=join([ ...
    "std::string arbitraryLengthStringInput(const mxArray* value, const char* name) {" ...
    "    if (!mxIsChar(value)) fail(""WaveVortexModel:CompiledKernelCommand"",std::string(name) + "" must be a character vector."");" ...
    "    char* buffer = mxArrayToString(value);" ...
    "    if (buffer == nullptr) fail(""WaveVortexModel:CompiledKernelCommand"",std::string(""Unable to read "") + name + '.');" ...
    "    std::string result(buffer); mxFree(buffer); return result;" ...
    "}"],newline)+newline+newline;
text=replaceOnce(text,anchor,helper+anchor);
anchor="void cleanup() { kernels.clear(); }"+newline;
helper=join([ ...
    "mxArray* scalarString(const std::string& value) { return mxCreateString(value.c_str()); }" ...
    "mxArray* moduleInfo(const std::string& expectedOpenMPRuntime) {" ...
    "    const char* names[] = {""engine"",""version"",""baseLibrary"",""threadLibrary"",""openMPRuntimeLibrary""};" ...
    "    mxArray* result = mxCreateStructMatrix(1,1,5,names); const auto identity = WVFFTWEngine::linkedLibraries(expectedOpenMPRuntime);" ...
    "    mxSetField(result,0,""engine"",mxCreateString(""fftw"")); mxSetField(result,0,""version"",scalarString(identity.version));" ...
    "    mxSetField(result,0,""baseLibrary"",scalarString(identity.baseLibrary)); mxSetField(result,0,""threadLibrary"",scalarString(identity.threadLibrary)); mxSetField(result,0,""openMPRuntimeLibrary"",scalarString(identity.openMPRuntimeLibrary)); return result;" ...
    "}"],newline)+newline;
text=replaceOnce(text,anchor,anchor+helper);
anchor="    if (command == ""moduleMetrics"") {";
command=join([ ...
    "    if (command == ""moduleInfo"") {" ...
    "        if ((nrhs != 1 && nrhs != 2) || nlhs != 1) fail(""WaveVortexModel:CompiledKernelCommand"",""moduleInfo accepts an optional expected OpenMP runtime path."");" ...
    "        plhs[0] = moduleInfo(nrhs == 2 ? arbitraryLengthStringInput(prhs[1],""Expected OpenMP runtime"") : std::string{}); return;" ...
    "    }"],newline)+newline;
text=replaceOnce(text,anchor,command+anchor);
old="    if (command == ""nonlinearFlux"") {"+newline+"        if (nrhs != 7 || nlhs != 3) fail(""WaveVortexModel:CompiledKernelCommand"",""nonlinearFlux requires handle, Ap, Am, A0, t, and t0 and returns Fp, Fm, F0."");";
new="    if (command == ""nonlinearFlux"" || command == ""nonlinearFluxTimed"") {"+newline+"        const bool timed = command == ""nonlinearFluxTimed"";"+newline+"        if (nrhs != 7 || nlhs != (timed ? 4 : 3)) fail(""WaveVortexModel:CompiledKernelCommand"",""nonlinearFlux requires handle, Ap, Am, A0, t, and t0 and returns Fp, Fm, F0."");";
text=replaceOnce(text,old,new);
old="        requireStatus(value.nonlinearFlux(state,flux));"+newline+"        return;";
new="        const auto start = std::chrono::steady_clock::now();"+newline+"        requireStatus(value.nonlinearFlux(state,flux));"+newline+"        if (timed) plhs[3] = mxCreateDoubleScalar(std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count());"+newline+"        return;";
text=replaceOnce(text,old,new); writeText(gateway,text);
end

function [mexPath,mexHash] = buildSnapshotMex(sourceRoot,outputDirectory,module,provider)
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
sourceDirectory=fullfile(sourceRoot,"CompiledKernel","src"); includeDirectory=fullfile(sourceRoot,"CompiledKernel","include"); gatewayDirectory=fullfile(sourceRoot,"Benchmarks","compiled-kernel");
compilerFlags="CXXFLAGS=$CXXFLAGS -std=c++17 -pthread -O3 -mcpu=native -DWV_KERNEL_NATIVE_OPTIMIZATION=1 -DWV_KERNEL_COEFFICIENT_WORKERS=2";
rpathDirectories=unique([string(fileparts(provider.threadLibrary)) string(fileparts(provider.baseLibrary))],"stable");
linkerFlags="LDFLAGS=$LDFLAGS -pthread -Wl,-rpath,"+join(rpathDirectories," -Wl,-rpath,");
mex("-R2018a",compilerFlags,fullfile(gatewayDirectory,"wv_compiled_transform_mex.cpp"),fullfile(sourceDirectory,"WVKernelTypes.cpp"),fullfile(sourceDirectory,"WVTransformConstantStratificationKernel.cpp"),fullfile(gatewayDirectory,"WVFFTWEngine.cpp"),"-I"+includeDirectory,"-I"+gatewayDirectory,"-I"+provider.includeDirectory,linkerFlags,provider.threadLibrary,provider.baseLibrary,"-outdir",outputDirectory,"-output",module);
mexPath=string(fullfile(outputDirectory,module+"."+mexext)); mexHash=sha256File(mexPath);
end

function run = runWorker(implementation,repeatIndex,cases,snapshots,provider,options,repositoryRoot,benchmarkFolder)
snapshot=emptySnapshot; module=""; moduleDirectory=""; sourceCommit=gitValue(repositoryRoot,"rev-parse HEAD");
if implementation~="matlab", snapshot=snapshots(string({snapshots.id})==implementation); module=snapshot.module; moduleDirectory=fileparts(snapshot.mexPath); sourceCommit=snapshot.commit; end
moduleUsesOpenMP=false; if implementation~="matlab", moduleUsesOpenMP=snapshot.moduleUsesOpenMP; end
config=struct("implementation",implementation,"sourceCommit",sourceCommit,"repeatIndex",repeatIndex,"module",module,"moduleDirectory",moduleDirectory,"moduleUsesOpenMP",moduleUsesOpenMP,"baseLibrary",provider.baseLibrary,"threadLibrary",provider.threadLibrary,"threadCount",options.threadCount,"cases",cases,"repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds);
configPath=string(tempname)+".json"; outputPath=string(tempname)+".json"; cleanup=onCleanup(@()deleteTemporaryFiles(configPath,outputPath)); writeText(configPath,jsonencode(config));
statement="addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelAssemblyDecisionWorker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
command=sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"')); [exitCode,commandOutput]=system(command);
if exitCode~=0||~isfile(outputPath), run=emptyRun; run.implementation=implementation; run.sourceCommit=sourceCommit; run.repeatIndex=repeatIndex; run.failure=struct("identifier","WaveVortexModel:AssemblyWorkerFailed","message",string(commandOutput),"report",string(commandOutput)); else, run=normalizeRun(jsondecode(fileread(outputPath))); end
clear cleanup
end

function run=normalizeRun(value)
run=struct("schemaVersion",string(value.schemaVersion),"status",string(value.status),"implementation",string(value.implementation),"sourceCommit",string(value.sourceCommit),"repeatIndex",value.repeatIndex,"module",string(value.module),"moduleInfo",value.moduleInfo,"cases",value.cases,"rss",value.rss,"moduleClearSeconds",value.moduleClearSeconds,"failure",value.failure);
end

function implementations=aggregateRuns(runs,ids,cases)
implementations=repmat(struct("id","","status","failed","sourceCommit","","runs",[],"cases",[]),numel(ids),1);
for iId=1:numel(ids)
    selected=runs(string({runs.implementation})==ids(iId)); aggregated=repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"processCompleteMexMedianSeconds",[],"completeMexMedianSeconds",NaN,"processNativeInternalMedianSeconds",[],"nativeInternalMedianSeconds",NaN,"processPeakIncrementRSSBytes",[],"peakIncrementRSSBytes",NaN,"maximumRelativeError",NaN,"ledger",struct(),"metadata",struct(),"stageMetrics",struct(),"lifecyclePassed",false),numel(cases),1);
    for iCase=1:numel(cases)
        caseRuns=selected(arrayfun(@(run)any(string({run.cases.id})==string(cases(iCase).id)),selected)); records=[caseRuns.cases];
        complete=[records.completeMexMedianSeconds]; internal=[records.nativeInternalMedianSeconds]; rss=arrayfun(@(item)item.rss.peakIncrementBytes,records);
        aggregated(iCase)=struct("id",string(cases(iCase).id),"Nxyz",cases(iCase).Nxyz,"isHydrostatic",cases(iCase).isHydrostatic,"processCompleteMexMedianSeconds",complete,"completeMexMedianSeconds",median(complete),"processNativeInternalMedianSeconds",internal,"nativeInternalMedianSeconds",median(internal,"omitnan"),"processPeakIncrementRSSBytes",rss,"peakIncrementRSSBytes",median(rss,"omitnan"),"maximumRelativeError",max([records.relativeError]),"ledger",records(1).ledger,"metadata",records(1).metadata,"stageMetrics",records(1).stageMetrics,"lifecyclePassed",all([records.lifecyclePassed]));
    end
    implementations(iId)=struct("id",ids(iId),"status",conditional(all(string({selected.status})=="complete"),"complete","failed"),"sourceCommit",string(selected(1).sourceCommit),"runs",selected,"cases",aggregated);
end
end

function comparison=comparisonRecords(implementations,cases,finalId,provider)
matlab=implementations(string({implementations.id})=="matlab"); final=implementations(string({implementations.id})==finalId); comparison=struct([]);
for iCase=1:numel(cases)
    m=matlab.cases(iCase); c=final.cases(iCase); identity=string(c.metadata.loadedBaseLibrary)==provider.baseLibrary && string(c.metadata.loadedThreadLibrary)==provider.threadLibrary;
    record=struct("id",c.id,"Nxyz",c.Nxyz,"isHydrostatic",c.isHydrostatic,"status",conditional(matlab.status=="complete"&&final.status=="complete","complete","failed"),"matlabSeconds",m.completeMexMedianSeconds,"compiledMexSeconds",c.completeMexMedianSeconds,"compiledNativeSeconds",c.nativeInternalMedianSeconds,"compiledSpeedup",m.completeMexMedianSeconds/c.completeMexMedianSeconds,"boundaryResidualSeconds",c.completeMexMedianSeconds-c.nativeInternalMedianSeconds,"matlabExactMaximumLiveBytes",m.ledger.comparableMaximumLiveBytes,"compiledExactMaximumLiveBytes",c.ledger.comparableMaximumLiveBytes,"exactMemoryRatio",c.ledger.comparableMaximumLiveBytes/m.ledger.comparableMaximumLiveBytes,"matlabPeakIncrementRSSBytes",m.peakIncrementRSSBytes,"compiledPeakIncrementRSSBytes",c.peakIncrementRSSBytes,"peakRSSRatio",c.peakIncrementRSSBytes/m.peakIncrementRSSBytes,"maximumRelativeError",c.maximumRelativeError,"lifecyclePassed",c.lifecyclePassed,"libraryIdentityPassed",identity,"nativeExecutionPassed",string(c.metadata.engine)=="fftw","noFallback",~c.metadata.fallback,"persistentFullHermitianBytes",c.ledger.persistentFullHermitianBytes);
    if iCase==1, comparison=record; else, comparison(end+1,1)=record; end %#ok<AGROW>
end
end

function value=stageCorrespondence
value=[struct("cppStage","phase","matlabOperation","evolve Ap and Am to time t");struct("cppStage","WV-to-field spectral assembly","matlabOperation","transformWaveVortexToUVWEta coefficient assembly");struct("cppStage","fields and derivatives","matlabOperation","F/G spatial reconstruction and derivatives");struct("cppStage","nonlinear products","matlabOperation","ordinary nonlinear advection products");struct("cppStage","field-to-WV projection","matlabOperation","transformUVEtaToWaveVortex or transformUVWEtaToWaveVortex")];
end

function writeArtifacts(results,outputDirectory,shouldWrite)
if ~shouldWrite, return, end; writeText(fullfile(outputDirectory,"compiled-kernel-assembly-decision.json"),jsonencode(results,PrettyPrint=true)); writeText(fullfile(outputDirectory,"summary.md"),markdownSummary(results));
end
function checkpoint(results,outputDirectory,shouldWrite)
if shouldWrite, writeArtifacts(results,outputDirectory,true); end
end
function text=markdownSummary(results)
lines=["# Compiled-kernel assembly decision";"";"- Status: `"+string(results.status)+"`";"- Core: `"+fieldOr(results.decision,"coreStatus","pending")+"`";"- Integration: `"+fieldOr(results.decision,"integrationStatus","pending")+"`";"- Provider: native FFTW 3.3.11 NEON/pthreads, 18 threads";"";"## Final MATLAB comparison";"";"| Case | MATLAB (ms) | C++ MEX (ms) | C++ internal (ms) | Speedup | Exact ratio | RSS ratio | Error |";"|---|---:|---:|---:|---:|---:|---:|---:|"];
if ~isempty(results.comparison), for item=results.comparison', lines(end+1)="| "+item.id+" | "+sprintf('%.3f',1e3*item.matlabSeconds)+" | "+sprintf('%.3f',1e3*item.compiledMexSeconds)+" | "+sprintf('%.3f',1e3*item.compiledNativeSeconds)+" | "+sprintf('%.3fx',item.compiledSpeedup)+" | "+sprintf('%.3f',item.exactMemoryRatio)+" | "+sprintf('%.3f',item.peakRSSRatio)+" | "+sprintf('%.3e',item.maximumRelativeError)+" |"; end, end
lines=[lines;"";"## Historical compiled progression";"";"| Implementation | Commit | Geometric-mean complete MEX (ms) |";"|---|---|---:|"];
if ~isempty(results.implementations), for item=results.implementations', values=[item.cases.completeMexMedianSeconds]; lines(end+1)="| "+item.id+" | `"+extractBefore(item.sourceCommit,9)+"` | "+sprintf('%.3f',1e3*exp(mean(log(values))))+" |"; end, end
lines=[lines;"";"## Stage correspondence";"";"| C++ stage | MATLAB operation |";"|---|---|"]; for item=results.stageCorrespondence', lines(end+1)="| "+item.cppStage+" | "+item.matlabOperation+" |"; end
if isfield(results,"failure")&&string(results.failure.identifier)~="", lines=[lines;"";"## Failure";"";"- Stage: `"+results.failure.stage+"`";"- `"+results.failure.identifier+"`: "+results.failure.message]; end
text=join(lines,newline)+newline;
end

function value=fieldOr(record,name,fallback)
if isstruct(record)&&isfield(record,name), value=string(record.(name)); else, value=fallback; end
end
function text=replaceOnce(text,old,new)
if count(text,old)~=1, error("WaveVortexModel:AssemblyInstrumentationOverlay","Expected one historical instrumentation anchor, found %d.",count(text,old)); end; text=replace(text,old,new);
end
function writeGitFile(repositoryRoot,specification,destination)
[status,output]=system("git -C "+shellQuote(repositoryRoot)+" show "+specification); if status~=0, error("WaveVortexModel:AssemblySnapshot","Unable to read %s.",specification); end; writeText(destination,output);
end
function value=gitValue(root,arguments)
[status,output]=system("git -C "+shellQuote(root)+" "+arguments); if status~=0, error("WaveVortexModel:AssemblyGit","Git command failed: %s",output); end; value=string(strtrim(output));
end
function [commit,tree,isDirty]=gitIdentity(root)
commit=gitValue(root,"rev-parse HEAD"); tree=gitValue(root,"rev-parse HEAD^{tree}"); [~,output]=system("git -C "+shellQuote(root)+" status --porcelain --untracked-files=no"); isDirty=strlength(strtrim(string(output)))>0;
end
function value=environmentRecord
value=struct("host",string(getenv("HOSTNAME")),"matlabVersion",string(version),"release",string(version("-release")),"architecture",string(computer("arch")),"platform",string(computer),"processor",string(getenv("PROCESSOR_IDENTIFIER")));
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
function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder); metadata=jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder=1:numel(metadata.folders), folder=fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end
function cacheRoot=resolveProviderCache(repositoryRoot)
candidates=[fullfile(repositoryRoot,".fftw-cache","issue137"),fullfile(fileparts(repositoryRoot),"wave-vortex-model-issue-137",".fftw-cache","issue137")];
for candidate=candidates, if isfile(fullfile(candidate,"downloads","fftw-3.3.11.tar.gz")), cacheRoot=candidate; return, end, end
error("WaveVortexModel:AssemblyProviderCache","The pinned #137 provider cache is unavailable. Expected one of: %s",strjoin(candidates,", "));
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
function value=emptySnapshot
value=struct("id","","requestedReference","","commit","","tree","","sourceRoot","","module","","mexPath","","mexSha256","","kernelSha256","","gatewaySha256","","instrumentationOverlay","","moduleDependencies","","moduleUsesOpenMP",false);
end
function value=emptyRun
value=struct("schemaVersion","1.0.0","status","failed","implementation","","sourceCommit","","repeatIndex",0,"module","","moduleInfo",struct(),"cases",[],"rss",struct(),"moduleClearSeconds",NaN,"failure",struct("identifier","","message","","report",""));
end
