classdef TestPortableFieldEvaluation < matlab.unittest.TestCase
    properties (SetAccess = private)
        Inspector
        ParticleInspector
        ModelOutputTestExecutable
        TemporaryFolder
    end

    methods (TestClassSetup)
        function buildFocusedContracts(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = string(fixture.Folder);
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            scriptPath = fullfile(repositoryRoot,"tools","portable-runtime","runFieldEvaluationContracts.sh");
            [status,output] = system(sprintf('"%s"',scriptPath));
            testCase.assertEqual(status,0,output)
            testCase.Inspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_field_evaluation_inspect");
            testCase.assertTrue(isfile(testCase.Inspector),output)
            testCase.ParticleInspector = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","wv_lagrangian_particle_inspect");
            testCase.assertTrue(isfile(testCase.ParticleInspector),output)
            testCase.ModelOutputTestExecutable = fullfile(repositoryRoot,"tools","compiled-kernel","build-portable","TestWVModelOutputNetCDF");
            testCase.assertTrue(isfile(testCase.ModelOutputTestExecutable),output)
        end
    end

    methods (Test, TestTags = "full")
        function completeCatalogAndSamplingMatchMatlab(testCase)
            cases = struct( ...
                "Nxyz",{[6 5 7],[7 6 7],[6 6 7],[7 5 7]}, ...
                "isHydrostatic",{true,false,true,false}, ...
                "shouldAntialias",{true,false,false,true});
            maximumRelativeError = 0;
            evidenceMetrics = struct();
            for iCase = 1:numel(cases)
                definition = cases(iCase);
                wvt = WVTransformConstantStratification( ...
                    [15000 12000 1300],definition.Nxyz,N0=5.2e-3, ...
                    latitude=33,isHydrostatic=definition.isHydrostatic, ...
                    shouldAntialias=definition.shouldAntialias);
                spectralIndex = reshape(1:numel(wvt.Ap),size(wvt.Ap));
                positive = 2.3e-3*sin(0.37*spectralIndex) - 1.7e-3i*cos(0.19*spectralIndex);
                negative = -1.1e-3*cos(0.23*spectralIndex) + 1.9e-3i*sin(0.41*spectralIndex);
                zeroFrequency = 1.3e-3*sin(0.29*spectralIndex) + 0.7e-3i*cos(0.31*spectralIndex);
                wvt.Ap = positive.*wvt.waveComponent.maskAp;
                wvt.Am = negative.*wvt.waveComponent.maskAm;
                inertialApMask = logical(wvt.inertialComponent.maskAp);
                inertialAmMask = logical(wvt.inertialComponent.maskAm);
                wvt.Ap(inertialApMask) = positive(inertialApMask);
                wvt.Am(inertialAmMask) = conj(wvt.Ap(inertialApMask));
                wvt.A0 = zeroFrequency.*wvt.geostrophicComponent.maskA0;
                mdaMask = logical(wvt.mdaComponent.maskA0);
                wvt.A0(mdaMask) = real(zeroFrequency(mdaMask));
                wvt.t0 = -3.5;
                wvt.t = 37.25;
                checkpointPath = fullfile(testCase.TemporaryFolder,sprintf("field-evaluation-%d.nc",iCase));
                ncfile = wvt.writeToFile(checkpointPath,shouldOverwriteExisting=true);
                ncfile.close();

                command = TestPortableFieldEvaluation.sanitizedCommand( ...
                    sprintf('"%s" "%s"',testCase.Inspector,checkpointPath));
                [status,output] = system(command);
                testCase.assertEqual(status,0,output)
                actual = jsondecode(output);
                positions = actual.positions;
                positions.x = reshape(positions.x,1,[]);
                positions.y = reshape(positions.y,1,[]);
                positions.z = reshape(positions.z,1,[]);
                records = reshape(actual.outputs,1,[]);
                expectedWriteCount = 0;
                for iRecord = 1:numel(records)
                    record = records(iRecord);
                    identifier = string(record.identifier);
                    fieldName = string(record.field);
                    separator = strfind(identifier,"__");
                    sampling = extractBefore(identifier,separator(1));
                    expected = TestPortableFieldEvaluation.expectedValue( ...
                        wvt,fieldName,sampling,positions);
                    actualValues = reshape(record.values,[],1);
                    expectedValues = reshape(expected,[],1);
                    testCase.verifyEqual(numel(actualValues),numel(expectedValues), ...
                        "Wrong output shape for " + identifier)
                    scale = max(norm(expectedValues,Inf),eps);
                    relativeError = norm(actualValues-expectedValues,Inf)/scale;
                    maximumRelativeError = max(maximumRelativeError,relativeError);
                    testCase.verifyLessThanOrEqual(relativeError,1e-12, ...
                        sprintf("%s relative error %.17g",identifier,relativeError))
                    expectedWriteCount = expectedWriteCount + numel(expectedValues);
                end
                movingRecords = reshape(actual.movingOutputs,1,[]);
                for iRecord = 1:numel(movingRecords)
                    record = movingRecords(iRecord);
                    identifier = string(record.identifier);
                    separator = strfind(identifier,"__");
                    interpolation = extractBefore(identifier,separator(1));
                    expected = wvt.variableAtPositionWithName( ...
                        positions.x,positions.y,positions.z,char(record.field), ...
                        interpolationMethod=char(interpolation));
                    actualValues = reshape(record.values,[],1);
                    expectedValues = reshape(expected,[],1);
                    scale = max(norm(expectedValues,Inf),eps);
                    relativeError = norm(actualValues-expectedValues,Inf)/scale;
                    maximumRelativeError = max(maximumRelativeError,relativeError);
                    testCase.verifyLessThanOrEqual(relativeError,1e-12, ...
                        sprintf("moving %s relative error %.17g",identifier,relativeError))
                end
                metrics = actual.metrics;
                testCase.verifyEqual(metrics.evaluationCount,1)
                testCase.verifyEqual(metrics.coincidentBatchCount,1)
                testCase.verifyEqual(metrics.transformCount,7)
                testCase.verifyEqual(metrics.primitiveFieldEvaluationCount,10)
                testCase.verifyEqual(metrics.primitiveFieldReuseCount,45)
                testCase.verifyEqual(metrics.fullGridWriteCount,20)
                testCase.verifyEqual(metrics.profileWriteCount,13)
                testCase.verifyEqual(metrics.linearInterpolationCount,96)
                testCase.verifyEqual(metrics.splineInterpolationCount,96)
                testCase.verifyEqual(metrics.outputElementWriteCount,expectedWriteCount)
                testCase.verifyEqual(actual.movingMetrics.evaluationCount,1)
                testCase.verifyEqual(actual.movingMetrics.positionCount,numel(positions.x))
                testCase.verifyEqual(actual.movingMetrics.primitiveTransformCount,1)
                testCase.verifyGreaterThan(actual.movingMetrics.workspaceBytes,0)
                testCase.verifyGreaterThan(metrics.servicePersistentBytes,metrics.transformPersistentBytes)
                testCase.verifyGreaterThan(metrics.lastPlanBytes,0)
                testCase.verifyEqual(metrics.lastPlanBytes,metrics.maximumPlanBytes)
                testCase.verifyLessThanOrEqual(metrics.scratchHighWaterBytes,metrics.scratchCapacityBytes)
                if iCase == 1
                    evidenceMetrics = metrics;
                end
            end
            fprintf("WV_FIELD_EVALUATION_MAX_RELATIVE_ERROR=%.17g\n",maximumRelativeError)
            fprintf("WV_FIELD_EVALUATION_STORAGE_BYTES service=%.0f transform=%.0f " + ...
                "plan=%.0f scratch_capacity=%.0f scratch_high_water=%.0f\n", ...
                evidenceMetrics.servicePersistentBytes,evidenceMetrics.transformPersistentBytes, ...
                evidenceMetrics.lastPlanBytes,evidenceMetrics.scratchCapacityBytes, ...
                evidenceMetrics.scratchHighWaterBytes)
            fprintf("WV_FIELD_EVALUATION_REUSE transforms=%.0f source_evaluations=%.0f " + ...
                "source_reuse=%.0f output_elements=%.0f\n", ...
                evidenceMetrics.transformCount,evidenceMetrics.primitiveFieldEvaluationCount, ...
                evidenceMetrics.primitiveFieldReuseCount,evidenceMetrics.outputElementWriteCount)
        end

        function particleRhsFixedDenseAndAdaptiveTrajectoriesMatchMatlab(testCase)
            wvt = WVTransformConstantStratification( ...
                [15000 12000 1300],[6 5 7],N0=5.2e-3,latitude=33, ...
                isHydrostatic=false,shouldAntialias=true);
            spectralIndex = reshape(1:numel(wvt.Ap),size(wvt.Ap));
            positive = 2.3e-3*sin(0.37*spectralIndex) - 1.7e-3i*cos(0.19*spectralIndex);
            negative = -1.1e-3*cos(0.23*spectralIndex) + 1.9e-3i*sin(0.41*spectralIndex);
            zeroFrequency = 1.3e-3*sin(0.29*spectralIndex) + 0.7e-3i*cos(0.31*spectralIndex);
            wvt.Ap = positive.*wvt.waveComponent.maskAp;
            wvt.Am = negative.*wvt.waveComponent.maskAm;
            inertialApMask = logical(wvt.inertialComponent.maskAp);
            inertialAmMask = logical(wvt.inertialComponent.maskAm);
            wvt.Ap(inertialApMask) = positive(inertialApMask);
            wvt.Am(inertialAmMask) = conj(wvt.Ap(inertialApMask));
            wvt.A0 = zeroFrequency.*wvt.geostrophicComponent.maskA0;
            mdaMask = logical(wvt.mdaComponent.maskA0);
            wvt.A0(mdaMask) = real(zeroFrequency(mdaMask));
            wvt.t0 = -3.5;
            wvt.t = 37.25;
            checkpointPath = fullfile(testCase.TemporaryFolder,"particle-trajectory.nc");
            ncfile = wvt.writeToFile(checkpointPath,shouldOverwriteExisting=true);
            ncfile.close();

            command = TestPortableFieldEvaluation.sanitizedCommand( ...
                sprintf('"%s" "%s"',testCase.ParticleInspector,checkpointPath));
            [status,output] = system(command);
            testCase.assertEqual(status,0,output)
            actual = jsondecode(output);

            model = WVModel(wvt,shouldUseLinearDynamics=true);
            dx = wvt.Lx/wvt.Nx;
            dy = wvt.Ly/wvt.Ny;
            dz = wvt.Lz/(wvt.Nz-1);
            surface = WVLagrangianParticles(model,name="surfaceParticles", ...
                x=[-0.35*dx wvt.Lx+0.4*dx], ...
                y=[wvt.Ly+0.55*dy -0.3*dy], ...
                z=[-wvt.Lz+0.4*dz -wvt.Lz+2.25*dz], ...
                isXYOnly=true,trackedFieldNames={}, ...
                advectionInterpolation="linear");
            volume = WVLagrangianParticles(model,name="volumeParticles", ...
                x=[2.35*dx wvt.Lx-0.2*dx], ...
                y=[1.7*dy wvt.Ly-0.1*dy], ...
                z=[-1.3*dz -wvt.Lz+1.6*dz], ...
                isXYOnly=false,trackedFieldNames={}, ...
                advectionInterpolation="spline");
            initial = TestPortableFieldEvaluation.flattenParticleState(actual.initial);
            testCase.verifyEqual(initial, ...
                TestPortableFieldEvaluation.particleState(surface,volume),AbsTol=1e-12)
            t = actual.initialTime;
            rhs = TestPortableFieldEvaluation.particleFlux(surface,volume,t,initial);
            rhsError = TestPortableFieldEvaluation.verifyRelative(testCase, ...
                TestPortableFieldEvaluation.flattenParticleState(actual.rightHandSide),rhs,1e-12,"particle RHS");

            h = actual.stepSize;
            k1 = rhs;
            k2 = TestPortableFieldEvaluation.particleFlux(surface,volume,t+h/2,initial+h*k1/2);
            k3 = TestPortableFieldEvaluation.particleFlux(surface,volume,t+h/2,initial+h*k2/2);
            k4 = TestPortableFieldEvaluation.particleFlux(surface,volume,t+h,initial+h*k3);
            endpoint = initial + h*(k1+2*k2+2*k3+k4)/6;
            fixedError = TestPortableFieldEvaluation.verifyRelative(testCase, ...
                TestPortableFieldEvaluation.flattenParticleState(actual.fixedEndpoint),endpoint,1e-12,"fixed RK4 trajectory");
            finalDerivative = TestPortableFieldEvaluation.particleFlux(surface,volume,t+h,endpoint);
            theta = 0.5;
            ew = 3*theta^2-2*theta^3;
            iw = 1-ew;
            isw = h*(theta-2*theta^2+theta^3);
            esw = h*(theta^3-theta^2);
            midpoint = iw*initial + ew*endpoint + isw*k1 + esw*finalDerivative;
            denseError = TestPortableFieldEvaluation.verifyRelative(testCase, ...
                TestPortableFieldEvaluation.flattenParticleState(actual.denseMidpoint),midpoint,1e-12,"dense-output trajectory");

            referenceOptions = odeset('RelTol',1e-12,'AbsTol',1e-12);
            [~,reference] = ode23( ...
                @(time,state)TestPortableFieldEvaluation.particleFlux(surface,volume,time,state), ...
                [t actual.adaptiveTime],initial,referenceOptions);
            adaptive = TestPortableFieldEvaluation.flattenParticleState(actual.adaptiveEndpoint);
            reference = reference(end,:).';
            tolerance = 1e-14 + 1e-9*max(abs(adaptive),abs(reference));
            adaptiveToleranceRatio = max(abs(adaptive-reference)./tolerance);
            testCase.verifyLessThanOrEqual(adaptiveToleranceRatio,2, ...
                "adaptive particle trajectory exceeded its tolerance contract")
            testCase.verifyGreaterThan(actual.adaptiveRejectedSteps,0)
            testCase.verifyEqual(actual.systemMetrics.velocityTransforms, ...
                actual.systemMetrics.rhsEvaluations)
            testCase.verifyGreaterThan(actual.systemMetrics.persistentBytes,0)
            fprintf("WV_PARTICLE_ORACLE rhs=%.17g fixed=%.17g dense=%.17g adaptive_tolerance_ratio=%.17g\n", ...
                rhsError,fixedError,denseError,adaptiveToleranceRatio)
        end

        function particleModelOutputIsBidirectionallyRestartable(testCase)
            matlabPath = fullfile(testCase.TemporaryFolder,"matlab-particles.nc");
            wvt = WVTransformConstantStratification( ...
                [4000 3000 1000],[8 6 5],N0=sqrt(2e-5),latitude=45, ...
                isHydrostatic=false,shouldAntialias=false);
            model = WVModel(wvt);
            outputFile = model.createNetCDFFileForModelOutput( ...
                matlabPath,outputInterval=1,shouldOverwriteExisting=true);
            model.setFloatPositions([500 1500],[400 1200],[-250 -750],'u', ...
                advectionInterpolation="spline",trackedVarInterpolation="linear", ...
                absToleranceXY=3e-4,absToleranceZ=7e-5);
            model.addTracer(reshape(1:prod(wvt.spatialMatrixSize),wvt.spatialMatrixSize),"dye");
            defaultGroup = outputFile.outputGroupWithName(model.defaultOutputGroupName());
            defaultGroup.addObservingSystem(WVMooring(model,name="mooring", ...
                x=[0 1000],y=[0 900],trackedFieldNames={}));
            particles = model.fluxedObservingSystemWithName("float");
            tracer = model.fluxedObservingSystemWithName("dye");
            shared = outputFile.addNewEvenlySpacedOutputGroup("shared",outputInterval=1);
            shared.addObservingSystem([particles tracer]);
            model.setupIntegrator(integratorType="fixed",deltaT=1);
            model.integrateToTime(2,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            model.closeNetCDFFile();

            runtimePath = fullfile(testCase.TemporaryFolder,"runtime-particles.nc");
            command = sprintf( ...
                'WV_MATLAB_MODEL_OUTPUT_FIXTURE="%s" WV_RUNTIME_MODEL_OUTPUT_EXPORT="%s" "%s"', ...
                matlabPath,runtimePath,testCase.ModelOutputTestExecutable);
            [status,output] = system(TestPortableFieldEvaluation.sanitizedCommand(command));
            testCase.assertEqual(status,0,output)
            testCase.verifyTrue(isfile(runtimePath))
            testCase.verifyTrue(isfile(runtimePath+".second.nc"))

            restored = WVModel.modelFromFile(char(runtimePath));
            cleanup = onCleanup(@()restored.closeNetCDFFile());
            restoredNames = restored.outputFileNames;
            testCase.verifyGreaterThanOrEqual(numel(restoredNames),1)
            restoredFile = restored.outputFileWithName(restoredNames(1));
            restoredParticles = restoredFile.outputGroupWithName("wave-vortex").observingSystemWithName("particles");
            sharedParticles = restoredFile.outputGroupWithName("shared").observingSystemWithName("particles");
            testCase.verifyTrue(restoredParticles == sharedParticles)
            positions = restoredParticles.initialConditions();
            testCase.verifyEqual(positions,{[1 1],[2 2]})
            testCase.verifyEqual(restoredParticles.z,[-100 -300])
            restored.closeNetCDFFile();
            clear cleanup
        end
    end

    methods (Static, Access = private)
        function state = flattenParticleState(value)
            state = [reshape(value.surfaceX,[],1); reshape(value.surfaceY,[],1); ...
                reshape(value.volumeX,[],1); reshape(value.volumeY,[],1); ...
                reshape(value.volumeZ,[],1)];
        end

        function state = particleState(surface,volume)
            state = [reshape(surface.x,[],1); reshape(surface.y,[],1); ...
                reshape(volume.x,[],1); reshape(volume.y,[],1); ...
                reshape(volume.z,[],1)];
        end

        function derivative = particleFlux(surface,volume,time,state)
            surfaceFlux = surface.fluxAtTime(time,{state(1:2).',state(3:4).'});
            volumeFlux = volume.fluxAtTime(time,{state(5:6).',state(7:8).',state(9:10).'});
            derivative = [reshape(surfaceFlux{1},[],1); reshape(surfaceFlux{2},[],1); ...
                reshape(volumeFlux{1},[],1); reshape(volumeFlux{2},[],1); ...
                reshape(volumeFlux{3},[],1)];
        end

        function error = verifyRelative(testCase,actual,expected,tolerance,label)
            scale = max(norm(expected,Inf),eps);
            error = norm(actual-expected,Inf)/scale;
            testCase.verifyLessThanOrEqual(error,tolerance, ...
                sprintf("%s relative error %.17g",label,error))
        end

        function value = expectedValue(wvt,fieldName,sampling,positions)
            if sampling == "full"
                if fieldName == "rho_bar"
                    value = wvt.rho_nm0 + (wvt.rho0/wvt.g)*wvt.N2 .* ...
                        (wvt.GinvMatrix*(wvt.NA0(:,1).*wvt.A0(:,1)));
                elseif fieldName == "energy"
                    value = sum(wvt.Apm_TE_factor(:).*(abs(wvt.Ap(:)).^2 + ...
                        abs(wvt.Am(:)).^2) + wvt.A0_TE_factor(:).*abs(wvt.A0(:)).^2);
                else
                    value = wvt.variableWithName(char(fieldName));
                end
                return
            end
            if sampling == "profile"
                field = wvt.variableWithName(char(fieldName));
                value = [reshape(field(1,1,:),[],1), ...
                    reshape(field(end,end,:),[],1)];
                return
            end
            if any(fieldName == ["ssu" "ssv" "ssh"])
                z = [];
            else
                z = positions.z;
            end
            value = wvt.variableAtPositionWithName( ...
                positions.x,positions.y,z,char(fieldName), ...
                interpolationMethod=char(sampling));
        end

        function command = sanitizedCommand(command)
            if isunix
                command = "/usr/bin/env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH " + command;
            end
        end
    end
end
