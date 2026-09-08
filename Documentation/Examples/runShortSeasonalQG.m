function model = runShortSeasonalQG(path)
% Run 32 days, close, restore and continue to day 64 in one standard file.
% Add this directory to the MATLAB path alongside the authoring dependencies.
% The output path must be new. No experiment-specific checkpoint is needed.
arguments (Input)
    path (1,1) string
end
arguments (Output)
    model (1,1) WVModel
end
model = makeShortSeasonalQGModel();
model.createNetCDFFileForModelOutput(char(path),outputInterval=86400);
model.addNetCDFOutputVariables('ssh','qgpv','eta');
model.integrateToTime(32*86400);
model.closeNetCDFFile();
model = WVModel.modelFromFile(char(path));
model.setupIntegrator(integratorType="exponential",initialStep=21600,maximumStep=21600,exponentialAdaptive=false);
model.integrateToTime(64*86400);
model.closeNetCDFFile();
end
