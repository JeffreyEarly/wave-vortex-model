function results = runFreeSurfaceQGCoefficientStorageCanonicalBenchmark(outputDirectory)
% Run the canonical Issue #343 matrix and write its immutable artifact.
arguments
    outputDirectory (1,1) string
end

results = runFreeSurfaceQGCoefficientStorageBenchmark(outputDirectory=outputDirectory);
end
