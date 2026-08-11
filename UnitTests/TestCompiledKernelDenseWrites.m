classdef TestCompiledKernelDenseWrites < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
            addpath(benchmarkFolder);
            testCase.addTeardown(@()rmpath(benchmarkFolder));
        end
    end

    methods (Test,TestTags="full")
        function decisionRequiresBothPhysicalConfigurationsAtOneSize(testCase)
            comparisons = [comparison([256 256 65],true,1.06,1.0); comparison([256 256 65],false,1.05,1.0); comparison([512 512 129],true,1.01,1.0); comparison([512 512 129],false,1.02,1.0)];
            decision = compiledKernelDenseWriteDecision(comparisons);
            testCase.verifyTrue(decision.adopted);
            testCase.verifyEqual(decision.qualifyingSize,"256x256x65");
            comparisons(2).completeCallSpeedup = 1.04;
            decision = compiledKernelDenseWriteDecision(comparisons);
            testCase.verifyFalse(decision.adopted);
            comparisons(1:2) = [comparison([256 256 65],true,1.0,0.94); comparison([256 256 65],false,1.0,0.95)];
            decision = compiledKernelDenseWriteDecision(comparisons);
            testCase.verifyTrue(decision.adopted);
        end
    end

    methods (Test,TestTags="optional")
        function segmentedProducerWritesEveryCellAndMatchesBaseline(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            cleanup = onCleanup(@()removeDirectory(outputDirectory));
            baselineModule = "wv_dense_write_baseline_test";
            candidateModule = "wv_dense_write_candidate_test";
            buildCompiledKernelTransformMex(outputDirectory=outputDirectory,outputName=baselineModule);
            buildCompiledKernelTransformMex(outputDirectory=outputDirectory,outputName=candidateModule,denseWriteStrategy="segmented",fuseInverseNormalization=true,validateDenseWrites=true);
            addpath(outputDirectory);
            pathCleanup = onCleanup(@()rmpath(outputDirectory));

            sizes = [9 8 7; 10 7 7];
            for iSize = 1:size(sizes,1)
                for isHydrostatic = [true false]
                    for shouldAntialias = [true false]
                        wvt = WVTransformConstantStratification([15000 15000 1300],sizes(iSize,:),isHydrostatic=isHydrostatic,shouldAntialias=shouldAntialias);
                        initializeWaveVortexBenchmarkState(wvt,1270+iSize+10*isHydrostatic+100*shouldAntialias);
                        configuration = kernelConfiguration(wvt);
                        baseline = feval(baselineModule,'create',configuration,1);
                        candidate = feval(candidateModule,'create',configuration,1);
                        handleCleanup = onCleanup(@()deleteHandles(baselineModule,baseline,candidateModule,candidate));
                        feval(baselineModule,'setStageInstrumentation',baseline,true);
                        feval(candidateModule,'setStageInstrumentation',candidate,true);
                        [baselineFp,baselineFm,baselineF0] = feval(baselineModule,'nonlinearFlux',baseline,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
                        [candidateFp,candidateFm,candidateF0] = feval(candidateModule,'nonlinearFlux',candidate,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
                        error = max([relativeError(candidateFp,baselineFp) relativeError(candidateFm,baselineFm) relativeError(candidateF0,baselineF0)]);
                        testCase.verifyLessThanOrEqual(error,1e-12);
                        baselineMetrics = feval(baselineModule,'metrics',baseline);
                        candidateMetrics = feval(candidateModule,'metrics',candidate);
                        targetCount = 3+~isHydrostatic;
                        testCase.verifyTrue(candidateMetrics.denseInputValidationPassed);
                        testCase.verifyEqual(candidateMetrics.denseInputValidationCount,targetCount+1);
                        testCase.verifyEqual(candidateMetrics.inverseNormalizationCellsWritten,0);
                        testCase.verifyGreaterThan(baselineMetrics.inverseNormalizationCellsWritten,0);
                        testCase.verifyLessThan(candidateMetrics.denseBytesWritten,baselineMetrics.denseBytesWritten);
                        testCase.verifyEqual(baselineMetrics.densePassCount,4*(targetCount+1));
                        testCase.verifyEqual(candidateMetrics.densePassCount,3*(targetCount+1));
                        clear handleCleanup
                        delete(wvt);
                    end
                end
            end
            clear pathCleanup cleanup
        end
    end
end

function value = comparison(Nxyz,isHydrostatic,speedup,maximumLiveRatio)
value = struct("Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"completeCallSpeedup",speedup,"maximumLiveRatio",maximumLiveRatio,"maximumRelativeError",1e-14,"selectedScheduleExecuted",true);
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],'omitmissing')/max(max(abs(expected(:)),[],'omitmissing'),realmin);
end

function deleteHandles(baselineModule,baseline,candidateModule,candidate)
try, feval(baselineModule,'delete',baseline); catch, end
try, feval(candidateModule,'delete',candidate); catch, end
end

function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end
