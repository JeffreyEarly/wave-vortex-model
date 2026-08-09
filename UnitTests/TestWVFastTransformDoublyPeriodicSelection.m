classdef TestWVFastTransformDoublyPeriodicSelection < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            supportFolder = fullfile(fileparts(mfilename("fullpath")),"Support");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test,TestTags="full")
        function builtinBypassesFFTWServices(testCase)
            geometry = testGeometry();
            mock = MockWVBackendServices();
            mock.installed = false;
            [adapter,selection] = createWithMock(geometry,3,"builtin",mock);
            cleanup = onCleanup(@()delete(adapter));
            testCase.verifyEqual(adapter.backendIdentifier,"builtin");
            testCase.verifyEqual(selection.requestedBackend,"builtin");
            testCase.verifyEqual(selection.activeBackend,"builtin");
            testCase.verifyFalse(selection.didFallback);
            testCase.verifyEqual(mock.queryCount,0);
            testCase.verifyEqual(mock.buildCount,0);
            clear cleanup
        end

        function validPartialCapabilitiesSelectFFTWWithoutBuild(testCase)
            geometry = testGeometry();
            capabilities = validCapabilities();
            capabilities.features.dct1.isAvailable = false;
            capabilities.features.dst1.isAvailable = false;
            mock = MockWVBackendServices(capabilities);
            [adapter,selection] = createWithMock(geometry,3,"fftw",mock);
            cleanup = onCleanup(@()delete(adapter));
            testCase.verifyEqual(adapter.backendIdentifier,"fftw");
            testCase.verifyEqual(selection.activeBackend,"fftw");
            testCase.verifyFalse(selection.didFallback);
            testCase.verifyTrue(selection.capabilityQueried);
            testCase.verifyEqual(selection.providerId,"matlab-bundled");
            testCase.verifyEqual(selection.libraryPath,"/validated/libmwfftw3.3.dylib");
            testCase.verifyEqual(mock.queryCount,1);
            testCase.verifyEqual(mock.buildCount,0);
            clear cleanup
        end

        function unavailableCapabilityBuildsOnceAndRequeries(testCase)
            geometry = testGeometry();
            unavailable = validCapabilities();
            unavailable.features.r2c.isAvailable = false;
            unavailable.build.isPossible = true;
            available = validCapabilities();
            mock = MockWVBackendServices({unavailable,available});
            mock.buildResult = struct("build",struct("succeeded",true));
            [adapter,selection] = createWithMock(geometry,3,"fftw",mock);
            cleanup = onCleanup(@()delete(adapter));
            testCase.verifyEqual(adapter.backendIdentifier,"fftw");
            testCase.verifyTrue(selection.buildAttempted);
            testCase.verifyTrue(selection.buildSucceeded);
            testCase.verifyEqual(mock.queryCount,2);
            testCase.verifyEqual(mock.buildCount,1);
            clear cleanup
        end

        function missingPackageWarnsOnceAndFallsBack(testCase)
            geometry = testGeometry();
            mock = MockWVBackendServices();
            mock.installed = false;
            testCase.verifyWarning(@()createWithMock(geometry,3,"fftw",mock),"WaveVortexModel:FFTWBackendUnavailable");
            warningState = warning("off","WaveVortexModel:FFTWBackendUnavailable");
            cleanup = onCleanup(@()warning(warningState));
            [adapter,selection] = createWithMock(geometry,3,"fftw",mock);
            adapterCleanup = onCleanup(@()delete(adapter));
            testCase.verifyEqual(adapter.backendIdentifier,"builtin");
            testCase.verifyTrue(selection.didFallback);
            testCase.verifyEqual(selection.reason.code,"package-missing");
            testCase.verifyEqual(mock.queryCount,0);
            clear adapterCleanup cleanup
        end

        function invalidContractsFallBackWithStructuredReasons(testCase)
            cases = invalidCapabilityCases();
            geometry = testGeometry();
            warningState = warning("off","WaveVortexModel:FFTWBackendUnavailable");
            cleanup = onCleanup(@()warning(warningState));
            for iCase = 1:numel(cases)
                mock = MockWVBackendServices(cases(iCase).capabilities);
                [adapter,selection] = createWithMock(geometry,3,"fftw",mock);
                testCase.verifyEqual(adapter.backendIdentifier,"builtin",cases(iCase).id);
                testCase.verifyTrue(selection.didFallback,cases(iCase).id);
                testCase.verifyEqual(selection.reason.code,cases(iCase).reasonCode,cases(iCase).id);
                testCase.verifyEqual(mock.buildCount,0,cases(iCase).id);
                delete(adapter);
            end
            clear cleanup
        end

        function capabilityAndConstructionFailuresFallBack(testCase)
            geometry = testGeometry();
            warningState = warning("off","WaveVortexModel:FFTWBackendUnavailable");
            cleanup = onCleanup(@()warning(warningState));

            queryMock = MockWVBackendServices();
            queryMock.queryException = MException("TestSelection:QueryFailed","injected query failure");
            [queryAdapter,querySelection] = createWithMock(geometry,3,"fftw",queryMock);
            testCase.verifyEqual(querySelection.reason.code,"capability-query-failed");
            delete(queryAdapter);

            constructorMock = MockWVBackendServices(validCapabilities());
            constructorMock.shouldFailFFTWConstruction = true;
            [constructorAdapter,constructorSelection] = createWithMock(geometry,3,"fftw",constructorMock);
            testCase.verifyEqual(constructorSelection.reason.code,"adapter-construction-failed");
            testCase.verifyEqual(constructorAdapter.backendIdentifier,"builtin");
            delete(constructorAdapter);

            unavailable = validCapabilities();
            unavailable.features.r2c.isAvailable = false;
            unavailable.build.isPossible = true;
            buildMock = MockWVBackendServices(unavailable);
            buildMock.buildException = MException("MockWVBackendServices:CompileFailed","injected compilation failure");
            [buildAdapter,buildSelection] = createWithMock(geometry,3,"fftw",buildMock);
            testCase.verifyTrue(buildSelection.buildAttempted);
            testCase.verifyFalse(buildSelection.buildSucceeded);
            testCase.verifyEqual(buildSelection.buildReason.code,"build-failed");
            testCase.verifyEqual(buildMock.buildCount,1);
            testCase.verifyEqual(buildMock.queryCount,2);
            delete(buildAdapter);
            clear cleanup
        end

        function geometryConstructorContainsNoGatewayProbe(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            source = fileread(fullfile(repositoryRoot,"@WVGeometryDoublyPeriodic","WVGeometryDoublyPeriodic.m"));
            forbidden = ["FFTWBackend" "RealToComplexTransform" "fftw_r2c" "fftw_dft2"];
            for token = forbidden
                testCase.verifyFalse(contains(source,token),token);
            end
            testCase.verifySubstring(source,"WVFastTransformDoublyPeriodic.create(self,self.Nz,options.fastTransform)");
        end

        function invalidInjectedServicesAreRejected(testCase)
            geometry = testGeometry();
            testCase.verifyError(@()WVFastTransformDoublyPeriodic.createWithServices(geometry,3,"builtin",struct()),"WaveVortexModel:InvalidBackendServices");
        end

        function packageDeclaresFFTWTransformsDependency(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            package = matlab.mpm.Package(repositoryRoot);
            names = string({package.Dependencies.Name});
            dependency = package.Dependencies(names == "FFTWTransforms");
            testCase.verifyNumElements(dependency,1);
            testCase.verifyEqual(string(dependency.VersionRange),"^1.0.2");
            testCase.verifyEqual(string(dependency.ID),"c9f6616c-d26a-4fdc-8426-91ca8ffd751b");
        end

        function nonconstantRestorationRejectsFFTW(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            pathname = fullfile(fixture.Folder,"barotropic.nc");
            original = WVTransformBarotropicQG([4000 3000],[8 6],latitude=45,shouldAntialias=false);
            file = original.writeToFile(pathname,shouldOverwriteExisting=true);
            file.close();
            testCase.verifyError(@()WVTransform.waveVortexTransformFromFile(pathname,fastTransform="fftw"),"WVTransform:UnsupportedFastTransform");
        end
    end
end

function [adapter,selection] = createWithMock(geometry,Nz,requestedBackend,mock)
[adapter,selection] = WVFastTransformDoublyPeriodic.createWithServices(geometry,Nz,requestedBackend,mock.functionHandles());
end

function geometry = testGeometry()
geometry = WVGeometryDoublyPeriodic([4000 3000],[8 6],Nz=3,shouldAntialias=false);
end

function capabilities = validCapabilities()
emptyReason = struct("code","","identifier","","message","");
feature = struct("isAvailable",true,"maximumRelativeError",1e-14,"reason",emptyReason);
capabilities = struct();
capabilities.provider = struct("id","matlab-bundled");
capabilities.modules = struct("r2c",struct("identityValidated",true,"libraryPath","/validated/libmwfftw3.3.dylib"));
capabilities.features = struct("r2c",feature,"c2r",feature,"dct1",feature,"dst1",feature);
capabilities.eligibility.horizontal = struct( ...
    "isReady",true, ...
    "layout","half-x", ...
    "transformDimensions",[2 1], ...
    "ownership","MATLAB-managed zero-copy forward and uniquely owned destructive inverse");
capabilities.memory.preservingInverseScratch = struct( ...
    "policy","lazy-on-first-preserving-c2r", ...
    "allocatedBytesAtPlanCreation",0, ...
    "allocatedBytesForDestructiveOnlyUse",0);
capabilities.build = struct("isPossible",false);
capabilities.reason = emptyReason;
end

function cases = invalidCapabilityCases()
cases = repmat(struct("id","","capabilities",struct(),"reasonCode",""),1,7);

capabilities = validCapabilities();
capabilities.provider.id = "native";
cases(1) = struct("id","provider","capabilities",capabilities,"reasonCode","provider-mismatch");

capabilities = validCapabilities();
capabilities.modules.r2c.identityValidated = false;
cases(2) = struct("id","library","capabilities",capabilities,"reasonCode","library-identity-failed");

capabilities = validCapabilities();
capabilities.features.c2r.isAvailable = false;
cases(3) = struct("id","feature","capabilities",capabilities,"reasonCode","horizontal-feature-unavailable");

capabilities = validCapabilities();
capabilities.features.r2c.maximumRelativeError = 2e-12;
cases(4) = struct("id","numerical","capabilities",capabilities,"reasonCode","horizontal-self-test-failed");

capabilities = validCapabilities();
capabilities.eligibility.horizontal.layout = "half-y";
cases(5) = struct("id","eligibility","capabilities",capabilities,"reasonCode","horizontal-eligibility-failed");

capabilities = validCapabilities();
capabilities.eligibility.horizontal.ownership = "copying";
cases(6) = struct("id","ownership","capabilities",capabilities,"reasonCode","ownership-contract-mismatch");

capabilities = validCapabilities();
capabilities.memory.preservingInverseScratch.allocatedBytesAtPlanCreation = 16;
cases(7) = struct("id","scratch","capabilities",capabilities,"reasonCode","scratch-contract-mismatch");
end
