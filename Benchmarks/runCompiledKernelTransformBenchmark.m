function results = runCompiledKernelTransformBenchmark(options)
% Benchmark the issue #49/#50 fused transform and derivative boundary.
arguments
    options.sizes (:,3) double = [256 256 65; 512 512 129]
    options.hydrostatic (1,:) logical = [true false]
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.mediumSampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
    options.largeSampleCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = string(datetime("now","TimeZone","UTC","Format","yyyyMMdd'T'HHmmss'Z'"))
    options.shouldWriteArtifacts (1,1) logical = true
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
originalDirectory = pwd; originalPath = path; originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng));
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"));
gateway = buildCompiledKernelTransformMex;
addpath(fileparts(gateway));
if options.outputDirectory == ""
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","runs",options.runId+"-compiled-transforms-"+computer("arch")+"-"+version("-release"));
end

caseResults = repmat(emptyCase(),0,1);
for iSize = 1:size(options.sizes,1)
    for isHydrostatic = options.hydrostatic
        sampleCount = options.mediumSampleCount;
        if prod(options.sizes(iSize,:)) >= prod(options.sizes(end,:)), sampleCount = options.largeSampleCount; end
        caseResults(end+1,1) = runCase(options.sizes(iSize,:),isHydrostatic,options.threadCount,options.warmupCount,sampleCount); %#ok<AGROW>
    end
end
[commit,tree] = gitIdentity(repositoryRoot);
results = struct( ...
    "schemaVersion","1.0.0","status","complete","runId",options.runId, ...
    "environment",environmentRecord(options.threadCount), ...
    "source",struct("repository","JeffreyEarly/wave-vortex-model","commit",commit,"tree",tree,"gatewaySha256",sha256File(fullfile(repositoryRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp")),"coreSha256",sha256File(fullfile(repositoryRoot,"CompiledKernel","src","WVTransformConstantStratificationKernel.cpp"))), ...
    "configuration",struct("sizes",options.sizes,"hydrostatic",options.hydrostatic,"warmupCount",options.warmupCount,"mediumSampleCount",options.mediumSampleCount,"largeSampleCount",options.largeSampleCount,"correctnessTolerance",1e-12), ...
    "cases",caseResults);
if options.shouldWriteArtifacts
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writeText(fullfile(options.outputDirectory,"compiled-transform-benchmark.json"),jsonencode(results,PrettyPrint=true));
    writeText(fullfile(options.outputDirectory,"summary.md"),summaryMarkdown(results));
end
clear stateCleanup
end

function result = runCase(Nxyz,isHydrostatic,threadCount,warmupCount,sampleCount)
rng(9100 + sum(Nxyz) + isHydrostatic,"twister");
wvt = WVTransformConstantStratification([15000 15000 1300],Nxyz,isHydrostatic=isHydrostatic,shouldAntialias=true);
configuration = kernelConfiguration(wvt);
tic; handle = wv_compiled_transform_mex('create',configuration,threadCount); constructionSeconds = toc;
cleanup = onCleanup(@()deleteKernel(handle));
channels = 4-isHydrostatic;
fields = randn([wvt.spatialMatrixSize channels]);
if isHydrostatic
    referenceForward = @()matlabForwardHydrostatic(wvt,fields);
else
    referenceForward = @()matlabForwardNonhydrostatic(wvt,fields);
end
compiledForward = @()kernelForward(handle,fields,wvt.t,wvt.t0);
[Ap,Am,A0] = forwardValues(wvt,fields,isHydrostatic);
referenceInverse = @()matlabInverse(wvt,Ap,Am,A0);
compiledInverse = @()kernelInverse(handle,Ap,Am,A0,wvt.t,wvt.t0);
Apm = randn(wvt.spectralMatrixSize)+1i*randn(wvt.spectralMatrixSize);
A0Derivative = randn(wvt.spectralMatrixSize)+1i*randn(wvt.spectralMatrixSize);
referenceF = @()matlabFAll(wvt,Apm,A0Derivative); compiledF = @()kernelAll('fAll',handle,Apm,A0Derivative);
referenceG = @()matlabGAll(wvt,Apm,A0Derivative); compiledG = @()kernelAll('gAll',handle,Apm,A0Derivative);
operations = ["matlab-forward" "compiled-forward" "matlab-inverse" "compiled-inverse" "matlab-f-all" "compiled-f-all" "matlab-g-all" "compiled-g-all"];
actions = {referenceForward,compiledForward,referenceInverse,compiledInverse,referenceF,compiledF,referenceG,compiledG};
for iWarmup = 1:warmupCount, for iOperation = 1:numel(actions), actions{iOperation}(); end, end
samples = zeros(sampleCount,numel(actions));
for iSample = 1:sampleCount
    order = mod((0:numel(actions)-1)+(iSample-1),numel(actions))+1;
    for iOperation = order
        tic; actions{iOperation}(); samples(iSample,iOperation) = toc;
    end
end
[compiledAp,compiledAm,compiledA0] = wv_compiled_transform_mex('forward',handle,fields,wvt.t,wvt.t0);
compiledFields = wv_compiled_transform_mex('inverse',handle,Ap,Am,A0,wvt.t,wvt.t0);
[expectedU,expectedV,expectedW,expectedN] = wvt.transformWaveVortexToUVWEta(Ap,Am,A0,wvt.t);
[expectedF0,expectedFx,expectedFy,expectedFz] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=Apm,A0=A0Derivative);
[expectedG0,expectedGx,expectedGy,expectedGz] = wvt.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=A0Derivative);
compiledFValues = wv_compiled_transform_mex('fAll',handle,Apm,A0Derivative);
compiledGValues = wv_compiled_transform_mex('gAll',handle,Apm,A0Derivative);
errors = struct( ...
    "forward",max([relativeError(compiledAp,Ap) relativeError(compiledAm,Am) relativeError(compiledA0,A0)]), ...
    "inverse",relativeError(compiledFields,cat(4,expectedU,expectedV,expectedW,expectedN)), ...
    "fAll",relativeError(compiledFValues,cat(4,expectedF0,expectedFx,expectedFy,expectedFz)), ...
    "gAll",relativeError(compiledGValues,cat(4,expectedG0,expectedGx,expectedGy,expectedGz)));
metrics = wv_compiled_transform_mex('metrics',handle);
timings = repmat(struct("operation","","samplesSeconds",[],"medianSeconds",0),numel(operations),1);
for iOperation = 1:numel(operations), timings(iOperation) = struct("operation",operations(iOperation),"samplesSeconds",samples(:,iOperation)',"medianSeconds",median(samples(:,iOperation))); end
result = struct("id",caseId(Nxyz,isHydrostatic),"Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"Nj",wvt.Nj,"Nkl",wvt.Nkl,"sampleCount",sampleCount,"constructionSeconds",constructionSeconds,"timings",timings,"speedups",struct("forward",median(samples(:,1))/median(samples(:,2)),"inverse",median(samples(:,3))/median(samples(:,4)),"fAll",median(samples(:,5))/median(samples(:,6)),"gAll",median(samples(:,7))/median(samples(:,8))),"errors",errors,"metrics",metrics,"storage",struct("fullComplexBytes",16*prod(Nxyz),"halfSpectrumScratchBytes",metrics.scratchCapacityBytes,"persistentBytes",metrics.persistentBytes));
clear cleanup
end

function value = matlabForwardHydrostatic(wvt,fields), [Ap,Am,A0] = wvt.transformUVEtaToWaveVortex(fields(:,:,:,1),fields(:,:,:,2),fields(:,:,:,3)); value = real(Ap(1)+Am(1)+A0(1)); end
function value = matlabForwardNonhydrostatic(wvt,fields), [Ap,Am,A0] = wvt.transformUVWEtaToWaveVortex(fields(:,:,:,1),fields(:,:,:,2),fields(:,:,:,3),fields(:,:,:,4)); value = real(Ap(1)+Am(1)+A0(1)); end
function value = kernelForward(handle,fields,t,t0), [Ap,Am,A0] = wv_compiled_transform_mex('forward',handle,fields,t,t0); value = real(Ap(1)+Am(1)+A0(1)); end
function value = matlabInverse(wvt,Ap,Am,A0), [U,V,W,N] = wvt.transformWaveVortexToUVWEta(Ap,Am,A0,wvt.t); value = U(1)+V(1)+W(1)+N(1); end
function value = kernelInverse(handle,Ap,Am,A0,t,t0), fields = wv_compiled_transform_mex('inverse',handle,Ap,Am,A0,t,t0); value = sum(fields(1,1,1,:)); end
function value = matlabFAll(wvt,Apm,A0), [f,x,y,z] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=Apm,A0=A0); value = f(1)+x(1)+y(1)+z(1); end
function value = matlabGAll(wvt,Apm,A0), [f,x,y,z] = wvt.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=A0); value = f(1)+x(1)+y(1)+z(1); end
function value = kernelAll(command,handle,Apm,A0), fields = wv_compiled_transform_mex(char(command),handle,Apm,A0); value = sum(fields(1,1,1,:)); end

function [Ap,Am,A0] = forwardValues(wvt,fields,isHydrostatic)
if isHydrostatic, [Ap,Am,A0] = wvt.transformUVEtaToWaveVortex(fields(:,:,:,1),fields(:,:,:,2),fields(:,:,:,3)); else, [Ap,Am,A0] = wvt.transformUVWEtaToWaveVortex(fields(:,:,:,1),fields(:,:,:,2),fields(:,:,:,3),fields(:,:,:,4)); end
end
function value = relativeError(actual,expected), value = max(abs(actual(:)-expected(:)))/max(max(abs(expected(:))),realmin); end
function value = caseId(Nxyz,isHydrostatic), value = sprintf("%dx%dx%d-%s",Nxyz(1),Nxyz(2),Nxyz(3),string(conditional(isHydrostatic,"hydrostatic","nonhydrostatic"))); end
function value = conditional(condition,a,b), if condition, value=a; else, value=b; end, end
function result = emptyCase(), result = struct("id","","Nxyz",[],"isHydrostatic",false,"Nj",0,"Nkl",0,"sampleCount",0,"constructionSeconds",0,"timings",[],"speedups",struct,"errors",struct,"metrics",struct,"storage",struct); end
function configuration = kernelConfiguration(wvt), configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias); end
function record = environmentRecord(threads), record = struct("os",string(system_dependent("getos")),"processor",string(system_dependent("getcpu")),"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")),"threads",threads,"fftwLibrary",matlabBundledFFTWLibrary); end
function [commit,tree] = gitIdentity(root), [~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root)); [~,tree]=system(sprintf('git -C "%s" rev-parse HEAD^{tree}',root)); commit=string(strtrim(commit)); tree=string(strtrim(tree)); end
function hash = sha256File(pathname), [status,output]=system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname)); if status~=0,error("WaveVortexModel:HashFailure","Unable to hash %s",pathname);end; hash=extractBefore(string(strtrim(output))," "); end
function writeText(pathname,text), file=fopen(pathname,"w"); cleanup=onCleanup(@()fclose(file)); fprintf(file,"%s",text); clear cleanup; end
function deleteKernel(handle), try, wv_compiled_transform_mex('delete',handle); catch, end, end
function restoreState(directory,originalPath,originalRng), cd(directory); path(originalPath); rng(originalRng); end

function markdown = summaryMarkdown(results)
lines = ["# Compiled constant-stratification transform benchmark";"";"- Status: `"+results.status+"`";"- Source: `"+results.source.commit+"`";"- MATLAB: `"+results.environment.matlabRelease+"` on `"+results.environment.architecture+"`";"- FFTW: `"+results.environment.fftwLibrary+"`";"";"| Case | Forward speedup | Inverse speedup | F-all speedup | G-all speedup | Max error | Scratch MiB |";"|---|---:|---:|---:|---:|---:|---:|"];
for iCase = 1:numel(results.cases)
    item = results.cases(iCase);
    maximumError = max([item.errors.forward item.errors.inverse item.errors.fAll item.errors.gAll]);
    lines(end+1) = sprintf("| %s | %.3fx | %.3fx | %.3fx | %.3fx | %.3g | %.2f |",item.id,item.speedups.forward,item.speedups.inverse,item.speedups.fAll,item.speedups.gAll,maximumError,item.storage.halfSpectrumScratchBytes/2^20); %#ok<AGROW>
end
markdown = join(lines,newline)+newline;
end
