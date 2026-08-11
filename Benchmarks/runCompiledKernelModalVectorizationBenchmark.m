function results = runCompiledKernelModalVectorizationBenchmark(options)
% Benchmark issue #126 modal normalization, vectorization, and bounded workers.
arguments
    options.baselineCommit (1,1) string = "52de16195c6817c6f107b6147c1f7e46922e8983"
    options.screenCaseIds (1,:) string = strings(1,0)
    options.gateCaseIds (1,:) string = strings(1,0)
    options.screenProcessRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.gateProcessRunCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.samplingIntervalSeconds (1,1) double {mustBePositive} = 0.02
    options.plateauSeconds (1,1) double {mustBePositive} = 0.15
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.screenVariantIds (1,:) string = strings(1,0)
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
    options.requireCleanCandidate (1,1) logical = false
end

benchmarkFolder=string(fileparts(mfilename("fullpath"))); repositoryRoot=string(fileparts(benchmarkFolder));
[candidateCommit,candidateTree,candidateDirty]=gitIdentity(repositoryRoot);
if options.requireCleanCandidate&&candidateDirty, error("WaveVortexBenchmark:DirtyModalCandidate","The canonical issue #126 benchmark requires a clean candidate commit."); end
baselineRoot=string(tempname); temporaryRoot=string(tempname); mkdir(temporaryRoot);
[status,output]=system(sprintf('git -C "%s" worktree add --detach "%s" "%s"',repositoryRoot,baselineRoot,options.baselineCommit));
if status~=0, rmdir(temporaryRoot,"s"); error("WaveVortexBenchmark:ModalBaselineCheckoutFailed","Unable to create the baseline worktree: %s",output); end
cleanup=onCleanup(@()removeTemporaryWorktree(repositoryRoot,baselineRoot,temporaryRoot));
cleanMatlabPath=benchmarkMatlabPath(repositoryRoot,baselineRoot);

baselineScreen=runSnapshot(baselineRoot,"baseline-screen",options.screenCaseIds,options.screenProcessRunCount,struct(),options,temporaryRoot,cleanMatlabPath,false);
variants=variantDefinitions;
if ~isempty(options.screenVariantIds), variants=variants(ismember(string({variants.id}),options.screenVariantIds)); end
if isempty(variants), error("WaveVortexBenchmark:NoModalVariants","No issue #126 variants matched the requested identifiers."); end
screenResults=repmat(emptyScreen(),0,1);
compactResult=struct();
normalizedResult=struct();
for iVariant=1:numel(variants)
    variant=variants(iVariant);
    if startsWith(variant.id,"threaded-") && ~isempty(fieldnames(normalizedResult)) && normalizedModalShare(normalizedResult)<0.10
        screenResults(end+1,1)=skippedScreen(variant,"Normalized modal arithmetic occupied less than 10% of complete nonlinearFlux time."); %#ok<AGROW>
        continue
    end
    snapshot=runSnapshot(repositoryRoot,variant.id,options.screenCaseIds,options.screenProcessRunCount,variant,options,temporaryRoot,cleanMatlabPath,true);
    controlResult=normalizedResult;
    if variant.id=="prescaled-modal", controlResult=compactResult; end
    screen=compareScreen(baselineScreen,snapshot,variant,controlResult);
    if variant.id=="compact-modal", compactResult=screen; end
    if variant.id=="prescaled-modal", normalizedResult=screen; end
    screenResults(end+1,1)=screen; %#ok<AGROW>
end
selected=selectCumulative(screenResults);

if sameCaseSelection(options.screenCaseIds,options.gateCaseIds)&&options.screenProcessRunCount==options.gateProcessRunCount
    winnerScreen=screenResults(string(arrayfun(@(item)item.variant.id,screenResults,UniformOutput=false))==selected.variantId); gateCases=winnerScreen.cases;
else
    baselineGate=runSnapshot(baselineRoot,"baseline-gate",options.gateCaseIds,options.gateProcessRunCount,struct(),options,temporaryRoot,cleanMatlabPath,false);
    selectedDefinition=variants(string({variants.id})==selected.variantId);
    candidateGate=runSnapshot(repositoryRoot,"cumulative-"+selected.variantId,options.gateCaseIds,options.gateProcessRunCount,selectedDefinition,options,temporaryRoot,cleanMatlabPath,true);
    gateCases=compareGateCases(baselineGate,candidateGate);
end
decision=compiledKernelModalVectorizationDecision(gateCases);
compilerEvidence=captureVectorizationEvidence(temporaryRoot,benchmarkFolder);
tableLedgers=arrayfun(@modalTableLedger,gateCases);
sourceHashes=sourceHashRecords(repositoryRoot);
results=struct("schemaVersion","1.0.0","status",conditional(all(string({gateCases.status})=="complete"),"complete","partial"),"runId",options.runId, ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","baselineCommit",options.baselineCommit,"candidateCommit",candidateCommit,"candidateTree",candidateTree,"candidateDirty",candidateDirty,"runtimeHashes",sourceHashes), ...
    "configuration",struct("suiteId","core-v1","operation","ordinary nonlinearFlux","screenProcessRunCount",options.screenProcessRunCount,"gateProcessRunCount",options.gateProcessRunCount,"warmups",2,"samples","7 medium / 3 large","componentStageThreshold",1.05,"componentCallThreshold",1.01,"qualificationSpeedThreshold",1.10,"qualificationMemoryThreshold",0.90,"maximumRegression",0.03,"correctnessTolerance",1e-12), ...
    "componentScreens",screenResults,"selectedCumulative",selected,"compilerEvidence",compilerEvidence,"modalTableLedgers",tableLedgers,"gateCases",gateCases,"decision",decision);
if options.outputDirectory=="", options.outputDirectory=fullfile(benchmarkFolder,"results","experiments","issue126",options.runId+"-"+computer("arch")+"-"+version("-release")); end
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"modal-vectorization-benchmark.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear cleanup
end

function tf=sameCaseSelection(first,second)
tf=(isempty(first)&&isempty(second))||isequal(sort(first),sort(second));
end

function variants=variantDefinitions
variants=[ ...
    variant("compact-modal","scalar","compact","default",1); ...
    variant("prescaled-modal","scalar","prescaled","default",1); ...
    variant("accelerate-phase","accelerate","prescaled","default",1); ...
    variant("native-vectorized","scalar","prescaled","native",1); ...
    variant("native-vforce","accelerate","prescaled","native",1); ...
    variant("threaded-2","scalar","prescaled","default",2); ...
    variant("threaded-4","scalar","prescaled","default",4); ...
    variant("threaded-8","scalar","prescaled","default",8)];
end

function value=variant(id,phaseImplementation,modalCoefficientMode,optimizationLevel,modalWorkerCount)
value=struct("id",id,"phaseImplementation",phaseImplementation,"modalCoefficientMode",modalCoefficientMode,"optimizationLevel",optimizationLevel,"modalWorkerCount",modalWorkerCount);
end

function result=runSnapshot(sourceRoot,identifier,caseIds,processRunCount,variant,options,temporaryRoot,cleanMatlabPath,isCandidate)
outputDirectory=fullfile(temporaryRoot,identifier); if ~isfolder(outputDirectory), mkdir(outputDirectory); end
caseExpression="strings(1,0)"; if ~isempty(caseIds), caseExpression="["+strjoin(string(compose('"%s"',caseIds))," ")+"]"; end
variantArguments="";
if isCandidate, variantArguments=",phaseImplementation='"+variant.phaseImplementation+"',modalCoefficientMode='"+variant.modalCoefficientMode+"',optimizationLevel='"+variant.optimizationLevel+"',modalWorkerCount="+variant.modalWorkerCount+",variantIdentifier='"+variant.id+"'"; end
statement="path('"+replace(cleanMatlabPath,"'","''")+"'); addpath('"+replace(fullfile(sourceRoot,"Benchmarks"),"'","''")+"'); runCompiledKernelReadinessBenchmark(caseIds="+caseExpression+",processRunCount="+processRunCount+",samplingIntervalSeconds="+options.samplingIntervalSeconds+",plateauSeconds="+options.plateauSeconds+",threadCount="+options.threadCount+",outputDirectory='"+replace(outputDirectory,"'","''")+"',runId='"+identifier+"'"+variantArguments+");";
command=sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
[status,output]=system(command); artifact=fullfile(outputDirectory,"compiled-kernel-readiness.json");
if status~=0||~isfile(artifact), error("WaveVortexBenchmark:ModalSnapshotFailed","The %s snapshot benchmark failed: %s",identifier,output); end
result=jsondecode(fileread(artifact));
end

function result=compareScreen(baseline,snapshot,variant,controlResult)
cases=compareGateCases(baseline,snapshot); stageShares=NaN(1,numel(cases));
for iCase=1:numel(cases)
    metrics=cases(iCase).candidate.metrics;
    modalSeconds=metrics.modalReconstructionSeconds+metrics.modalDerivativeSeconds+metrics.modalProjectionSeconds;
    stageShares(iCase)=modalSeconds/cases(iCase).candidate.medianSeconds;
end
result=struct("status",conditional(all(string({cases.status})=="complete"),"complete","partial"),"variant",variant,"cases",cases,"geometricMeanSpeedup",geomeanPositive([cases.speedup]),"maximumRegression",max(1./[cases.speedup]-1),"minimumDescriptorReduction",NaN,"modalStageShare",stageShares,"componentCallSpeedup",NaN,"targetedStageSpeedup",NaN,"beneficialDirectionPassed",false,"beneficial",false,"reason","");
if isempty(fieldnames(controlResult))
    componentCallSpeedups=[cases.speedup];
    descriptorRatios=arrayfun(@(item)item.candidate.ledger.descriptorBytes/item.baseline.ledger.descriptorBytes,cases);
    controlBackends=[cases.baseline];
else
    componentCallSpeedups=arrayfun(@(index)controlResult.cases(index).candidate.medianSeconds/cases(index).candidate.medianSeconds,1:numel(cases));
    descriptorRatios=arrayfun(@(index)cases(index).candidate.ledger.descriptorBytes/controlResult.cases(index).candidate.ledger.descriptorBytes,1:numel(cases));
    controlCases=controlResult.cases; controlBackends=[controlCases.candidate];
end
candidateBackends=[cases.candidate];
processDirections=arrayfun(@(index)all(controlBackends(index).processMedianSeconds./candidateBackends(index).processMedianSeconds>1),1:numel(cases));
targetedSpeedups=targetedStageSpeedups(result,controlBackends);
completeBenefit=all(componentCallSpeedups>=1.01); stageBenefit=all(targetedSpeedups>=1.05); descriptorBenefit=all(descriptorRatios<=0.95); noRegression=all(componentCallSpeedups>=1/1.03);
result.minimumDescriptorReduction=min(1-descriptorRatios); result.beneficialDirectionPassed=all(processDirections); result.beneficial=result.beneficialDirectionPassed&&noRegression&&((completeBenefit&&stageBenefit)||descriptorBenefit);
result.componentCallSpeedup=geomeanPositive(componentCallSpeedups); result.targetedStageSpeedup=geomeanPositive(targetedSpeedups);
result.reason=conditional(result.beneficial,"Passed the component inclusion rule.","Did not pass the component inclusion rule.");
end

function speedups=targetedStageSpeedups(result,controlBackends)
speedups=ones(1,numel(result.cases));
for iCase=1:numel(result.cases)
    candidate=result.cases(iCase).candidate.metrics;
    control=controlBackends(iCase).metrics;
    if ~isfield(control,"modalReconstructionSeconds")||~isfield(candidate,"modalReconstructionSeconds"), speedups(iCase)=1; continue, end
    if contains(result.variant.id,"phase")||contains(result.variant.id,"vforce")
        controlStage=control.phaseSeconds; candidateStage=candidate.phaseSeconds;
    else
        controlStage=control.modalReconstructionSeconds+control.modalDerivativeSeconds+control.modalProjectionSeconds; candidateStage=candidate.modalReconstructionSeconds+candidate.modalDerivativeSeconds+candidate.modalProjectionSeconds;
    end
    speedups(iCase)=controlStage/max(candidateStage,realmin);
end
end

function share=normalizedModalShare(result)
share=min(result.modalStageShare,[],"omitnan");
end

function selected=selectCumulative(screens)
complete=string({screens.status})=="complete"; beneficial=[screens.beneficial]; candidates=screens(complete&beneficial);
if isempty(candidates), candidates=screens(complete&string(arrayfun(@(item)item.variant.id,screens,UniformOutput=false))=="prescaled-modal"); end
if isempty(candidates), error("WaveVortexBenchmark:NoCumulativeCandidate","No complete issue #126 candidate was available for the gate."); end
[~,index]=max([candidates.geometricMeanSpeedup]); winner=candidates(index);
selected=struct("variantId",winner.variant.id,"phaseImplementation",winner.variant.phaseImplementation,"modalCoefficientMode",winner.variant.modalCoefficientMode,"optimizationLevel",winner.variant.optimizationLevel,"modalWorkerCount",winner.variant.modalWorkerCount,"selectionReason","Fastest component-screen candidate satisfying the inclusion and regression rules.");
end

function evidence=captureVectorizationEvidence(temporaryRoot,benchmarkFolder)
reportDirectory=fullfile(temporaryRoot,"vectorization-report");
try
    statement="addpath('"+replace(benchmarkFolder,"'","''")+"'); buildCompiledKernelTransformMex(outputDirectory='"+replace(reportDirectory,"'","''")+"',outputName='wv_compiled_transform_vector_report',phaseImplementation='scalar',modalCoefficientMode='prescaled',optimizationLevel='native',modalWorkerCount=1,shouldReportVectorization=true);";
    command=sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
    [status,report]=system(command);
    if status~=0, error("WaveVortexBenchmark:VectorizationReportFailed","Vectorization-report build failed: %s",report); end
    reportLines=splitlines(string(report)); retained=reportLines(contains(reportLines,"remark:")|contains(reportLines,"WVTransformConstantStratificationKernel.cpp"));
    evidence=struct("status","complete","compiler","Apple Clang through mex","flags","-O3 -mcpu=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize -Rpass-analysis=loop-vectorize","vectorizedRemarkCount",sum(contains(retained,"vectorized loop")),"missedRemarkCount",sum(contains(retained,"loop not vectorized")),"report",join(retained,newline),"failure",struct("identifier","","message",""));
catch exception
    evidence=struct("status","failed","compiler","Apple Clang through mex","flags","-O3 -mcpu=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize -Rpass-analysis=loop-vectorize","vectorizedRemarkCount",0,"missedRemarkCount",0,"report","","failure",struct("identifier",string(exception.identifier),"message",string(exception.message)));
end
end


function ledger=modalTableLedger(caseResult)
Nj=caseResult.candidate.metrics.Nj; Nkl=caseResult.candidate.metrics.Nkl; Nz=caseResult.candidate.metrics.Nz; M=Nj*Nkl;
baselineRecords=repmat(struct("name","","shape",[],"type","double","bytes",0),0,1);
baselineRecords(end+1)=tableRecord("z",[Nz 1],8*Nz); %#ok<AGROW>
for name=["j" "h0"], baselineRecords(end+1)=tableRecord(name,[Nj 1],8*Nj); end %#ok<AGROW>
for name=["hpm" "omega" "Fg" "Gg" "Fwg" "Gwg" "NAp" "NAm" "NA0" "A0Z" "A0N" "ApmN" "ApmDScaled"], baselineRecords(end+1)=tableRecord(name,[Nj Nkl],8*M); end %#ok<AGROW>
for name=["UAp" "UAm" "VAp" "VAm" "WAp" "WAm" "UA0" "VA0" "ApmD" "ApmWScaled"], baselineRecords(end+1)=tableRecord(name,[Nj Nkl],16*M,"complex double"); end %#ok<AGROW>
candidateRecords=repmat(struct("name","","shape",[],"type","double","bytes",0),0,1);
candidateRecords(end+1)=tableRecord("z",[Nz 1],8*Nz); %#ok<AGROW>
verticalNames=["j" "h0" "verticalWavenumber" "Fg" "Gg" "inverseFg" "inverseGg" "Gwg" "inverseGwg" "GgOverGwg" "deltaScale" "inertialScale" "gWaveScale"];
for name=verticalNames, candidateRecords(end+1)=tableRecord(name,[Nj 1],8*Nj); end %#ok<AGROW>
for name=["Kh" "cosAlpha" "sinAlpha"], candidateRecords(end+1)=tableRecord(name,[1 Nkl],8*Nkl); end %#ok<AGROW>
if string(caseResult.candidate.metadata.modalCoefficientMode)=="prescaled"
    realNames=["omega" "fWaveScale" "NApField" "NAmField" "NA0Field" "A0FromVorticity" "A0FromBuoyancy" "ApmNProjection" "ApmDScaled"];
    complexNames=["UApField" "UAmField" "VApField" "VAmField" "WApField" "WAmField" "UA0Field" "VA0Field" "ApmDProjection" "ApmWScaled"];
else
    realNames=["omega" "Fwg" "NAp" "NAm" "NA0" "A0Z" "A0N" "ApmN" "ApmDScaled"];
    complexNames=["UAp" "UAm" "VAp" "VAm" "WAp" "WAm" "UA0" "VA0" "ApmD" "ApmWScaled"];
end
for name=realNames, candidateRecords(end+1)=tableRecord(name,[Nj Nkl],8*M); end %#ok<AGROW>
for name=complexNames, candidateRecords(end+1)=tableRecord(name,[Nj Nkl],16*M,"complex double"); end %#ok<AGROW>
baselineComparableBytes=sum([baselineRecords.bytes]); candidateBytes=sum([candidateRecords.bytes]);
ledger=struct("caseId",caseResult.id,"baselineRecords",baselineRecords,"candidateRecords",candidateRecords,"baselineComparableBytes",baselineComparableBytes,"candidateComparableBytes",candidateBytes,"comparableRatio",candidateBytes/baselineComparableBytes,"reportedDescriptorBytes",caseResult.candidate.ledger.descriptorBytes);
end

function value=tableRecord(name,shape,bytes,type)
if nargin<4, type="double"; end
value=struct("name",name,"shape",shape,"type",type,"bytes",bytes);
end

function cases=compareGateCases(baseline,candidate)
candidateCases=candidate.suite.cases; baselineCases=baseline.suite.cases; cases=repmat(emptyGateCase(),numel(candidateCases),1);
for iCase=1:numel(candidateCases)
    candidateCase=candidateCases(iCase); baselineIndex=find(string({baselineCases.id})==string(candidateCase.id),1);
    if isempty(baselineIndex), error("WaveVortexBenchmark:MissingModalBaselineCase","Baseline result is missing case %s.",candidateCase.id); end
    baselineCompiled=backend(baselineCases(baselineIndex),"compiled"); candidateCompiled=backend(candidateCase,"compiled");
    speedup=baselineCompiled.medianSeconds/candidateCompiled.medianSeconds; exactStorageRatio=candidateCompiled.ledger.knownMaximumLiveBytes/baselineCompiled.ledger.knownMaximumLiveBytes; peakRSSRatio=candidateCompiled.rss.medianPeakIncrementBytes/baselineCompiled.rss.medianPeakIncrementBytes;
    cases(iCase)=struct("id",string(candidateCase.id),"Nxyz",candidateCase.Nxyz(:)',"isHydrostatic",candidateCase.isHydrostatic,"status",conditional(string(candidateCase.status)=="complete"&&string(baselineCases(baselineIndex).status)=="complete","complete","partial"),"baseline",baselineCompiled,"candidate",candidateCompiled,"speedup",speedup,"exactStorageRatio",exactStorageRatio,"peakRSSRatio",peakRSSRatio,"correctnessPassed",candidateCompiled.maximumRelativeError<=1e-12&&candidateCompiled.correctnessPassed,"implementationExecuted",string(candidateCompiled.metadata.activeImplementation)=="compiled"&&~candidateCompiled.metadata.fallback,"noSpeedRegression",speedup>=1/1.03,"noMemoryRegression",exactStorageRatio<=1.03&&peakRSSRatio<=1.03);
end
end

function value=backend(caseResult,identifier)
index=find(string({caseResult.backends.id})==identifier,1); if isempty(index), error("WaveVortexBenchmark:MissingModalBackend","Case %s is missing backend %s.",caseResult.id,identifier); end; value=caseResult.backends(index);
end

function markdown=summaryMarkdown(results)
lines=["# Compiled-kernel modal/vectorization benchmark";"";"- Status: `"+results.status+"`";"- Decision: **"+results.decision.outcome+"**";"- Selected candidate: `"+results.selectedCumulative.variantId+"` (`"+results.selectedCumulative.modalCoefficientMode+"`, `"+results.selectedCumulative.phaseImplementation+"`, "+results.selectedCumulative.modalWorkerCount+" modal workers)";"- Reason: "+results.decision.reason;"- Baseline commit: `"+results.source.baselineCommit+"`";"- Candidate commit: `"+results.source.candidateCommit+"`";"";"## Component screen";"";"| Variant | Versus pinned baseline | Versus component control | Target-stage speedup | Descriptor reduction | All-process direction | Included |";"|---|---:|---:|---:|---:|---:|---:|"];
for item=results.componentScreens', lines(end+1)=sprintf("| %s | %.3fx | %.3fx | %.3fx | %.1f%% | %s | %s |",item.variant.id,item.geometricMeanSpeedup,item.componentCallSpeedup,item.targetedStageSpeedup,100*item.minimumDescriptorReduction,string(item.beneficialDirectionPassed),string(item.beneficial)); end %#ok<AGROW>
lines=[lines;"";"## Qualification gate";"";"| Case | Baseline (ms) | Candidate (ms) | Speedup | Live ratio | Peak RSS ratio | Error |";"|---|---:|---:|---:|---:|---:|---:|"];
for item=results.gateCases', lines(end+1)=sprintf("| %s | %.3f | %.3f | %.3fx | %.3f | %.3f | %.3g |",item.id,1e3*item.baseline.medianSeconds,1e3*item.candidate.medianSeconds,item.speedup,item.exactStorageRatio,item.peakRSSRatio,item.candidate.maximumRelativeError); end %#ok<AGROW>
lines=[lines;"";"## Candidate stage budget";"";"| Case | Phase (ms) | Reconstruction (ms) | Derivatives (ms) | Products (ms) | Projection (ms) |";"|---|---:|---:|---:|---:|---:|"];
for item=results.gateCases', metrics=item.candidate.metrics; lines(end+1)=sprintf("| %s | %.3f | %.3f | %.3f | %.3f | %.3f |",item.id,1e3*metrics.phaseSeconds,1e3*metrics.reconstructionSeconds,1e3*metrics.derivativeReconstructionSeconds,1e3*metrics.productSeconds,1e3*metrics.projectionSeconds); end %#ok<AGROW>
lines=[lines;"";"## Modal-table storage";"";"| Case | Baseline tables (MiB) | Candidate tables (MiB) | Ratio | Reported descriptor (MiB) |";"|---|---:|---:|---:|---:|"];
for item=results.modalTableLedgers', lines(end+1)=sprintf("| %s | %.3f | %.3f | %.3f | %.3f |",item.caseId,item.baselineComparableBytes/2^20,item.candidateComparableBytes/2^20,item.comparableRatio,item.reportedDescriptorBytes/2^20); end %#ok<AGROW>
lines=[lines;"";"## Compiler evidence";"";"- Status: `"+results.compilerEvidence.status+"`";"- Flags: `"+results.compilerEvidence.flags+"`";"- Vectorized remarks: "+results.compilerEvidence.vectorizedRemarkCount;"- Missed-vectorization remarks: "+results.compilerEvidence.missedRemarkCount];
markdown=join(lines,newline)+newline;
end

function [commit,tree,isDirty]=gitIdentity(root)
[~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree]=system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); [~,status]=system(sprintf('git -C "%s" status --porcelain',root)); commit=string(strtrim(commit)); tree=string(strtrim(tree)); isDirty=strlength(strtrim(string(status)))>0;
end

function records=sourceHashRecords(repositoryRoot)
paths=["CompiledKernel/include/WaveVortexKernel/WVKernelTypes.hpp" "CompiledKernel/src/WVKernelTypes.cpp" "CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" "Benchmarks/compiled-kernel/wv_compiled_transform_mex.cpp"];
records=repmat(struct("path","","sha256",""),numel(paths),1);
for iPath=1:numel(paths)
    pathname=fullfile(repositoryRoot,paths(iPath)); [status,output]=system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname));
    if status~=0, error("WaveVortexBenchmark:SourceHashFailed","Unable to hash %s.",pathname); end
    fields=split(strtrim(string(output))); records(iPath)=struct("path",paths(iPath),"sha256",fields(1));
end
end

function value=benchmarkMatlabPath(repositoryRoot,baselineRoot)
entries=string(strsplit(path,pathsep)); selected=~contains(lower(entries),"wave-vortex-model")&~contains(lower(entries),"wavevortexmodel-")&~startsWith(entries,baselineRoot)&~startsWith(entries,repositoryRoot); value=strjoin(entries(selected),pathsep);
end

function removeTemporaryWorktree(repositoryRoot,baselineRoot,temporaryRoot)
system(sprintf('git -C "%s" worktree remove --force "%s"',repositoryRoot,baselineRoot)); if isfolder(temporaryRoot), rmdir(temporaryRoot,"s"); end
end

function writeText(pathname,contents)
fileId=fopen(pathname,"w"); if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s",pathname); end; cleanup=onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function value=conditional(condition,trueValue,falseValue)
if condition, value=trueValue; else, value=falseValue; end
end

function value=geomeanPositive(values)
value=exp(mean(log(values(values>0&isfinite(values)))));
end

function value=emptyGateCase
value=struct("id","","Nxyz",[],"isHydrostatic",false,"status","failed","baseline",struct(),"candidate",struct(),"speedup",NaN,"exactStorageRatio",NaN,"peakRSSRatio",NaN,"correctnessPassed",false,"implementationExecuted",false,"noSpeedRegression",false,"noMemoryRegression",false);
end

function value=emptyScreen
value=struct("status","failed","variant",variant("","scalar","prescaled","default",1),"cases",repmat(emptyGateCase(),0,1),"geometricMeanSpeedup",NaN,"maximumRegression",NaN,"minimumDescriptorReduction",NaN,"modalStageShare",[],"componentCallSpeedup",NaN,"targetedStageSpeedup",NaN,"beneficialDirectionPassed",false,"beneficial",false,"reason","");
end

function value=skippedScreen(definition,reason)
value=emptyScreen(); value.status="skipped"; value.variant=definition; value.reason=reason;
end
