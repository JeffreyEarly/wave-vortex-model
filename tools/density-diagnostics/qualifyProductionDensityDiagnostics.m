function report = qualifyProductionDensityDiagnostics(inputPath,baselineDirectory,outputPath)
% Qualify the production default density pipeline on one captured state.
% No profile is injected and no diagnostic-selection flag is changed.
% Historical comparisons use retained aggregate measurements, not replayed
% legacy code or an assumption that the captured distribution is exact truth.
arguments (Input)
    inputPath (1,1) string {mustBeFile}
    baselineDirectory (1,1) string {mustBeFolder}
    outputPath (1,1) string
end
arguments (Output)
    report (1,1) struct
end
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
[~,name] = fileparts(inputPath);
day = extractAfter(name,"day");
legacyPath = fullfile(baselineDirectory,"calculus-"+day+".json");
solverPath = fullfile(baselineDirectory,name+"-report.json");
legacy = jsondecode(fileread(legacyPath));
historicalSolver = jsondecode(fileread(solverPath));
report = struct(schema="wave-vortex-production-density-qualification-v1",status="incomplete");
report.input = provenance(inputPath);
report.matlabRelease = string(version("-release"));
report.platform = string(computer);
[status,commit] = system("git -C "+shellQuote(root)+" rev-parse HEAD");
assert(status==0,"Cannot read the source revision.");
report.sourceCommit = string(strtrim(commit));
report.sourceSHA256 = sourceProvenance(root);
report.scope = "Restored captured states using the production default rho_nm, eta_true, ape and apv operations. No profile injection, flag override or integrations. Source hashes describe the actual files even when sourceCommit is a parent of uncommitted changes.";
fprintf("PRODUCTION_DENSITY_BEGIN %s\n",inputPath);

lastwarn("");
started = tic;
[wvt,file] = WVTransform.waveVortexTransformFromFile(char(inputPath),iTime=Inf,shouldReadOnly=true);
cleanup = onCleanup(@()file.close());
rho_total = wvt.rho_total;
report.timings.loadAndDensitySeconds = toc(started);
[warningMessage,warningID] = lastwarn;
report.lastLoadWarning = struct(identifier=string(warningID),message=string(warningMessage));
report.transform = string(class(wvt));
report.grid = wvt.spatialMatrixSize;
report.time = wvt.t;
report.actualReferenceDefault = wvt.shouldUseTrueNoMotionProfile;
operation = wvt.operationWithName('rho_nm');
report.selectedSolver = operation.solver;
assert(report.actualReferenceDefault,"The restored state did not select the actual no-motion reference by default.");
assert(report.selectedSolver=="dampedLeastSquares","The production operation did not select dampedLeastSquares.");

started = tic;
rho_nm = wvt.rho_nm;
report.timings.noMotionProfileSeconds = toc(started);
report.solver = operation.lastSolverOutput;
started = tic;
eta_true = wvt.eta_true;
report.timings.etaTrueSeconds = toc(started);
materialHeight = wvt.Z-eta_true;
profile = WVNoMotionProfile(wvt.z,rho_nm);
report.densityRange = [min(rho_total,[],"all"),max(rho_total,[],"all")];
report.noMotionRange = [min(rho_nm),max(rho_nm)];
report.materialHeightRange = [min(materialHeight,[],"all"),max(materialHeight,[],"all")];
report.densityClosureMaximum = max(abs(profile.density(materialHeight)-rho_total),[],"all");
report.meanDisplacement = volumeMean(eta_true,wvt.z_int,wvt.Lz);
report.maximumAbsoluteDisplacement = max(abs(eta_true),[],"all");
report.noMotionProfile = rho_nm;
report.weightSum = sum(wvt.z_int)/wvt.Lz;

% Independently evaluate the first four raw density moments of the returned
% public profile against the full state. This checks the diagnostic output,
% rather than relying exclusively on the optimizer's residual bookkeeping.
rho0 = wvt.rho_nm0(end);
rhoD = wvt.rho_nm0(1);
normalizedProfile = (rho_nm(:)-rho0)/(rhoD-rho0);
normalizedDensity = (rho_total-rho0)/(rhoD-rho0);
report.firstFourMomentResiduals = zeros(4,1);
for degree = 1:4
    fittedMoment = sum((wvt.z_int(:)/wvt.Lz).*normalizedProfile.^degree);
    report.firstFourMomentResiduals(degree) = fittedMoment-volumeMean(normalizedDensity.^degree,wvt.z_int,wvt.Lz);
end
clear normalizedDensity

started = tic;
ape = wvt.ape;
report.timings.apeSeconds = toc(started);
report.ape = fieldStatistics(ape,wvt.z_int,wvt.Lz);
started = tic;
apv = wvt.apv;
report.timings.apvSeconds = toc(started);
report.apv = fieldStatistics(apv,wvt.z_int,wvt.Lz);
report.timings.densityDiagnosticsSeconds = report.timings.noMotionProfileSeconds ...
    + report.timings.etaTrueSeconds+report.timings.apeSeconds+report.timings.apvSeconds;

closureTolerance = 8*eps(max(abs(rho_total),[],"all"));
heightTolerance = 16*eps(max(abs(wvt.z))+wvt.Lz);
report.acceptance = struct(maximumMomentResidual=1e-8,densityClosureTolerance=closureTolerance,materialHeightTolerance=heightTolerance);
report.checks = [
    struct(name="actual-reference-default",passed=logical(report.actualReferenceDefault))
    struct(name="damped-solver-success",passed=report.selectedSolver=="dampedLeastSquares" && report.solver.exitflag>0 && report.solver.maximumResidual<=report.acceptance.maximumMomentResidual && max(abs(report.firstFourMomentResiduals))<=report.acceptance.maximumMomentResidual)
    struct(name="ordered-profile",passed=all(isfinite(rho_nm)) && all(diff(rho_nm(:))<0))
    struct(name="bounded-material-height",passed=all(isfinite(eta_true),"all") && report.materialHeightRange(1)>=min(wvt.z)-heightTolerance && report.materialHeightRange(2)<=max(wvt.z)+heightTolerance)
    struct(name="density-closure",passed=all(isfinite(rho_total),"all") && report.densityClosureMaximum<=closureTolerance)
    struct(name="finite-nonnegative-ape",passed=report.ape.allFinite && report.ape.negativeCount==0)
    struct(name="finite-apv",passed=report.apv.allFinite)
    ];
report.historicalComparison = struct();
report.historicalComparison.sources = [provenance(legacyPath),provenance(solverPath)];
report.historicalComparison.scope = "Saved legacy calculus used an explicitly selected actual-reference branch with a fixed lsqnonlin profile. It does not represent the former false-flag default. Only saved aggregate differences are reported; no legacy full-field APV comparison was captured.";
report.historicalComparison.noMotionProfileMaximumDifference = max(abs(rho_nm(:)-historicalSolver.solvers(1).rho(:)));
report.historicalComparison.meanDisplacementDifference = report.meanDisplacement-legacy.legacyMeanDisplacement;
report.historicalComparison.maximumAPEDifference = report.ape.maximum-legacy.legacyAPE.maximum;
report.historicalComparison.negativeAPECountDifference = report.ape.negativeCount-legacy.legacyAPE.negativeCount;
report.historicalComparison.etaAndAPESeconds = legacy.legacyInverseSeconds+legacy.legacyAPESeconds;
report.historicalComparison.productionEtaAndAPESeconds = report.timings.etaTrueSeconds+report.timings.apeSeconds;
assert(isequal(report.sourceSHA256,sourceProvenance(root)),"Critical production source files changed during qualification.");
if all([report.checks.passed])
    report.status = "passed";
else
    report.status = "failed";
end
folder = fileparts(outputPath);
if ~isfolder(folder)
    mkdir(folder);
end
stream = fopen(outputPath,"w");
assert(stream>=0,"Cannot open %s.",outputPath);
closeStream = onCleanup(@()fclose(stream));
fprintf(stream,"%s\n",jsonencode(report,PrettyPrint=true));
fprintf("PRODUCTION_DENSITY_COMPLETE %s status=%s solverResidual=%.6g closure=%.6g meanEta=%.6g apeMean=%.6g apvRMS=%.6g diagnosticSeconds=%.6g\n", ...
    name,report.status,report.solver.maximumResidual,report.densityClosureMaximum,report.meanDisplacement,report.ape.mean,report.apv.rms,report.timings.densityDiagnosticsSeconds);
assert(report.status=="passed","Production density qualification failed; inspect the retained report.");
end

function result = fieldStatistics(field,z_int,Lz)
result = struct(allFinite=all(isfinite(field),"all"),minimum=min(field,[],"all"),maximum=max(field,[],"all"), ...
    mean=volumeMean(field,z_int,Lz),rms=sqrt(volumeMean(field.^2,z_int,Lz)),negativeCount=nnz(field<0));
end

function result = volumeMean(field,z_int,Lz)
result = sum(squeeze(mean(field,[1,2])).*z_int(:))/Lz;
end

function entries = sourceProvenance(root)
paths = ["Operations/WVNoMotionProfileOperation.m","Operations/EtaTrueOperation.m", ...
    "Operations/APEOperation.m","Operations/APVOperation.m","Operations/@WVNoMotionProfile/WVNoMotionProfile.m", ...
    "@WVTransform/WVTransform.m","@WVTransform/removeFromVariableCache.m","@WVTransform/waveVortexTransformFromFile.m", ...
    "@WVTransformHydrostatic/WVTransformHydrostatic.m","@WVTransformBoussinesq/WVTransformBoussinesq.m", ...
    "@WVTransformConstantStratification/WVTransformConstantStratification.m", ...
    "tools/density-diagnostics/qualifyProductionDensityDiagnostics.m"];
entries = repmat(struct(path="",bytes=0,sha256=""),numel(paths),1);
for index = 1:numel(paths)
    entry = provenance(fullfile(root,paths(index)));
    entry.path = paths(index);
    entries(index) = entry;
end
end

function entry = provenance(path)
information = dir(path);
[status,digest] = system("shasum -a 256 "+shellQuote(path));
assert(status==0,"Cannot hash %s.",path);
entry = struct(path=path,bytes=information.bytes,sha256=string(extractBefore(digest," ")));
end

function quoted = shellQuote(value)
quote = string(char(39));
quoted = quote+replace(value,quote,string(char([39,34,39,34,39])))+quote;
end
