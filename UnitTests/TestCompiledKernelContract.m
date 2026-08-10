classdef TestCompiledKernelContract < matlab.unittest.TestCase
    methods (TestClassSetup)
        function buildStandaloneTools(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            scriptPath = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
            [status,output] = system(sprintf('"%s"',scriptPath));
            testCase.assertEqual(status,0,output);
        end
    end

    methods (Test,TestTags="full")
        function descriptorMatchesMatlabConstantStratification(testCase)
            cases = struct( ...
                "Lxyz",{[15000 12000 1300],[15000 12000 1300],[15000 15000 1300]}, ...
                "Nxyz",{[16 12 9],[15 13 9],[36 36 9]}, ...
                "isHydrostatic",{false,true,true}, ...
                "shouldAntialias",{true,false,true});
            for testDefinition = cases
                wvt = WVTransformConstantStratification(testDefinition.Lxyz,testDefinition.Nxyz,isHydrostatic=testDefinition.isHydrostatic,shouldAntialias=testDefinition.shouldAntialias);
                actual = descriptorDump(testDefinition,wvt.Nj);
                testCase.verifyEqual(actual.contractVersion,2);
                testCase.verifyEqual(actual.Nkl,wvt.Nkl);
                testCase.verifyEqual(actual.spectralShape(:)',[wvt.Nj wvt.Nkl]);
                testCase.verifyEqual(actual.kMode(:),wvt.kMode_wv(:));
                testCase.verifyEqual(actual.lMode(:),wvt.lMode_wv(:));
                testCase.verifyEqual(actual.k(:),wvt.k(:),AbsTol=1e-15);
                testCase.verifyEqual(actual.l(:),wvt.l(:),AbsTol=1e-15);
                testCase.verifyEqual(uint64(actual.dftPrimaryIndices2D(:)),wvt.dftPrimaryIndices2D(:));
                testCase.verifyEqual(uint64(actual.dftConjugateIndices2D(:)),wvt.dftConjugateIndices2D(:));
                layout = WVFourierStorageLayout(wvt,"hermitian-half",compressedDimension=1);
                testCase.verifyEqual(uint64(actual.halfDirectRows(:))+1,layout.fourierRowsForDirectWVIndices(:));
                testCase.verifyEqual(uint64(actual.halfDirectWVIndices(:))+1,layout.directWVIndices(:));
                testCase.verifyEqual(uint64(actual.halfConjugatedRows(:))+1,layout.fourierRowsForConjugatedWVIndices(:));
                testCase.verifyEqual(uint64(actual.halfConjugatedWVIndices(:))+1,layout.conjugatedWVIndices(:));
                testCase.verifyEqual(uint64(actual.halfCompletionRows(:))+1,layout.hermitianCompletionRows(:));
                testCase.verifyEqual(uint64(actual.halfCompletionSourceRows(:))+1,layout.hermitianSourceRows(:));
                testCase.verifyEqual(uint64(actual.halfSelfConjugateRows(:))+1,layout.selfConjugateFourierRows(:));
                testCase.verifyEqual(actual.z(:),wvt.z(:),AbsTol=1e-14);
                testCase.verifyEqual(actual.j(:),wvt.j(:));
                testCase.verifyEqual(actual.h0(:),wvt.h_0(:),RelTol=1e-14);
                testCase.verifyEqual(actual.coriolisFrequency,wvt.f,RelTol=1e-14);
                testCase.verifyEqual(reshape(actual.hpm,wvt.spectralMatrixSize),wvt.h_pm,RelTol=1e-13);
                testCase.verifyEqual(reshape(actual.omega,wvt.spectralMatrixSize),wvt.Omega,RelTol=1e-13);
                testCase.verifyEqual(reshape(actual.Fg,wvt.spectralMatrixSize),wvt.F_g,RelTol=1e-13);
                testCase.verifyEqual(reshape(actual.Gg,wvt.spectralMatrixSize),wvt.G_g,RelTol=1e-13);
                testCase.verifyEqual(reshape(actual.Fwg,wvt.spectralMatrixSize),wvt.F_wg,RelTol=1e-13);
                testCase.verifyEqual(reshape(actual.Gwg,wvt.spectralMatrixSize),wvt.G_wg,RelTol=1e-13);
                complexFields = ["UAp" "UAm" "VAp" "VAm" "WAp" "WAm" "UA0" "VA0" "ApmD" "ApmWScaled"];
                matlabFields = ["UAp" "UAm" "VAp" "VAm" "WAp" "WAm" "UA0" "VA0" "ApmD" "ApmW_scaled"];
                for iField = 1:numel(complexFields)
                    value = actual.(complexFields(iField) + "Real") + 1i*actual.(complexFields(iField) + "Imag");
                    expected = expandToSpectralSize(wvt.(matlabFields(iField)),wvt.spectralMatrixSize);
                    testCase.verifyEqual(reshape(value,wvt.spectralMatrixSize),expected,RelTol=1e-13,AbsTol=1e-14);
                end
                realFields = ["NAp" "NAm" "NA0" "A0Z" "A0N" "ApmN" "ApmDScaled"];
                matlabFields = ["NAp" "NAm" "NA0" "A0Z" "A0N" "ApmN" "ApmD_scaled"];
                for iField = 1:numel(realFields)
                    expected = expandToSpectralSize(wvt.(matlabFields(iField)),wvt.spectralMatrixSize);
                    testCase.verifyEqual(reshape(actual.(realFields(iField)),wvt.spectralMatrixSize),expected,RelTol=1e-13,AbsTol=1e-14);
                end
            end
        end

        function baselineWrapperProducesCompleteArtifacts(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(repositoryRoot,"Benchmarks"));
            outputDirectory = string(tempname);
            cleanup = onCleanup(@()removeDirectory(outputDirectory));
            results = runCompiledKernelBuiltinBaseline(suiteId="smoke-v1",caseIds=["smoke-constant-nonhydrostatic" "smoke-constant-hydrostatic"],processRunCount=1,outputDirectory=outputDirectory,runId="contract-smoke");
            testCase.verifyEqual(results.status,"complete");
            testCase.verifyEqual(results.configuration.backend,"builtin");
            testCase.verifyEqual(numel(results.performance.suites(1).cases),2);
            testCase.verifyEqual(numel(results.storage.cases),2);
            backendIds = arrayfun(@(benchmarkCase)string(benchmarkCase.backends(1).id),results.performance.suites(1).cases);
            testCase.verifyEqual(backendIds,repmat("builtin",size(backendIds)));
            testCase.verifyTrue(all(strlength(string({results.source.files.sha256})) == 64));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"compiled-kernel-baseline.json")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")));
            decoded = jsondecode(fileread(fullfile(outputDirectory,"compiled-kernel-baseline.json")));
            testCase.verifyEqual(string(decoded.schemaVersion),"1.0.0");
            summary = string(fileread(fullfile(outputDirectory,"summary.md")));
            testCase.verifyTrue(contains(summary,"Complete nonlinear flux"));
            testCase.verifyTrue(contains(summary,"Storage and fresh-process RSS"));
            clear cleanup
        end
    end
end

function value = expandToSpectralSize(value,spectralSize)
value = value + zeros(spectralSize);
end

function actual = descriptorDump(definition,Nj)
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
executable = fullfile(repositoryRoot,"tools","compiled-kernel","build","WVKernelDescriptorDump");
arguments = [definition.Nxyz(1:3) Nj definition.Lxyz 5.2e-3 1025 9.81 7.2921e-5 33 definition.isHydrostatic definition.shouldAntialias];
command = sprintf('"%s" %s',executable,strjoin(compose("%.17g",arguments)," "));
[status,output] = system(command);
if status ~= 0
    error("WaveVortexModel:KernelDescriptorDumpFailed","%s",output);
end
actual = jsondecode(output);
end

function removeDirectory(pathname)
if isfolder(pathname)
    rmdir(pathname,"s");
end
end
