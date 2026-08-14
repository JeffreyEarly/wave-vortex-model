classdef TestPortableFieldEvaluation < matlab.unittest.TestCase
    properties (SetAccess = private)
        Inspector
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
    end

    methods (Static, Access = private)
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
