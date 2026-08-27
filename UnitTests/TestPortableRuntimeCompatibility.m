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
            [status,output] = systemWithoutMatlabRuntime(configure);
            testCase.assertEqual(status,0,output)
            [status,output] = systemWithoutMatlabRuntime("cmake --build " + shellQuote(buildDirectory) + ...
                " --parallel --target wave-vortex-run");
            testCase.assertEqual(status,0,output)
            testCase.Runner = fullfile(buildDirectory,"wave-vortex-run");
            testCase.assertTrue(isfile(testCase.Runner))
        end
    end

    methods (Test, TestTags = "full")
        function matlabFixtureRunsAndRuntimeCheckpointRestores(testCase)
            inputPath = fullfile(testCase.RepositoryRoot,"PortableRuntime","tests", ...
                "fixtures","forcing-nonlinear.nc");
            outputPath = fullfile(testCase.TemporaryFolder,"runtime-output.nc");
            command = shellQuote(testCase.Runner) + " " + shellQuote(inputPath) + ...
                " " + shellQuote(outputPath) + ...
                " --restart-mode coefficients --output-policy create" + ...
                " --delta-t 0.01 --steps 1 --fft-provider reference";
            [status,output] = systemWithoutMatlabRuntime(command);
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

        function matlabModelGraphRoundTripsThroughStandalone(testCase)
            sourcePath = fullfile(testCase.TemporaryFolder,"matlab-model.nc");
            controlPath = fullfile(testCase.TemporaryFolder,"matlab-control.nc");
            source = testCase.createNonlinearModel(sourcePath);
            source.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            source.closeNetCDFFile();
            copyfile(sourcePath,controlPath)

            command = shellQuote(testCase.Runner) + " " + shellQuote(sourcePath) + ...
                " --restart-mode model --output-policy append" + ...
                " --delta-t 1e-4 --final-time 2e-4 --fft-provider reference";
            [status,output] = systemWithoutMatlabRuntime(command);
            testCase.assertEqual(status,0,output)
            report = jsondecode(output);
            testCase.verifyEqual(string(report.status),"complete")
            testCase.verifyEqual(string(report.restartMode),"model")
            testCase.verifyEqual(string(report.outputPolicy),"append")
            testCase.verifySubstring(string(report.execution.schedule),"WVBottomFrictionLinear")
            testCase.verifyTrue(report.execution.noFallback)
            testCase.verifyGreaterThan(report.forcingOperations.physicalFieldReconstructionCount,0)
            testCase.verifyEqual(report.forcingOperations.physicalFieldReconstructionCount,report.forcingOperations.evaluationCount)
            testCase.verifyGreaterThanOrEqual(report.forcingOperations.physicalFieldReuseCount,2*report.forcingOperations.evaluationCount)
            testCase.verifyEqual(report.forcingOperations.spatialTendencyProjectionCount,2*report.forcingOperations.physicalFieldReconstructionCount)
            testCase.verifyGreaterThan(report.forcingOperations.spatialTendencyClearElementWrites,0)

            runtimeModel = WVModel.modelFromFile(char(sourcePath));
            runtimeCleanup = onCleanup(@()runtimeModel.closeNetCDFFile());
            controlModel = WVModel.modelFromFile(char(controlPath));
            controlCleanup = onCleanup(@()controlModel.closeNetCDFFile());
            controlModel.setupIntegrator(integratorType="fixed",deltaT=1e-4);
            controlModel.integrateToTime(2e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);

            testCase.verifyModelGraphsEqual(runtimeModel,controlModel)
            testCase.verifyEqual(runtimeModel.wvt.Ap,controlModel.wvt.Ap,AbsTol=1e-12)
            testCase.verifyEqual(runtimeModel.wvt.Am,controlModel.wvt.Am,AbsTol=1e-12)
            testCase.verifyEqual(runtimeModel.wvt.A0,controlModel.wvt.A0,AbsTol=1e-12)
            [runtimeX,runtimeY,runtimeZ] = runtimeModel.floatPositions();
            [controlX,controlY,controlZ] = controlModel.floatPositions();
            testCase.verifyEqual(runtimeX,controlX,AbsTol=1e-8)
            testCase.verifyEqual(runtimeY,controlY,AbsTol=1e-8)
            testCase.verifyEqual(runtimeZ,controlZ,AbsTol=1e-10)
            testCase.verifyEqual(runtimeModel.tracer("dye"),controlModel.tracer("dye"),AbsTol=1e-8)
            testCase.verifyEqual(runtimeModel.outputFileWithName("matlab-model.nc").outputGroupWithName("wave-vortex").incrementsWrittenToGroup,uint64(3))
            testCase.verifyEqual(runtimeModel.outputFileWithName("matlab-model.nc").outputGroupWithName("particles").incrementsWrittenToGroup,uint64(3))
            testCase.verifyEqual(runtimeModel.outputFileWithName("matlab-model.nc").outputGroupWithName("tracers").incrementsWrittenToGroup,uint64(3))
            clear runtimeCleanup controlCleanup
        end

        function linearAdaptiveGraphRoundTripsThroughStandalone(testCase)
            sourcePath = fullfile(testCase.TemporaryFolder,"linear-model.nc");
            wvt = WVTransformConstantStratification([4000 3000 1000],[8 6 5], ...
                N0=sqrt(2e-5),latitude=45,isHydrostatic=false,shouldAntialias=false);
            wvt.Ap(2) = 2e-4 + 1e-4i;
            model = WVModel(wvt,shouldUseLinearDynamics=true);
            outputFile = model.createNetCDFFileForModelOutput(sourcePath, ...
                outputInterval=1e-4,shouldOverwriteExisting=true);
            model.eulerianObservingSystem.addNetCDFOutputVariables('u');
            model.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            model.closeNetCDFFile();

            command = shellQuote(testCase.Runner) + " " + shellQuote(sourcePath) + ...
                " --restart-mode model --output-policy append" + ...
                " --integrator adaptive-rk23 --relative-tolerance 1e-6" + ...
                " --absolute-tolerance 1e-8 --delta-t 1e-4" + ...
                " --final-time 2e-4 --fft-provider reference";
            [status,output] = systemWithoutMatlabRuntime(command);
            testCase.assertEqual(status,0,output)
            restored = WVModel.modelFromFile(char(sourcePath));
            cleanup = onCleanup(@()restored.closeNetCDFFile());
            testCase.verifyTrue(restored.isDynamicsLinear)
            testCase.verifyEqual(restored.wvt.t,2e-4,AbsTol=1e-14)
            testCase.verifyEqual(restored.wvt.Ap(2),wvt.Ap(2),AbsTol=1e-14)
            testCase.verifyEqual(restored.outputFileWithName("linear-model.nc").outputGroupWithName("wave-vortex").incrementsWrittenToGroup,uint64(3))
            clear cleanup
        end

        function linearBottomFrictionMatchesMatlabFixedAndAdaptive(testCase)
            cases = {
                true, "fixed", 5, 0; ...
                false, "fixed", 7, 2.5e-7; ...
                true, "ode23", 7, 2.5e-7; ...
                false, "ode23", 5, 2.5e-7; ...
                true, "ode45", 5, 2.5e-7; ...
                false, "ode45", 7, 2.5e-7};
            for iCase = 1:size(cases,1)
                isHydrostatic = cases{iCase,1};
                integratorType = cases{iCase,2};
                Nz = cases{iCase,3};
                r = cases{iCase,4};
                caseName = sprintf("linear-%s-h%d-nz%d",integratorType,isHydrostatic,Nz);
                sourcePath = fullfile(testCase.TemporaryFolder,caseName+"-source.nc");
                controlPath = fullfile(testCase.TemporaryFolder,caseName+"-control.nc");
                model = testCase.createLinearBottomFrictionModel(sourcePath,isHydrostatic,Nz,r,integratorType);
                model.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                model.closeNetCDFFile();
                copyfile(sourcePath,controlPath)

                command = shellQuote(testCase.Runner) + " " + shellQuote(sourcePath) + ...
                    " --restart-mode model --output-policy append" + ...
                    " --delta-t 1e-5 --final-time 2e-4 --fft-provider reference";
                if ismember(integratorType,["ode23" "ode45"])
                    command = command + " --integrator adaptive-rk" + extractAfter(integratorType,"ode") + ...
                        " --relative-tolerance 1e-8 --absolute-tolerance 1e-10" + ...
                        " --maximum-step 1e-5";
                end
                [status,output] = systemWithoutMatlabRuntime(command);
                testCase.assertEqual(status,0,output)
                report = jsondecode(output);
                testCase.verifySubstring(string(report.execution.schedule),"WVBottomFrictionLinear")
                testCase.verifyTrue(report.execution.noFallback)
                testCase.verifyEqual(report.forcingOperations.physicalFieldReconstructionCount,report.forcingOperations.evaluationCount)

                runtimeModel = WVModel.modelFromFile(char(sourcePath));
                runtimeCleanup = onCleanup(@()runtimeModel.closeNetCDFFile());
                controlModel = WVModel.modelFromFile(char(controlPath));
                controlCleanup = onCleanup(@()controlModel.closeNetCDFFile());
                testCase.configureLinearIntegrator(controlModel,integratorType);
                controlModel.integrateToTime(2e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                testCase.verifyEqual(runtimeModel.wvt.forcingWithName("linear bottom friction").r,r)
                testCase.verifyEqual(runtimeModel.wvt.forcingWithName("linear bottom friction").r_scaled,2*(Nz-1)*r,RelTol=10*eps)
                testCase.verifyLessThanOrEqual(testCase.normalizedCoefficientError(runtimeModel.wvt,controlModel.wvt),1e-12,caseName)
                clear runtimeCleanup controlCleanup
            end
        end

        function linearOde78EndpointMatchesMatlab(testCase)
            sourcePath = fullfile(testCase.TemporaryFolder,"linear-ode78-source.nc");
            controlPath = fullfile(testCase.TemporaryFolder,"linear-ode78-control.nc");
            runtimePath = fullfile(testCase.TemporaryFolder,"linear-ode78-runtime.nc");
            model = testCase.createLinearBottomFrictionModel(sourcePath,false,7,2.5e-7,"ode78");
            model.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            model.closeNetCDFFile();
            copyfile(sourcePath,controlPath)

            command = shellQuote(testCase.Runner) + " " + shellQuote(sourcePath) + ...
                " " + shellQuote(runtimePath) + ...
                " --restart-mode coefficients --output-policy create" + ...
                " --integrator adaptive-rk78 --relative-tolerance 1e-8" + ...
                " --absolute-tolerance 1e-10 --delta-t 1e-5" + ...
                " --initial-step 1e-5 --maximum-step 1e-5" + ...
                " --final-time 2e-4 --fft-provider reference";
            [status,output] = systemWithoutMatlabRuntime(command);
            testCase.assertEqual(status,0,output)
            report = jsondecode(output);
            testCase.verifyEqual(string(report.integrator.id),"adaptive-rk78")
            testCase.verifyEqual(string(report.integrator.controller),"matlab-ode78-v1")
            testCase.verifyEqual(report.integrator.workspaceStateEquivalentCount,11)
            testCase.verifyEqual(report.integrator.denseHistoryStateEquivalentCount,0)

            [runtimeTransform,runtimeFile] = WVTransform.waveVortexTransformFromFile(runtimePath,shouldReadOnly=true);
            runtimeCleanup = onCleanup(@()runtimeFile.close());
            controlModel = WVModel.modelFromFile(char(controlPath));
            controlCleanup = onCleanup(@()controlModel.closeNetCDFFile());
            testCase.configureLinearIntegrator(controlModel,"ode78");
            controlModel.integrateToTime(2e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            testCase.verifyLessThanOrEqual(testCase.normalizedCoefficientError(runtimeTransform,controlModel.wvt),1e-12)
            clear runtimeCleanup controlCleanup
        end

        function linearOde78ContinuousOutputMatchesMatlab(testCase)
            sourcePath = fullfile(testCase.TemporaryFolder,"linear-ode78-dense-source.nc");
            controlPath = fullfile(testCase.TemporaryFolder,"linear-ode78-dense-control.nc");
            outputDirectory = fullfile(testCase.TemporaryFolder,"linear-ode78-dense-output");
            model = testCase.createLinearBottomFrictionModel(sourcePath,false,7,2.5e-7,"ode78");
            model.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            model.closeNetCDFFile();
            copyfile(sourcePath,controlPath)

            requestedTimes = [1.25e-4 1.5e-4 1.75e-4 2e-4];
            command = shellQuote(testCase.Runner) + " " + shellQuote(sourcePath) + ...
                " --restart-mode coefficients --output-policy create" + ...
                " --integrator adaptive-rk78 --relative-tolerance 1e-8" + ...
                " --absolute-tolerance 1e-10 --delta-t 1e-4" + ...
                " --initial-step 1e-4 --maximum-step 1e-4" + ...
                " --final-time 2e-4 --fft-provider reference";
            for requestedTime = requestedTimes
                command = command + " --output-time " + string(requestedTime);
            end
            command = command + " --output-directory " + shellQuote(outputDirectory);
            [status,output] = systemWithoutMatlabRuntime(command);
            testCase.assertEqual(status,0,output)
            report = jsondecode(output);
            testCase.verifyEqual(report.integrator.baseRightHandSideEvaluationCount,13)
            testCase.verifyEqual(report.integrator.continuousExtensionRightHandSideEvaluationCount,4)
            testCase.verifyEqual(report.integrator.denseOutputCacheBuildCount,1)
            testCase.verifyEqual(report.integrator.denseOutputCacheReuseCount,2)
            testCase.verifyEqual(report.integrator.retainedBaseStageStateEquivalentCount,8)
            testCase.verifyEqual(report.integrator.continuousExtensionWorkspaceStateEquivalentCount,4)
            testCase.verifyEqual(report.integrator.workspaceMaximumLiveStateEquivalentCount,15)

            runtimeFiles = dir(fullfile(outputDirectory,"*.nc"));
            testCase.assertNumElements(runtimeFiles,numel(requestedTimes))
            controlModel = WVModel.modelFromFile(char(controlPath));
            controlCleanup = onCleanup(@()controlModel.closeNetCDFFile());
            testCase.configureLinearIntegrator(controlModel,"ode78");
            for iTime = 1:numel(requestedTimes)
                controlModel.integrateToTime(requestedTimes(iTime), ...
                    shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                runtimePath = fullfile(runtimeFiles(iTime).folder,runtimeFiles(iTime).name);
                [runtimeTransform,runtimeFile] = WVTransform.waveVortexTransformFromFile( ...
                    runtimePath,shouldReadOnly=true);
                runtimeCleanup = onCleanup(@()runtimeFile.close());
                testCase.verifyEqual(runtimeTransform.t,requestedTimes(iTime),AbsTol=4*eps(requestedTimes(iTime)))
                testCase.verifyLessThanOrEqual( ...
                    testCase.normalizedCoefficientError(runtimeTransform,controlModel.wvt),1e-12)
                clear runtimeCleanup
            end
            clear controlCleanup
        end

        function matlabCFLReferenceFixturesMatchPortableConstants(testCase)
            cfl = 0.4;
            fixtures = {
                false, 0.1020286099012897, 23522.813868795667, 3.2273103327544224e8, 0.0013924156036910925, 1804.9741156372481; ...
                true, 0.10202859972462885, 23522.816215036815, 3.117452951358881e8, 0.0014450221120718154, 1739.2634354005847};
            for iFixture = 1:size(fixtures,1)
                isHydrostatic = fixtures{iFixture,1};
                wvt = WVTransformConstantStratification([15000 12000 1300],[6 5 7], ...
                    N0=5.2e-3,rho0=1027,g=9.80665,planetaryRadius=6.3712e6, ...
                    rotationRate=7.292115e-5,latitude=33, ...
                    isHydrostatic=isHydrostatic,shouldAntialias=true);
                testCase.setConstantCFLFixtureState(wvt)
                candidates = testCase.matlabCFLCandidates(wvt,cfl);
                testCase.verifyEqual(candidates.effectiveHorizontalGridResolution,6000.0000000000009,RelTol=1e-13)
                testCase.verifyEqual(candidates.maximumHorizontalSpeed,fixtures{iFixture,2},RelTol=1e-12)
                testCase.verifyEqual(candidates.horizontalAdvective,fixtures{iFixture,3},RelTol=1e-12)
                testCase.verifyEqual(candidates.verticalAdvective,fixtures{iFixture,4},RelTol=1e-12)
                testCase.verifyEqual(candidates.highestActiveWaveFrequency,fixtures{iFixture,5},RelTol=1e-12)
                testCase.verifyEqual(candidates.oscillatory,fixtures{iFixture,6},RelTol=1e-12)
            end

            qg = WVTransformBarotropicQG([15000 12000],[6 5],h=0.8,j=1, ...
                g=9.80665,planetaryRadius=6.3712e6,rotationRate=7.292115e-5, ...
                latitude=33,shouldAntialias=true);
            p = reshape(1:numel(qg.A0),[],1);
            qg.A0(:) = complex(1e-5*sin(0.19*(p+4)),1e-5*cos(0.05*(p+5)));
            testCase.verifyEqual(qg.effectiveHorizontalGridResolution,6000.0000000000009,RelTol=1e-13)
            testCase.verifyEqual(qg.uvMax,0.11956917129957827,RelTol=1e-12)
            testCase.verifyEqual(cfl*qg.effectiveHorizontalGridResolution/qg.uvMax,20072.063508635067,RelTol=1e-12)
            testCase.verifyFalse(qg.hasWaveComponent)
        end

        function runRequestV2MatchesCFLAndExactMatlabSolvers(testCase)
            sourcePath = fullfile(testCase.TemporaryFolder,"request-v2-source.nc");
            model = testCase.createLinearBottomFrictionModel(sourcePath,false,7,2.5e-7,"fixed");
            model.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            sourceTime = model.wvt.t;
            fixedFinalTime = sourceTime+1e-4;
            adaptiveFinalTime = sourceTime+2e-4;
            candidates = testCase.matlabCFLCandidates(model.wvt,0.25);
            selectedStep = min(candidates.advective,candidates.oscillatory);
            model.closeNetCDFFile();

            explicitPath = fullfile(testCase.TemporaryFolder,"request-v2-explicit.nc");
            cflPath = fullfile(testCase.TemporaryFolder,"request-v2-cfl.nc");
            copyfile(sourcePath,explicitPath)
            copyfile(sourcePath,cflPath)
            explicit = struct(method="fixed-rk4",finalTime=fixedFinalTime,initialStep=selectedStep);
            explicitReport = testCase.runV2Request(explicitPath,explicit,"request-v2-explicit-report.json");
            cflIntegration = struct(method="fixed-rk4",finalTime=fixedFinalTime,cfl=0.25,timeStepConstraint="min");
            cflReport = testCase.runV2Request(cflPath,cflIntegration,"request-v2-cfl-report.json");
            testCase.verifyEqual(string(cflReport.integrationRequest.requestedMethod),"fixed-rk4")
            testCase.verifyEqual(string(cflReport.integrationRequest.activeMethod),"fixed-rk4")
            testCase.verifyEqual(string(cflReport.integrationRequest.stepPolicy),"cfl")
            testCase.verifyTrue(cflReport.integrationRequest.noFallback)
            testCase.verifyEqual(cflReport.integrationRequest.candidates.horizontalAdvective,candidates.horizontalAdvective,RelTol=1e-12)
            if isinf(candidates.verticalAdvective)
                testCase.verifyEqual(string(cflReport.integrationRequest.candidates.verticalAdvective),"infinity")
            else
                testCase.verifyEqual(cflReport.integrationRequest.candidates.verticalAdvective,candidates.verticalAdvective,RelTol=1e-12)
            end
            testCase.verifyEqual(cflReport.integrationRequest.candidates.advective,candidates.advective,RelTol=1e-12)
            testCase.verifyEqual(cflReport.integrationRequest.candidates.oscillatory,candidates.oscillatory,RelTol=1e-12)
            testCase.verifyEqual(cflReport.integrationRequest.selectedStep,selectedStep,RelTol=1e-12)
            testCase.verifyGreaterThan(cflReport.integrationRequest.transientWorkspaceMaximumLiveBytes,0)
            testCase.verifyTrue(all(isfield(cflReport.timingSeconds,["parse" "preflight" "provider" "startup"])))
            explicitModel = WVModel.modelFromFile(char(explicitPath));
            explicitCleanup = onCleanup(@()explicitModel.closeNetCDFFile());
            cflModel = WVModel.modelFromFile(char(cflPath));
            cflCleanup = onCleanup(@()cflModel.closeNetCDFFile());
            testCase.verifyLessThanOrEqual(testCase.normalizedCoefficientError(explicitModel.wvt,cflModel.wvt),1e-12)
            testCase.verifyEqual(string(explicitReport.integrationRequest.stepPolicy),"explicit")
            testCase.verifyEqual(explicitReport.integrationRequest.selectedStep,selectedStep,RelTol=1e-12)
            testCase.verifyEqual(explicitReport.integrator.requestedInitialStep,selectedStep,RelTol=1e-12)
            clear explicitCleanup cflCleanup

            methods = ["ode23" "ode45" "ode78"];
            identifiers = ["adaptive-rk23" "adaptive-rk45" "adaptive-rk78"];
            controllers = ["matlab-ode23-v1" "matlab-ode45-v1" "matlab-ode78-v1"];
            for iMethod = 1:numel(methods)
                runtimePath = fullfile(testCase.TemporaryFolder,"request-v2-"+methods(iMethod)+"-runtime.nc");
                controlPath = fullfile(testCase.TemporaryFolder,"request-v2-"+methods(iMethod)+"-control.nc");
                copyfile(sourcePath,runtimePath)
                copyfile(sourcePath,controlPath)
                integration = struct(method=identifiers(iMethod),finalTime=adaptiveFinalTime, ...
                    initialStep=2e-4,maximumStep=2e-4, ...
                    relativeTolerance=1e-8,absoluteToleranceScale=1e-10);
                report = testCase.runV2Request(runtimePath,integration,"request-v2-"+methods(iMethod)+"-report.json");
                testCase.verifyEqual(string(report.integrationRequest.requestedMethod),identifiers(iMethod))
                testCase.verifyEqual(string(report.integrationRequest.activeMethod),identifiers(iMethod))
                testCase.verifyEqual(string(report.integrationRequest.controller),controllers(iMethod))
                testCase.verifyTrue(report.integrationRequest.noFallback)
                testCase.verifyEqual(report.integrator.requestedInitialStep,integration.initialStep,RelTol=1e-12)
                testCase.verifyEqual(report.integrator.requestedMaximumStep,integration.maximumStep,RelTol=1e-12)
                testCase.verifyEqual(report.integrator.relativeTolerance,integration.relativeTolerance)
                testCase.verifyEqual(report.integrator.absoluteTolerance,integration.absoluteToleranceScale)
                if methods(iMethod) == "ode78"
                    testCase.verifyEqual(report.integrator.continuousExtensionRightHandSideEvaluationCount,4)
                    testCase.verifyEqual(report.integrator.denseOutputCacheBuildCount,1)
                end
                runtimeModel = WVModel.modelFromFile(char(runtimePath));
                runtimeCleanup = onCleanup(@()runtimeModel.closeNetCDFFile());
                controlModel = WVModel.modelFromFile(char(controlPath));
                controlCleanup = onCleanup(@()controlModel.closeNetCDFFile());
                testCase.configureLinearIntegrator(controlModel,methods(iMethod));
                controlModel.integrateToTime(adaptiveFinalTime,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                testCase.verifyLessThanOrEqual(testCase.normalizedCoefficientError(runtimeModel.wvt,controlModel.wvt),1e-12,methods(iMethod))
                clear runtimeCleanup controlCleanup
            end
        end

        function barotropicQGModelOutputRoundTripsThroughStandalone(testCase)
            cases = {
                [5 4], 0, false; ...
                [6 5], 1, true; ...
                [5 6], 1, false; ...
                [6 4], 0, true};
            fieldNames = ["u" "v" "eta" "pi" "psi" "qgpv" "zeta_z" "ssh"];
            maximumCoefficientError = 0;
            maximumFieldError = 0;
            maximumParticleError = 0;
            maximumTracerError = 0;
            for iCase = 1:size(cases,1)
                Nxy = cases{iCase,1};
                j = cases{iCase,2};
                shouldAntialias = cases{iCase,3};
                caseName = sprintf("qg-%dx%d-j%d-a%d",Nxy(1),Nxy(2),j,shouldAntialias);
                runtimePath = fullfile(testCase.TemporaryFolder,caseName+"-runtime.nc");
                controlPath = fullfile(testCase.TemporaryFolder,caseName+"-control.nc");
                source = testCase.createBarotropicQGModel(runtimePath,Nxy,j,shouldAntialias);
                source.integrateToTime(0.01,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                source.closeNetCDFFile();
                copyfile(runtimePath,controlPath)

                command = shellQuote(testCase.Runner) + " " + shellQuote(runtimePath) + ...
                    " --restart-mode model --output-policy append" + ...
                    " --integrator fixed-rk4 --delta-t 0.0025" + ...
                    " --final-time 0.02 --fft-provider reference";
                [status,output] = systemWithoutMatlabRuntime(command);
                testCase.assertEqual(status,0,output)
                report = jsondecode(output);
                testCase.verifyEqual(string(report.status),"complete",caseName)
                testCase.verifyEqual(string(report.execution.engine),"reference-direct",caseName)
                testCase.verifyEqual(report.execution.planCount,3,caseName)
                testCase.verifyEqual(report.storageBytes.persistentFullHermitian,0,caseName)
                testCase.verifyGreaterThan(report.forcingOperations.physicalFieldReuseCount,0,caseName)
                testCase.verifyGreaterThan(report.integrationBreakdownSeconds.tracerAdvection,0,caseName)
                testCase.verifyGreaterThan(report.integrationBreakdownSeconds.particleAdvection,0,caseName)

                runtimeModel = WVModel.modelFromFile(char(runtimePath));
                runtimeCleanup = onCleanup(@()runtimeModel.closeNetCDFFile());
                controlModel = WVModel.modelFromFile(char(controlPath));
                controlCleanup = onCleanup(@()controlModel.closeNetCDFFile());
                controlModel.setupIntegrator(integratorType="fixed",deltaT=0.0025);
                controlModel.integrateToTime(0.02,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                [coefficientError,fieldError,particleError,tracerError] = ...
                    testCase.verifyBarotropicQGModelsEqual(runtimeModel,controlModel,fieldNames,caseName);
                maximumCoefficientError = max(maximumCoefficientError,coefficientError);
                maximumFieldError = max(maximumFieldError,fieldError);
                maximumParticleError = max(maximumParticleError,particleError);
                maximumTracerError = max(maximumTracerError,tracerError);
                testCase.verifyModelGraphsEqual(runtimeModel,controlModel)
                runtimeForcingNames = runtimeModel.wvt.forcingNames;
                controlForcingNames = controlModel.wvt.forcingNames;
                testCase.verifyEqual(string(runtimeForcingNames(:)), ...
                    string(controlForcingNames(:)),caseName)
                testCase.verifyEqual(runtimeModel.outputFiles(1).outputGroups(1).incrementsWrittenToGroup,uint64(5),caseName)

                for iGroup = 1:numel(runtimeModel.outputFiles(1).outputGroups)
                    runtimeModel.outputFiles(1).outputGroups(iGroup).finalTime = runtimeModel.wvt.t;
                    controlModel.outputFiles(1).outputGroups(iGroup).finalTime = controlModel.wvt.t;
                end
                runtimeModel.setupIntegrator(integratorType="fixed",deltaT=0.0025);
                runtimeFinalTime = runtimeModel.wvt.t + 4*0.0025;
                controlFinalTime = controlModel.wvt.t + 4*0.0025;
                runtimeModel.integrateToTime(runtimeFinalTime,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                controlModel.integrateToTime(controlFinalTime,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                [coefficientError,fieldError,particleError,tracerError] = ...
                    testCase.verifyBarotropicQGModelsEqual(runtimeModel,controlModel,fieldNames,caseName+" MATLAB continuation");
                maximumCoefficientError = max(maximumCoefficientError,coefficientError);
                maximumFieldError = max(maximumFieldError,fieldError);
                maximumParticleError = max(maximumParticleError,particleError);
                maximumTracerError = max(maximumTracerError,tracerError);
                clear runtimeCleanup controlCleanup
            end
            fprintf("Barotropic QG model-output MATLAB/C++ coefficient error: %.3e\n",maximumCoefficientError)
            fprintf("Barotropic QG model-output MATLAB/C++ field error: %.3e\n",maximumFieldError)
            fprintf("Barotropic QG model-output MATLAB/C++ particle error: %.3e\n",maximumParticleError)
            fprintf("Barotropic QG model-output MATLAB/C++ tracer error: %.3e\n",maximumTracerError)
        end

        function matlabWriterRequestsDecodeAndRunEveryIntegrationForm(testCase)
            sourceFixture = fullfile(testCase.TemporaryFolder,"writer-source.nc");
            sourceModel = testCase.createLinearBottomFrictionModel(sourceFixture,true,5,0,"fixed");
            sourceModel.integrateToTime(1e-4,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            sourceModel.closeNetCDFFile();
            forms = {
                1,"fixed-rk4","explicit";
                1,"adaptive-rk23","adaptive";
                2,"fixed-rk4","explicit";
                2,"fixed-rk4","advective";
                2,"fixed-rk4","oscillatory";
                2,"fixed-rk4","min";
                2,"adaptive-rk23","adaptive";
                2,"adaptive-rk45","adaptive";
                2,"adaptive-rk78","adaptive";
                };
            for iForm = 1:size(forms,1)
                schemaVersion = forms{iForm,1};
                method = forms{iForm,2};
                policy = forms{iForm,3};
                stem = "writer-v"+schemaVersion+"-"+method+"-"+policy;
                modelPath = fullfile(testCase.TemporaryFolder,stem+".nc");
                requestPath = fullfile(testCase.TemporaryFolder,stem+".json");
                reportPath = stem+"-report.json";
                copyfile(sourceFixture,modelPath)
                ncwriteatt(modelPath,"/","portableFileIdentifier",stem);
                times = ncread(modelPath,"/wave-vortex/t");
                finalTime = times(end);
                if policy == "explicit"
                    WVModel.writePortableRunRequest(requestPath,modelPath, ...
                        schemaVersion=schemaVersion,method=method,finalTime=finalTime,initialStep=.25, ...
                        reportPath=reportPath);
                elseif method == "fixed-rk4"
                    WVModel.writePortableRunRequest(requestPath,modelPath, ...
                        schemaVersion=schemaVersion,method=method,finalTime=finalTime,cfl=.25, ...
                        timeStepConstraint=policy,reportPath=reportPath);
                else
                    WVModel.writePortableRunRequest(requestPath,modelPath, ...
                        schemaVersion=schemaVersion,method=method,finalTime=finalTime, ...
                        initialStep=.25,maximumStep=1,relativeTolerance=1e-3, ...
                        absoluteToleranceScale=1e-6,reportPath=reportPath);
                end
                immutableRequest = fileread(requestPath);
                command = shellQuote(testCase.Runner)+" --request "+shellQuote(requestPath);
                [status,output] = systemWithoutMatlabRuntime(command);
                testCase.assertEqual(status,0,output)
                testCase.verifyEqual(fileread(requestPath),immutableRequest)
                report = jsondecode(fileread(fullfile(testCase.TemporaryFolder,reportPath)));
                testCase.verifyEqual(string(report.status),"complete")
                testCase.verifyEqual(string(report.request.schemaIdentifier),"wave-vortex-run-request-v"+schemaVersion)
                testCase.verifyEqual(report.request.schemaVersion,schemaVersion)
                testCase.verifyEqual(string(report.integrator.id),method)
                if schemaVersion == 2
                    testCase.verifyEqual(string(report.integrationRequest.requestedMethod),method)
                    testCase.verifyTrue(report.integrationRequest.noFallback)
                end
            end
        end

        function matlabWriterBarotropicQGRequestsDecodeAndRun(testCase)
            sourceFixture = fullfile(testCase.TemporaryFolder,"writer-qg-source.nc");
            sourceModel = testCase.createBarotropicQGModel(sourceFixture,[6 5],1,true);
            sourceModel.integrateToTime(.005,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            sourceModel.closeNetCDFFile();
            forms = {
                "fixed-rk4", "explicit"; ...
                "fixed-rk4", "cfl"; ...
                "adaptive-rk23", "adaptive"; ...
                "adaptive-rk45", "adaptive"; ...
                "adaptive-rk78", "adaptive"};
            for iForm = 1:size(forms,1)
                method = forms{iForm,1};
                stepPolicy = forms{iForm,2};
                stem = "writer-qg-"+method+"-"+stepPolicy;
                modelPath = fullfile(testCase.TemporaryFolder,stem+".nc");
                requestPath = fullfile(testCase.TemporaryFolder,stem+".json");
                reportName = stem+"-report.json";
                copyfile(sourceFixture,modelPath)
                ncwriteatt(modelPath,"/","portableFileIdentifier",stem);
                if stepPolicy == "explicit"
                    WVModel.writePortableRunRequest(requestPath,modelPath, ...
                        schemaVersion=2,method=method,finalTime=.01,initialStep=.0025,reportPath=reportName);
                elseif stepPolicy == "cfl"
                    WVModel.writePortableRunRequest(requestPath,modelPath, ...
                        schemaVersion=2,method=method,finalTime=.01,cfl=.25, ...
                        timeStepConstraint="advective",reportPath=reportName);
                else
                    WVModel.writePortableRunRequest(requestPath,modelPath, ...
                        schemaVersion=2,method=method,finalTime=.01,initialStep=.0025,maximumStep=.005, ...
                        relativeTolerance=1e-6,absoluteToleranceScale=1e-9,reportPath=reportName);
                end
                immutableRequest = fileread(requestPath);
                command = shellQuote(testCase.Runner)+" --request "+shellQuote(requestPath);
                [status,output] = systemWithoutMatlabRuntime(command);
                testCase.assertEqual(status,0,output)
                testCase.verifyEqual(fileread(requestPath),immutableRequest)
                report = jsondecode(fileread(fullfile(testCase.TemporaryFolder,reportName)));
                testCase.verifyEqual(string(report.status),"complete")
                testCase.verifyEqual(string(report.integrationRequest.requestedMethod),method)
                testCase.verifyEqual(string(report.integrationRequest.activeMethod),method)
                testCase.verifyEqual(string(report.integrationRequest.stepPolicy),stepPolicy)
                testCase.verifyTrue(report.integrationRequest.noFallback)
                testCase.verifyEqual(string(report.execution.engine),"reference-direct")
                testCase.verifyTrue(report.execution.noFallback)
                testCase.verifyEqual(report.storageBytes.persistentFullHermitian,0)
                restored = WVModel.modelFromFile(char(modelPath));
                cleanup = onCleanup(@()restored.closeNetCDFFile());
                testCase.verifyClass(restored.wvt,"WVTransformBarotropicQG")
                outputInformation = ncinfo(modelPath,"/wave-vortex");
                variableNames = string({outputInformation.Variables.Name});
                testCase.verifyFalse(any(startsWith(variableNames,["Ap" "Am"])))
                clear cleanup
            end
        end
    end

    methods (Access = private)
        function model = createNonlinearModel(testCase,path)
            wvt = WVTransformConstantStratification([4000 3000 1000],[8 6 5], ...
                N0=sqrt(2e-5),latitude=45,isHydrostatic=false,shouldAntialias=false);
            wvt.Ap(2) = 2e-6 + 1e-6i;
            wvt.Am(3) = -1e-6 + 0.5e-6i;
            wvt.A0(4) = 0.75e-6i;
            [x,y] = ndgrid(wvt.x,wvt.y);
            wvt.addForcing([ ...
                WVAdaptiveDamping(wvt) ...
                WVBottomFrictionLinear(wvt,r=2.5e-7) ...
                WVBottomFrictionQuadratic(wvt,Cd=1e-3) ...
                WVBetaPlanePVAdvection(wvt) ...
                WVPseudoTopographicWaveGeneration(wvt, ...
                    topographicHeight=2*cos(2*pi*x/wvt.Lx)+sin(2*pi*y/wvt.Ly), ...
                    barotropicVelocityAmplitude=[1e-4; -0.5e-4], ...
                    frequency=1.31e-4,name="terrain") ...
                WVFixedAmplitudeForcing(wvt,name="fixed", ...
                    A0_indices=uint64(4),A0bar=0.75e-6i)]);
            model = WVModel(wvt);
            outputFile = model.createNetCDFFileForModelOutput(path, ...
                outputInterval=1e-4,shouldOverwriteExisting=true);
            model.eulerianObservingSystem.addNetCDFOutputVariables('u');
            model.setFloatPositions([500 1500],[400 1200],[-250 -750],'u', ...
                absToleranceXY=1e-8,absToleranceZ=1e-8);
            tracer = sin(2*pi*wvt.X/wvt.Lx);
            model.addTracer(tracer,"dye");
            group = outputFile.outputGroupWithName(model.defaultOutputGroupName());
            particles = model.fluxedObservingSystemWithName("float");
            tracerObserver = model.fluxedObservingSystemWithName("dye");
            group.removeObservingSystem([particles tracerObserver]);
            particleGroup = outputFile.addNewEvenlySpacedOutputGroup("particles",outputInterval=1e-4);
            particleGroup.addObservingSystem(particles);
            tracerGroup = outputFile.addNewEvenlySpacedOutputGroup("tracers",outputInterval=1e-4);
            tracerGroup.addObservingSystem(tracerObserver);
            group.addObservingSystem(WVMooring(model,name="mooring", ...
                x=[0 1000],y=[0 900],trackedFieldNames={'u'}));
            model.setupIntegrator(integratorType="fixed",deltaT=1e-4);
            forcingNames = wvt.forcingNames;
            testCase.assertEqual(string(forcingNames(:)), ...
                ["nonlinear advection"; "linear bottom friction"; "quadratic bottom friction"; "adaptive damping"; ...
                 "beta-plane advection of qgpv"; "terrain"; "fixed"])
        end

        function model = createLinearBottomFrictionModel(testCase,path,isHydrostatic,Nz,r,integratorType)
            wvt = WVTransformConstantStratification([4000 3000 1000],[8 6 Nz], ...
                N0=sqrt(2e-5),latitude=45,isHydrostatic=isHydrostatic,shouldAntialias=false);
            wvt.Ap(2) = 2e-6 + 1e-6i;
            wvt.Am(3) = -1e-6 + 0.5e-6i;
            wvt.A0(4) = 0.75e-6i;
            wvt.addForcing(WVBottomFrictionLinear(wvt,r=r));
            model = WVModel(wvt);
            model.createNetCDFFileForModelOutput(path,outputInterval=1e-4,shouldOverwriteExisting=true);
            testCase.configureLinearIntegrator(model,integratorType);
        end

        function model = createBarotropicQGModel(~,path,Nxy,j,shouldAntialias)
            wvt = WVTransformBarotropicQG([15000 9000],Nxy,h=0.8,j=j, ...
                g=9.80665,planetaryRadius=6.3712e6,rotationRate=7.292115e-5, ...
                latitude=33,shouldAntialias=shouldAntialias);
            index = reshape(1:numel(wvt.A0),[],1);
            wvt.A0(:) = complex(2e-5*sin(0.37*index),1e-5*cos(0.23*(index+2)));
            wvt.A0(wvt.Kh == 0) = 0;
            selfConjugate = wvt.dftPrimaryIndices2D == wvt.dftConjugateIndices2D;
            wvt.A0(selfConjugate) = real(wvt.A0(selfConjugate));
            wvt.addForcing([WVAdaptiveDamping(wvt) ...
                WVBottomFrictionLinear(wvt,r=2.5e-7) ...
                WVBetaPlanePVAdvection(wvt)]);
            model = WVModel(wvt);
            model.eulerianObservingSystem.addNetCDFOutputVariables( ...
                'u','v','eta','pi','psi','qgpv','zeta_z','ssh');
            model.setDrifterPositions([0.13 0.77]*wvt.Lx,[0.21 0.63]*wvt.Ly, ...
                [],'u','qgpv',absToleranceXY=1e-5, ...
                advectionInterpolation="linear",trackedVarInterpolation="spline");
            tracer = 0.3 + 0.2*sin(2*pi*wvt.X/wvt.Lx).*cos(2*pi*wvt.Y/wvt.Ly);
            model.addTracer(tracer,"dye");
            model.createNetCDFFileForModelOutput(char(path), ...
                outputInterval=0.005,shouldOverwriteExisting=true);
            model.setupIntegrator(integratorType="fixed",deltaT=0.0025);
        end

        function configureLinearIntegrator(~,model,integratorType)
            if integratorType == "ode23"
                model.setupIntegrator(integratorType="adaptive",integrator=@ode23,absTolerance=1e-10,relTolerance=1e-8);
            elseif integratorType == "ode45"
                model.setupIntegrator(integratorType="adaptive",integrator=@ode45,absTolerance=1e-10,relTolerance=1e-8);
            elseif integratorType == "ode78"
                model.setupIntegrator(integratorType="adaptive",integrator=@ode78,absTolerance=1e-10,relTolerance=1e-8);
            else
                model.setupIntegrator(integratorType="fixed",deltaT=1e-5);
            end
        end

        function setConstantCFLFixtureState(~,wvt)
            p = reshape(1:numel(wvt.Ap),[],1);
            wvt.Ap(:) = complex(1e-5*sin(0.17*p),1e-5*cos(0.13*(p+1)));
            wvt.Am(:) = complex(1e-5*cos(0.11*(p+2)),1e-5*sin(0.07*(p+3)));
            wvt.A0(:) = complex(1e-5*sin(0.19*(p+4)),1e-5*cos(0.05*(p+5)));
            wvt.t0 = -0.25;
            wvt.t = 0.5;
        end

        function candidates = matlabCFLCandidates(~,wvt,cfl)
            candidates = struct;
            candidates.effectiveHorizontalGridResolution = wvt.effectiveHorizontalGridResolution;
            candidates.maximumHorizontalSpeed = wvt.uvMax;
            candidates.horizontalAdvective = cfl*candidates.effectiveHorizontalGridResolution/candidates.maximumHorizontalSpeed;
            candidates.verticalAdvective = Inf;
            if wvt.hasVariableWithName("w")
                W = wvt.w;
                W = W(:,:,2:end);
                ratio = abs(W./((3/2)*shiftdim(diff(wvt.z),-2)));
                candidates.verticalAdvective = cfl/max(ratio(:));
            end
            candidates.advective = min(candidates.horizontalAdvective,candidates.verticalAdvective);
            candidates.highestActiveWaveFrequency = 0;
            candidates.oscillatory = Inf;
            if wvt.hasWaveComponent
                omega = wvt.Omega;
                omega(1,:) = [];
                candidates.highestActiveWaveFrequency = max(abs(omega(:)));
                candidates.oscillatory = cfl*2*pi/candidates.highestActiveWaveFrequency;
            end
        end

        function report = runV2Request(testCase,modelPath,integration,reportName)
            reportPath = fullfile(testCase.TemporaryFolder,reportName);
            requestPath = reportPath+".request.json";
            request = struct;
            request.schemaIdentifier = "wave-vortex-run-request-v2";
            request.schemaVersion = 2;
            request.modelFiles = {char(modelPath)};
            request.integration = integration;
            request.output = struct(policy="append",destinations=struct);
            request.execution = struct(fftProvider="reference",threads=1);
            request.report = reportPath;
            writelines(jsonencode(request),requestPath)
            immutableRequest = fileread(requestPath);
            command = shellQuote(testCase.Runner)+" --request "+shellQuote(requestPath);
            [status,output] = systemWithoutMatlabRuntime(command);
            testCase.assertEqual(status,0,output)
            testCase.verifyEqual(fileread(requestPath),immutableRequest)
            report = jsondecode(fileread(reportPath));
            testCase.verifyEqual(string(report.request.schemaIdentifier),"wave-vortex-run-request-v2")
            testCase.verifyEqual(report.request.schemaVersion,2)
            testCase.verifyTrue(report.execution.noFallback)
        end

        function errorValue = normalizedCoefficientError(~,actual,reference)
            absoluteError = max([max(abs(actual.Ap-reference.Ap),[],"all"),max(abs(actual.Am-reference.Am),[],"all"),max(abs(actual.A0-reference.A0),[],"all")]);
            referenceScale = max([max(abs(reference.Ap),[],"all"),max(abs(reference.Am),[],"all"),max(abs(reference.A0),[],"all"),eps]);
            errorValue = absoluteError/referenceScale;
        end

        function [coefficientError,fieldError,particleError,tracerError] = ...
                verifyBarotropicQGModelsEqual(testCase,actual,expected,fieldNames,diagnostic)
            coefficientScale = max(max(abs(expected.wvt.A0),[],'all'),eps);
            coefficientError = max(abs(actual.wvt.A0-expected.wvt.A0),[],'all')/coefficientScale;
            testCase.verifyLessThanOrEqual(coefficientError,1e-12,diagnostic+" A0")
            fieldError = 0;
            for fieldName = fieldNames
                actualField = actual.wvt.(fieldName);
                expectedField = expected.wvt.(fieldName);
                scale = max(max(abs(expectedField),[],'all'),eps);
                fieldError = max(fieldError,max(abs(actualField-expectedField),[],'all')/scale);
            end
            testCase.verifyLessThanOrEqual(fieldError,1e-12,diagnostic+" fields")
            [actualX,actualY,actualZ,actualTracked] = actual.drifterPositions();
            [expectedX,expectedY,expectedZ,expectedTracked] = expected.drifterPositions();
            particleError = max([max(abs(actualX-expectedX),[],'all'), ...
                max(abs(actualY-expectedY),[],'all'), ...
                max(abs(actualTracked.u-expectedTracked.u),[],'all'), ...
                max(abs(actualTracked.qgpv-expectedTracked.qgpv),[],'all')]);
            testCase.verifyEqual(actualZ,expectedZ,diagnostic+" particle z")
            testCase.verifyLessThanOrEqual(particleError,1e-8,diagnostic+" particles")
            actualTracer = actual.tracer("dye");
            expectedTracer = expected.tracer("dye");
            tracerError = max(abs(actualTracer-expectedTracer),[],'all');
            testCase.verifyLessThanOrEqual(tracerError,1e-8,diagnostic+" tracer")
            testCase.verifyLessThanOrEqual(abs(actual.wvt.t-expected.wvt.t), ...
                4*eps(expected.wvt.t),diagnostic)
        end

        function verifyModelGraphsEqual(testCase,actual,expected)
            testCase.verifyEqual(actual.isDynamicsLinear,expected.isDynamicsLinear)
            actualForcingNames = actual.wvt.forcingNames;
            expectedForcingNames = expected.wvt.forcingNames;
            testCase.verifyEqual(string(actualForcingNames(:)),string(expectedForcingNames(:)))
            actualFile = actual.outputFiles(1);
            expectedFile = expected.outputFiles(1);
            testCase.verifyEqual(sort(actualFile.outputGroupNames),sort(expectedFile.outputGroupNames))
            for groupName = reshape(expectedFile.outputGroupNames,1,[])
                actualGroup = actualFile.outputGroupWithName(groupName);
                expectedGroup = expectedFile.outputGroupWithName(groupName);
                testCase.verifyEqual(string(arrayfun(@class,actualGroup.observingSystems,UniformOutput=false)), ...
                    string(arrayfun(@class,expectedGroup.observingSystems,UniformOutput=false)))
                testCase.verifyEqual(string({actualGroup.observingSystems.name}), ...
                    string({expectedGroup.observingSystems.name}))
                testCase.verifyEqual(actualGroup.outputInterval,expectedGroup.outputInterval)
                testCase.verifyEqual(actualGroup.initialTime,expectedGroup.initialTime)
                testCase.verifyEqual(actualGroup.finalTime,expectedGroup.finalTime)
            end
        end
    end
end

function value = shellQuote(value)
value = "'" + replace(string(value),"'","'""'""'") + "'";
end

function [status,output] = systemWithoutMatlabRuntime(command)
if isunix && ~ismac
    command = "env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH " + string(command);
end
[status,output] = system(command);
end
