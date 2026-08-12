classdef TestWVCompiledBackend < matlab.unittest.TestCase
    properties
        repositoryRoot
    end

    methods (TestClassSetup)
        function locateRepository(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
        end
    end

    methods (Test, TestTags="smoke")
        function capabilitiesAreNonthrowingAndDoNotBuild(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            root = string(fixture.Folder);
            action = @()WVCompiledBackend.capabilitiesForTesting(struct("PackageRoot",root,"Architecture","maca64","OperatingSystem","macOS","Release","R2025b","MaxThreads",16));
            capabilities = testCase.verifyWarningFree(action);
            testCase.verifyEqual(capabilities.schemaVersion,"1.0.0");
            testCase.verifyEqual(capabilities.status,"not-built");
            testCase.verifyEqual(capabilities.contract.threadCount,16);
            testCase.verifyEqual(capabilities.provider.id,"native-neon-pthreads");
            testCase.verifyEqual(capabilities.provider.sourceSHA256,"5630c24cdeb33b131612f7eb4b1a9934234754f9f388ff8617458d0be6f239a1");
            testCase.verifyFalse(isfolder(fullfile(root,".compiled-backend-cache")));
        end

        function unsupportedSystemsProduceStructuredUnavailability(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            root = string(fixture.Folder);
            oldRelease = WVCompiledBackend.capabilitiesForTesting(struct("PackageRoot",root,"Architecture","maca64","OperatingSystem","macOS","Release","R2025a"));
            testCase.verifyEqual(oldRelease.status,"unsupported");
            testCase.verifyEqual(oldRelease.failure.identifier,"WaveVortexModel:CompiledBackendUnsupported");
            wrongArchitecture = WVCompiledBackend.capabilitiesForTesting(struct("PackageRoot",root,"Architecture","maci64","OperatingSystem","macOS","Release","R2025b"));
            testCase.verifyEqual(wrongArchitecture.status,"unsupported");
            testCase.verifyFalse(wrongArchitecture.platform.isSupported);
            testCase.verifyFalse(isfolder(fullfile(root,".compiled-backend-cache")));
        end

        function portableLinuxPathHasNoDownloadBuildOrOutput(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            root = string(fixture.Folder);
            capabilities = WVCompiledBackend.buildForTesting(struct("PackageRoot",root,"Architecture","glnxa64","OperatingSystem","Linux","Release","R2026a","DownloadFunction",@unexpectedDownload));
            testCase.verifyEqual(capabilities.status,"unsupported");
            testCase.verifyFalse(capabilities.isAvailable);
            testCase.verifyFalse(isfolder(fullfile(root,".compiled-backend-cache")));
            entries = dir(root); entries = entries(~ismember(string({entries.name}),["." ".."]));
            testCase.verifyEmpty(entries);
        end

        function capabilityAndUnsupportedBuildRestoreState(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            originalDirectory = string(pwd); originalPath = path; originalRng = rng; originalWarnings = warning;
            cd(fixture.Folder); rng(169,"twister"); expectedRng = rng;
            cleanup = onCleanup(@()restoreState(originalDirectory,originalPath,originalRng,originalWarnings));
            WVCompiledBackend.capabilitiesForTesting(struct("PackageRoot",string(fixture.Folder),"Architecture","glnxa64","OperatingSystem","Linux","Release","R2026a"));
            WVCompiledBackend.buildForTesting(struct("PackageRoot",string(fixture.Folder),"Architecture","glnxa64","OperatingSystem","Linux","Release","R2026a"));
            testCase.verifyEqual(string(pwd),string(fixture.Folder));
            testCase.verifyEqual(path,originalPath);
            testCase.verifyEqual(rng,expectedRng);
            clear cleanup
        end
    end

    methods (Test, TestTags="full")
        function compilerDownloadChecksumAndBuildFailuresAreStructured(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            root = string(fixture.Folder);
            common = struct("PackageRoot",root,"Architecture","maca64","OperatingSystem","macOS","Release","R2025b","MaxThreads",2);
            compilerOptions = common; compilerOptions.CompilerAvailable = false;
            compilerFailure = WVCompiledBackend.buildForTesting(compilerOptions);
            testCase.verifyEqual(compilerFailure.status,"build-failed");
            testCase.verifyEqual(compilerFailure.failure.identifier,"WaveVortexModel:CompiledBackendCompilerUnavailable");
            testCase.verifyFalse(isfolder(fullfile(root,".compiled-backend-cache")));

            downloadOptions = common; downloadOptions.DownloadFunction = @failedDownload;
            downloadFailure = WVCompiledBackend.buildForTesting(downloadOptions);
            testCase.verifyEqual(downloadFailure.buildAttempt.stage,"download");
            testCase.verifyEqual(downloadFailure.failure.identifier,"WaveVortexModel:TestDownloadFailure");

            archiveFolder = fullfile(root,".compiled-backend-cache","downloads");
            if ~isfolder(archiveFolder), mkdir(archiveFolder); end
            writelines("not fftw",fullfile(archiveFolder,"fftw-3.3.11.tar.gz"));
            checksumFailure = WVCompiledBackend.buildForTesting(common);
            testCase.verifyEqual(checksumFailure.buildAttempt.stage,"checksum");
            testCase.verifyEqual(checksumFailure.failure.identifier,"WaveVortexModel:CompiledBackendChecksumMismatch");

            delete(fullfile(archiveFolder,"fftw-3.3.11.tar.gz"));
            injected = common; injected.FailureStage = "download";
            buildFailure = WVCompiledBackend.buildForTesting(injected);
            testCase.verifyEqual(buildFailure.status,"build-failed");
            testCase.verifyEqual(buildFailure.failure.identifier,"WaveVortexModel:CompiledBackendInjectedFailure");
        end

        function loadedModuleReplacementIsRefused(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            options = struct("PackageRoot",string(fixture.Folder),"Architecture","maca64","OperatingSystem","macOS","Release","R2025b","ModuleLoaded",true);
            capabilities = WVCompiledBackend.buildForTesting(options);
            testCase.verifyEqual(capabilities.status,"build-failed");
            testCase.verifyEqual(capabilities.failure.identifier,"WaveVortexModel:CompiledBackendModuleLoaded");
            testCase.verifyFalse(isfolder(fullfile(fixture.Folder,".compiled-backend-cache")));
        end

        function unrelatedCwdAndTrackedExportResolveProductionSources(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            exportRoot = fullfile(fixture.Folder,"export"); mkdir(exportRoot);
            tracked = splitlines(strtrim(string(runGit(testCase.repositoryRoot,"ls-files"))));
            classFiles = tracked(startsWith(tracked,"@WVCompiledBackend/"));
            required = [classFiles;"CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp";"CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.hpp";"CompiledKernel/adapters/native-fftw/wv_compiled_backend_mex.cpp";"CompiledKernel/src/WVKernelTypes.cpp";"CompiledKernel/src/WVTransformConstantStratificationKernel.cpp"];
            testCase.verifyTrue(all(ismember(required,tracked)));
            for relative = required'
                destination = fullfile(exportRoot,relative);
                if ~isfolder(fileparts(destination)), mkdir(fileparts(destination)); end
                copyfile(fullfile(testCase.repositoryRoot,relative),destination);
            end
            originalDirectory = pwd; originalPath = path; cleanup = onCleanup(@()restoreDirectoryAndPath(originalDirectory,originalPath));
            cd(fixture.Folder); addpath(exportRoot,"-begin"); clear WVCompiledBackend
            testCase.verifyTrue(startsWith(string(which("WVCompiledBackend")),string(exportRoot)));
            capabilities = WVCompiledBackend.capabilitiesForTesting(struct("PackageRoot",string(exportRoot),"Architecture","glnxa64","OperatingSystem","Linux","Release","R2026a"));
            testCase.verifyEqual(capabilities.cache.root,string(fullfile(exportRoot,".compiled-backend-cache")));
            testCase.verifyFalse(isfolder(fullfile(exportRoot,".compiled-backend-cache")));
            clear cleanup
        end
    end

    methods (Test, TestTags="optional")
        function nativeBuildHasExactIdentitiesSelfTestsLifecycleAndRollback(testCase)
            capabilities = WVCompiledBackend.build();
            testCase.assertEqual(capabilities.status,"available",capabilities.failure.message);
            testCase.verifyEqual(capabilities.schemaVersion,"1.0.0");
            testCase.verifyEqual(capabilities.matlab.release,"R2025b");
            testCase.verifyEqual(capabilities.platform.architecture,"maca64");
            testCase.verifyEqual(capabilities.contract.threadCount,min(18,maxNumCompThreads));
            testCase.verifyEqual(capabilities.contract.planCount,17);
            testCase.verifyEqual(capabilities.libraries.base.path,string(realpath(fullfile(capabilities.cache.root,"provider","native-neon-pthreads","lib","libfftw3.3.dylib"))));
            testCase.verifyEqual(capabilities.libraries.thread.path,string(realpath(fullfile(capabilities.cache.root,"provider","native-neon-pthreads","lib","libfftw3_threads.3.dylib"))));
            testCase.verifyFalse(capabilities.libraries.openmp.detected);
            testCase.verifyLessThanOrEqual(capabilities.featureValidation.maximumRelativeError,1e-12);
            testCase.verifyTrue(capabilities.featureValidation.hydrostatic.lifecyclePassed);
            testCase.verifyTrue(capabilities.featureValidation.nonhydrostatic.lifecyclePassed);
            testCase.verifyEqual(capabilities.featureValidation.hydrostatic.planCount,17);
            testCase.verifyEqual(capabilities.featureValidation.nonhydrostatic.planCount,17);

            missingSymbols = WVCompiledBackend.buildForTesting(struct("CommandOutputFunction",@missingSymbolOutput));
            testCase.verifyEqual(missingSymbols.status,"build-failed");
            testCase.verifyEqual(missingSymbols.buildAttempt.stage,"provider-validation");
            testCase.verifyEqual(missingSymbols.failure.identifier,"WaveVortexModel:CompiledBackendSymbolMissing");

            buildFailure = WVCompiledBackend.buildForTesting(struct("FailureStage","provider-build"));
            testCase.verifyEqual(buildFailure.status,"build-failed");
            testCase.verifyEqual(buildFailure.buildAttempt.stage,"provider-build");
            testCase.verifyEqual(buildFailure.failure.identifier,"WaveVortexModel:CompiledBackendInjectedFailure");

            recordPath = fullfile(capabilities.cache.root,"state","validated-build.json");
            originalRecord = string(fileread(recordPath));
            recordCleanup = onCleanup(@()writeText(recordPath,originalRecord));
            record = jsondecode(originalRecord); record.libraries.base.path = record.libraries.thread.path;
            writeText(recordPath,jsonencode(record,PrettyPrint=true));
            identityMismatch = WVCompiledBackend.capabilities();
            testCase.verifyEqual(identityMismatch.status,"invalid");
            testCase.verifyEqual(identityMismatch.failure.identifier,"WaveVortexModel:CompiledBackendIdentityMismatch");
            clear recordCleanup

            originalHash = capabilities.module.sha256;
            rollback = WVCompiledBackend.buildForTesting(struct("FailureStage","install-validation"));
            testCase.verifyEqual(rollback.status,"build-failed");
            afterRollback = WVCompiledBackend.capabilities();
            testCase.verifyEqual(afterRollback.status,"available");
            testCase.verifyEqual(afterRollback.module.sha256,originalHash);
            testCase.verifyFalse(afterRollback.module.loadedAfterInspection);
        end
    end
end

function unexpectedDownload(~,~)
error("WaveVortexModel:UnexpectedDownload","Unsupported capability detection attempted a download.");
end

function failedDownload(~,~)
error("WaveVortexModel:TestDownloadFailure","Injected network failure.");
end

function [status,output] = missingSymbolOutput(~)
status = 0; output = "";
end

function output = runGit(repositoryRoot,arguments)
[status,output] = system("git -C "+shellQuote(repositoryRoot)+" "+arguments);
if status ~= 0, error("WaveVortexModel:TestGit","git %s failed.",arguments); end
end

function pathname = realpath(pathname)
[status,pathname] = system("/bin/realpath "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:TestPath","Unable to resolve path."); end
pathname = strtrim(pathname);
end

function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end

function restoreState(directory,originalPath,originalRng,originalWarnings)
cd(directory); path(originalPath); rng(originalRng); warning(originalWarnings);
end

function restoreDirectoryAndPath(directory,originalPath)
cd(directory); path(originalPath);
end

function writeText(pathname,value)
fileId = fopen(pathname,"w");
if fileId < 0, error("WaveVortexModel:TestWrite","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end
