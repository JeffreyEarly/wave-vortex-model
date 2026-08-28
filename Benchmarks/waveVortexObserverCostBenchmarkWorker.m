function waveVortexObserverCostBenchmarkWorker(configPath,outputPath)
% Execute one observer-cost benchmark sample in a fresh MATLAB process.
arguments
    configPath (1,1) string
    outputPath (1,1) string
end

config = jsondecode(fileread(configPath));
result = failedResult(config);
try
    path(config.matlabPath);
    result = runWaveVortexObserverCostBenchmarkCase(string(config.case.id), ...
        Nxyz=config.Nxyz,Lxyz=config.Lxyz,deltaT=config.deltaT, ...
        integrationStepCount=config.integrationStepCount, ...
        denseOutputPointsPerStep=config.denseOutputPointsPerStep, ...
        seed=config.seed,outputPath=string(config.modelOutputPath), ...
        phasePath=string(config.phasePath),plateauSeconds=config.plateauSeconds);
    result.failure = struct("identifier","","message","","report","");
catch exception
    result.status = "failed";
    result.failure = struct("identifier",string(exception.identifier),"message",string(exception.message),"report",string(getReport(exception,"extended","hyperlinks","off")));
end
writeText(outputPath,jsonencode(result,PrettyPrint=true));
end

function value = failedResult(config)
value = struct("schemaVersion","observer-cost-case-v1","status","failed","case",config.case,"timing",struct(),"work",struct(),"finalState",struct(),"failure",struct("identifier","","message","","report",""));
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end
