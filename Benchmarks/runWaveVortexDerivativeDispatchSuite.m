function suiteResult = runWaveVortexDerivativeDispatchSuite(suite,backends,correctnessTolerance,repositoryRoot)
% Benchmark complete spatial-derivative implementations and select dispatch.
arguments
    suite (1,1) struct
    backends (1,:) struct
    correctnessTolerance (1,1) double {mustBePositive} = 1e-12
    repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
metadata = struct( ...
    "schema","derivative-dispatch-v1", ...
    "selectionThreshold",1.10, ...
    "correctnessTolerance",correctnessTolerance, ...
    "steadyStateExcludesPlanning",true, ...
    "matlabCopyObservation","unavailable", ...
    "matlabCopyObservationReason","No supported MATLAB API exposes MATLAB FFT work-buffer or copy-on-write allocation state.", ...
    "productionSources",productionSourceRecords(repositoryRoot));
suiteResult = struct("id",suite.id,"version",suite.version,"kind",suite.kind,"description",suite.description,"operation",suite.operation,"isScored",suite.isScored,"selectionIsComplete",suite.selectionIsComplete,"status","complete","cases",emptyCases(),"familyScores",emptyScores(),"suiteScores",emptyScores(),"referenceArtifact","","metadata",metadata);
for iCase = 1:numel(suite.cases)
    try
        if string(getenv("WVM_DERIVATIVE_DISPATCH_WORKER")) == "1" || suite.cases(iCase).Nxyz(1) >= 512
            caseResult = runCase(suite.cases(iCase),backends,correctnessTolerance);
        else
            caseResult = runCaseInFreshProcess(suite.cases(iCase),backends,correctnessTolerance,repositoryRoot);
        end
        suiteResult.cases(end+1) = caseResult; %#ok<AGROW>
    catch exception
        suiteResult.cases(end+1) = failedCase(suite.cases(iCase),exception); %#ok<AGROW>
        suiteResult.status = "partial";
    end
end
end

function result = runCaseInFreshProcess(definition,backends,tolerance,repositoryRoot)
benchmarkFolder = string(fileparts(mfilename("fullpath")));
configPath = string(tempname) + ".json";
outputPath = string(tempname) + ".json";
config = struct("caseId",definition.id,"backendIds",string({backends.id}),"correctnessTolerance",tolerance,"repositoryRoot",repositoryRoot);
writeText(configPath,jsonencode(config));
cleanup = onCleanup(@()deleteTemporaryFiles([configPath outputPath]));
matlabExecutable = fullfile(matlabroot,"bin","matlab");
statement = "addpath('" + replace(repositoryRoot,"'","''") + "'); addpath('" + replace(benchmarkFolder,"'","''") + "'); waveVortexDerivativeDispatchCaseWorker('" + replace(configPath,"'","''") + "','" + replace(outputPath,"'","''") + "')";
command = sprintf('"%s" -batch "%s"',matlabExecutable,replace(statement,'"','\"'));
[exitCode,commandOutput] = system(command);
if exitCode ~= 0 || ~isfile(outputPath)
    error("WaveVortexBenchmark:DerivativeWorkerFailed","Derivative worker failed for %s: %s",definition.id,commandOutput);
end
result = jsondecode(fileread(outputPath));
clear cleanup
end

function caseResult = runCase(definition,backends,tolerance)
backendResults = emptyBackends();
for iBackend = 1:numel(backends)
    rng(definition.seed,"twister");
    timer = tic;
    model = createWaveVortexBenchmarkTransform(definition,backends(iBackend).id);
    constructionSeconds = toc(timer);
    runtime = createRuntime(model,backends(iBackend).id);
    runtimeCleanup = onCleanup(@()deleteRuntime(runtime,model));
    Apm = randn(model.spectralMatrixSize) + 1i*randn(model.spectralMatrixSize);
    A0 = randn(model.spectralMatrixSize) + 1i*randn(model.spectralMatrixSize);
    inputs = createInputs(model,Apm,A0);
    operationDefinitions = createOperations(definition.Nxyz,definition.isHydrostatic);
    backendResults(end+1) = runBackend(runtime,inputs,operationDefinitions,definition,tolerance,constructionSeconds); %#ok<AGROW>
    clear runtimeCleanup model runtime inputs Apm A0
end
caseResult = struct("id",definition.id,"transformId",definition.transformId,"scoreFamily",definition.scoreFamily,"operation",definition.operation,"Lxyz",definition.Lxyz,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"status","complete","failure",emptyFailure(),"backends",backendResults);
end

function runtime = createRuntime(model,backendId)
runtime = struct("model",model,"backendId",backendId,"xPlan",[],"yPlan",[],"planConstructionSeconds",struct("x",0,"y",0));
if backendId ~= "fftw"
    return
end
timer = tic;
runtime.xPlan = RealToComplexTransform(model.spatialMatrixSize,dims=1,planner="measure",alignmentMode="unaligned",plannerTimeLimitSeconds=10);
runtime.planConstructionSeconds.x = toc(timer);
timer = tic;
runtime.yPlan = RealToComplexTransform(model.spatialMatrixSize,dims=2,planner="measure",alignmentMode="unaligned",plannerTimeLimitSeconds=10);
runtime.planConstructionSeconds.y = toc(timer);
end

function inputs = createInputs(model,Apm,A0)
F = model.transformToSpatialDomainWithF(Apm=Apm,A0=A0);
G = model.transformToSpatialDomainWithG(Apm=Apm,A0=A0);
inputs = struct("Apm",Apm,"A0",A0,"F",F,"G",G);
end

function definitions = createOperations(Nxyz,isHydrostatic)
orders = 1:4;
if Nxyz(1) >= 256
    orders = 1;
end
definitions = emptyOperationDefinitions();
for n = orders
    definitions(end+1) = operation("diffX-"+n,"horizontal-x",n,"F"); %#ok<AGROW>
    definitions(end+1) = operation("diffY-"+n,"horizontal-y",n,"F"); %#ok<AGROW>
    definitions(end+1) = operation("diffZF-"+n,"vertical-f",n,"F"); %#ok<AGROW>
    definitions(end+1) = operation("diffZG-"+n,"vertical-g",n,"G"); %#ok<AGROW>
end
definitions(end+1) = operation("F-all-derivatives","all-f",1,"F"); %#ok<AGROW>
definitions(end+1) = operation("G-all-derivatives","all-g",1,"G"); %#ok<AGROW>
for iDefinition = 1:numel(definitions)
    definitions(iDefinition).isHydrostatic = isHydrostatic;
end
end

function definition = operation(id,kind,order,inputId)
definition = struct("id",id,"kind",kind,"order",order,"inputId",inputId,"isHydrostatic",false);
end

function result = runBackend(runtime,inputs,operations,definition,tolerance,constructionSeconds)
operationResults = emptyOperations();
for operationDefinition = operations
    candidateIds = candidatesFor(runtime.backendId,operationDefinition.kind);
    validations = validateCandidates(runtime,inputs,operationDefinition,candidateIds,tolerance);
    pairs = 1:numel(candidateIds);
    warmupSchedules = strings(definition.warmupCount,numel(pairs));
    for iWarmup = 1:definition.warmupCount
        order = rotatedOrder(numel(pairs),iWarmup);
        warmupSchedules(iWarmup,:) = candidateIds(order);
        for iCandidate = order
            execute(runtime,inputs,operationDefinition,candidateIds(iCandidate));
        end
    end
    rawSeconds = NaN(numel(candidateIds),definition.sampleCount);
    sampleSchedules = strings(definition.sampleCount,numel(pairs));
    for iSample = 1:definition.sampleCount
        order = rotatedOrder(numel(pairs),iSample);
        sampleSchedules(iSample,:) = candidateIds(order);
        for iCandidate = order
            timer = tic;
            execute(runtime,inputs,operationDefinition,candidateIds(iCandidate));
            rawSeconds(iCandidate,iSample) = toc(timer);
        end
    end
    candidates = emptyCandidates();
    for iCandidate = 1:numel(candidateIds)
        samples = rawSeconds(iCandidate,:);
        candidates(end+1) = struct("id",candidateIds(iCandidate),"rawSeconds",samples,"medianSeconds",median(samples),"relativeError",validations(iCandidate).relativeError,"correctnessPassed",validations(iCandidate).relativeError <= tolerance,"memory",memoryRecord(runtime,operationDefinition,candidateIds(iCandidate))); %#ok<AGROW>
    end
    selection = selectCandidate(candidates,baselineFor(operationDefinition.kind));
    operationResults(end+1) = struct("id",operationDefinition.id,"kind",operationDefinition.kind,"derivativeOrder",operationDefinition.order,"warmupSchedules",warmupSchedules,"sampleSchedules",sampleSchedules,"candidates",candidates,"selection",selection); %#ok<AGROW>
end
result = struct("id",runtime.backendId,"constructionSeconds",constructionSeconds,"planConstructionSeconds",runtime.planConstructionSeconds,"operations",operationResults,"verticalTransformDispatch",runtime.model.verticalTransform.dispatchRecords());
end

function ids = candidatesFor(backendId,kind)
switch kind
    case {"horizontal-x","horizontal-y"}
        ids = "matlab-1d";
        if backendId == "fftw"
            ids = [ids "fftw-1d" "fftw-2d"];
        end
    case {"vertical-f","vertical-g"}
        ids = ["dense-matrix" "fft-extension"];
        if backendId == "fftw"
            ids = [ids "eligibility-r2r"];
        end
    case {"all-f","all-g"}
        ids = ["composed-current" "modal-direct"];
    otherwise
        error("WaveVortexBenchmark:UnknownDerivativeKind","Unknown derivative kind %s.",kind);
end
end

function validations = validateCandidates(runtime,inputs,definition,candidateIds,tolerance)
reference = referenceOutput(runtime,inputs,definition);
validations = repmat(struct("relativeError",NaN),1,numel(candidateIds));
for iCandidate = 1:numel(candidateIds)
    output = execute(runtime,inputs,definition,candidateIds(iCandidate));
    errorValue = outputError(reference,output);
    validations(iCandidate).relativeError = errorValue;
end
end

function output = referenceOutput(runtime,inputs,definition)
switch definition.kind
    case "horizontal-x"
        output = matlabHorizontal(runtime.model,inputs.(definition.inputId),1,definition.order);
    case "horizontal-y"
        output = matlabHorizontal(runtime.model,inputs.(definition.inputId),2,definition.order);
    case "vertical-f"
        output = denseVertical(runtime.model,inputs.F,"F",definition.order);
    case "vertical-g"
        output = denseVertical(runtime.model,inputs.G,"G",definition.order);
    case "all-f"
        output = referenceComposedAll(runtime.model,inputs,"F");
    case "all-g"
        output = referenceComposedAll(runtime.model,inputs,"G");
end
end

function output = execute(runtime,inputs,definition,candidateId)
switch definition.kind
    case {"horizontal-x","horizontal-y"}
        dimension = conditional(definition.kind == "horizontal-x",1,2);
        input = inputs.(definition.inputId);
        switch candidateId
            case "matlab-1d"
                output = matlabHorizontal(runtime.model,input,dimension,definition.order);
            case "fftw-1d"
                output = fftwOneDimensional(runtime,input,dimension,definition.order);
            case "fftw-2d"
                output = fftwTwoDimensional(runtime.model,input,dimension,definition.order);
        end
    case {"vertical-f","vertical-g"}
        family = conditional(definition.kind == "vertical-f","F","G");
        input = inputs.(family);
        switch candidateId
            case "dense-matrix"
                output = denseVertical(runtime.model,input,family,definition.order);
            case "fft-extension"
                output = fftExtensionVertical(runtime.model,input,family,definition.order);
            case "eligibility-r2r"
                if family == "F"
                    output = runtime.model.diffZF(input,n=definition.order);
                else
                    output = runtime.model.diffZG(input,n=definition.order);
                end
        end
    case "all-f"
        if candidateId == "composed-current"
            output = composedAll(runtime,inputs,"F");
        else
            output = modalAll(runtime.model,inputs,"F");
        end
    case "all-g"
        if candidateId == "composed-current"
            output = composedAll(runtime,inputs,"G");
        else
            output = modalAll(runtime.model,inputs,"G");
        end
end
end

function output = matlabHorizontal(model,input,dimension,n)
if dimension == 1
    output = ifft((1i*model.k_dft).^n.*fft(input,model.Nx,1),model.Nx,1,"symmetric");
else
    output = ifft((1i*shiftdim(model.l_dft,-1)).^n.*fft(input,model.Ny,2),model.Ny,2,"symmetric");
end
end

function output = fftwOneDimensional(runtime,input,dimension,n)
plan = runtime.xPlan;
N = runtime.model.Nx;
L = runtime.model.Lx;
if dimension == 2
    plan = runtime.yPlan;
    N = runtime.model.Ny;
    L = runtime.model.Ly;
end
spectrum = plan.transformForward(input);
modes = (0:floor(N/2))';
if mod(N,2) == 0 && mod(n,2) == 1
    modes(end) = 0;
end
multiplier = (1i*2*pi*modes/L).^n;
shape = ones(1,numel(plan.complexSize));
shape(dimension) = numel(multiplier);
spectrum = reshape(multiplier,shape).*spectrum;
output = zeros(plan.realSize);
[spectrum,output] = plan.transformBackIntoArrayDestructive(spectrum,output);
output = plan.scaleFactor*output;
end

function output = fftwTwoDimensional(model,input,dimension,n)
coefficients = model.transformFromSpatialDomainWithFourier(input);
multiplier = model.k;
if dimension == 2
    multiplier = model.l;
end
output = model.transformToSpatialDomainWithFourier((1i*multiplier.').^n.*coefficients);
end

function output = denseVertical(model,input,family,n)
rows = reshape(permute(input,[3 1 2]),model.Nz,[]);
m = pi*model.j/model.Lz;
if family == "F"
    signs = [-1 -1 1 1];
    coefficients = model.DCT*rows;
    if mod(n,2) == 0
        rows = model.iDCT*(signs(n)*(m.^n).*coefficients);
    else
        rows = model.iDST*(signs(n)*(m.^n).*coefficients);
    end
else
    signs = [1 -1 -1 1];
    coefficients = model.DST*rows;
    if mod(n,2) == 0
        rows = model.iDST*(signs(n)*(m.^n).*coefficients);
    else
        rows = model.iDCT*(signs(n)*(m.^n).*coefficients);
    end
end
output = permute(reshape(rows,model.Nz,model.Nx,model.Ny),[2 3 1]);
end

function output = fftExtensionVertical(model,input,family,n)
rows = reshape(permute(input,[3 1 2]),model.Nz,[]);
if family == "F"
    extension = [rows;flip(rows(2:end-1,:),1)];
else
    extension = [rows;-flip(rows(2:end-1,:),1)];
end
N = 2*(model.Nz-1);
modes = [0:ceil(N/2)-1 -floor(N/2):-1]';
multiplier = (1i*pi*modes/model.Lz).^n;
extension = ifft(multiplier.*fft(extension,N,1),N,1,"symmetric");
rows = extension(1:model.Nz,:);
if family == "G" && mod(n,2) == 0 || family == "F" && mod(n,2) == 1
    rows([1 end],:) = 0;
end
output = permute(reshape(rows,model.Nz,model.Nx,model.Ny),[2 3 1]);
end

function output = composedAll(runtime,inputs,family)
model = runtime.model;
if family == "F"
    field = model.transformToSpatialDomainWithF(Apm=inputs.Apm,A0=inputs.A0);
    z = model.diffZF(field);
else
    field = model.transformToSpatialDomainWithG(Apm=inputs.Apm,A0=inputs.A0);
    z = model.diffZG(field);
end
if WVSpatialDerivativeDispatch.implementation(runtime.backendId,"diffX",[model.Nx model.Ny model.Nz],1,model.isHydrostatic) == "fftw-1d"
    x = fftwOneDimensional(runtime,field,1,1);
else
    x = matlabHorizontal(model,field,1,1);
end
y = model.diffY(field);
output = {field,x,y,z};
end

function output = referenceComposedAll(model,inputs,family)
if family == "F"
    field = model.transformToSpatialDomainWithF(Apm=inputs.Apm,A0=inputs.A0);
    z = denseVertical(model,field,"F",1);
else
    field = model.transformToSpatialDomainWithG(Apm=inputs.Apm,A0=inputs.A0);
    z = denseVertical(model,field,"G",1);
end
x = matlabHorizontal(model,field,1,1);
y = matlabHorizontal(model,field,2,1);
output = {field,x,y,z};
end

function output = modalAll(model,inputs,family)
if family == "F"
    coefficients = model.F_g .* (inputs.Apm./model.F_wg + inputs.A0);
    fieldBar = model.verticalTransform.transformBack(coefficients,"cosine",model.iDCT);
    zBar = model.verticalTransform.transformBack((-pi*model.j/model.Lz).*coefficients,"sine",model.iDST);
else
    coefficients = model.G_g .* (inputs.Apm./model.G_wg + inputs.A0);
    fieldBar = model.verticalTransform.transformBack(coefficients,"sine",model.iDST);
    zBar = model.verticalTransform.transformBack((pi*model.j/model.Lz).*coefficients,"cosine",model.iDCT);
end
[field,x,y] = model.fastTransform.transformToSpatialDomainWithFourierAndDerivatives(fieldBar);
z = model.transformToSpatialDomainWithFourier(zBar);
output = {field,x,y,z};
end

function value = outputError(reference,output)
if iscell(reference)
    values = zeros(1,numel(reference));
    for iValue = 1:numel(reference)
        values(iValue) = relativeError(reference{iValue},output{iValue});
    end
    value = max(values);
else
    value = relativeError(reference,output);
end
end

function value = relativeError(reference,candidate)
denominator = max(abs(reference(:)));
if denominator == 0
    denominator = 1;
end
value = max(abs(reference(:)-candidate(:)))/denominator;
end

function selection = selectCandidate(candidates,baselineId)
valid = [candidates.correctnessPassed] & arrayfun(@(candidate)candidate.memory.selectionPassed,candidates);
validCandidates = candidates(valid);
[fastestSeconds,index] = min([validCandidates.medianSeconds]);
fastestId = validCandidates(index).id;
baseline = candidates(string({candidates.id}) == baselineId);
speedup = baseline.medianSeconds/fastestSeconds;
selected = baselineId;
if speedup >= 1.10
    selected = fastestId;
end
selection = struct("baseline",baselineId,"strictFastest",fastestId,"strictFastestSeconds",fastestSeconds,"baselineSeconds",baseline.medianSeconds,"speedup",speedup,"threshold",1.10,"selected",selected,"adopted",selected ~= baselineId);
end

function id = baselineFor(kind)
if startsWith(kind,"horizontal")
    id = "matlab-1d";
elseif startsWith(kind,"vertical")
    id = "dense-matrix";
else
    id = "composed-current";
end
end

function memory = memoryRecord(runtime,definition,candidateId)
N = prod(runtime.model.spatialMatrixSize);
outputCount = conditional(startsWith(definition.kind,"all-"),4,1);
knownTemporaryBytes = 0;
persistentArrayBytes = 0;
usesPreservingInverse = false;
hasPersistentFullSpectrum = false;
switch candidateId
    case "fftw-1d"
        plan = runtime.xPlan;
        if definition.kind == "horizontal-y"
            plan = runtime.yPlan;
        end
        knownTemporaryBytes = 16*prod(plan.complexSize) + 8*N;
    case "fftw-2d"
        knownTemporaryBytes = 16*runtime.model.Nz*runtime.model.Nkl + 8*N;
    case "fft-extension"
        knownTemporaryBytes = 16*2*(runtime.model.Nz-1)*runtime.model.Nx*runtime.model.Ny;
    case "eligibility-r2r"
        knownTemporaryBytes = 8*runtime.model.Nj*runtime.model.Nx*runtime.model.Ny + 8*N;
    case "modal-direct"
        knownTemporaryBytes = 16*runtime.model.Nz*runtime.model.Nkl + 8*outputCount*N;
    case "dense-matrix"
        knownTemporaryBytes = 8*runtime.model.Nj*runtime.model.Nx*runtime.model.Ny;
end
selectionPassed = ~usesPreservingInverse && ~hasPersistentFullSpectrum && persistentArrayBytes == 0;
memory = struct("resultBytes",8*outputCount*N,"knownTemporaryBytes",knownTemporaryBytes,"persistentArrayBytes",persistentArrayBytes,"usesPreservingInverse",usesPreservingInverse,"hasPersistentFullSpectrum",hasPersistentFullSpectrum,"matlabInternalBuffers","unresolved","selectionPassed",selectionPassed);
end

function records = productionSourceRecords(repositoryRoot)
paths = [ ...
    "FastTransforms/WVSpatialDerivativeDispatch.m", ...
    "FastTransforms/@WVFastTransformDoublyPeriodicFFTW/diffX.m", ...
    "FastTransforms/@WVFastTransformDoublyPeriodicFFTW/diffY.m", ...
    "@WVGeometryDoublyPeriodicStratifiedConstant/diffZF.m", ...
    "@WVGeometryDoublyPeriodicStratifiedConstant/diffZG.m", ...
    "@WVTransformConstantStratification/transformToSpatialDomainWithFAllDerivatives.m", ...
    "@WVTransformConstantStratification/transformToSpatialDomainWithGAllDerivatives.m"];
records = repmat(struct("path","","sha256",""),1,numel(paths));
for iPath = 1:numel(paths)
    pathname = fullfile(repositoryRoot,paths(iPath));
    records(iPath) = struct("path",paths(iPath),"sha256",sha256(pathname));
end
end

function digest = sha256(pathname)
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(uint8(fileread(pathname)));
digest = lower(join(compose("%02x",typecast(engine.digest(),"uint8")),""));
end

function deleteRuntime(runtime,model)
if ~isempty(runtime.xPlan) && isvalid(runtime.xPlan)
    delete(runtime.xPlan);
end
if ~isempty(runtime.yPlan) && isvalid(runtime.yPlan)
    delete(runtime.yPlan);
end
if ~isempty(model) && isvalid(model)
    delete(model);
end
end

function order = rotatedOrder(count,roundIndex)
shift = mod(roundIndex-1,count);
order = [shift+1:count 1:shift];
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function cases = emptyCases()
cases = struct("id",{},"transformId",{},"scoreFamily",{},"operation",{},"Lxyz",{},"Nxyz",{},"isHydrostatic",{},"shouldAntialias",{},"seed",{},"warmupCount",{},"sampleCount",{},"status",{},"failure",{},"backends",{});
end

function backends = emptyBackends()
backends = struct("id",{},"constructionSeconds",{},"planConstructionSeconds",{},"operations",{},"verticalTransformDispatch",{});
end

function operations = emptyOperations()
operations = struct("id",{},"kind",{},"derivativeOrder",{},"warmupSchedules",{},"sampleSchedules",{},"candidates",{},"selection",{});
end

function definitions = emptyOperationDefinitions()
definitions = struct("id",{},"kind",{},"order",{},"inputId",{},"isHydrostatic",{});
end

function candidates = emptyCandidates()
candidates = struct("id",{},"rawSeconds",{},"medianSeconds",{},"relativeError",{},"correctnessPassed",{},"memory",{});
end

function scores = emptyScores()
scores = struct("id",{},"backendId",{},"score",{});
end

function result = failedCase(definition,exception)
result = struct("id",definition.id,"transformId",definition.transformId,"scoreFamily",definition.scoreFamily,"operation",definition.operation,"Lxyz",definition.Lxyz,"Nxyz",definition.Nxyz,"isHydrostatic",definition.isHydrostatic,"shouldAntialias",definition.shouldAntialias,"seed",definition.seed,"warmupCount",definition.warmupCount,"sampleCount",definition.sampleCount,"status","failed","failure",exceptionFailure(exception),"backends",emptyBackends());
end

function failure = emptyFailure()
failure = struct("identifier","","message","","stack",strings(0,1));
end

function failure = exceptionFailure(exception)
stack = strings(numel(exception.stack),1);
for iFrame = 1:numel(exception.stack)
    stack(iFrame) = string(exception.stack(iFrame).name) + ":" + exception.stack(iFrame).line;
end
failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"stack",stack);
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to write %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end

function deleteTemporaryFiles(paths)
for pathname = paths
    if isfile(pathname)
        delete(pathname);
    end
end
end
