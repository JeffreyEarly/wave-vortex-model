classdef TestThermalReadinessRestart < matlab.unittest.TestCase
    methods (TestClassSetup)
        function includeAuthoringTools(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
        end
    end
    methods (Test,TestTags="full")
        function clocksIndependentStreamsAndProviderFreeReplay(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            output=fullfile(folder.Folder,'restart');
            w=thermalReadinessCase(struct(Nx=18,Ny=18,Nz=65,thermalCount=17,mdaCount=4,assemblyCount=0,productCount=0,inverseScale=0,domainSize=[5e5 5e5 1000],N0=.01,t=123,t0=45,phase=pi/2));
            before=w.coefficientState();
            first=qualifyThermalReadinessRestart(w,output,duration=6,step=1,maximumWallSeconds=120,caseId="manufactured-clock-control");
            testCase.verifyEqual(first.contract.initialTime,123); testCase.verifyEqual(first.contract.t0,45);
            testCase.verifyEqual(first.contract.checkpointTime,125); testCase.verifyEqual(first.contract.finalTime,129);
            testCase.verifyLessThan(first.continuation.coefficientError,1e-10);
            testCase.verifyLessThan(first.continuation.fieldError,1e-10);
            testCase.verifyEqual(w.coefficientState(),before); testCase.verifyEqual([w.t w.t0],[123 45]);
            testCase.verifyTrue(any(first.streams.variable=="Ath"));
            testCase.verifyTrue(any(first.streams.variable=="Amda"));
            testCase.verifyTrue(any(first.streams.group=="inventory"));
            testCase.verifyTrue(all(ismember(["surfaceAnomaly","bottomAnomaly"],first.streams.variable)));
            testCase.verifyEqual(first.status,"CONDITIONAL: fresh-process provider-unavailable replay required");
            testCase.verifyError(@()qualifyThermalReadinessRestart(w,output,duration=6,step=1),'WV:ReadinessRestartExists');
            % This exercises the replay branch in a functional test. The real
            % qualification invokes that branch in a separate MATLAB process.
            originalPath=path; cleanup=onCleanup(@()path(originalPath));
            providerRoot=string(fileparts(fileparts(which('IMInternalModes'))));
            paths=string(strsplit(path,pathsep)); selected=startsWith(paths,providerRoot+filesep) | paths==providerRoot;
            rmpath(char(join(paths(selected),pathsep)));
            testCase.assertEmpty(which('IMInternalModes'));
            second=qualifyThermalReadinessRestart([],output,restoreOnly=true,maximumWallSeconds=120);
            testCase.verifyLessThan(second.continuation.coefficientError,1e-10);
            testCase.verifyLessThan(second.continuation.fieldError,1e-10);
            testCase.verifyEqual(second.streams,first.streams);
        end
    end
end
