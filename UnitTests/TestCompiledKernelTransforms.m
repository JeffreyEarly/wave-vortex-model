classdef TestCompiledKernelTransforms < matlab.unittest.TestCase
    methods (TestClassSetup)
        function buildGateway(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(repositoryRoot,"Benchmarks"));
            gateway = buildCompiledKernelTransformMex;
            addpath(fileparts(gateway));
            testCase.addTeardown(@()rmpath(fileparts(gateway)));
        end
    end

    methods (Test,TestTags="optional")
        function fusedTransformsMatchMatlab(testCase)
            definitions = struct( ...
                "domain",{[15000 12000 1300],[15000 12000 1300],[15000 15000 1300]}, ...
                "size",{[7 6 7],[6 5 7],[36 36 9]}, ...
                "hydrostatic",{true,false,true}, ...
                "antialias",{false,true,true});
            for definition = definitions
                rng(3027,"twister");
                wvt = WVTransformConstantStratification(definition.domain,definition.size, ...
                    isHydrostatic=definition.hydrostatic,shouldAntialias=definition.antialias);
                handle = wv_compiled_transform_mex('create',kernelConfiguration(wvt),1);
                cleanup = onCleanup(@()deleteKernel(handle));
                U = randn(wvt.spatialMatrixSize); V = randn(wvt.spatialMatrixSize);
                N = randn(wvt.spatialMatrixSize);
                if definition.hydrostatic
                    fields = cat(4,U,V,N);
                    [expectedAp,expectedAm,expectedA0] = wvt.transformUVEtaToWaveVortex(U,V,N);
                else
                    W = randn(wvt.spatialMatrixSize);
                    fields = cat(4,U,V,W,N);
                    [expectedAp,expectedAm,expectedA0] = wvt.transformUVWEtaToWaveVortex(U,V,W,N);
                end
                [actualAp,actualAm,actualA0] = wv_compiled_transform_mex('forward',handle,fields,wvt.t,wvt.t0);
                verifyRelative(testCase,actualAp,expectedAp,"Ap forward");
                verifyRelative(testCase,actualAm,expectedAm,"Am forward");
                verifyRelative(testCase,actualA0,expectedA0,"A0 forward");

                actualFields = wv_compiled_transform_mex('inverse',handle,expectedAp,expectedAm,expectedA0,wvt.t,wvt.t0);
                [expectedU,expectedV,expectedW,expectedN] = wvt.transformWaveVortexToUVWEta(expectedAp,expectedAm,expectedA0,wvt.t);
                expectedFields = cat(4,expectedU,expectedV,expectedW,expectedN);
                inverseNames = ["U" "V" "W" "N"];
                for iField = 1:4
                    verifyRelative(testCase,actualFields(:,:,:,iField),expectedFields(:,:,:,iField),"inverse "+inverseNames(iField));
                end
                zero = zeros(wvt.spectralMatrixSize);
                actualA0Fields = wv_compiled_transform_mex('inverse',handle,complex(zero),complex(zero),expectedA0,wvt.t,wvt.t0);
                [expectedU,expectedV,expectedW,expectedN] = wvt.transformWaveVortexToUVWEta(zero,zero,expectedA0,wvt.t);
                expectedA0Fields = cat(4,expectedU,expectedV,expectedW,expectedN);
                for iField = 1:4
                    verifyRelative(testCase,actualA0Fields(:,:,:,iField),expectedA0Fields(:,:,:,iField),"A0 inverse "+inverseNames(iField));
                end
                probe = complex(zeros(wvt.spectralMatrixSize));
                probe(min(2,wvt.Nj),min(2,wvt.Nkl)) = 1+2i;
                actualProbe = wv_compiled_transform_mex('inverse',handle,complex(zero),complex(zero),probe,wvt.t,wvt.t0);
                [expectedU,expectedV,expectedW,expectedN] = wvt.transformWaveVortexToUVWEta(zero,zero,probe,wvt.t);
                expectedProbe = cat(4,expectedU,expectedV,expectedW,expectedN);
                for iField = 1:4
                    verifyRelative(testCase,actualProbe(:,:,:,iField),expectedProbe(:,:,:,iField),"A0 probe "+inverseNames(iField));
                end

                Apm = randn(wvt.spectralMatrixSize) + 1i*randn(wvt.spectralMatrixSize);
                A0 = randn(wvt.spectralMatrixSize) + 1i*randn(wvt.spectralMatrixSize);
                [value,x,y,z] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=Apm,A0=A0);
                actual = wv_compiled_transform_mex('fAll',handle,Apm,A0);
                verifyRelative(testCase,actual,cat(4,value,x,y,z),"F derivatives");
                [value,x,y,z] = wvt.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=A0);
                actual = wv_compiled_transform_mex('gAll',handle,Apm,A0);
                verifyRelative(testCase,actual,cat(4,value,x,y,z),"G derivatives");

                wvt.initWithRandomFlow(uvMax=0.01);
                wvt.t = 90;
                [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
                [actualFp,actualFm,actualF0] = wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
                verifyRelative(testCase,actualFp,expectedFp,"Fp nonlinear flux");
                verifyRelative(testCase,actualFm,expectedFm,"Fm nonlinear flux");
                verifyRelative(testCase,actualF0,expectedF0,"F0 nonlinear flux");
                metrics = wv_compiled_transform_mex('metrics',handle);
                testCase.verifyEqual(string(metrics.engine),"fftw");
                expectedLibrary = string(fullfile(matlabroot,"bin",computer("arch"),"libmwfftw3.3.dylib"));
                testCase.verifyEqual(string(metrics.loadedLibrary),expectedLibrary);
                testCase.verifyEqual(metrics.contractVersion,4);
                testCase.verifyEqual(metrics.planCount,17);
                testCase.verifyGreaterThan(metrics.scratchCapacityBytes,0);
                testCase.verifyEqual(string(metrics.coefficientStorageMode),"natural-dimensional");
                testCase.verifyEqual(string(metrics.coefficientArithmeticMode),"natural-dimensional-prescaled");
                testCase.verifyEqual(string(metrics.inverseNormalizationPlacement),"coefficient-production");
                testCase.verifyEqual(string(metrics.optimizationImplementation),"O3-native");
                testCase.verifyEqual(metrics.coefficientWorkerCount,2);
                clear cleanup
            end
        end

        function nonlinearFluxEvaluatesPhaseOnce(testCase)
            definitions = struct("hydrostatic",{true,false},"size",{[8 6 7],[8 6 7]});
            for definition = definitions
                rng(4127,"twister");
                wvt = WVTransformConstantStratification([15000 12000 1300],definition.size,isHydrostatic=definition.hydrostatic,shouldAntialias=true);
                wvt.initWithRandomFlow(uvMax=0.01);
                Ap = wvt.Ap; Am = wvt.Am; A0 = wvt.A0;
                handle = wv_compiled_transform_mex('create',kernelConfiguration(wvt),1);
                cleanup = onCleanup(@()deleteKernel(handle));
                before = wv_compiled_transform_mex('metrics',handle);
                timeOffsets = [0 90 -45];
                for timeOffset = timeOffsets
                    wvt.t = wvt.t0 + timeOffset;
                    [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
                    [actualFp,actualFm,actualF0] = wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
                    verifyRelative(testCase,actualFp,expectedFp,"Fp nonlinear flux at time offset "+timeOffset);
                    verifyRelative(testCase,actualFm,expectedFm,"Fm nonlinear flux at time offset "+timeOffset);
                    verifyRelative(testCase,actualF0,expectedF0,"F0 nonlinear flux at time offset "+timeOffset);
                end
                after = wv_compiled_transform_mex('metrics',handle);
                expectedCalls = numel(timeOffsets);
                expectedPhaseEvaluations = expectedCalls*prod(wvt.spectralMatrixSize);
                testCase.verifyEqual(after.nonlinearFluxCallCount-before.nonlinearFluxCallCount,expectedCalls);
                testCase.verifyEqual(after.nonlinearFluxPhaseEvaluationCount-before.nonlinearFluxPhaseEvaluationCount,expectedPhaseEvaluations);
                testCase.verifyGreaterThan(after.phaseWorkspaceBytes,0);
                testCase.verifyEqual(after.phaseWorkspaceBytes,after.phaseReservationBytes);
                testCase.verifyEqual(after.scratchCapacityBytes,before.scratchCapacityBytes);
                testCase.verifyEqual(string(after.nonlinearFluxSchedule),"streamed-target-three-channel");
                testCase.verifyEqual(wvt.Ap,Ap);
                testCase.verifyEqual(wvt.Am,Am);
                testCase.verifyEqual(wvt.A0,A0);
                clear cleanup
            end
        end

        function coefficientFormulaModesMatchMatlab(testCase)
            definitions = struct( ...
                "size",{[6 8 7],[6 8 7],[8 6 7],[8 6 7]}, ...
                "hydrostatic",{true,false,true,false});
            for definition = definitions
                wvt = WVTransformConstantStratification([15000 12000 1300],definition.size,isHydrostatic=definition.hydrostatic,shouldAntialias=false);
                wvt.t = wvt.t0 + 37.5;
                handle = wv_compiled_transform_mex('create',kernelConfiguration(wvt),1);
                cleanup = onCleanup(@()deleteKernel(handle));
                layout = WVFourierStorageLayout(wvt,"hermitian-half",compressedDimension=1);
                directModes = setdiff(layout.directWVIndices,1,"stable");
                conjugatedModes = layout.conjugatedWVIndices;
                testCase.assertNotEmpty(directModes,"A nonzero direct mode is required.");
                testCase.assertNotEmpty(conjugatedModes,"A conjugated mode is required.");
                waveJ = min(2,wvt.Nj);
                mdaJ = min(2,wvt.Nj);
                probeDefinitions = struct( ...
                    "name",{"direct wave","conjugated wave","geostrophic","mean-density","inertial"}, ...
                    "family",{"wave","wave","geostrophic","mean-density","inertial"}, ...
                    "mode",{directModes(1),conjugatedModes(1),directModes(1),1,1}, ...
                    "j",{waveJ,waveJ,waveJ,mdaJ,waveJ});
                for probeDefinition = probeDefinitions
                    zero = complex(zeros(wvt.spectralMatrixSize));
                    Ap = zero; Am = zero; A0 = zero;
                    index = {probeDefinition.j,probeDefinition.mode};
                    switch probeDefinition.family
                        case "wave"
                            Ap(index{:}) = 0.23+0.17i;
                            Am(index{:}) = -0.11+0.07i;
                        case {"geostrophic","mean-density"}
                            A0(index{:}) = 0.19-0.13i;
                        case "inertial"
                            Ap(index{:}) = 0.21-0.09i;
                            Am(index{:}) = conj(Ap(index{:}));
                    end
                    actualFields = wv_compiled_transform_mex('inverse',handle,Ap,Am,A0,wvt.t,wvt.t0);
                    [expectedU,expectedV,expectedW,expectedN] = wvt.transformWaveVortexToUVWEta(Ap,Am,A0,wvt.t);
                    expectedFields = cat(4,expectedU,expectedV,expectedW,expectedN);
                    verifyScaled(testCase,actualFields,expectedFields,probeDefinition.name+" inverse");
                    if definition.hydrostatic
                        [expectedAp,expectedAm,expectedA0] = wvt.transformUVEtaToWaveVortex(expectedU,expectedV,expectedN);
                        fields = cat(4,expectedU,expectedV,expectedN);
                    else
                        [expectedAp,expectedAm,expectedA0] = wvt.transformUVWEtaToWaveVortex(expectedU,expectedV,expectedW,expectedN);
                        fields = expectedFields;
                    end
                    [actualAp,actualAm,actualA0] = wv_compiled_transform_mex('forward',handle,fields,wvt.t,wvt.t0);
                    verifyScaled(testCase,actualAp,expectedAp,probeDefinition.name+" Ap projection");
                    verifyScaled(testCase,actualAm,expectedAm,probeDefinition.name+" Am projection");
                    verifyScaled(testCase,actualA0,expectedA0,probeDefinition.name+" A0 projection");
                end

                Apm = complex(zeros(wvt.spectralMatrixSize));
                A0 = complex(zeros(wvt.spectralMatrixSize));
                Apm(waveJ,directModes(1)) = 0.17-0.12i;
                Apm(waveJ,conjugatedModes(1)) = -0.08+0.14i;
                A0(mdaJ,1) = 0.09+0.03i;
                [value,x,y,z] = wvt.transformToSpatialDomainWithFAllDerivatives(Apm=Apm,A0=A0);
                verifyScaled(testCase,wv_compiled_transform_mex('fAll',handle,Apm,A0),cat(4,value,x,y,z),"isolated F derivatives");
                [value,x,y,z] = wvt.transformToSpatialDomainWithGAllDerivatives(Apm=Apm,A0=A0);
                verifyScaled(testCase,wv_compiled_transform_mex('gAll',handle,Apm,A0),cat(4,value,x,y,z),"isolated G derivatives");

                fields = zeros([wvt.spatialMatrixSize,3+~definition.hydrostatic]);
                fields(:,:,:,1) = 0.17;
                fields(:,:,:,2) = -0.11;
                fields(:,:,:,end) = 0.07;
                verifyForwardFields(testCase,wvt,handle,fields,"zero mode");
                if mod(wvt.Nx,2)==0
                    fields = zeros(size(fields));
                    fields(:,:,:,1) = repmat(reshape((-1).^(0:wvt.Nx-1),[],1,1),1,wvt.Ny,wvt.Nz);
                    verifyForwardFields(testCase,wvt,handle,fields,"x Nyquist mode");
                end
                if mod(wvt.Ny,2)==0
                    fields = zeros(size(fields));
                    fields(:,:,:,2) = repmat(reshape((-1).^(0:wvt.Ny-1),1,[],1),wvt.Nx,1,wvt.Nz);
                    verifyForwardFields(testCase,wvt,handle,fields,"y Nyquist mode");
                end
                metrics = wv_compiled_transform_mex('metrics',handle);
                testCase.verifyEqual(metrics.contractVersion,4);
                testCase.verifyEqual([metrics.Nj metrics.Nkl],wvt.spectralMatrixSize);
                testCase.verifyEqual(metrics.planCount,17);
                testCase.verifyEqual(metrics.halfSpectrumScratchCapacityBytes,4*(floor(wvt.Nx/2)+1)*wvt.Ny*wvt.Nz*16);
                testCase.verifyEqual(metrics.realScratchCapacityBytes,6*prod(wvt.spatialMatrixSize)*8);
                testCase.verifyEqual(metrics.coefficientWorkerCount,2);
                testCase.verifyEqual(metrics.persistentFullHermitianBytes,0);
                clear cleanup
            end
        end

        function transformBenchmarkProducesArtifacts(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory = string(tempname);
            cleanup = onCleanup(@()removeDirectory(outputDirectory));
            result = runCompiledKernelTransformBenchmark(sizes=[8 6 7],hydrostatic=[true false],warmupCount=1,mediumSampleCount=2,largeSampleCount=2,threadCount=1,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(numel(result.cases),2);
            testCase.verifyEqual([result.cases.sampleCount],[2 2]);
            errors = arrayfun(@(item)max([item.errors.forward item.errors.inverse item.errors.fAll item.errors.gAll]),result.cases);
            testCase.verifyLessThanOrEqual(max(errors),1e-12);
            metrics = [result.cases.metrics];
            testCase.verifyTrue(all([metrics.scratchCapacityBytes] > 0));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"compiled-transform-benchmark.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"compiled-transform-benchmark.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            clear cleanup
        end

        function mexFailuresAndLifetimeRemainBalanced(testCase)
            wvt = WVTransformConstantStratification([15000 12000 1300],[8 6 7],isHydrostatic=false,shouldAntialias=true);
            wvt.initWithRandomFlow(uvMax=0.01);
            configuration = kernelConfiguration(wvt);
            baseline = wv_compiled_transform_mex('moduleMetrics');
            testCase.verifyError(@()wv_compiled_transform_mex('createInjectedFailure',configuration,1,'plan'), ...
                'WaveVortexModel:CompiledKernelPlan');
            testCase.verifyError(@()wv_compiled_transform_mex('createInjectedFailure',configuration,1,'allocation'), ...
                'WaveVortexModel:CompiledKernelAllocation');
            afterCreationFailures = wv_compiled_transform_mex('moduleMetrics');
            testCase.verifyEqual(afterCreationFailures.kernelCount,baseline.kernelCount);
            testCase.verifyEqual(afterCreationFailures.activePlans,baseline.activePlans);
            testCase.verifyEqual(afterCreationFailures.outstandingPlanningBytes,0);

            handle = wv_compiled_transform_mex('createInjectedFailure',configuration,1,'execution');
            cleanup = onCleanup(@()deleteKernel(handle));
            testCase.verifyError(@()executeNonlinearFlux(handle,wvt),'WaveVortexModel:CompiledKernelExecution');
            [Fp,Fm,F0] = executeNonlinearFlux(handle,wvt);
            testCase.verifySize(Fp,wvt.spectralMatrixSize);
            testCase.verifySize(Fm,wvt.spectralMatrixSize);
            testCase.verifySize(F0,wvt.spectralMatrixSize);
            clear cleanup
            final = wv_compiled_transform_mex('moduleMetrics');
            testCase.verifyEqual(final.kernelCount,baseline.kernelCount);
            testCase.verifyEqual(final.activePlans,baseline.activePlans);
            testCase.verifyEqual(final.outstandingPlanningBytes,0);
            testCase.verifyEqual(final.totalPlansCreated-final.totalPlansDestroyed,final.activePlans);
        end

        function validationHarnessProducesFreshProcessEvidence(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory = string(tempname);
            cleanup = onCleanup(@()removeDirectory(outputDirectory));
            result = runCompiledKernelValidation(sizes=[8 6 7],hydrostatic=false,antialias=[true false], ...
                processRunCount=1,warmupCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.08, ...
                threadCount=1,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(numel(result.cases),2);
            numerical = [result.cases.numerical];
            ledgers = [result.cases.ledger];
            testCase.verifyLessThanOrEqual(max([numerical.maximumRelativeError]),1e-12);
            testCase.verifyTrue(all([result.cases.lifecyclePassed]));
            testCase.verifyTrue(result.staticChecks.passed);
            testCase.verifyTrue(all([ledgers.persistentFullHermitianBytes]==0));
            testCase.verifyTrue(all([ledgers.gradientMaskBytes]==0));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"compiled-kernel-validation.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"compiled-kernel-validation.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            clear cleanup
        end

        function readinessHarnessUsesCoreSchemaAndExecutedMetadata(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory = string(tempname);
            cleanup = onCleanup(@()removeDirectory(outputDirectory));
            result = runCompiledKernelReadinessBenchmark( ...
                caseIds="constant-hydrostatic-256x256x65",processRunCount=1, ...
                samplingIntervalSeconds=0.01,plateauSeconds=0.08,threadCount=1, ...
                outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(result.configuration.suiteId,"core-v1");
            testCase.verifyEqual(result.configuration.operation,"ordinary nonlinearFlux");
            testCase.verifyEqual(numel(result.suite.cases),1);
            backends = result.suite.cases.backends;
            testCase.verifyEqual(string({backends.id}),["builtin" "compiled"]);
            testCase.verifyEqual(numel(backends(1).runs.rawSeconds),7);
            testCase.verifyEqual(numel(backends(2).runs.rawSeconds),7);
            testCase.verifyEqual(string(backends(1).metadata.activeImplementation),"builtin");
            testCase.verifyEqual(string(backends(2).metadata.activeImplementation),"compiled");
            testCase.verifyFalse(backends(2).metadata.fallback);
            testCase.verifyLessThanOrEqual(backends(2).maximumRelativeError,1e-12);
            testCase.verifyTrue(backends(2).lifecyclePassed);
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"compiled-kernel-readiness.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            clear cleanup
        end

        function phaseOnceBenchmarkComparesParentAndCandidate(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory = string(tempname);
            cleanup = onCleanup(@()removeDirectory(outputDirectory));
            result = runCompiledKernelPhaseOnceBenchmark(caseIds="constant-hydrostatic-256x256x65",processRunCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.08,threadCount=1,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(numel(result.cases),1);
            testCase.verifyEqual(result.source.baselineCommit,"199c9b8240a46fae8babbce413ee948ac4f89d38");
            testCase.verifyTrue(result.cases.phaseCountPassed);
            testCase.verifyTrue(result.cases.correctnessPassed);
            testCase.verifyLessThan(result.cases.exactStorageRatio,1);
            testCase.verifyEqual(string(result.cases.candidate.metrics.nonlinearFluxSchedule),"streamed-target-three-channel");
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"phase-once-benchmark.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"phase-once-benchmark.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            clear cleanup
        end

        function phaseOnceDecisionHandlesMultipleGateSizes(testCase)
            mediumHydro=decisionCase([256 256 65],true,true); mediumNonhydro=decisionCase([256 256 65],false,true);
            largeHydro=decisionCase([512 512 129],true,false); largeNonhydro=decisionCase([512 512 129],false,false);
            decision=compiledKernelPhaseOnceDecision([mediumHydro;mediumNonhydro;largeHydro;largeNonhydro]);
            testCase.verifyTrue(decision.qualified);
            testCase.verifyEqual(decision.qualifyingSizes,"256x256x65");
            largeNonhydro.noMemoryRegression=false;
            decision=compiledKernelPhaseOnceDecision([mediumHydro;mediumNonhydro;largeHydro;largeNonhydro]);
            testCase.verifyFalse(decision.qualified);
        end

    end
end

function value = decisionCase(Nxyz,isHydrostatic,fivePercentSpeedPassed)
value=struct("Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"fivePercentSpeedPassed",fivePercentSpeedPassed,"correctnessPassed",true,"phaseCountPassed",true,"noSpeedRegression",true,"noMemoryRegression",true,"status","complete");
end

function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end

function configuration = kernelConfiguration(wvt)
configuration = struct( ...
    "Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj, ...
    "Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0, ...
    "rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius, ...
    "rotationRate",wvt.rotationRate,"latitude",wvt.latitude, ...
    "isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function verifyRelative(testCase,actual,expected,label)
expectedMaximum = max(max(abs(expected(:)),[],"omitmissing"),realmin);
error = max(abs(actual(:)-expected(:)),[],"omitmissing")/expectedMaximum;
testCase.verifyLessThanOrEqual(error,1e-12,label+" relative error was "+error+", maximum ratio "+max(abs(actual(:)))/expectedMaximum);
end

function verifyScaled(testCase,actual,expected,label)
scale = max(max(abs(expected(:)),[],"omitmissing"),1);
error = max(abs(actual(:)-expected(:)),[],"omitmissing")/scale;
testCase.verifyLessThanOrEqual(error,1e-12,label+" scaled error was "+error);
end

function verifyForwardFields(testCase,wvt,handle,fields,label)
if wvt.isHydrostatic
    [expectedAp,expectedAm,expectedA0] = wvt.transformUVEtaToWaveVortex(fields(:,:,:,1),fields(:,:,:,2),fields(:,:,:,3));
else
    [expectedAp,expectedAm,expectedA0] = wvt.transformUVWEtaToWaveVortex(fields(:,:,:,1),fields(:,:,:,2),fields(:,:,:,3),fields(:,:,:,4));
end
[actualAp,actualAm,actualA0] = wv_compiled_transform_mex('forward',handle,fields,wvt.t,wvt.t0);
verifyScaled(testCase,actualAp,expectedAp,label+" Ap projection");
verifyScaled(testCase,actualAm,expectedAm,label+" Am projection");
verifyScaled(testCase,actualA0,expectedA0,label+" A0 projection");
end

function [Fp,Fm,F0] = executeNonlinearFlux(handle,wvt)
[Fp,Fm,F0] = wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
end

function deleteKernel(handle)
try
    wv_compiled_transform_mex('delete',handle);
catch
end
end
