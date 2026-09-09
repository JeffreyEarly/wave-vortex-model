function report = writeWaveAdvisoryRegressionReference(outputDirectory,oceanKitRoot)
% Record a fresh advisory reference with the configured released provider.
% Use a new output directory; historical study results are never overwritten.
arguments (Input)
    outputDirectory (1,1) string
    oceanKitRoot (1,1) string
end
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('WVStudy:ReferenceAlreadyExists','Choose a new output directory to preserve existing reference results.')
end
provenance = configureStudyPath(oceanKitRoot);
providerRoot = fileparts(fileparts(string(which('IMInternalModes'))));
providerManifest = jsondecode(fileread(fullfile(providerRoot,'resources','mpackage.json')));
provenance = rmfield(provenance,'internalModesPath');
provenance.internalModesVersion = string(providerManifest.version);
provenance.caseId = "cal-constant-17";
provenance.requestedWaveCount = 3;
data = prepareSourceStudy(resolveStudyCase(provenance.caseId));
report = assessWaveQuadraticResolution(data,requestedWaveCount=provenance.requestedWaveCount);
provenance.caseConfiguration = data.config;
provenance.quadraticTolerance = report.quadraticTolerance;
provenance.status = report.status;
provenance.largestSampledCount = report.largestSampledCount;
provenance.requestedCountAccepted = report.requestedCountAccepted;
provenance.nonzeroProducts = report.cost.nonzeroProducts;
provenance.createdAtUTC = string(datetime('now',TimeZone='UTC',Format='yyyy-MM-dd''T''HH:mm:ss''Z'''));
mkdir(outputDirectory);
writetable(report.prefixDiagnostics(:,["waveCount","gramError","quadraticError"]),fullfile(outputDirectory,'prefix-errors.csv'));
writelines(jsonencode(provenance,PrettyPrint=true),fullfile(outputDirectory,'provenance.json'));
end
