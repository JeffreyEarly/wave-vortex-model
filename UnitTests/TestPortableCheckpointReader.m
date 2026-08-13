classdef TestPortableCheckpointReader < matlab.unittest.TestCase
    methods (Test, TestTags = "optional")
        function cppAndMatlabReadersAgree(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_checkpoint_inspect");
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
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_checkpoint_inspect");
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

        function portableForcingEngineMatchesMatlab(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            fixtureToolDirectory = fullfile(repositoryRoot,"tools","portable-runtime");
            addpath(fixtureToolDirectory)
            fixtureToolCleanup = onCleanup(@()rmpath(fixtureToolDirectory));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_portable_forcing_inspect");
            fixtureDirectory = string(tempname);
            mkdir(fixtureDirectory)
            fixtureCleanup = onCleanup(@()rmdir(fixtureDirectory,"s"));
            generateForcingScheduleFixtures(outputDirectory=fixtureDirectory,coefficientMode="physical-small");
            fixtureNames = ["forcing-nonlinear.nc" "forcing-adaptive-damping.nc" "forcing-fixed-amplitude.nc" "forcing-quadratic-bottom-friction.nc" "forcing-pseudo-topographic.nc" "forcing-beta-plane.nc" "forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];

            for fixtureName = fixtureNames
                fixturePath = fullfile(fixtureDirectory,fixtureName);
                command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s"',inspector,fixturePath));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                record = jsondecode(output);
                shape = [record.shape(1) record.shape(2)];
                actual = {
                    complex(reshape(record.FpReal,shape),reshape(record.FpImag,shape))
                    complex(reshape(record.FmReal,shape),reshape(record.FmImag,shape))
                    complex(reshape(record.F0Real,shape),reshape(record.F0Imag,shape))
                    };

                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,shouldReadOnly=true);
                cleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                horizontalMean = wvt.Kh == 0;
                waveOrInertial = horizontalMean | wvt.J > 0;
                geostrophicOrMDA = ~horizontalMean | wvt.J > 0;
                wvt.Ap(~waveOrInertial) = 0;
                wvt.Am(~waveOrInertial) = 0;
                wvt.A0(~geostrophicOrMDA) = 0;
                [expected{1:3}] = wvt.nonlinearFlux();
                for iCoefficient = 1:3
                    scale = max(max(abs(expected{iCoefficient}),[],"all"),realmin);
                    relativeError = max(abs(actual{iCoefficient}-expected{iCoefficient}),[],"all")/scale;
                    testCase.verifyLessThanOrEqual(relativeError,1e-12,sprintf("%s coefficient %d",fixtureName,iCoefficient))
                end
                ncfile.close();
                clear cleanup
            end
            clear fixtureCleanup
            clear fixtureToolCleanup
        end

        function portableRK4MatchesMatlab(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            fixtureToolDirectory = fullfile(repositoryRoot,"tools","portable-runtime");
            addpath(fixtureToolDirectory)
            fixtureToolCleanup = onCleanup(@()rmpath(fixtureToolDirectory));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_portable_rk4_inspect");
            fixtureDirectory = string(tempname);
            mkdir(fixtureDirectory)
            fixtureCleanup = onCleanup(@()rmdir(fixtureDirectory,"s"));
            generateForcingScheduleFixtures(outputDirectory=fixtureDirectory,coefficientMode="physical-small");

            fixtureNames = ["forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];
            for fixtureName = fixtureNames
                fixturePath = fullfile(fixtureDirectory,fixtureName);
                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,shouldReadOnly=true);
                transformCleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                deltaT = 0.037;
                finalTime = wvt.t+2.5*deltaT;
                [Ap,Am,A0,t,stepCount] = TestPortableCheckpointReader.advanceRK4(wvt,finalTime,deltaT);

                command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" %.17g %.17g',inspector,fixturePath,finalTime,deltaT));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                record = jsondecode(output);
                shape = [record.shape(1) record.shape(2)];
                actual = {
                    complex(reshape(record.ApReal,shape),reshape(record.ApImag,shape))
                    complex(reshape(record.AmReal,shape),reshape(record.AmImag,shape))
                    complex(reshape(record.A0Real,shape),reshape(record.A0Imag,shape))
                    };
                expected = {Ap;Am;A0};
                for iCoefficient = 1:3
                    scale = max(max(abs(expected{iCoefficient}),[],"all"),realmin);
                    testCase.verifyLessThanOrEqual(max(abs(actual{iCoefficient}-expected{iCoefficient}),[],"all")/scale,1e-12)
                end
                testCase.verifyEqual(record.t,t,AbsTol=4*eps(t))
                testCase.verifyEqual(record.stepCount,stepCount)
                testCase.verifyEqual(record.rhsEvaluationCount,4*stepCount)
                testCase.verifyEqual(record.workspaceBytes,9*numel(Ap)*16)
                ncfile.close();
                clear transformCleanup
            end
            clear fixtureCleanup fixtureToolCleanup
        end

        function portableRK4DenseOutputMatchesWVArrayIntegrator(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_portable_rk4_inspect");
            fixtureDirectory = string(tempname);
            mkdir(fixtureDirectory)
            fixtureCleanup = onCleanup(@()rmdir(fixtureDirectory,"s"));
            addpath(fullfile(repositoryRoot,"tools","portable-runtime"))
            toolCleanup = onCleanup(@()rmpath(fullfile(repositoryRoot,"tools","portable-runtime")));
            generateForcingScheduleFixtures(outputDirectory=fixtureDirectory,coefficientMode="physical-small");

            fixtureNames = ["forcing-nonlinear.nc" "forcing-adaptive-damping.nc" "forcing-fixed-amplitude.nc" "forcing-quadratic-bottom-friction.nc" "forcing-pseudo-topographic.nc" "forcing-beta-plane.nc" "forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];
            for fixtureName = fixtureNames
                fixturePath = fullfile(fixtureDirectory,fixtureName);
                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,shouldReadOnly=true);
                transformCleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
                initialTime = wvt.t;
                deltaT = 0.037;
                outputTime = initialTime+0.37*deltaT;
                finalTime = initialTime+deltaT;
                y0 = {wvt.Ap;wvt.Am;wvt.A0};
                matlabIntegrator = WVArrayIntegrator(@(t,y)TestPortableCheckpointReader.rhsAtState(wvt,t,y),[initialTime outputTime finalTime],y0,deltaT);
                expected = matlabIntegrator.valueAtTime(outputTime);

                command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" %.17g %.17g %.17g',inspector,fixturePath,finalTime,deltaT,outputTime));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                record = jsondecode(output);
                shape = [record.shape(1) record.shape(2)];
                actual = {
                    complex(reshape(record.outputApReal,shape),reshape(record.outputApImag,shape))
                    complex(reshape(record.outputAmReal,shape),reshape(record.outputAmImag,shape))
                    complex(reshape(record.outputA0Real,shape),reshape(record.outputA0Imag,shape))
                    };
                for iCoefficient = 1:3
                    scale = max(max(abs(expected{iCoefficient}),[],"all"),realmin);
                    testCase.verifyLessThanOrEqual(max(abs(actual{iCoefficient}-expected{iCoefficient}),[],"all")/scale,1e-12,fixtureName)
                end
                testCase.verifyEqual(record.outputTime,outputTime,AbsTol=4*eps(outputTime))
                testCase.verifyEqual(record.rhsEvaluationCount,4)
                stateBytes = numel(wvt.Ap)*16;
                testCase.verifyEqual(record.workspaceBytes,12*stateBytes)
                testCase.verifyEqual(record.interpolationBufferBytes,3*stateBytes)
                ncfile.close();
                clear transformCleanup
            end
            clear toolCleanup fixtureCleanup
        end

        function standaloneRunnerMatchesMatlab(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            fixtureToolDirectory = fullfile(repositoryRoot,"tools","portable-runtime");
            addpath(fixtureToolDirectory)
            fixtureToolCleanup = onCleanup(@()rmpath(fixtureToolDirectory));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            runner = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wave-vortex-run");
            fixtureDirectory = string(tempname);
            outputDirectory = string(tempname);
            mkdir(fixtureDirectory)
            mkdir(outputDirectory)
            fixtureCleanup = onCleanup(@()rmdir(fixtureDirectory,"s"));
            outputCleanup = onCleanup(@()rmdir(outputDirectory,"s"));
            generateForcingScheduleFixtures(outputDirectory=fixtureDirectory,coefficientMode="physical-small");
            fixtureNames = ["forcing-nonlinear.nc" "forcing-adaptive-damping.nc" "forcing-fixed-amplitude.nc" "forcing-quadratic-bottom-friction.nc" "forcing-pseudo-topographic.nc" "forcing-beta-plane.nc" "forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];
            deltaT = 0.037;

            for fixtureName = fixtureNames
                inputPath = fullfile(fixtureDirectory,fixtureName);
                outputPath = fullfile(outputDirectory,fixtureName);
                reportPath = outputPath+".json";
                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(inputPath,shouldReadOnly=true);
                transformCleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                [Ap,Am,A0,t] = TestPortableCheckpointReader.advanceRK4(wvt,wvt.t+2*deltaT,deltaT);

                command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" "%s" --delta-t %.17g --steps 2 --fft-provider reference --report "%s"',runner,inputPath,outputPath,deltaT,reportPath));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                report = jsondecode(fileread(reportPath));
                testCase.verifyEqual(string(report.status),"complete")
                testCase.verifyEqual(report.state.stepCount,2)
                testCase.verifyEqual(report.state.rhsEvaluationCount,8)
                testCase.verifyTrue(report.execution.noFallback)
                testCase.verifyEqual(string(report.provider.id),"reference")
                stateElementCount = prod(report.state.shape);
                testCase.verifyEqual(report.arrayTraffic.integrator.stageStateConstructionReads,36*stateElementCount)
                testCase.verifyEqual(report.arrayTraffic.integrator.stageFluxClearWrites,0)
                testCase.verifyEqual(report.arrayTraffic.integrator.weightedFluxInitializationReads,6*stateElementCount)
                testCase.verifyEqual(report.livenessBytes.integratorWorkspaceLive,9*stateElementCount*16)
                testCase.verifyEqual(report.livenessBytes.contractAbstractionAdditionalArrayStorage,0)

                [actual,actualFile] = WVTransform.waveVortexTransformFromFile(outputPath,shouldReadOnly=true);
                actualCleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(actualFile));
                expected = {Ap;Am;A0};
                observed = {actual.Ap;actual.Am;actual.A0};
                for iCoefficient = 1:3
                    scale = max(max(abs(expected{iCoefficient}),[],"all"),realmin);
                    testCase.verifyLessThanOrEqual(max(abs(observed{iCoefficient}-expected{iCoefficient}),[],"all")/scale,1e-12,fixtureName)
                end
                testCase.verifyEqual(actual.t,t,AbsTol=4*eps(t))
                TestPortableCheckpointReader.verifyForcingEquivalent(testCase,wvt.forcing,actual.forcing)
                ncfile.close();
                actualFile.close();
                clear transformCleanup actualCleanup
            end

            inPlacePath = fullfile(outputDirectory,"in-place.nc");
            copyfile(fullfile(fixtureDirectory,"forcing-nonlinear.nc"),inPlacePath);
            [initial,initialFile] = WVTransform.waveVortexTransformFromFile(inPlacePath,shouldReadOnly=true);
            initialTime = initial.t;
            initialFile.close();
            command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" "%s" --delta-t %.17g --steps 1 --fft-provider reference',runner,inPlacePath,inPlacePath,deltaT));
            [status,output] = system(command);
            testCase.verifyEqual(status,0,output)
            [actual,actualFile] = WVTransform.waveVortexTransformFromFile(inPlacePath,shouldReadOnly=true);
            testCase.verifyEqual(actual.t,initialTime+deltaT,AbsTol=4*eps(initialTime+deltaT))
            actualFile.close();
            clear outputCleanup fixtureCleanup fixtureToolCleanup
        end

        function adaptiveTolerancesMatchMatlab(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_adaptive_tolerance_inspect");
            fixtureDirectory = fullfile(repositoryRoot,"tools","portable-runtime","fixtures");
            for fixtureName = ["forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"]
                fixturePath = fullfile(fixtureDirectory,fixtureName);
                command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" %.17g',inspector,fixturePath,1e-6));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                record = jsondecode(output);
                [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,shouldReadOnly=true);
                cleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(ncfile));
                [expectedVortex,expectedWave] = WVCoefficients.errorTolerances(wvt,1e-6);
                testCase.verifyEqual(reshape(record.wave,size(expectedWave)),expectedWave,RelTol=8*eps)
                testCase.verifyEqual(reshape(record.vortex,size(expectedVortex)),expectedVortex,RelTol=8*eps)
                ncfile.close();
                clear cleanup
            end
        end

        function cppWriterProducesMatlabCompatibleCheckpoints(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            buildScript = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [buildStatus,buildOutput] = system(sprintf('"%s"',buildScript));
            testCase.assertEqual(buildStatus,0,buildOutput)
            writer = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_checkpoint_roundtrip");
            fixtureDirectory = fullfile(repositoryRoot,"tools","portable-runtime","fixtures");
            outputDirectory = string(tempname);
            mkdir(outputDirectory)
            outputCleanup = onCleanup(@()rmdir(outputDirectory,"s"));
            fixtureNames = ["root-hydrostatic.nc" "root-nonhydrostatic.nc" "time-series-hydrostatic.nc" "time-series-nonhydrostatic.nc" "forcing-nonlinear.nc" "forcing-adaptive-damping.nc" "forcing-fixed-amplitude.nc" "forcing-quadratic-bottom-friction.nc" "forcing-pseudo-topographic.nc" "forcing-beta-plane.nc" "forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];

            for fixtureName = fixtureNames
                inputPath = fullfile(fixtureDirectory,fixtureName);
                outputPath = fullfile(outputDirectory,fixtureName);
                command = TestPortableCheckpointReader.sanitizedCommand(sprintf('"%s" "%s" "%s"',writer,inputPath,outputPath));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                [expected,expectedFile] = WVTransform.waveVortexTransformFromFile(inputPath,iTime=Inf,shouldReadOnly=true);
                expectedCleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(expectedFile));
                [actual,actualFile] = WVTransform.waveVortexTransformFromFile(outputPath,shouldReadOnly=true);
                actualCleanup = onCleanup(@()TestPortableCheckpointReader.closeIfOpen(actualFile));
                testCase.verifyEqual([actual.Nx actual.Ny actual.Nz],[expected.Nx expected.Ny expected.Nz])
                testCase.verifyEqual([actual.Lx actual.Ly actual.Lz],[expected.Lx expected.Ly expected.Lz])
                testCase.verifyEqual(actual.t,expected.t)
                testCase.verifyEqual(actual.t0,expected.t0)
                testCase.verifyEqual(actual.isHydrostatic,expected.isHydrostatic)
                testCase.verifyEqual(actual.shouldAntialias,expected.shouldAntialias)
                testCase.verifyTrue(isequaln(actual.Ap,expected.Ap))
                testCase.verifyTrue(isequaln(actual.Am,expected.Am))
                testCase.verifyTrue(isequaln(actual.A0,expected.A0))
                TestPortableCheckpointReader.verifyForcingEquivalent(testCase,expected.forcing,actual.forcing)
                expectedFile.close();
                actualFile.close();
                clear expectedCleanup actualCleanup
            end
            clear outputCleanup
        end
    end

    methods (Static, Access=private)
        function [Ap,Am,A0,t,stepCount] = advanceRK4(wvt,finalTime,deltaT)
            TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
            stepCount = 0;
            while wvt.t < finalTime
                h = min(deltaT,finalTime-wvt.t);
                Ap0 = wvt.Ap; Am0 = wvt.Am; A00 = wvt.A0; t0 = wvt.t;
                [k1p,k1m,k10] = wvt.nonlinearFlux();
                wvt.Ap = Ap0+0.5*h*k1p; wvt.Am = Am0+0.5*h*k1m; wvt.A0 = A00+0.5*h*k10; wvt.t = t0+0.5*h; TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
                [k2p,k2m,k20] = wvt.nonlinearFlux();
                wvt.Ap = Ap0+0.5*h*k2p; wvt.Am = Am0+0.5*h*k2m; wvt.A0 = A00+0.5*h*k20; TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
                [k3p,k3m,k30] = wvt.nonlinearFlux();
                wvt.Ap = Ap0+h*k3p; wvt.Am = Am0+h*k3m; wvt.A0 = A00+h*k30; wvt.t = t0+h; TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
                [k4p,k4m,k40] = wvt.nonlinearFlux();
                wvt.Ap = Ap0+(h/6)*(k1p+2*k2p+2*k3p+k4p);
                wvt.Am = Am0+(h/6)*(k1m+2*k2m+2*k3m+k4m);
                wvt.A0 = A00+(h/6)*(k10+2*k20+2*k30+k40);
                wvt.t = t0+h;
                TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
                stepCount = stepCount+1;
            end
            Ap = wvt.Ap; Am = wvt.Am; A0 = wvt.A0; t = wvt.t;
        end

        function restoreFixedAmplitudes(wvt)
            forcing = wvt.forcing;
            fixed = forcing(arrayfun(@(force)isa(force,"WVFixedAmplitudeForcing"),forcing));
            for force = fixed
                wvt.Ap(force.Ap_indices) = force.Apbar;
                wvt.Am(force.Am_indices) = force.Ambar;
                wvt.A0(force.A0_indices) = force.A0bar;
            end
        end

        function flux = rhsAtState(wvt,t,state)
            wvt.t = t;
            wvt.Ap = state{1};
            wvt.Am = state{2};
            wvt.A0 = state{3};
            TestPortableCheckpointReader.restoreFixedAmplitudes(wvt)
            flux = cell(3,1);
            [flux{:}] = wvt.nonlinearFlux();
        end

        function verifyForcingEquivalent(testCase,expected,actual)
            testCase.verifyEqual(numel(actual),numel(expected))
            for iForcing = 1:numel(expected)
                testCase.verifyEqual(class(actual(iForcing)),class(expected(iForcing)))
                testCase.verifyEqual(string(actual(iForcing).name),string(expected(iForcing).name))
                testCase.verifyEqual(actual(iForcing).priority,expected(iForcing).priority)
                if isa(expected(iForcing),"WVBottomFrictionQuadratic")
                    testCase.verifyEqual(actual(iForcing).Cd,expected(iForcing).Cd)
                elseif isa(expected(iForcing),"WVFixedAmplitudeForcing")
                    testCase.verifyEqual(actual(iForcing).Ap_indices,expected(iForcing).Ap_indices)
                    testCase.verifyEqual(actual(iForcing).Am_indices,expected(iForcing).Am_indices)
                    testCase.verifyEqual(actual(iForcing).A0_indices,expected(iForcing).A0_indices)
                    testCase.verifyEqual(actual(iForcing).Apbar,expected(iForcing).Apbar)
                    testCase.verifyEqual(actual(iForcing).Ambar,expected(iForcing).Ambar)
                    testCase.verifyEqual(actual(iForcing).A0bar,expected(iForcing).A0bar)
                elseif isa(expected(iForcing),"WVPseudoTopographicWaveGeneration")
                    testCase.verifyEqual(actual(iForcing).topographicHeight,expected(iForcing).topographicHeight)
                    testCase.verifyEqual(actual(iForcing).barotropicVelocityAmplitude,expected(iForcing).barotropicVelocityAmplitude)
                    testCase.verifyEqual(actual(iForcing).frequency,expected(iForcing).frequency)
                    testCase.verifyEqual(actual(iForcing).darwinSymbol,expected(iForcing).darwinSymbol)
                    testCase.verifyEqual(actual(iForcing).rampDuration,expected(iForcing).rampDuration)
                    testCase.verifyEqual(actual(iForcing).startTime,expected(iForcing).startTime)
                    testCase.verifyEqual(actual(iForcing).shouldAvoidAdaptiveDamping,expected(iForcing).shouldAvoidAdaptiveDamping)
                    testCase.verifyEqual(actual(iForcing).maximumForcedHorizontalWavenumber,expected(iForcing).maximumForcedHorizontalWavenumber)
                    testCase.verifyEqual(actual(iForcing).maximumForcedVerticalMode,expected(iForcing).maximumForcedVerticalMode)
                end
            end
        end

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
