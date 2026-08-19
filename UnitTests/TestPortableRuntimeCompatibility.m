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
                true, "adaptive", 7, 2.5e-7; ...
                false, "adaptive", 5, 2.5e-7};
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
                if integratorType == "adaptive"
                    command = command + " --integrator adaptive-rk23" + ...
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

        function configureLinearIntegrator(~,model,integratorType)
            if integratorType == "adaptive"
                model.setupIntegrator(integratorType="adaptive",integrator=@ode23,absTolerance=1e-10,relTolerance=1e-8);
            else
                model.setupIntegrator(integratorType="fixed",deltaT=1e-5);
            end
        end

        function errorValue = normalizedCoefficientError(~,actual,reference)
            absoluteError = max([max(abs(actual.Ap-reference.Ap),[],"all"),max(abs(actual.Am-reference.Am),[],"all"),max(abs(actual.A0-reference.A0),[],"all")]);
            referenceScale = max([max(abs(reference.Ap),[],"all"),max(abs(reference.Am),[],"all"),max(abs(reference.A0),[],"all"),eps]);
            errorValue = absoluteError/referenceScale;
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
