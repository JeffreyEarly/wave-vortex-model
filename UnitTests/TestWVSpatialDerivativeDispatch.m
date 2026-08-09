classdef TestWVSpatialDerivativeDispatch < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repositoryRoot,"Benchmarks")));
        end
    end

    methods (Test,TestTags="full")
        function exactRecordsDoNotExtrapolate(testCase)
            records = WVSpatialDerivativeDispatch.allRecords();
            testCase.verifyNumElements(records,11);
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","diffX",[128 128 129],2,false),"fftw-1d");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","diffY",[128 128 257],3,false),"fftw-1d");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","diffY",[128 128 129],2,false),"matlab-1d");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","G-all",[256 256 65],1,true),"modal-direct");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","diffX",[128 128 129],1,false),"matlab-1d");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","diffY",[128 128 257],4,false),"matlab-1d");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","G-all",[129 128 257],1,false),"composed-current");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","G-all",[512 512 129],1,false),"composed-current");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("fftw","G-all",[512 512 129],1,true),"composed-current");
            testCase.verifyEqual(WVSpatialDerivativeDispatch.implementation("builtin","G-all",[128 128 257],1,true),"composed-current");
            testCase.verifyTrue(all(string({records.sourceSuite}) == "derivative-dispatch-v1"));
            testCase.verifyTrue(all([records.speedThreshold] == 1.10));
            testCase.verifyTrue(all([records.relativeErrorTolerance] == 1e-12));
        end

        function ordinaryBuiltinDerivativesRemainComposed(testCase)
            wvt = WVTransformConstantStratification([4000 3000 1000],[16 12 9],shouldAntialias=false,fastTransform="builtin");
            cleanup = onCleanup(@()delete(wvt));
            rng(7474,"twister");
            Apm = randn(wvt.spectralMatrixSize) + 1i*randn(wvt.spectralMatrixSize);
            A0 = randn(wvt.spectralMatrixSize) + 1i*randn(wvt.spectralMatrixSize);
            [F,Fx,Fy,Fz] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=Apm,A0=A0);
            referenceF = wvt.transformToSpatialDomainWithF(Apm=Apm,A0=A0);
            testCase.verifyEqual(F,referenceF,AbsTol=0);
            testCase.verifyLessThanOrEqual(relativeError(Fx,wvt.diffX(referenceF)),1e-12);
            testCase.verifyLessThanOrEqual(relativeError(Fy,wvt.diffY(referenceF)),1e-12);
            testCase.verifyLessThanOrEqual(relativeError(Fz,wvt.diffZF(referenceF)),1e-12);
            clear cleanup
        end

        function suiteIsRegisteredAsUnscoredDiagnostic(testCase)
            suite = waveVortexBenchmarkSuites("derivative-dispatch-v1");
            testCase.verifyEqual(suite.kind,"derivative-dispatch");
            testCase.verifyFalse(suite.isScored);
            testCase.verifyEqual(suite.operation,"spatial-derivatives");
            testCase.verifyNumElements(suite.cases,9);
            testCase.verifyEqual([suite.cases.warmupCount],2*ones(1,9));
            testCase.verifyEqual([suite.cases.sampleCount],[7 7 7 7 7 7 7 3 3]);
        end
    end
end

function value = relativeError(actual,expected)
value = norm(actual(:)-expected(:),inf)/max(norm(expected(:),inf),eps);
end
