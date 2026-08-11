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
                testCase.verifyEqual(string(metrics.phaseImplementation),"accelerate-vvsincos-output-workspace");
                testCase.verifyEqual(metrics.planCount,14);
                testCase.verifyGreaterThan(metrics.scratchCapacityBytes,0);
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
                testCase.verifyEqual(after.phaseWorkspaceBytes,0);
                testCase.verifyEqual(after.scratchCapacityBytes,before.scratchCapacityBytes);
                testCase.verifyEqual(string(after.nonlinearFluxSchedule),"sequential-phase-once");
                testCase.verifyEqual(wvt.Ap,Ap);
                testCase.verifyEqual(wvt.Am,Am);
                testCase.verifyEqual(wvt.A0,A0);
                clear cleanup
            end
        end

        function experimentalModalAndPhaseVariantsAgree(testCase)
            repositoryRoot=fileparts(fileparts(mfilename("fullpath"))); addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory=string(tempname); mkdir(outputDirectory); cleanup=onCleanup(@()cleanupVariantModules(outputDirectory));
            variants=struct( ...
                "name",{"wv_compiled_compact_scalar","wv_compiled_prescaled_scalar","wv_compiled_prescaled_accelerate"}, ...
                "phase",{"scalar","scalar","accelerate"}, ...
                "coefficients",{"compact","prescaled","prescaled"});
            for iVariant=1:numel(variants)
                buildCompiledKernelTransformMex(outputDirectory=outputDirectory,outputName=variants(iVariant).name,phaseImplementation=variants(iVariant).phase,modalCoefficientMode=variants(iVariant).coefficients,modalWorkerCount=1);
            end
            addpath(outputDirectory);
            wvt=WVTransformConstantStratification([15000 12000 1300],[8 6 7],isHydrostatic=false,shouldAntialias=true); wvt.initWithRandomFlow(uvMax=0.01); wvt.t=73;
            [expectedFp,expectedFm,expectedF0]=wvt.nonlinearFlux();
            for iVariant=1:numel(variants)
                module=variants(iVariant).name; handle=feval(module,'create',kernelConfiguration(wvt),1);
                [actualFp,actualFm,actualF0]=feval(module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
                verifyRelative(testCase,actualFp,expectedFp,string(module)+" Fp"); verifyRelative(testCase,actualFm,expectedFm,string(module)+" Fm"); verifyRelative(testCase,actualF0,expectedF0,string(module)+" F0");
                metrics=feval(module,'metrics',handle); testCase.verifyEqual(string(metrics.modalCoefficientMode),string(variants(iVariant).coefficients));
                feval(module,'delete',handle); clear(module);
            end
            delete(wvt); clear cleanup
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
            testCase.verifyEqual(string(result.cases.candidate.metrics.nonlinearFluxSchedule),"sequential-phase-once");
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

        function modalVectorizationBenchmarkProducesArtifacts(testCase)
            repositoryRoot=fileparts(fileparts(mfilename("fullpath"))); addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory=string(tempname); cleanup=onCleanup(@()removeDirectory(outputDirectory));
            result=runCompiledKernelModalVectorizationBenchmark(screenCaseIds="constant-hydrostatic-256x256x65",gateCaseIds="constant-hydrostatic-256x256x65",screenVariantIds="prescaled-modal",screenProcessRunCount=1,gateProcessRunCount=1,samplingIntervalSeconds=0.01,plateauSeconds=0.08,threadCount=1,outputDirectory=outputDirectory,runId="smoke");
            testCase.verifyEqual(result.status,"complete");
            testCase.verifyEqual(result.selectedCumulative.variantId,"prescaled-modal");
            testCase.verifyEqual(string(result.gateCases.candidate.metadata.variantIdentifier),"prescaled-modal");
            testCase.verifyEqual(string(result.gateCases.candidate.metadata.modalCoefficientMode),"prescaled");
            testCase.verifyLessThanOrEqual(result.gateCases.candidate.maximumRelativeError,1e-12);
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"modal-vectorization-benchmark.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded=jsondecode(fileread(fullfile(outputDirectory,"modal-vectorization-benchmark.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            clear cleanup
        end

        function modalVectorizationDecisionHandlesSpeedAndMemory(testCase)
            mediumHydro=modalDecisionCase([256 256 65],true,1.11,1.0,1.0); mediumNonhydro=modalDecisionCase([256 256 65],false,1.10,1.0,1.0);
            largeHydro=modalDecisionCase([512 512 129],true,1.0,0.89,0.89); largeNonhydro=modalDecisionCase([512 512 129],false,1.0,0.88,0.90);
            decision=compiledKernelModalVectorizationDecision([mediumHydro;mediumNonhydro;largeHydro;largeNonhydro]);
            testCase.verifyTrue(decision.qualified); testCase.verifyEqual(decision.qualifyingSizes,["256x256x65" "512x512x129"]); testCase.verifyEqual(decision.qualifyingMechanisms,["speed" "memory"]);
            largeNonhydro.noMemoryRegression=false; decision=compiledKernelModalVectorizationDecision([mediumHydro;mediumNonhydro;largeHydro;largeNonhydro]); testCase.verifyFalse(decision.qualified);
        end

    end
end

function value = decisionCase(Nxyz,isHydrostatic,fivePercentSpeedPassed)
value=struct("Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"fivePercentSpeedPassed",fivePercentSpeedPassed,"correctnessPassed",true,"phaseCountPassed",true,"noSpeedRegression",true,"noMemoryRegression",true,"status","complete");
end

function value=modalDecisionCase(Nxyz,isHydrostatic,speedup,exactStorageRatio,peakRSSRatio)
value=struct("Nxyz",Nxyz,"isHydrostatic",isHydrostatic,"speedup",speedup,"exactStorageRatio",exactStorageRatio,"peakRSSRatio",peakRSSRatio,"correctnessPassed",true,"implementationExecuted",true,"noSpeedRegression",true,"noMemoryRegression",true,"status","complete");
end

function removeDirectory(pathname)
if isfolder(pathname), rmdir(pathname,"s"); end
end

function cleanupVariantModules(outputDirectory)
rmpath(outputDirectory); clear("wv_compiled_compact_scalar","wv_compiled_prescaled_scalar","wv_compiled_prescaled_accelerate");
if isfolder(outputDirectory), rmdir(outputDirectory,"s"); end
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

function [Fp,Fm,F0] = executeNonlinearFlux(handle,wvt)
[Fp,Fm,F0] = wv_compiled_transform_mex('nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
end

function deleteKernel(handle)
try
    wv_compiled_transform_mex('delete',handle);
catch
end
end
