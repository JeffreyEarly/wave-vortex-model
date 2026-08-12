function results = runCompiledKernelIssue130DonutReduced(options)
% Run the reduced Donut dual-host validation for issue #130.
arguments
    options.nativeProviderRoot (1,1) string
    options.baselineRepositoryRoot (1,1) string
    options.buildDirectory (1,1) string
    options.controlNativeExecutable (1,1) string
    options.streamedNativeExecutable (1,1) string
    options.singleOutputNativeExecutable (1,1) string
    options.outputDirectory (1,1) string
    options.scratchDirectory (1,1) string = fullfile(tempdir,"wave-vortex-issue130-donut-reduced-runs")
end

repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
originalDirectory = pwd;
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);
validateSource(repositoryRoot,options.baselineRepositoryRoot);
provider = nativeProvider(options.nativeProviderRoot);
paths = validatedPaths(options);
if isfolder(options.outputDirectory), error("WaveVortexModel:Issue130DonutOutputExists","Output directory already exists: %s",options.outputDirectory); end
if isfolder(options.scratchDirectory), error("WaveVortexModel:Issue130DonutScratchExists","Scratch directory already exists: %s",options.scratchDirectory); end
mkdir(options.scratchDirectory);
scratchCleanup = onCleanup(@()removeDirectory(options.scratchDirectory));

cases = caseDefinitions;
[nativeRuns,nativeOrder] = runNativePaths(cases,paths,options.scratchDirectory);
[matlabRuns,matlabOrder] = runMatlabPaths(cases,paths,provider,repositoryRoot,benchmarkFolder,options.scratchDirectory);
comparisons = comparisonRecords(cases,nativeRuns,matlabRuns);
candidates = candidateClassifications(comparisons);
allRequiredChecksPassed = all([candidates.requiredChecksPassed]);
results = struct("schemaVersion","1.0.0","status",conditional(allRequiredChecksPassed,"complete","failed"),"runId",string(extractBefore(string(basename(options.outputDirectory)),strlength(string(basename(options.outputDirectory)))+1)),"generatedAtUTC",utcTimestamp,"source",sourceRecord(repositoryRoot,options.baselineRepositoryRoot,paths),"environment",environmentRecord(provider),"configuration",struct("protocol","Donut reduced dual-host validation","threadCount",18,"warmupCount",2,"sampleCount",3,"caseIds",string({cases.id}),"largeCasesRun",false,"finalistThreeProcessProtocolRun",false,"rssProtocolRun",false,"correctnessTolerance",1e-12,"maximumAllowedRegression",0.05,"nativeExecutionOrder",nativeOrder,"matlabExecutionOrder",matlabOrder,"deterministicStateAdvancement","state i uses t=t0+30i and coefficient phases +/-0.017i and 0.017i/3","freshProcessPolicy","one fresh process per implementation and case"),"nativeRuns",nativeRuns,"matlabRuns",matlabRuns,"comparisons",comparisons,"candidates",candidates,"commands",commandRecord(options,paths));
mkdir(options.outputDirectory);
writeText(fullfile(options.outputDirectory,"donut-reduced.json"),jsonencode(results,PrettyPrint=true));
writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
fprintf("Issue #130 Donut reduced validation complete: %s\n",options.outputDirectory);
clear scratchCleanup stateCleanup
end

function [runs,orderRecords] = runNativePaths(cases,paths,scratchDirectory)
variants = [struct("id","control-be0f789","executable",paths.controlNativeExecutable); struct("id","streamed-target-three-channel","executable",paths.streamedNativeExecutable); struct("id","streamed-target-single-output-4H+5R","executable",paths.singleOutputNativeExecutable)];
runs = repmat(struct("executionOrdinal",0,"caseIndex",0,"variantIndex",0,"result",struct(),"comparison",struct()),0,1);
orderRecords = repmat(struct("caseId","","order",strings(1,0)),numel(cases),1);
for iCase = 1:numel(cases)
    order = mod((0:numel(variants)-1)+(iCase-1),numel(variants))+1;
    orderRecords(iCase) = struct("caseId",string(cases(iCase).id),"order",string({variants(order).id}));
    caseToken = conditional(cases(iCase).isHydrostatic,"hydrostatic","nonhydrostatic");
    fluxPaths = strings(numel(variants),1);
    runIndexes = zeros(numel(variants),1);
    for iVariant = order
        variant = variants(iVariant);
        prefix = "native-case-"+iCase+"-variant-"+iVariant;
        resultPath = fullfile(scratchDirectory,prefix+".json");
        fluxPaths(iVariant) = fullfile(scratchDirectory,prefix+".bin");
        command = shellQuote(variant.executable)+" --case "+caseToken+" --threads 18 --warmups 2 --samples 3 --output "+shellQuote(resultPath)+" --flux "+shellQuote(fluxPaths(iVariant));
        fprintf("Donut reduced native: %s, %s.\n",cases(iCase).id,variant.id);
        [status,output] = system(command);
        if status ~= 0 || ~isfile(resultPath), error("WaveVortexModel:Issue130DonutNativeFailure","Native path failed for %s/%s.%s%s",cases(iCase).id,variant.id,newline,output); end
        result = jsondecode(fileread(resultPath));
        if string(result.status) ~= "complete", error("WaveVortexModel:Issue130DonutNativeIncomplete","Native path was incomplete for %s/%s.",cases(iCase).id,variant.id); end
        runs(end+1,1) = struct("executionOrdinal",numel(runs)+1,"caseIndex",iCase,"variantIndex",iVariant,"result",result,"comparison",struct()); %#ok<AGROW>
        runIndexes(iVariant) = numel(runs);
    end
    for iVariant = 2:numel(variants)
        comparisonPath = fullfile(scratchDirectory,"native-compare-case-"+iCase+"-variant-"+iVariant+".json");
        command = shellQuote(paths.controlNativeExecutable)+" --compare "+shellQuote(fluxPaths(1))+" "+shellQuote(fluxPaths(iVariant))+" "+shellQuote(comparisonPath);
        [status,output] = system(command);
        if status ~= 0 || ~isfile(comparisonPath), error("WaveVortexModel:Issue130DonutNativeComparison","Native comparison failed.%s%s",newline,output); end
        runs(runIndexes(iVariant)).comparison = jsondecode(fileread(comparisonPath));
    end
    runs(runIndexes(1)).comparison = struct("Fp",0,"Fm",0,"F0",0,"maximumRelativeInfinityError",0);
end
end

function [runs,orderRecords] = runMatlabPaths(cases,paths,provider,repositoryRoot,benchmarkFolder,scratchDirectory)
variants = [struct("id","control-be0f789","mode","mex","module","wv_issue130_donut_control"); struct("id","streamed-target-three-channel","mode","mex","module","wv_issue130_donut_streamed"); struct("id","streamed-target-single-output-4H+5R","mode","mex","module","wv_issue130_donut_single_output"); struct("id","production-matlab-wvt-nonlinearFlux","mode","production","module","")];
runs = repmat(struct("executionOrdinal",0,"caseIndex",0,"variantIndex",0,"result",struct()),0,1);
orderRecords = repmat(struct("caseId","","order",strings(1,0)),numel(cases),1);
matlabExecutable = fullfile(matlabroot,"bin","matlab");
for iCase = 1:numel(cases)
    order = mod((0:numel(variants)-1)+(iCase-1),numel(variants))+1;
    orderRecords(iCase) = struct("caseId",string(cases(iCase).id),"order",string({variants(order).id}));
    for iVariant = order
        variant = variants(iVariant);
        prefix = "matlab-case-"+iCase+"-variant-"+iVariant;
        configPath = fullfile(scratchDirectory,prefix+"-config.json");
        resultPath = fullfile(scratchDirectory,prefix+"-result.json");
        config = struct("repositoryRoot",repositoryRoot,"benchmarkFolder",benchmarkFolder,"mexDirectory",paths.buildDirectory,"mode",variant.mode,"variantId",variant.id,"module",variant.module,"provider",provider,"caseDefinition",cases(iCase),"threadCount",18,"warmupCount",2,"sampleCount",3);
        writeText(configPath,jsonencode(config,PrettyPrint=true));
        expression = "addpath("+matlabString(benchmarkFolder)+"); compiledKernelIssue130DonutReducedWorker("+matlabString(configPath)+","+matlabString(resultPath)+")";
        command = shellQuote(matlabExecutable)+" -batch "+shellQuote(expression);
        fprintf("Donut reduced MATLAB: %s, %s.\n",cases(iCase).id,variant.id);
        [status,output] = system(command);
        if status ~= 0 || ~isfile(resultPath), error("WaveVortexModel:Issue130DonutMatlabFailure","MATLAB path failed for %s/%s.%s%s",cases(iCase).id,variant.id,newline,output); end
        result = jsondecode(fileread(resultPath));
        if string(result.status) ~= "complete", error("WaveVortexModel:Issue130DonutMatlabIncomplete","MATLAB path was incomplete for %s/%s: %s",cases(iCase).id,variant.id,result.failure.message); end
        runs(end+1,1) = struct("executionOrdinal",numel(runs)+1,"caseIndex",iCase,"variantIndex",iVariant,"result",result); %#ok<AGROW>
    end
end
end

function records = comparisonRecords(cases,nativeRuns,matlabRuns)
candidateIds = ["streamed-target-three-channel" "streamed-target-single-output-4H+5R"];
records = repmat(struct("caseId","","isHydrostatic",false,"candidateId","","native",struct(),"mex",struct()),numel(cases)*numel(candidateIds),1);
index = 0;
for iCase = 1:numel(cases)
    nativeControl = nativeRuns([nativeRuns.caseIndex]==iCase & [nativeRuns.variantIndex]==1);
    mexControl = matlabRuns([matlabRuns.caseIndex]==iCase & [matlabRuns.variantIndex]==1).result;
    production = matlabRuns([matlabRuns.caseIndex]==iCase & [matlabRuns.variantIndex]==4).result;
    for iCandidate = 1:numel(candidateIds)
        index = index+1;
        nativeCandidateRun = nativeRuns([nativeRuns.caseIndex]==iCase & [nativeRuns.variantIndex]==iCandidate+1);
        nativeCandidate = nativeCandidateRun.result;
        mexCandidate = matlabRuns([matlabRuns.caseIndex]==iCase & [matlabRuns.variantIndex]==iCandidate+1).result;
        nativeMemoryReduction = 1-nativeCandidate.memory.knownMaximumLiveOwnedBytesLowerBound/nativeControl.result.memory.knownMaximumLiveOwnedBytesLowerBound;
        mexMemoryReduction = 1-mexCandidate.metrics.knownMaximumLiveOwnedBytes/mexControl.metrics.knownMaximumLiveOwnedBytes;
        records(index) = struct("caseId",string(cases(iCase).id),"isHydrostatic",cases(iCase).isHydrostatic,"candidateId",candidateIds(iCandidate),"native",struct("controlMedianSeconds",median(nativeControl.result.timing.samplesSeconds),"candidateMedianSeconds",median(nativeCandidate.timing.samplesSeconds),"speedup",median(nativeControl.result.timing.samplesSeconds)/median(nativeCandidate.timing.samplesSeconds),"exactLiveReduction",nativeMemoryReduction,"maximumRelativeInfinityError",nativeCandidateRun.comparison.maximumRelativeInfinityError,"candidate",nativeCandidate,"control",nativeControl.result),"mex",struct("baselineCoreMedianSeconds",mexControl.totalMedianSeconds,"candidateMedianSeconds",mexCandidate.totalMedianSeconds,"productionMedianSeconds",production.totalMedianSeconds,"speedupVersusBaselineCore",mexControl.totalMedianSeconds/mexCandidate.totalMedianSeconds,"speedupVersusProduction",production.totalMedianSeconds/mexCandidate.totalMedianSeconds,"exactLiveReduction",mexMemoryReduction,"maximumRelativeInfinityError",mexCandidate.maximumRelativeInfinityError,"candidate",mexCandidate,"baselineCore",mexControl,"production",production));
    end
end
end

function candidates = candidateClassifications(comparisons)
ids = unique(string({comparisons.candidateId}),"stable");
candidates = repmat(struct("id","","classification","CORE_REJECT","nativeClassification","CORE_REJECT","mexClassification","MEX_NOT_QUALIFIED","requiredChecksPassed",false,"nativeMaximumRegression",NaN,"mexMaximumRegression",NaN,"nativeGeometricMeanSpeedup",NaN,"mexGeometricMeanSpeedup",NaN,"rationale",""),numel(ids),1);
for iCandidate = 1:numel(ids)
    selected = comparisons(string({comparisons.candidateId})==ids(iCandidate));
    nativeSpeedups = arrayfun(@(item)item.native.speedup,selected);
    mexSpeedups = arrayfun(@(item)item.mex.speedupVersusBaselineCore,selected);
    correctness = all(arrayfun(@(item)item.native.maximumRelativeInfinityError<=1e-12 && item.mex.maximumRelativeInfinityError<=1e-12,selected));
    cleanup = all(arrayfun(@(item)item.native.candidate.lifecycle.balancedCleanup && item.mex.candidate.lifecycle.passed,selected));
    storage = all(arrayfun(@(item)item.native.candidate.memory.persistentFullHermitianBytes==0 && item.mex.candidate.metrics.persistentFullHermitianBytes==0,selected));
    noFallback = all(arrayfun(@(item)~item.native.candidate.fallbackOccurred && ~item.mex.candidate.fallbackOccurred,selected));
    noOpenMP = all(arrayfun(@(item)string(item.native.candidate.identity.openMPRuntimeDladdr)=="" && string(item.mex.candidate.moduleInfo.openMPRuntimeLibrary)=="",selected));
    noOversubscription = noOpenMP && all(arrayfun(@(item)item.native.candidate.configuration.threadsEffective==18 && item.mex.candidate.threadCountEffective==18 && item.mex.candidate.metrics.coefficientWorkerCount==1,selected));
    required = correctness && cleanup && storage && noFallback && noOversubscription;
    nativePassed = required && all(nativeSpeedups>=1/1.05);
    mexPassed = required && all(mexSpeedups>=1/1.05) && exp(mean(log(mexSpeedups)))>1;
    nativeClassification = conditional(nativePassed,"ADVANCE","CORE_REJECT");
    mexClassification = conditional(mexPassed,"ADVANCE","MEX_NOT_QUALIFIED");
    classification = nativeClassification;
    rationale = conditional(nativePassed,"The standalone native candidate passed correctness, lifecycle, storage, provider/thread, and 5% regression gates.","The standalone native candidate failed a required correctness/lifecycle/storage/thread gate or exceeded 5% regression in at least one medium case.");
    if nativePassed && ~mexPassed, rationale = rationale+" MATLAB/MEX did not qualify, but the native result advances independently."; end
    candidates(iCandidate) = struct("id",ids(iCandidate),"classification",classification,"nativeClassification",nativeClassification,"mexClassification",mexClassification,"requiredChecksPassed",required,"nativeMaximumRegression",max(1./nativeSpeedups-1),"mexMaximumRegression",max(1./mexSpeedups-1),"nativeGeometricMeanSpeedup",exp(mean(log(nativeSpeedups))),"mexGeometricMeanSpeedup",exp(mean(log(mexSpeedups))),"rationale",rationale);
end
end

function paths = validatedPaths(options)
paths = struct("buildDirectory",canonicalPath(options.buildDirectory),"controlNativeExecutable",canonicalFile(options.controlNativeExecutable),"streamedNativeExecutable",canonicalFile(options.streamedNativeExecutable),"singleOutputNativeExecutable",canonicalFile(options.singleOutputNativeExecutable),"controlMex",canonicalFile(fullfile(options.buildDirectory,"wv_issue130_donut_control."+mexext)),"streamedMex",canonicalFile(fullfile(options.buildDirectory,"wv_issue130_donut_streamed."+mexext)),"singleOutputMex",canonicalFile(fullfile(options.buildDirectory,"wv_issue130_donut_single_output."+mexext)));
end

function provider = nativeProvider(root)
root = canonicalPath(root);
includeDirectory = fullfile(root,"install","include");
baseLibrary = canonicalFile(fullfile(root,"install","lib","libfftw3.3.dylib"));
threadLibrary = canonicalFile(fullfile(root,"install","lib","libfftw3_threads.3.dylib"));
if ~isfile(fullfile(includeDirectory,"fftw3.h"))
    error("WaveVortexModel:Issue130DonutProviderMissing","Missing pinned FFTW header under %s.",root);
end
provider = struct("id","native-neon-pthreads","version","3.3.11","buildKey","99b0f0e9ae7e3864","configureFlags","--host=aarch64-apple-darwin --enable-neon --enable-threads --disable-fortran --disable-openmp --enable-shared --disable-static","compilerFlags","-O3 -mcpu=native -mmacosx-version-min=13.3","baseLibrary",baseLibrary,"threadLibrary",threadLibrary,"baseLibrarySha256",sha256File(baseLibrary),"threadLibrarySha256",sha256File(threadLibrary));
expectedBase = "abc08b7b2c328d9659dd89a382494d7ca2e7aaec369c1f1025e255c6a2d99a0b";
expectedThreads = "6e5c9a14b2c3db5fc8ec5f9ba5bd08457677cc9b8c12baa6331379c6145ba0ca";
if provider.baseLibrarySha256 ~= expectedBase || provider.threadLibrarySha256 ~= expectedThreads, error("WaveVortexModel:Issue130DonutProviderHash","The pinned #137 provider hashes do not match the selected baseline artifact."); end
end

function validateSource(repositoryRoot,baselineRoot)
[commit,~,dirty] = gitIdentity(repositoryRoot);
if commit == "7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05", error("WaveVortexModel:Issue130DonutHarnessUncommitted","Commit the implementation/test harness before producing the measured artifact."); end
[status,isAncestor] = system("git -C "+shellQuote(repositoryRoot)+" merge-base --is-ancestor 7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05 HEAD"); %#ok<ASGLU>
if status ~= 0 || dirty, error("WaveVortexModel:Issue130DonutSource","The reduced validation requires a clean harness commit descended from exact 7fd33f74."); end
[baselineCommit,~,baselineDirty] = gitIdentity(baselineRoot);
if baselineCommit ~= "be0f78995c49a2bfe4c43d75827856e3812ac278" || baselineDirty, error("WaveVortexModel:Issue130DonutBaseline","The baseline source must be a clean detached worktree at exact be0f78995c49a2bfe4c43d75827856e3812ac278."); end
end

function value = sourceRecord(repositoryRoot,baselineRoot,paths)
[commit,tree,dirty] = gitIdentity(repositoryRoot);
[baselineCommit,baselineTree,baselineDirty] = gitIdentity(baselineRoot);
files = ["CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" "CompiledKernel/include/WaveVortexKernel/WVTransformConstantStratificationKernel.hpp" "Benchmarks/compiled-kernel/issue130_donut_reduced_driver.cpp" "Benchmarks/compiledKernelIssue130DonutReducedWorker.m" "Benchmarks/runCompiledKernelIssue130DonutReduced.m"];
hashes = repmat(struct("path","","sha256",""),numel(files),1);
for iFile = 1:numel(files), hashes(iFile) = struct("path",files(iFile),"sha256",sha256File(fullfile(repositoryRoot,files(iFile)))); end
value = struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",dirty,"pinnedParent","7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05","baselineCommit",baselineCommit,"baselineTree",baselineTree,"baselineIsDirty",baselineDirty,"files",hashes,"buildProducts",struct("controlNativeSha256",sha256File(paths.controlNativeExecutable),"streamedNativeSha256",sha256File(paths.streamedNativeExecutable),"singleOutputNativeSha256",sha256File(paths.singleOutputNativeExecutable),"controlMexSha256",sha256File(paths.controlMex),"streamedMexSha256",sha256File(paths.streamedMex),"singleOutputMexSha256",sha256File(paths.singleOutputMex)));
end

function value = environmentRecord(provider)
value = struct("host",commandOutput("hostname -s"),"hardwareModel",commandOutput("sysctl -n hw.model"),"processor",commandOutput("sysctl -n machdep.cpu.brand_string"),"os",commandOutput("uname -a"),"osVersion",commandOutput("sw_vers"),"architecture",string(computer("arch")),"memoryBytes",str2double(commandOutput("sysctl -n hw.memsize")),"physicalCores",str2double(commandOutput("sysctl -n hw.physicalcpu")),"logicalCores",str2double(commandOutput("sysctl -n hw.logicalcpu")),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"matlabMaximumThreads",maxNumCompThreads,"compiler",commandOutput("xcrun clang++ --version"),"provider",provider,"openMPRuntimePolicy","No isolated LLVM libomp was loaded; dladdr identities were required to be empty for OpenMP.");
end

function value = commandRecord(options,paths)
value = struct("contractTests","tools/compiled-kernel/run_issue130_donut_reduced_contract_tests.sh <temporary-build-root>","nativeBuild","clang++ -std=c++17 -O3 -mcpu=native -pthread -DWV_KERNEL_NATIVE_OPTIMIZATION=1 -DWV_KERNEL_COEFFICIENT_WORKERS=2 -DWV_KERNEL_ISSUE130_VARIANT=<0|3|4> <driver and exact source files> <pinned FFTW thread/base libraries>","mexBuild","buildCompiledKernelTransformMex with exact be0f baseline for control and issue130Variant 3/4 from the harness commit for candidates","benchmark","runCompiledKernelIssue130DonutReduced(nativeProviderRoot="+options.nativeProviderRoot+",baselineRepositoryRoot="+options.baselineRepositoryRoot+",buildDirectory="+paths.buildDirectory+",controlNativeExecutable="+paths.controlNativeExecutable+",streamedNativeExecutable="+paths.streamedNativeExecutable+",singleOutputNativeExecutable="+paths.singleOutputNativeExecutable+",outputDirectory="+options.outputDirectory+")");
end

function markdown = summaryMarkdown(results)
lines = ["# Issue #130 — Donut reduced dual-host validation";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"` (pinned parent `"+results.source.pinnedParent+"`)";"- Explicit control: `"+results.source.baselineCommit+"`";"- Provider: FFTW 3.3.11 NEON/pthreads build `"+results.environment.provider.buildKey+"`, 18 threads";"- MATLAB: `"+results.environment.matlabVersion+"`";"- Protocol: medium hydrostatic/nonhydrostatic only; one fresh process per path; two warmups and three samples; rotated order; no RSS/finalist protocol";"";"| Case | Candidate | Native control (ms) | Native candidate (ms) | Native speedup | MEX baseline (ms) | Candidate MEX (ms) | MEX speedup | Production (ms) | Native/MEX error |";"|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"];
for item = results.comparisons'
    lines(end+1) = sprintf("| %s | %s | %.3f | %.3f | %.3fx | %.3f | %.3f | %.3fx | %.3f | %.3g / %.3g |",item.caseId,item.candidateId,1e3*item.native.controlMedianSeconds,1e3*item.native.candidateMedianSeconds,item.native.speedup,1e3*item.mex.baselineCoreMedianSeconds,1e3*item.mex.candidateMedianSeconds,item.mex.speedupVersusBaselineCore,1e3*item.mex.productionMedianSeconds,item.native.maximumRelativeInfinityError,item.mex.maximumRelativeInfinityError); %#ok<AGROW>
end
lines = [lines;"";"## Classification";"";"| Candidate | Overall | Native | MATLAB/MEX | Native geometric speedup | MEX geometric speedup |";"|---|---|---|---|---:|---:|"];
for candidate = results.candidates'
    lines(end+1) = sprintf("| %s | `%s` | `%s` | `%s` | %.3fx | %.3fx |",candidate.id,candidate.classification,candidate.nativeClassification,candidate.mexClassification,candidate.nativeGeometricMeanSpeedup,candidate.mexGeometricMeanSpeedup); %#ok<AGROW>
end
lines = [lines;"";"All reported native and MEX candidates require relative-infinity error <= 1e-12, balanced plan cleanup, zero fallback, zero persistent full-Hermitian storage, the pinned FFTW libraries by `dladdr`, exactly 18 requested/effective FFTW threads, one coefficient worker, and no loaded OpenMP runtime. FFTW-owned plan memory is opaque; plan wrapper bytes are a lower bound, while descriptor/scratch/state/output array byte counts are exact."];
markdown = join(lines,newline)+newline;
end

function cases = caseDefinitions
cases = [struct("id","constant-hydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",true,"seed",1302561); struct("id","constant-nonhydrostatic-256x256x65","Nxyz",[256 256 65],"isHydrostatic",false,"seed",1302562)];
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
addpath(repositoryRoot,benchmarkFolder);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders), folder = fullfile(repositoryRoot,metadata.folders(iFolder).path); if isfolder(folder), addpath(folder); end, end
end

function [commit,tree,isDirty] = gitIdentity(repositoryRoot)
[status,commit] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve commit."); end
[status,tree] = system("git -C "+shellQuote(repositoryRoot)+" rev-parse HEAD^{tree}"); if status ~= 0, error("WaveVortexModel:Issue130GitIdentity","Unable to resolve tree."); end
[~,dirty] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain --untracked-files=no");
commit = string(strtrim(commit)); tree = string(strtrim(tree)); isDirty = strlength(strtrim(string(dirty)))>0;
end

function value = canonicalFile(pathname)
if ~isfile(pathname), error("WaveVortexModel:Issue130DonutMissingBuild","Missing build product: %s",pathname); end
value = canonicalPath(pathname);
end

function value = canonicalPath(pathname)
[status,value] = system("/bin/realpath "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:Issue130DonutPath","Unable to resolve %s.",pathname); end
value = string(strtrim(value));
end

function value = commandOutput(command)
[status,value] = system(command);
if status ~= 0, value = "unavailable"; else, value = string(strtrim(value)); end
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function value = matlabString(text)
value = "'"+replace(string(text),"'","''")+"'";
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function value = basename(pathname)
[~,value] = fileparts(pathname);
value = string(value);
end

function writeText(pathname,value)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end

function restoreState(directory,originalPath,originalRng)
cd(directory); path(originalPath); rng(originalRng);
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
