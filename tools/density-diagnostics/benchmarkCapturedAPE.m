function report = benchmarkCapturedAPE(inputPath,outputPath)
% Compare fixed-input APE kernels and operation costs against commit 7c26eca0.
% Configure the package dependencies first. Run without other MATLAB jobs.
arguments (Input)
    inputPath (1,1) string {mustBeFile}
    outputPath (1,1) string
end
arguments (Output)
    report (1,1) struct
end
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
referenceCommit = "7c26eca05561e1fda4e99f641080efc5f6a7a449";
referencePath = fullfile(root,"tools","density-diagnostics","APEReference7c26.m");
referenceText = string(fileread(referencePath));
referenceText = replace(referenceText,"classdef APEReference7c26","classdef WVNoMotionProfile");
referenceText = replace(referenceText,"function self = APEReference7c26(z,rho)","function self = WVNoMotionProfile(z,rho)");
referenceText = erase(referenceText,"    % Frozen benchmark reference from commit "+referenceCommit+"."+newline);
referenceText = erase(referenceText,"    % Only the class and constructor names differ from the original source."+newline);
[status,originalText] = system("git -C "+shellQuote(root)+" show "+referenceCommit+":Operations/@WVNoMotionProfile/WVNoMotionProfile.m");
assert(status==0 && referenceText==string(originalText),"The frozen APE reference differs from its pinned original source.");
sourcePaths = ["Operations/@WVNoMotionProfile/WVNoMotionProfile.m","Operations/APEOperation.m", ...
    "Operations/EtaTrueOperation.m","Operations/WVNoMotionProfileOperation.m", ...
    "tools/density-diagnostics/APEReference7c26.m","tools/density-diagnostics/benchmarkCapturedAPE.m"];
sources = sourceProvenance(root,sourcePaths);
report = struct(schema="wave-vortex-captured-ape-performance-v1",status="incomplete",referenceCommit=referenceCommit);
report.input = provenance(inputPath);
report.sourceSHA256 = sources;
report.matlabRelease = string(version("-release"));
report.platform = string(computer);
report.scope = "Three serial paired trials with alternating order after one warmup of each path. Fixed-profile kernel timing excludes profile construction. Operation timing includes construction and cached rho_nm/eta_true access; only the ape cache is cleared outside each operation timer. No integrations.";
report.referenceOperationInterpretation = "Frozen old profile constructor/kernel with the original APEOperation expressions and profile-selection branch. The current operation is the real public wvt.ape dispatch. Both include profile construction; the reference wrapper does not reproduce the public variable dispatch overhead.";
fprintf("APE_BENCHMARK_BEGIN %s\n",inputPath);
started = tic;
[wvt,file] = WVTransform.waveVortexTransformFromFile(char(inputPath),iTime=Inf,shouldReadOnly=true);
fileCleanup = onCleanup(@()file.close());
rho = wvt.rho_nm;
eta = wvt.eta_true;
Z = wvt.Z;
materialHeight = Z-eta;
g = wvt.g;
rho0 = wvt.rho0;
report.setupSeconds = toc(started);
report.grid = size(Z);
operation = wvt.operationWithName('rho_nm');
report.solver = operation.lastSolverOutput;
report.actualReferenceDefault = wvt.shouldUseTrueNoMotionProfile;
assert(report.actualReferenceDefault,"Use the actual-reference production default for the captured-state benchmark.");
original = APEReference7c26(wvt.z,rho);
current = WVNoMotionProfile(wvt.z,rho);
original.availablePotentialEnergy(Z,materialHeight,g,rho0);
current.availablePotentialEnergy(Z,materialHeight,g,rho0);
referenceOperation(wvt);
wvt.removeFromVariableCache('ape');
warmAPE = wvt.ape; %#ok<NASGU>

orders = [1,2;2,1;1,2];
kernelSeconds = zeros(3,2);
operationSeconds = zeros(3,2);
referenceKernel = [];
currentKernel = [];
referenceFullOperation = [];
currentFullOperation = [];
for trial = 1:3
    for implementation = orders(trial,:)
        started = tic;
        if implementation==1
            referenceKernel = original.availablePotentialEnergy(Z,materialHeight,g,rho0);
        else
            currentKernel = current.availablePotentialEnergy(Z,materialHeight,g,rho0);
        end
        kernelSeconds(trial,implementation) = toc(started);
    end
end
for trial = 1:3
    for implementation = orders(trial,:)
        wvt.removeFromVariableCache('ape');
        started = tic;
        if implementation==1
            referenceFullOperation = referenceOperation(wvt);
        else
            currentFullOperation = wvt.ape;
        end
        operationSeconds(trial,implementation) = toc(started);
    end
end
report.trialOrders = orders;
report.trialColumns = ["original7c26","currentProduction"];
report.kernel = timingSummary(kernelSeconds);
report.operation = timingSummary(operationSeconds);
report.kernelComparison = compareArrays(currentKernel,referenceKernel);
report.operationComparison = compareArrays(currentFullOperation,referenceFullOperation);
report.currentOperationMatchesKernel = isequal(currentFullOperation,currentKernel);
report.referenceOperationMatchesKernel = isequal(referenceFullOperation,referenceKernel);
report.fixedStatePreserved = isequal(wvt.rho_nm,rho) && isequal(wvt.eta_true,eta);
indices = unique(round(linspace(1,numel(Z),257))).';
report.capturedSamples = struct(linearIndex=indices,z=Z(indices),materialHeight=materialHeight(indices), ...
    referenceAPE=referenceKernel(indices),currentAPE=currentKernel(indices));

% Small representable displacements and multiple-interval crossings use the
% same captured profile, independently of which tiny values occur in it.
knots = wvt.z(:);
centers = knots([2,round(numel(knots)/2),end-1]);
probeZ = [];
probeMaterialHeight = [];
for center = centers.'
    gap = min(center-knots(1),knots(end)-center);
    increments = [0,eps(center),-eps(center),1e-10,-1e-10,.25*gap,-.25*gap];
    probeZ = [probeZ,center+increments]; %#ok<AGROW>
    probeMaterialHeight = [probeMaterialHeight,repmat(center,size(increments))]; %#ok<AGROW>
end
probeZ = [probeZ,knots(1),knots(end)];
probeMaterialHeight = [probeMaterialHeight,knots(end),knots(1)];
referenceProbe = original.availablePotentialEnergy(probeZ,probeMaterialHeight,g,rho0);
currentProbe = current.availablePotentialEnergy(probeZ,probeMaterialHeight,g,rho0);
report.probes = struct(z=probeZ,materialHeight=probeMaterialHeight,referenceAPE=referenceProbe,currentAPE=currentProbe,comparison=compareArrays(currentProbe,referenceProbe));
assert(isequal(sources,sourceProvenance(root,sourcePaths)),"APE benchmark sources changed during timing.");
comparisons = [report.kernelComparison,report.operationComparison,report.probes.comparison];
passed = all([comparisons.accepted]) && report.fixedStatePreserved ...
    && report.currentOperationMatchesKernel && report.referenceOperationMatchesKernel;
if passed
    report.status = "passed";
else
    report.status = "failed";
end
folder = fileparts(outputPath);
if ~isfolder(folder)
    mkdir(folder);
end
stream = fopen(outputPath,"w");
assert(stream>=0,"Cannot open the captured APE benchmark report.");
streamCleanup = onCleanup(@()fclose(stream));
fprintf(stream,"%s\n",jsonencode(report,PrettyPrint=true));
fprintf("APE_BENCHMARK_COMPLETE grid=%s status=%s kernelMedians=%s operationMedians=%s operationSpeedup=%.6g maxAbs=%.6g scaledRelative=%.6g\n", ...
    mat2str(report.grid),report.status,mat2str(report.kernel.medianSeconds,6),mat2str(report.operation.medianSeconds,6), ...
    report.operation.medianSpeedup,report.operationComparison.maximumAbsoluteDifference,report.operationComparison.maximumScaledRelativeDifference);
assert(passed,"APE benchmark numerical acceptance failed; inspect the retained report.");
end

function ape = referenceOperation(wvt)
if wvt.shouldUseTrueNoMotionProfile
    rho = wvt.rho_nm;
else
    rho = wvt.rho_nm0;
end
profile = APEReference7c26(wvt.z,rho);
materialHeight = wvt.Z-wvt.eta_true;
ape = profile.availablePotentialEnergy(wvt.Z,materialHeight,wvt.g,wvt.rho0);
end

function summary = timingSummary(seconds)
summary = struct(trialSeconds=seconds,medianSeconds=median(seconds,1),minimumSeconds=min(seconds,[],1), ...
    maximumSeconds=max(seconds,[],1),pairedSpeedups=seconds(:,1)./seconds(:,2));
summary.medianSpeedup = summary.medianSeconds(1)/summary.medianSeconds(2);
end

function comparison = compareArrays(current,reference)
peak = max(abs(reference),[],"all");
floor = max(1e-24,peak*1e-12);
difference = abs(current-reference);
comparison = struct(allFinite=all(isfinite(current),"all") && all(isfinite(reference),"all"), ...
    bitwiseEqual=isequal(current,reference),maximumAbsoluteDifference=max(difference,[],"all"), ...
    relativeFloor=floor,maximumScaledRelativeDifference=max(difference./max(abs(reference),floor),[],"all"), ...
    referenceNegativeCount=nnz(reference<0),currentNegativeCount=nnz(current<0), ...
    zeroMaskDifferenceCount=nnz((current==0)~=(reference==0)),referencePeak=peak);
comparison.absoluteTolerance = 128*eps(max(peak,realmin));
comparison.scaledRelativeTolerance = 1e-11;
comparison.accepted = comparison.allFinite && comparison.currentNegativeCount==0 ...
    && comparison.maximumAbsoluteDifference<=comparison.absoluteTolerance ...
    && comparison.maximumScaledRelativeDifference<=comparison.scaledRelativeTolerance;
end

function entries = sourceProvenance(root,paths)
entries = repmat(struct(path="",sha256=""),numel(paths),1);
for index = 1:numel(paths)
    entry = provenance(fullfile(root,paths(index)));
    entry.path = paths(index);
    entries(index) = entry;
end
end

function entry = provenance(path)
[status,digest] = system("shasum -a 256 "+shellQuote(path));
assert(status==0,"Cannot hash the APE benchmark source or input.");
entry = struct(path=path,sha256=string(extractBefore(digest," ")));
end

function quoted = shellQuote(value)
quote = string(char(39));
quoted = quote+replace(value,quote,string(char([39,34,39,34,39])))+quote;
end
