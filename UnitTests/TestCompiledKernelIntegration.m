classdef TestCompiledKernelIntegration < matlab.unittest.TestCase
    properties
        repositoryRoot
        selection
    end

    methods (TestClassSetup)
        function loadSelection(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.selection = jsondecode(fileread(fullfile(testCase.repositoryRoot,"CompiledKernel","source-selection.json")));
        end
    end

    methods (Test,TestTags="smoke")
        function selectionRecordsTheAcceptedContract(testCase)
            testCase.verifyEqual(string(testCase.selection.schemaVersion),"1.0.0");
            testCase.verifyEqual(string(testCase.selection.selectedFeatureSnapshot),"8d0b49236c703dfa7230a8875022fdb3e30283b0");
            testCase.verifyEqual(string(testCase.selection.preparation.sharedCoefficientFormulas),"97e28a892f55877a9267b2c4e3ca399b85596a34");
            testCase.verifyEqual(string(testCase.selection.preparation.nativeFFTWProvider),"1854d72ec07b0fb58c2b2aa972250d91629e669d");
            testCase.verifyEqual(testCase.selection.contract.version,4);
            testCase.verifyEqual(string(testCase.selection.contract.coefficientShape),"[Nj,Nkl]");
            testCase.verifyEqual(testCase.selection.contract.planCount,17);
            testCase.verifyEqual(string(testCase.selection.contract.knownScratch),"4H+6R");
            testCase.verifyEqual(testCase.selection.contract.coefficientWorkers,2);
            testCase.verifyFalse(testCase.selection.contract.persistentFullHermitianSpectrum);
        end

        function keyRuntimeHashesMatchTheSelection(testCase)
            entries = {
                "CompiledKernel/src/WVCoefficientFormulas.hpp","coefficientFormulas"
                "CompiledKernel/src/WVTransformConstantStratificationKernel.cpp","kernel"
                "CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp","nativeEngine"
                "CompiledKernel/adapters/native-fftw/wv_compiled_backend_mex.cpp","mexGateway"
                "@WVCompiledBackend/private/wvCompiledBackendBuild.m","buildOrchestrator"
                };
            for iEntry = 1:size(entries,1)
                actual = sha256File(fullfile(testCase.repositoryRoot,entries{iEntry,1}));
                testCase.verifyEqual(actual,string(testCase.selection.keySourceSHA256.(entries{iEntry,2})),entries{iEntry,1});
            end
        end
    end

    methods (Test,TestTags="full")
        function portableCoreHasNoHostOrVendorDependency(testCase)
            coreFiles = [
                filesUnder(fullfile(testCase.repositoryRoot,"CompiledKernel","include"),[".hpp" ".h"])
                filesUnder(fullfile(testCase.repositoryRoot,"CompiledKernel","src"),[".cpp" ".hpp" ".h"])
                ];
            forbidden = ["mex.h" "matrix.h" "MatlabDataArray" "fftw3.h" "netcdf.h" "Accelerate/Accelerate.h"];
            for file = coreFiles'
                source = string(fileread(file));
                testCase.verifyFalse(any(contains(source,forbidden)),"Portable dependency found in "+file);
            end
        end

        function repositoryTracksOnlySourceProducts(testCase)
            tracked = splitlines(strtrim(runGit(testCase.repositoryRoot,"ls-files")));
            required = [
                "CompiledKernel/CMakeLists.txt"
                "CompiledKernel/source-selection.json"
                "CompiledKernel/include/WaveVortexKernel/WVFFTEngine.hpp"
                "CompiledKernel/src/WVTransformConstantStratificationKernel.cpp"
                "CompiledKernel/adapters/native-fftw/wv_compiled_backend_mex.cpp"
                "@WVCompiledBackend/WVCompiledBackend.m"
                ];
            testCase.verifyTrue(all(ismember(required,tracked)));
            forbidden = contains(tracked,".compiled-backend-cache/") | ...
                endsWith(tracked,[".a" ".o" ".dylib" ".tar.gz"]) | ...
                ~cellfun(@isempty,regexp(cellstr(tracked),'\.mex[a-z0-9]*$','once'));
            testCase.verifyFalse(any(forbidden),"Generated native products are tracked.");
            testCase.verifyFalse(any(startsWith(tracked,"Benchmarks/results/experiments/issue1")),"Engineering benchmark artifacts entered the integration branch.");
        end
    end
end

function files = filesUnder(root,extensions)
listing = dir(fullfile(root,"**","*"));
listing = listing(~[listing.isdir]);
paths = string(fullfile({listing.folder},{listing.name}))';
[~,~,extension] = fileparts(paths);
files = paths(ismember(extension,extensions));
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:TestHash","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function output = runGit(repositoryRoot,arguments)
[status,output] = system("git -C "+shellQuote(repositoryRoot)+" "+arguments);
if status ~= 0, error("WaveVortexModel:TestGit","git %s failed.",arguments); end
output = string(output);
end

function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end
