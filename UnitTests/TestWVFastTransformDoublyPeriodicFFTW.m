classdef TestWVFastTransformDoublyPeriodicFFTW < matlab.unittest.TestCase
    properties
        fftwTransformsRoot (1,1) string
    end

    methods (TestMethodSetup)
        function addFFTWTransforms(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            workspaceRoot = string(fileparts(repositoryRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repositoryRoot,"Benchmarks")));
            candidates = [fullfile(workspaceRoot,"fftw-transforms") fullfile(workspaceRoot,"OceanKit","FFTWTransforms-1.0.2")];
            selected = candidates(arrayfun(@(candidate)isfile(fullfile(candidate,"RealToComplexTransform.m")),candidates));
            testCase.assertNotEmpty(selected,"FFTWTransforms 1.0.2 is required for this optional suite.");
            testCase.fftwTransformsRoot = selected(1);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.fftwTransformsRoot));
            testCase.assertEqual(exist("RealToComplexTransform","class"),8);
            testCase.assertEqual(exist("fftw_r2c","file"),3,"Build FFTWTransforms through FFTWBackend.build() before running the optional suite.");
        end
    end

    methods (Test,TestTags="optional")
        function allVerticalOperationsRespectIssue43Dispatch(testCase)
            Nz = 129;
            Nj = 128;
            Nbatch = 8320;
            strategy = WVVerticalTransformConstantStratification.create(Nz,Nj,"fftw");
            cleanup = onCleanup(@()delete(strategy));
            DCT = WVGeometryDoublyPeriodicStratifiedConstant.CosineTransformForwardMatrix(Nz);
            DCT = DCT(1:Nj,:);
            iDCT = WVGeometryDoublyPeriodicStratifiedConstant.CosineTransformBackMatrix(Nz);
            iDCT = iDCT(:,1:Nj);
            DST = WVGeometryDoublyPeriodicStratifiedConstant.SineTransformForwardMatrix(Nz);
            DST = [zeros(1,Nz); DST];
            DST = DST(1:Nj,:);
            iDST = WVGeometryDoublyPeriodicStratifiedConstant.SineTransformBackMatrix(Nz);
            iDST = [zeros(Nz,1) iDST];
            iDST = iDST(:,1:Nj);
            rng(7330,"twister");

            maximumError = 0;
            for isComplex = [false true]
                values = randn(Nz,Nbatch);
                coefficients = randn(Nj,Nbatch);
                if isComplex
                    values = complex(values,randn(Nz,Nbatch));
                    coefficients = complex(coefficients,randn(Nj,Nbatch));
                end
                operations = { ...
                    strategy.transformForward(values,"cosine",DCT), DCT*values; ...
                    strategy.transformBack(coefficients,"cosine",iDCT), iDCT*coefficients; ...
                    strategy.transformForward(values,"sine",DST), DST*values; ...
                    strategy.transformBack(coefficients,"sine",iDST), iDST*coefficients};
                for iOperation = 1:size(operations,1)
                    operationError = relativeError(operations{iOperation,1},operations{iOperation,2});
                    maximumError = max(maximumError,operationError);
                    testCase.verifyLessThanOrEqual(operationError,1e-12);
                end
                if isComplex
                    testCase.verifyEqual(operations{4,1}([1 end],:),zeros(2,Nbatch,"like",operations{4,1}),AbsTol=0);
                end
            end
            records = strategy.dispatchRecords();
            testCase.verifyNumElements(records,8);
            testCase.verifyEqual(nnz([records.isEligible]),5);
            testCase.verifyEqual(nnz([records.implementation] == "fftw"),5);
            testCase.verifyEqual(unique([records([records.isEligible]).minimumBatchCount]),8320);
            matrixRecords = records(~[records.isEligible]);
            testCase.verifyEqual(string({matrixRecords.key}),[ ...
                "cosine|forward|real|8320" ...
                "cosine|inverse|real|8320" ...
                "sine|inverse|real|8320"]);
            testCase.verifyLessThanOrEqual(maximumError,1e-12);
            testCase.verifyEqual(strategy.cacheDiagnostics().planCount,uint64(3));
            clear cleanup
        end

        function completeConstantTransformsSelectEquivalentBackends(testCase)
            for isHydrostatic = [false true]
                arguments = {'N0',sqrt(2e-5),'latitude',45,'isHydrostatic',isHydrostatic,'shouldAntialias',true};
                builtin = WVTransformConstantStratification([4000 3000 1000],[8 6 5],arguments{:},fastTransform="builtin");
                fftw = WVTransformConstantStratification([4000 3000 1000],[8 6 5],arguments{:},fastTransform="fftw");
                cleanup = onCleanup(@()deleteTransforms(builtin,fftw));
                testCase.verifyEqual(builtin.fastTransform.backendIdentifier,"builtin");
                testCase.verifyEqual(fftw.fastTransform.backendIdentifier,"fftw");
                testCase.verifyEqual(builtin.verticalTransform.backendIdentifier,"builtin");
                testCase.verifyEqual(fftw.verticalTransform.backendIdentifier,"fftw");
                testCase.verifyEqual(fftw.k,builtin.k);
                testCase.verifyEqual(fftw.l,builtin.l);
                testCase.verifyEqual(fftw.Nkl,builtin.Nkl);
                testCase.verifyEqual(fftw.dftPrimaryIndices2D,builtin.dftPrimaryIndices2D);
                testCase.verifyEqual(fftw.dftConjugateIndices2D,builtin.dftConjugateIndices2D);
                testCase.verifyEqual(fftw.spatialMatrixSize,builtin.spatialMatrixSize);
                testCase.verifyEqual(fftw.spectralMatrixSize,builtin.spectralMatrixSize);

                rng(7200+isHydrostatic,"twister");
                builtin.initWithRandomFlow(uvMax=0.01);
                fftw.Ap = builtin.Ap;
                fftw.Am = builtin.Am;
                fftw.A0 = builtin.A0;
                [builtinU,builtinV,builtinW,builtinEta] = builtin.variableWithName("u","v","w","eta");
                [fftwU,fftwV,fftwW,fftwEta] = fftw.variableWithName("u","v","w","eta");
                verifyArrays(testCase,{fftwU,fftwV,fftwW,fftwEta},{builtinU,builtinV,builtinW,builtinEta});
                [builtinFp,builtinFm,builtinF0] = builtin.nonlinearFlux();
                [fftwFp,fftwFm,fftwF0] = fftw.nonlinearFlux();
                verifyArrays(testCase,{fftwFp,fftwFm,fftwF0},{builtinFp,builtinFm,builtinF0});
                clear cleanup
            end
        end

        function resolutionAndAntialiasingPreserveActiveBackend(testCase)
            wvt = WVTransformConstantStratification([4000 3000 1000],[8 6 5],N0=sqrt(2e-5),latitude=45,shouldAntialias=true,fastTransform="fftw");
            cleanup = onCleanup(@()delete(wvt));
            resized = wvt.waveVortexTransformWithResolution([10 8 7]);
            resizedCleanup = onCleanup(@()delete(resized));
            explicit = wvt.waveVortexTransformWithExplicitAntialiasing();
            explicitCleanup = onCleanup(@()delete(explicit));
            testCase.verifyEqual(resized.fastTransform.backendIdentifier,"fftw");
            testCase.verifyEqual(explicit.fastTransform.backendIdentifier,"fftw");
            testCase.verifyFalse(explicit.shouldAntialias);
            clear explicitCleanup resizedCleanup cleanup
        end

        function persistenceUsesRuntimeBackendOverride(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            pathname = fullfile(fixture.Folder,"fftw-runtime-selection.nc");
            original = WVTransformConstantStratification([4000 3000 1000],[8 6 5],N0=sqrt(2e-5),latitude=45,shouldAntialias=false,fastTransform="fftw");
            originalCleanup = onCleanup(@()delete(original));
            file = original.writeToFile(pathname,shouldOverwriteExisting=true);
            testCase.verifyFalse(file.hasVariableWithName("fastTransform"));
            file.close();

            restoredBuiltin = WVTransform.waveVortexTransformFromFile(pathname);
            builtinCleanup = onCleanup(@()delete(restoredBuiltin));
            restoredFFTW = WVTransform.waveVortexTransformFromFile(pathname,fastTransform="fftw");
            fftwCleanup = onCleanup(@()delete(restoredFFTW));
            testCase.verifyEqual(restoredBuiltin.fastTransform.backendIdentifier,"builtin");
            testCase.verifyEqual(restoredFFTW.fastTransform.backendIdentifier,"fftw");
            testCase.verifyEqual(restoredFFTW.k,restoredBuiltin.k);
            testCase.verifyEqual(restoredFFTW.l,restoredBuiltin.l);
            testCase.verifyEqual(restoredFFTW.Ap,restoredBuiltin.Ap);
            testCase.verifyEqual(restoredFFTW.Am,restoredBuiltin.Am);
            testCase.verifyEqual(restoredFFTW.A0,restoredBuiltin.A0);
            clear fftwCleanup builtinCleanup originalCleanup
        end

        function benchmarkConstructionRejectsFallback(testCase)
            benchmarkCase = struct("transformId","constant-nonhydrostatic","Lxyz",[4000 3000 1000],"Nxyz",[8 6 5],"shouldAntialias",false);
            wvt = createWaveVortexBenchmarkTransform(benchmarkCase,"fftw");
            cleanup = onCleanup(@()delete(wvt));
            testCase.verifyEqual(wvt.fastTransform.backendIdentifier,"fftw");
            clear cleanup
        end

        function forwardInverseAndMappingImplementationsAgree(testCase)
            cases = struct( ...
                "size",{[16 12 5],[15 11 4],[16 11 3]}, ...
                "conjugateDimension",{1,2,2}, ...
                "shouldAntialias",{false,true,false});
            for benchmarkCase = cases
                Nx = benchmarkCase.size(1);
                Ny = benchmarkCase.size(2);
                Nz = benchmarkCase.size(3);
                geometry = WVGeometryDoublyPeriodic([4000 3000],[Nx Ny],Nz=Nz,shouldAntialias=benchmarkCase.shouldAntialias,shouldExcludeNyquist=true,conjugateDimension=benchmarkCase.conjugateDimension);
                builtin = geometry.fastTransform;
                layoutAdapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz,planner="estimate",nCores=1,forwardMappingMethod="layout-methods",inverseMappingMethod="layout-methods");
                specializedAdapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz,planner="estimate",nCores=1,forwardMappingMethod="specialized-rows",inverseMappingMethod="specialized-rows");
                cleanup = onCleanup(@()deleteAdapters(layoutAdapter,specializedAdapter));

                rng(7100+Nx+Ny+Nz,"twister");
                spatial = randn(Nx,Ny,Nz);
                builtinWV = builtin.transformFromSpatialDomainWithFourier(spatial);
                layoutWV = layoutAdapter.transformFromSpatialDomainWithFourier(spatial);
                specializedWV = specializedAdapter.transformFromSpatialDomainWithFourier(spatial);
                testCase.verifyLessThanOrEqual(relativeError(layoutWV,builtinWV),1e-12);
                testCase.verifyLessThanOrEqual(relativeError(specializedWV,builtinWV),1e-12);
                testCase.verifyLessThanOrEqual(relativeError(specializedWV,layoutWV),1e-12);

                builtinSpatial = builtin.transformToSpatialDomainWithFourier(builtinWV);
                layoutSpatial = layoutAdapter.transformToSpatialDomainWithFourier(layoutWV);
                specializedSpatial = specializedAdapter.transformToSpatialDomainWithFourier(specializedWV);
                testCase.verifyLessThanOrEqual(relativeError(layoutSpatial,builtinSpatial),1e-12);
                testCase.verifyLessThanOrEqual(relativeError(specializedSpatial,builtinSpatial),1e-12);
                testCase.verifyLessThanOrEqual(relativeError(specializedSpatial,layoutSpatial),1e-12);
                clear cleanup
            end
        end

        function destructiveOwnershipUsesOnePlanAndNoScratch(testCase)
            before = fftw_r2c('lifetime');
            geometry = WVGeometryDoublyPeriodic([4000 3000],[16 12],Nz=5,shouldAntialias=false,shouldExcludeNyquist=true);
            adapter = WVFastTransformDoublyPeriodicFFTW(geometry,5,planner="estimate",nCores=1);
            cleanup = onCleanup(@()delete(adapter));
            afterConstruction = fftw_r2c('lifetime');
            testCase.verifyEqual(afterConstruction(1)-before(1),1);
            testCase.verifyEqual(afterConstruction(3)-before(3),1);
            testCase.verifyEqual(afterConstruction(7:10),before(7:10));

            rng(7117,"twister");
            spatial = randn(16,12,5);
            coefficients = adapter.transformFromSpatialDomainWithFourier(spatial);
            [reconstructed,pointers] = adapter.destructiveInverseDiagnostics(coefficients);
            builtinReconstruction = geometry.fastTransform.transformToSpatialDomainWithFourier(coefficients);
            testCase.verifyLessThanOrEqual(relativeError(reconstructed,builtinReconstruction),1e-12);
            testCase.verifyEqual(pointers.spectrumAfter,pointers.spectrumBefore);
            testCase.verifyEqual(pointers.outputAfter,pointers.outputBefore);
            afterCalls = fftw_r2c('lifetime');
            testCase.verifyEqual(afterCalls(7:10),before(7:10));

            delete(adapter);
            clear cleanup adapter
            afterDeletion = fftw_r2c('lifetime');
            testCase.verifyEqual(afterDeletion(2)-before(2),1);
            testCase.verifyEqual(afterDeletion(3),before(3));
            testCase.verifyEqual(afterDeletion(6),before(6));
            testCase.verifyEqual(afterDeletion(7:10),before(7:10));
        end

        function adapterRetainsNoArraySizedStorage(testCase)
            geometry = WVGeometryDoublyPeriodic([4000 3000],[16 12],Nz=5,shouldAntialias=false);
            adapter = WVFastTransformDoublyPeriodicFFTW(geometry,5,planner="estimate",nCores=1);
            cleanup = onCleanup(@()delete(adapter));
            diagnostics = adapter.storageDiagnostics();
            testCase.verifyEqual(diagnostics.fourierStorageType,"hermitian-half");
            testCase.verifyEqual(diagnostics.compressedDimension,1);
            testCase.verifyEqual(diagnostics.fourierStorageSize,[9 12]);
            testCase.verifyEqual(diagnostics.horizontalPlanCount,1);
            testCase.verifyEqual(diagnostics.persistentArrayBytes,0);

            metadata = metaclass(adapter);
            properties = metadata.PropertyList;
            if iscell(properties)
                properties = [properties{:}];
            end
            propertyNames = string({properties.Name});
            removedNames = ["complexBuffer" "dftXY" "dftX" "dftY" "dftXYComplexBuffer" "dftXComplexBuffer" "dftYComplexBuffer" "dftRealBuffer" "dx" "dy" "k_hc" "l_hc"];
            testCase.verifyFalse(any(ismember(propertyNames,removedNames)));
            clear cleanup
        end

        function derivativesRetainBuiltinMATLABBehavior(testCase)
            geometry = WVGeometryDoublyPeriodic([4000 3000],[16 12],Nz=4,shouldAntialias=false);
            adapter = WVFastTransformDoublyPeriodicFFTW(geometry,4,planner="estimate",nCores=1);
            cleanup = onCleanup(@()delete(adapter));
            rng(7131,"twister");
            spatial = randn(16,12,4);
            for order = [1 2 3]
                testCase.verifyEqual(adapter.diffX(spatial,n=order),geometry.fastTransform.diffX(spatial,n=order),AbsTol=1e-12);
                testCase.verifyEqual(adapter.diffY(spatial,n=order),geometry.fastTransform.diffY(spatial,n=order),AbsTol=1e-12);
            end
            clear cleanup
        end

        function selectedOneDimensionalDerivativesAreCorrectAndLazy(testCase)
            geometry = WVGeometryDoublyPeriodic([4000 3000],[128 128],Nz=129,shouldAntialias=false);
            adapter = WVFastTransformDoublyPeriodicFFTW(geometry,129,planner="estimate",nCores=1);
            cleanup = onCleanup(@()delete(adapter));
            rng(7475,"twister");
            spatial = randn(128,128,129);
            before = adapter.storageDiagnostics();
            testCase.verifyEqual(before.horizontalPlanCount,1);
            for order = [2 3]
                testCase.verifyLessThanOrEqual(relativeError(adapter.diffX(spatial,n=order),geometry.fastTransform.diffX(spatial,n=order)),1e-12);
            end
            testCase.verifyLessThanOrEqual(relativeError(adapter.diffY(spatial,n=2),geometry.fastTransform.diffY(spatial,n=2)),1e-12);
            after = adapter.storageDiagnostics();
            testCase.verifyEqual(after.horizontalPlanCount,3);
            testCase.verifyEqual(after.persistentArrayBytes,0);
            clear cleanup
        end

        function selectedModalAllDerivativePathMatchesBuiltin(testCase)
            builtin = WVTransformConstantStratification([4000 3000 1000],[64 64 65],shouldAntialias=false,fastTransform="builtin");
            fftw = WVTransformConstantStratification([4000 3000 1000],[64 64 65],shouldAntialias=false,fastTransform="fftw");
            cleanup = onCleanup(@()deleteTransforms(builtin,fftw));
            rng(7476,"twister");
            Apm = randn(builtin.spectralMatrixSize) + 1i*randn(builtin.spectralMatrixSize);
            A0 = randn(builtin.spectralMatrixSize) + 1i*randn(builtin.spectralMatrixSize);
            [a,b,c,d] = builtin.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=A0);
            [w,x,y,z] = fftw.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=A0);
            verifyArrays(testCase,{w,x,y,z},{a,b,c,d});
            diagnostics = fftw.fastTransform.storageDiagnostics();
            testCase.verifyEqual(diagnostics.horizontalPlanCount,1);
            testCase.verifyEqual(diagnostics.persistentArrayBytes,0);
            clear cleanup
        end

        function repeatedConstructionAndFailureCleanupAreBalanced(testCase)
            before = fftw_r2c('lifetime');
            geometry = WVGeometryDoublyPeriodic([4000 3000],[8 6],Nz=3,shouldAntialias=false);
            for iRepeat = 1:3
                adapter = WVFastTransformDoublyPeriodicFFTW(geometry,3,planner="estimate",nCores=1);
                testCase.verifyError(@()adapter.transformFromSpatialDomainWithFourier(zeros(7,6,3)),"RealToComplexTransform:DimensionMismatch");
                delete(adapter);
                clear adapter
            end
            after = fftw_r2c('lifetime');
            testCase.verifyEqual(after(1)-before(1),3);
            testCase.verifyEqual(after(2)-before(2),3);
            testCase.verifyEqual(after(3),before(3));
            testCase.verifyEqual(after(6),before(6));
            testCase.verifyEqual(after(7:10),before(7:10));
        end

        function reducedBenchmarkRecordsCompleteCallsAndSelection(testCase)
            result = runWVFFTWAdapterBenchmark(sizes=[16 12 4],antialiasValues=false,warmupCount=1,sampleCount=2,largeSampleCount=2,planner="estimate",nCores=1,fftwTransformsRoot=testCase.fftwTransformsRoot,shouldWriteArtifacts=false,requireCleanTree=false,runId="issue-71-smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(result.candidateIds,["builtin" "layout-methods" "specialized-rows"]);
            testCase.verifyEqual(result.operationIds,["forward" "inverse"]);
            testCase.verifyEqual(result.selection.forward,"layout-methods");
            testCase.verifyEqual(result.selection.inverse,"layout-methods");
            benchmarkCase = result.cases;
            testCase.verifyEqual(benchmarkCase.status,"complete");
            testCase.verifySize(benchmarkCase.warmupSchedules,[1 6]);
            testCase.verifySize(benchmarkCase.sampleSchedules,[2 6]);
            testCase.verifyEqual(benchmarkCase.storage.fourierStorageSize,[9 12]);
            testCase.verifyEqual(benchmarkCase.storage.adapterPersistentArrayBytes,0);
            for candidate = benchmarkCase.candidates
                for operation = candidate.operations
                    testCase.verifyNumElements(operation.rawSeconds,2);
                    testCase.verifyTrue(all(isfinite(operation.rawSeconds)));
                    testCase.verifyEqual(operation.medianSeconds,median(operation.rawSeconds),AbsTol=eps(operation.medianSeconds));
                    testCase.verifyLessThanOrEqual(operation.relativeError,1e-12);
                end
            end
        end
    end
end

function deleteAdapters(varargin)
for iAdapter = 1:numel(varargin)
    adapter = varargin{iAdapter};
    if ~isempty(adapter) && isvalid(adapter)
        delete(adapter);
    end
end
end

function deleteTransforms(varargin)
for iTransform = 1:numel(varargin)
    transform = varargin{iTransform};
    if ~isempty(transform) && isvalid(transform)
        delete(transform);
    end
end
end

function verifyArrays(testCase,actual,expected)
for iArray = 1:numel(actual)
    testCase.verifyLessThanOrEqual(relativeError(actual{iArray},expected{iArray}),1e-12);
end
end

function value = relativeError(actual,expected)
value = norm(actual(:)-expected(:),inf)/max(norm(expected(:),inf),eps);
end
