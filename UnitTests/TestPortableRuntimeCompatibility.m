classdef TestPortableRuntimeCompatibility < matlab.unittest.TestCase
    properties (SetAccess = private)
        RepositoryRoot (1,1) string
        Runner (1,1) string
        TemporaryFolder (1,1) string
    end

    methods (TestClassSetup)
        function buildReferenceRuntime(testCase)
            testCase.RepositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = string(fixture.Folder);
            buildDirectory = fullfile(testCase.TemporaryFolder,"build");
            configure = "cmake -S " + shellQuote(fullfile(testCase.RepositoryRoot,"PortableRuntime")) + ...
                " -B " + shellQuote(buildDirectory) + ...
                " -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF";
            [status,output] = system(configure);
            testCase.assertEqual(status,0,output)
            [status,output] = system("cmake --build " + shellQuote(buildDirectory) + ...
                " --parallel --target wave-vortex-run");
            testCase.assertEqual(status,0,output)
            testCase.Runner = fullfile(buildDirectory,"wave-vortex-run");
            testCase.assertTrue(isfile(testCase.Runner))
        end
    end

    methods (Test, TestTags = "optional")
        function matlabFixtureRunsAndRuntimeCheckpointRestores(testCase)
            inputPath = fullfile(testCase.RepositoryRoot,"PortableRuntime","tests", ...
                "fixtures","forcing-nonlinear.nc");
            outputPath = fullfile(testCase.TemporaryFolder,"runtime-output.nc");
            command = shellQuote(testCase.Runner) + " " + shellQuote(inputPath) + ...
                " " + shellQuote(outputPath) + ...
                " --delta-t 0.01 --steps 1 --fft-provider reference";
            [status,output] = system(command);
            testCase.assertEqual(status,0,output)
            report = jsondecode(output);
            testCase.verifyEqual(string(report.status),"complete")
            testCase.verifyEqual(string(report.execution.engine),"reference-direct")
            testCase.verifyTrue(report.execution.noFallback)

            [wvt,ncfile] = WVTransform.waveVortexTransformFromFile( ...
                outputPath,shouldReadOnly=true);
            cleanup = onCleanup(@()ncfile.close());
            testCase.verifyEqual(wvt.t,report.state.finalTime,AbsTol=4*eps(report.state.finalTime))
            testCase.verifyEqual([wvt.Nj wvt.Nkl],reshape(report.state.shape,1,[]))
            testCase.verifyFalse(any(~isfinite(wvt.Ap),"all"))
            testCase.verifyFalse(any(~isfinite(wvt.Am),"all"))
            testCase.verifyFalse(any(~isfinite(wvt.A0),"all"))
            clear cleanup
        end
    end
end

function value = shellQuote(value)
value = "'" + replace(string(value),"'","'""'""'") + "'";
end
