function requestPath = generatePortableRunRequestDeterminismFixture(outputFolder)
% Generate the release-independent portable run-request hash fixture.
arguments
    outputFolder (1,1) string {mustBeNonzeroLengthText}
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
modelName = "model bundle Ω.nc";
modelPath = fullfile(outputFolder,modelName);
copyfile(fullfile(repositoryRoot,"PortableRuntime","tests","fixtures", ...
    "time-series-hydrostatic.nc"),modelPath);
ncwriteatt(modelPath,"/","portableFileIdentifier","primary");
requestPath = fullfile(outputFolder,"portable request Ω.json");
WVModel.writePortableRunRequest(requestPath,modelName, ...
    schemaVersion=2,method="adaptive-rk78",finalTime=12, ...
    initialStep=.25,maximumStep=1,relativeTolerance=1e-3, ...
    absoluteToleranceScale=1e-6,reportPath="portable report Ω.json");
end
