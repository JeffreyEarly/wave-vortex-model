function results = runCompiledKernelDenseEngineBenchmark(options)
% Screen PFFFT and Accelerate/vDSP against the selected native FFTW pipeline.
arguments
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [256 256 65; 512 512 129]
    options.channelCounts (1,:) double {mustBeInteger,mustBePositive} = [3 4]
    options.workerCount (1,1) double {mustBeInteger,mustBePositive} = 18
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 1
    options.sampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.seed (1,1) double {mustBeInteger,mustBeNonnegative} = 129
    options.errorTolerance (1,1) double {mustBeNonnegative} = 1e-12
    options.advanceSpeedup (1,1) double {mustBeGreaterThan(options.advanceSpeedup,1)} = 1.10
    options.outputRoot (1,1) string = fullfile(fileparts(mfilename("fullpath")),"results","experiments","issue129")
    options.runId (1,1) string = ""
    options.shouldWriteArtifacts (1,1) logical = true
    options.buildOptions (1,1) struct = struct
end
if any(options.sizes(:,1) ~= options.sizes(:,2)) || any(2.^round(log2(options.sizes(:,1))) ~= options.sizes(:,1))
    error("WaveVortexModel:DenseEngineSizes","Issue #129 requires square power-of-two horizontal grids.");
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
if strlength(options.runId) == 0, options.runId = string(datetime("now",TimeZone="UTC",Format="yyyyMMdd'T'HHmmssSSS'Z'"))+"-"+computer("arch")+"-r"+lower(string(version("-release"))); end
runDirectory = fullfile(options.outputRoot,options.runId);
if options.shouldWriteArtifacts
    if isfolder(runDirectory), error("WaveVortexModel:DenseEngineOutputExists","Output already exists at %s.",runDirectory); end
    mkdir(runDirectory);
else
    runDirectory = string(tempname); mkdir(runDirectory);
    temporaryCleanup = onCleanup(@()rmdir(runDirectory,"s"));
end
build = buildWithOptions(options.buildOptions);
[commit,tree,isDirty] = repositoryIdentity(repositoryRoot);
results = struct("schemaVersion","1.0.0","status","running","runId",options.runId,"generatedAtUTC",utcTimestamp,"completedAtUTC","","environment",environmentRecord,"source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"isDirty",isDirty,"baselineCommit","be0f78995c49a2bfe4c43d75827856e3812ac278","sourceSha256",build.sourceSha256),"configuration",struct("sizes",options.sizes,"channelCounts",options.channelCounts,"workerCount",options.workerCount,"warmupCount",options.warmupCount,"sampleCount",options.sampleCount,"seed",options.seed,"errorTolerance",options.errorTolerance,"advanceSpeedup",options.advanceSpeedup,"screenBoundary","complete preallocated batched horizontal r2c/c2r pipeline including all provider-required packing, reorder, split/interleaved conversion, scaling, workspace access, and worker lifecycle"),"build",build,"runs",repmat(emptyRun,0,1),"assessment",struct,"decision",struct,"failure",struct);
activeStage = "screen";
try
    for iSize = 1:size(options.sizes,1)
        for channels = options.channelCounts
            sz = options.sizes(iSize,:); planes = sz(3)*channels;
            outputPath = fullfile(runDirectory,sprintf("screen-%dx%d-%dplanes.json",sz(1),sz(2),planes));
            command = shellQuote(build.executable)+" --nx "+sz(1)+" --ny "+sz(2)+" --planes "+planes+" --workers "+options.workerCount+" --warmups "+options.warmupCount+" --samples "+options.sampleCount+" --seed "+(options.seed+10*iSize+channels)+" --output "+shellQuote(outputPath);
            [status,output] = system(command);
            if status ~= 0, error("WaveVortexModel:DenseEngineExecutionFailed","The %dx%d, %d-channel screen failed: %s",sz(1),sz(2),channels,output); end
            record = jsondecode(fileread(outputPath)); delete(outputPath);
            results.runs(end+1,1) = summarizeRun(record,sz,channels);
        end
    end
    activeStage = "assessment";
    results.assessment = assess(results.runs,options);
    results.decision = decisionRecord(results.assessment);
    results.status = "passed"; results.completedAtUTC = utcTimestamp;
    if options.shouldWriteArtifacts, writeArtifacts(results,runDirectory); end
catch exception
    results.status="failed"; results.completedAtUTC=utcTimestamp; results.failure=struct("stage",activeStage,"identifier",string(exception.identifier),"message",string(exception.message),"stack",string({exception.stack.name}));
    if options.shouldWriteArtifacts, writeArtifacts(results,runDirectory); end
    rethrow(exception)
end
end

function build = buildWithOptions(options)
names = fieldnames(options); arguments = cell(1,2*numel(names));
for i=1:numel(names), arguments{2*i-1}=names{i}; arguments{2*i}=options.(names{i}); end
build = buildCompiledKernelDenseEngineScreen(arguments{:});
end

function run = summarizeRun(record,sz,channels)
engines = record.engines;
for i=1:numel(engines)
    engines(i).forwardMedianSeconds=median(engines(i).forwardSeconds);
    engines(i).inverseMedianSeconds=median(engines(i).inverseSeconds);
    engines(i).combinedMedianSeconds=sqrt(engines(i).forwardMedianSeconds*engines(i).inverseMedianSeconds);
end
control=engines(find(string({engines.id})=="native-fftw",1));
for i=1:numel(engines)
    engines(i).forwardSpeedup=control.forwardMedianSeconds/engines(i).forwardMedianSeconds;
    engines(i).inverseSpeedup=control.inverseMedianSeconds/engines(i).inverseMedianSeconds;
    engines(i).combinedSpeedup=control.combinedMedianSeconds/engines(i).combinedMedianSeconds;
    engines(i).maximumRelativeError=max(engines(i).forwardRelativeError,engines(i).inverseRelativeError);
    engines(i).knownMaximumLiveBytes=record.realBytes+record.halfSpectrumBytes+engines(i).workspaceBytes;
end
run=struct("size",sz,"channels",channels,"planes",record.planes,"workers",record.workers,"realBytes",record.realBytes,"halfSpectrumBytes",record.halfSpectrumBytes,"engines",engines);
end

function assessment = assess(runs,options)
ids=["pffft" "accelerate-vdsp"];
records=repmat(struct("engine","","advanced",false,"bestCommonSize",zeros(0,3),"minimumCommonSpeedup",NaN,"maximumRelativeError",NaN,"reason",""),numel(ids),1);
for i=1:numel(ids)
    id=ids(i); best=-Inf; bestSize=zeros(0,3); maxError=0;
    for iSize=1:size(options.sizes,1)
        matching=runs(arrayfun(@(r)isequal(r.size,options.sizes(iSize,:)),runs));
        speedups=zeros(numel(matching),1);
        for j=1:numel(matching), engine=matching(j).engines(find(string({matching(j).engines.id})==id,1)); speedups(j)=engine.combinedSpeedup; maxError=max(maxError,engine.maximumRelativeError); end
        common=min(speedups);
        if common>best, best=common; bestSize=options.sizes(iSize,:); end
    end
    records(i).engine=id; records(i).bestCommonSize=bestSize; records(i).minimumCommonSpeedup=best; records(i).maximumRelativeError=maxError;
    records(i).advanced=best>=options.advanceSpeedup && maxError<=options.errorTolerance;
    if records(i).advanced, records(i).reason="Complete transform pipeline cleared the 1.10x screen for both channel counts at one size."; else, records(i).reason="Complete transform pipeline did not clear the 1.10x screen for both channel counts at a common size."; end
end
assessment=struct("engines",records,"anyAdvanced",any([records.advanced]),"fullNonlinearFluxRunRequired",any([records.advanced]));
end

function decision = decisionRecord(assessment)
if assessment.anyAdvanced
    decision=struct("outcome","ADVANCE","reason","At least one dense engine cleared the transform-pipeline screen and requires the complete nonlinearFlux gate.");
else
    decision=struct("outcome","CORE-REJECT","reason","Neither PFFFT nor Accelerate/vDSP was at least 10% faster than selected native FFTW in the complete batched horizontal transform pipeline; no nonlinearFlux integration was warranted.");
end
end

function writeArtifacts(results,directory)
writeText(fullfile(directory,"dense-engine-benchmark.json"),jsonencode(results,PrettyPrint=true));
lines=["# Issue #129 dense 2-D FFT-engine screen";"";"Decision: **"+results.decision.outcome+"**";"";"| Size | Channels | Engine | Forward (ms) | Inverse (ms) | Combined speedup | Workspace (MiB) | Max error |";"|---|---:|---|---:|---:|---:|---:|---:|"];
for run=results.runs'
    for engine=run.engines'
        lines(end+1)=sprintf("| %d x %d x %d | %d | %s | %.3f | %.3f | %.3fx | %.3f | %.3g |",run.size(1),run.size(2),run.size(3),run.channels,engine.id,1e3*engine.forwardMedianSeconds,1e3*engine.inverseMedianSeconds,engine.combinedSpeedup,engine.workspaceBytes/2^20,engine.maximumRelativeError); %#ok<AGROW>
    end
end
lines=[lines;"";"## Assessment";"";"| Engine | Advanced | Best common size | Minimum common speedup | Max error | Reason |";"|---|:---:|---|---:|---:|---|"];
for record=results.assessment.engines', lines(end+1)=sprintf("| %s | %s | %s | %.3fx | %.3g | %s |",record.engine,yesNo(record.advanced),strjoin(string(record.bestCommonSize)," x "),record.minimumCommonSpeedup,record.maximumRelativeError,record.reason); end %#ok<AGROW>
lines=[lines;"";results.decision.reason;"";"The native control is FFTW 3.3.11 NEON/pthreads with 18 workers. PFFFT is the pinned maintained double-precision fork; vDSP uses the double split-complex radix-2 2-D pipeline. All conversion and worker costs are included."];
writeText(fullfile(directory,"summary.md"),join(lines,newline)+newline);
end

function value=yesNo(tf), if tf, value="yes"; else, value="no"; end, end
function writeText(pathname,value), fileId=fopen(pathname,"w"); if fileId<0,error("WaveVortexModel:ArtifactWriteFailed","Unable to write %s.",pathname);end;cleanup=onCleanup(@()fclose(fileId));fprintf(fileId,"%s",value);clear cleanup;end
function quoted=shellQuote(value), quoted="'"+replace(string(value),"'","'""'""'")+"'"; end
function value=utcTimestamp, value=string(datetime("now",TimeZone="UTC",Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")); end
function environment=environmentRecord, environment=struct("matlabVersion",string(version),"release",string(version("-release")),"architecture",string(computer("arch")),"operatingSystem",string(system_dependent("getos")),"processor",string(system_dependent("getcpu")),"hardwareThreads",maxNumCompThreads); end
function [commit,tree,isDirty]=repositoryIdentity(root), [a,commit]=system("git -C "+shellQuote(root)+" rev-parse HEAD");[b,tree]=system("git -C "+shellQuote(root)+" rev-parse HEAD^{tree}");[c,dirty]=system("git -C "+shellQuote(root)+" status --porcelain");if a~=0||b~=0||c~=0,error("WaveVortexModel:GitIdentity","Unable to inspect repository identity.");end;commit=string(strtrim(commit));tree=string(strtrim(tree));isDirty=strlength(strtrim(string(dirty)))>0;end
function value=emptyRun, value=struct("size",zeros(1,3),"channels",0,"planes",0,"workers",0,"realBytes",0,"halfSpectrumBytes",0,"engines",struct([])); end
