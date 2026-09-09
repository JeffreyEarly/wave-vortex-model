function report = qualifyDensityCalculus(inputPath,solverReportPath,outputPath)
% Compare density calculus on one captured state without repeating its fit.
arguments
    inputPath (1,1) string {mustBeFile}
    solverReportPath (1,1) string {mustBeFile}
    outputPath (1,1) string
end
solverReport = jsondecode(fileread(solverReportPath));
[wvt,file] = WVTransform.waveVortexTransformFromFile(char(inputPath),iTime=Inf,shouldReadOnly=true);
cleanup = onCleanup(@()file.close());
rho = wvt.rho_total;
wvt.shouldUseTrueNoMotionProfile = true;
wvt.addToVariableCache('rho_nm',solverReport.solvers(1).rho);
started = tic;
legacyEta = wvt.eta_true;
report.legacyInverseSeconds = toc(started);
started = tic;
legacyAPE = wvt.ape;
report.legacyAPESeconds = toc(started);
report.legacyAPE = extrema(legacyAPE);
clear legacyAPE
profile = WVNoMotionProfile(wvt.z,solverReport.solvers(1).rho);
started = tic;
materialHeight = profile.inverse(rho);
eta = wvt.Z-materialHeight;
report.cubicInverseSeconds = toc(started);
started = tic;
ape = profile.availablePotentialEnergy(wvt.Z,materialHeight,wvt.g,wvt.rho0);
report.cubicAPESeconds = toc(started);
report.cubicAPE = extrema(ape);
weights = reshape(wvt.z_int/wvt.Lz,1,1,[]);
average = @(field) sum(weights.*mean(field,[1 2]),'all');
report.legacyMeanDisplacement = average(legacyEta);
report.cubicMeanDisplacement = average(eta);
report.inverseDifferenceMaximum = max(abs(eta-legacyEta),[],'all');
report.inverseDifferenceRMS = sqrt(average((eta-legacyEta).^2));
report.cubicDensityResidualMaximum = max(abs(profile.density(materialHeight)-rho),[],'all');
report.inputPath = inputPath;
report.solverReportPath = solverReportPath;
report.grid = wvt.spatialMatrixSize;
report.interpretation = 'Calculus comparison on a fixed lsqnonlin profile. Neither inverse establishes that the fitted profile is the true rearranged distribution.';
stream = fopen(outputPath,'w');
assert(stream>=0,'Cannot open calculus report.');
closeStream = onCleanup(@()fclose(stream));
fprintf(stream,'%s\n',jsonencode(report,PrettyPrint=true));
disp(report)
end

function values = extrema(field)
values = struct(minimum=min(field,[],'all'),maximum=max(field,[],'all'),negativeCount=nnz(field<0));
end
