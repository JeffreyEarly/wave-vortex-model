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

        function forcingSchedulesAgree(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build","wv_checkpoint_inspect");
            fixtureDirectory = fullfile(repositoryRoot,"tools","portable-runtime","fixtures");

            capabilityCommand = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" --forcing-capabilities',inspector));
            [capabilityStatus,capabilityOutput] = system(capabilityCommand);
            testCase.assertEqual(capabilityStatus,0,capabilityOutput)
            capabilityRecord = jsondecode(capabilityOutput);
            capabilities = reshape(capabilityRecord.capabilities,[],1);
            expectedClasses = ["WVNonlinearAdvection" "WVAntialiasing" "WVAdaptiveDamping" "WVFixedAmplitudeForcing" "WVBottomFrictionQuadratic" "WVPseudoTopographicWaveGeneration" "WVBetaPlanePVAdvection" "WVHorizontalDamping" "WVVerticalDamping" "WVThermalDamping" "WVBottomFrictionLinear" "WVVerticalDiffusivity"];
            testCase.verifyEqual(string({capabilities.typeIdentifier}),expectedClasses)
            testCase.verifyEqual(nnz([capabilities.isSupported]),6)

            fixtureNames = ["forcing-nonlinear.nc" "forcing-adaptive-damping.nc" "forcing-fixed-amplitude.nc" "forcing-quadratic-bottom-friction.nc" "forcing-pseudo-topographic.nc" "forcing-beta-plane.nc" "forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];
            for fixtureName = fixtureNames
                fixturePath = fullfile(fixtureDirectory,fixtureName);
                inspectCommand = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" --include-forcing-arrays',inspector,fixturePath));
                [inspectStatus,inspectOutput] = system(inspectCommand);
                testCase.assertEqual(inspectStatus,0,inspectOutput)
                record = jsondecode(inspectOutput);
                decodedForcing = reshape(record.forcing,[],1);

                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,shouldReadOnly=true);
                cleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                matlabForcing = reshape(wvt.forcing,[],1);
                classes = strings(numel(matlabForcing),1);
                names = strings(numel(matlabForcing),1);
                priorities = zeros(numel(matlabForcing),1);
                for iForcing = 1:numel(matlabForcing)
                    classes(iForcing) = class(matlabForcing(iForcing));
                    names(iForcing) = string(matlabForcing(iForcing).name);
                    priorities(iForcing) = double(matlabForcing(iForcing).priority);
                end
                testCase.verifyEqual(string({decodedForcing.annotatedClass}).',classes)
                testCase.verifyEqual(string({decodedForcing.name}).',names)
                testCase.verifyEqual(double([decodedForcing.priority]).',priorities)

                fixedIndex = find(classes == "WVFixedAmplitudeForcing",1);
                if ~isempty(fixedIndex)
                    force = matlabForcing(fixedIndex);
                    payload = decodedForcing(fixedIndex).payload;
                    testCase.verifyEqual(uint64(payload.ApIndices),force.Ap_indices)
                    testCase.verifyEqual(complex(payload.ApReal,payload.ApImag),force.Apbar)
                    testCase.verifyEqual(uint64(payload.AmIndices),force.Am_indices)
                    testCase.verifyEqual(complex(payload.AmReal,payload.AmImag),force.Ambar)
                    testCase.verifyEqual(uint64(payload.A0Indices),force.A0_indices)
                    testCase.verifyEqual(complex(payload.A0Real,payload.A0Imag),force.A0bar)
                end

                quadraticIndex = find(classes == "WVBottomFrictionQuadratic",1);
                if ~isempty(quadraticIndex)
                    testCase.verifyEqual(decodedForcing(quadraticIndex).payload.Cd,matlabForcing(quadraticIndex).Cd)
                end

                pseudoIndex = find(classes == "WVPseudoTopographicWaveGeneration",1);
                if ~isempty(pseudoIndex)
                    force = matlabForcing(pseudoIndex);
                    payload = decodedForcing(pseudoIndex).payload;
                    testCase.verifyEqual(reshape(payload.topographicHeight,size(force.topographicHeight)),force.topographicHeight,AbsTol=1e-13)
                    testCase.verifyEqual(complex(payload.barotropicVelocityReal,payload.barotropicVelocityImag),force.barotropicVelocityAmplitude)
                    testCase.verifyEqual(payload.frequency,force.frequency)
                    testCase.verifyEqual(string(payload.darwinSymbol),force.darwinSymbol)
                    testCase.verifyEqual(payload.rampDuration,force.rampDuration)
                    testCase.verifyEqual(payload.startTime,force.startTime)
                    testCase.verifyEqual(payload.shouldAvoidAdaptiveDamping,force.shouldAvoidAdaptiveDamping)
                end
                ncfile.close();
                clear cleanup
            end
        end
    end

    methods (Static, Access=private)
        function command = sanitizedCommand(command)
            if isunix
                command = "/usr/bin/env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+command;
            end
        end

        function closeIfOpen(ncfile)
            if ~isempty(ncfile) && isvalid(ncfile) && ~isempty(ncfile.id)
                ncfile.close();
            end
        end
    end
end
