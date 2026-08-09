function waveVortexDerivativeDispatchCaseWorker(configPath,outputPath)
% Run one derivative-dispatch case in an isolated MATLAB process.
arguments
    configPath (1,1) string
    outputPath (1,1) string
end
config = jsondecode(fileread(configPath));
setenv("WVM_DERIVATIVE_DISPATCH_WORKER","1");
cleanup = onCleanup(@()setenv("WVM_DERIVATIVE_DISPATCH_WORKER",""));
addpath(config.repositoryRoot,fullfile(config.repositoryRoot,"Benchmarks"),fullfile(config.repositoryRoot,"FastTransforms"));
fftwTransformsRoot = fullfile(fileparts(config.repositoryRoot),"fftw-transforms");
if isfolder(fftwTransformsRoot)
    addpath(fftwTransformsRoot);
end
results = runWaveVortexBenchmark(suites="derivative-dispatch-v1",backends=string(config.backendIds),caseIds=string(config.caseId),shouldMeasureMemory=false,shouldWriteArtifacts=false,correctnessTolerance=config.correctnessTolerance);
writeText(outputPath,jsonencode(results.suites.cases(1)));
clear cleanup
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:WorkerWriteFailed","Unable to write %s.",pathname);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end
