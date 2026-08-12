classdef TestCompiledKernelDenseEngineScreen < matlab.unittest.TestCase
    methods (Test, TestTags="optional")
        function comparesCompletePipelines(testCase)
            testCase.assumeTrue(ismac && string(computer("arch")) == "maca64");
            repositoryRoot=fileparts(fileparts(mfilename("fullpath"))); addpath(fullfile(repositoryRoot,"Benchmarks")); cleanup=onCleanup(@()rmpath(fullfile(repositoryRoot,"Benchmarks")));
            results=runCompiledKernelDenseEngineBenchmark(sizes=[64 64 1],channelCounts=1,workerCount=2,warmupCount=0,sampleCount=1,shouldWriteArtifacts=false);
            testCase.verifyEqual(string({results.runs.engines.id}),["native-fftw" "pffft" "accelerate-vdsp"]);
            testCase.verifyLessThanOrEqual(max([results.runs.engines.maximumRelativeError]),1e-12);
            testCase.verifyTrue(all(isfinite([results.runs.engines.combinedMedianSeconds])));
            clear cleanup
        end
    end
end
