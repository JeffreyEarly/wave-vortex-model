classdef TestPortableCheckpointReader < matlab.unittest.TestCase
    methods (Test, TestTags = "optional")
        function cppAndMatlabReadersAgree(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build","wv_checkpoint_inspect");
            fixtureDirectory = fullfile(repositoryRoot,"tools","portable-runtime","fixtures");
            cases = {
                "root-nonhydrostatic.nc", Inf, []
                "root-hydrostatic.nc", Inf, []
                "time-series-nonhydrostatic.nc", Inf, []
                "time-series-hydrostatic.nc", 2, 1
                };

            for iCase = 1:size(cases,1)
                fixturePath = fullfile(fixtureDirectory,cases{iCase,1});
                inspectorArguments = " --include-coefficients";
                if ~isempty(cases{iCase,3})
                    inspectorArguments = " "+string(cases{iCase,3})+inspectorArguments;
                end
                inspectCommand = sprintf('"%s" "%s"%s',inspector,fixturePath,inspectorArguments);
                if isunix
                    inspectCommand = "/usr/bin/env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+inspectCommand;
                end
                [inspectStatus,inspectOutput] = system(inspectCommand);
                testCase.assertEqual(inspectStatus,0,inspectOutput)
                record = jsondecode(inspectOutput);

                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,iTime=cases{iCase,2},shouldReadOnly=true);
                cleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                shape = [record.shape(1) record.shape(2)];
                testCase.verifyEqual(wvt.Ap,complex(reshape(record.ApReal,shape),reshape(record.ApImag,shape)))
                testCase.verifyEqual(wvt.Am,complex(reshape(record.AmReal,shape),reshape(record.AmImag,shape)))
                testCase.verifyEqual(wvt.A0,complex(reshape(record.A0Real,shape),reshape(record.A0Imag,shape)))
                testCase.verifyEqual(wvt.t,record.t)
                testCase.verifyEqual(wvt.t0,record.t0)
                testCase.verifyEqual(wvt.isHydrostatic,record.isHydrostatic)
                testCase.verifyEqual(wvt.shouldAntialias,record.shouldAntialias)
                testCase.verifyEqual(wvt.Nj,record.shape(1))
                testCase.verifyEqual(wvt.Nkl,record.shape(2))
                ncfile.close();
                clear cleanup
            end
        end
    end

    methods (Static, Access=private)
        function closeIfOpen(ncfile)
            if ~isempty(ncfile) && isvalid(ncfile) && ~isempty(ncfile.id)
                ncfile.close();
            end
        end
    end
end
