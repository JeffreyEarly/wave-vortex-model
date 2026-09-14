function results=qualifyThermalRestart(outputFolder,options)
% Qualify thermal committed restart and physical resolution transfer.
% Scientific construction uses the configured InternalModes provider. Run
% TestThermalOutputRestart.verifyRestartWithoutProvider(outputFolder) in a
% separate MATLAB process with provider paths removed to finish the gate.
% Checkpoint/reference files are qualification artifacts, not runtime inputs.
% - Topic: Developer utilities
% - Parameter outputFolder: folder for NetCDF checkpoints, MAT references and CSVs
% - Parameter options.fullPhysics: include quadratic drag and the named mapped APV closure
% - Parameter options.shouldRunRestart: disable to repeat only transfer quadrature checks
% - Returns results: measured restart and I/O evidence
arguments (Input)
    outputFolder (1,1) string
    options.fullPhysics (1,1) logical = true
    options.shouldRunRestart (1,1) logical = true
end
arguments (Output)
    results table
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
results=table();
if options.shouldRunRestart
    results=TestThermalOutputRestart.runStudy(outputFolder,fullPhysics=options.fullPhysics);
end
rows=struct([]);
for profile=["constant","exponential"]
    a=0; if profile=="exponential", a=1/1300; end
    w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=17,mdaModeCount=4,kappa_z=1e-5,shouldCheckQuadraticAliasing=true);
    thermalManufacturedState(w,[2 16 9],1000); w.Amda=[.1;-.2;.3;-.1]; w.t=127; w.t0=31;
    for kind=["refine","coarsen"]
        grid=[12 12 97]; count=25; meanCount=4;
        if kind=="coarsen", grid=[6 6 65]; count=9; meanCount=3; end
        [target,assessment]=w.waveVortexTransformWithResolution(grid,thermalModeCount=count,mdaModeCount=meanCount);
        [~,refined]=w.coefficientStateForTransform(target,quadratureCount=2*assessment.quadratureCount+1);
        quadratureDifference=abs(assessment.errorEnergy-refined.errorEnergy)/max(assessment.sourceEnergy,realmin);
        assert(quadratureDifference<1e-7);
        if kind=="refine", assert(assessment.relativeFieldError<1e-6); end
        row=struct(profile=profile,transfer=kind,sourceThermalCount=17,targetThermalCount=count,sourceMdaCount=4,targetMdaCount=meanCount,relativeFieldError=assessment.relativeFieldError,qgpvRMS=assessment.qgpvRMS,velocityRMS=assessment.velocityRMS,surfaceRMS=assessment.endpointRMS(1),bottomRMS=assessment.endpointRMS(2),meanDisplacementRMS=assessment.meanDisplacementRMS,meanBuoyancyInventoryError=assessment.meanBuoyancyInventoryError,discardedFourierCount=assessment.discardedFourierCount,quadratureDifference=quadratureDifference);
        rows=[rows;row]; %#ok<AGROW>
    end
end
writetable(struct2table(rows),fullfile(outputFolder,'transfer.csv'));
end
