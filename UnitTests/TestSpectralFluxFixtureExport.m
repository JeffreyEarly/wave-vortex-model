classdef TestSpectralFluxFixtureExport < matlab.unittest.TestCase
    properties
        benchmarkFolder
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.benchmarkFolder));
        end
    end

    methods (Test,TestTags="full")
        function exportsVersionedMappedOperatorFixture(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            outputDirectory = fullfile(string(folderFixture.Folder),"fixture");
            manifest = exportSpectralFluxFixture(outputDirectory,Nxyz=[8 8 7],seed=19);

            testCase.verifyEqual(manifest.schema,"spectral-flux-fixture-v1");
            testCase.verifyEqual(manifest.authoritative,~manifest.provenance.dirtyTree);
            testCase.verifyEqual(manifest.status,conditional(manifest.authoritative,"authoritative-wvm-export","invalid"));
            testCase.verifyEqual(manifest.workload.Nkl,11);
            testCase.verifyEqual(manifest.workload.Nj,4);
            testCase.verifyEqual(manifest.operatorContract.familyIds,["wave-f" "wave-g"]);
            testCase.verifyEqual(manifest.operatorContract.inputFieldFamilies,uint32([0 0 1 0 0 1 0 0 1 1 1 0 1 1 0]));
            testCase.verifyEqual(manifest.operatorContract.targetFieldFamilies,uint32([0 0 1 1]));
            testCase.verifyEqual(numel(manifest.payloads),8);

            decoded = jsondecode(fileread(fullfile(outputDirectory,"manifest.json")));
            testCase.verifyEqual(string(decoded.schema),"spectral-flux-fixture-v1");
            for iPayload = 1:numel(manifest.payloads)
                payload = manifest.payloads(iPayload);
                pathname = fullfile(outputDirectory,payload.path);
                information = dir(pathname);
                testCase.verifyEqual(information.bytes,payload.byteCount);
                testCase.verifyEqual(sha256File(pathname),payload.sha256);
            end

            modeKeys = readNumeric(fullfile(outputDirectory,"horizontal-mode-keys.i32le"),"int32");
            testCase.verifyEqual(reshape(modeKeys,2,[]),int32([0 0 1 -1 1 0 2 -2 -1 1 2;0 1 0 1 1 2 0 1 2 2 1]));
            inputs = readComplex(fullfile(outputDirectory,"modal-inputs.c128le"));
            targets = readComplex(fullfile(outputDirectory,"expected-modal-targets.c128le"));
            testCase.verifyEqual(numel(inputs),4*15*11);
            testCase.verifyEqual(numel(targets),4*4*11);
            inputFields = reshape(inputs,4,15,11);
            testCase.verifyEqual(imag(inputFields(:,:,1)),zeros(4,15));
            testCase.verifyGreaterThan(max(abs(targets)),0);
            testCase.verifyError(@()exportSpectralFluxFixture(outputDirectory,Nxyz=[8 8 7],seed=19),"WaveVortexBenchmark:SpectralFluxFixtureExists");
        end
    end
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function values = readNumeric(pathname,precision)
fileId = fopen(pathname,"r","ieee-le");
cleanup = onCleanup(@()fclose(fileId));
values = fread(fileId,Inf,"*"+precision);
clear cleanup
end

function values = readComplex(pathname)
scalars = readNumeric(pathname,"double");
values = complex(scalars(1:2:end),scalars(2:2:end));
end

function hash = sha256File(pathname)
fileId = fopen(pathname,"r");
cleanup = onCleanup(@()fclose(fileId));
bytes = fread(fileId,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
hashBytes = typecast(digest.digest(),"uint8");
hash = lower(string(reshape(dec2hex(hashBytes,2).',1,[])));
clear cleanup
end
