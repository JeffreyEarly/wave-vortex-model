classdef TestFreeSurfaceInitializationPilot < matlab.unittest.TestCase
    properties (TestParameter)
        policy={"none","fixedFraction","effectiveBandwidth"}
    end
    methods (Test, TestTags="full")
        function rejectedPilotPreservesFullAcceptedEvidence(testCase,policy)
            N2=@(z)1e-4*exp(2*z/700);
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 65],N2Function=N2,quadraticDealiasing=policy);
            [control,b]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 65],N2Function=N2,quadraticDealiasing=policy,nEVP=a.nEVP,referenceNEVP=a.referenceNEVP);
            testCase.verifyEqual(a.cost.pilotRejectedAttempts,1)
            testCase.verifyEqual(a.cost.pilotPages,8)
            testCase.verifyEqual(a.cost.waveEigensolves,2*(numel(w.khUnique)+1)+16)
            testCase.verifyEqual(rmfield(w.scientificState(),{'N2Function','rhoFunction'}),rmfield(control.scientificState(),{'N2Function','rhoFunction'}))
            testCase.verifyEqual(withoutAssessmentTimers(rmfield(a,'cost')),withoutAssessmentTimers(rmfield(b,'cost')))
        end

        function passingPilotStillChecksEveryPageAndStrictCount(testCase)
            N2=@(z)1e-4+0*z;
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 33],N2Function=N2);
            testCase.verifyEqual(a.cost.pilotRejectedAttempts,0)
            testCase.verifyEqual(a.cost.pilotPages,8)
            testCase.verifyEqual(a.cost.waveEigensolves,2*(numel(w.khUnique)+1)+16)
            testCase.verifyEqual(numel(a.modeConvergence),numel(w.khUnique))
            testCase.verifyFalse(any(cellfun(@isempty,a.modeConvergence)))
            % A strict failure at the second positive page lies between the
            % first two distributed samples; it must survive a passing pilot.
            counts=3*ones(size(w.khUnique)); counts(2)=32;
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 33],N2Function=N2,waveModeKappa=w.khUnique,waveModeCount=counts),'WV:StrictWaveModeCountRejected')
        end

        function smallAndFixedReferenceRequestsBypassPilot(testCase)
            for nx=[8 16]
                referenceNEVP=[];
                if nx==16, referenceNEVP=96; end
                [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[nx nx 33],N2Function=@(z)1e-4+0*z,waveModeCount=0,inertialModeCount=2,referenceNEVP=referenceNEVP);
                testCase.verifyEqual(a.cost.pilotPages,0)
                testCase.verifyEqual(a.cost.waveEigensolves,2*(numel(w.khUnique)+1))
                testCase.verifyEmpty(w.waveMode)
                testCase.verifyEqual(a.pages.candidateCount,32*ones(size(w.khUnique)))
            end
        end

        function sharpProfileKeepsThreeAttemptLimit(testCase)
            N2=@(z)2e-5+8e-5*exp(-((z+300)/80).^2);
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 65],N2Function=N2);
            [control,b]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 65],N2Function=N2,nEVP=156,referenceNEVP=234);
            testCase.verifyEqual([a.nEVP a.referenceNEVP],[156 234])
            testCase.verifyEqual(a.cost.pilotRejectedAttempts,1)
            testCase.verifyEqual(a.cost.waveEigensolves,3*(numel(w.khUnique)+1)+16)
            testCase.verifyEqual(rmfield(w.scientificState(),{'N2Function','rhoFunction'}),rmfield(control.scientificState(),{'N2Function','rhoFunction'}))
            testCase.verifyEqual(withoutAssessmentTimers(rmfield(a,'cost')),withoutAssessmentTimers(rmfield(b,'cost')))
        end

        function inconclusivePilotFallsBackToCompleteAssessment(testCase)
            [factory,assessmentTrace]=initializationFactoryWithFault(testCase,"inconclusive");
            N2=@(z)1e-4*exp(2*z/700);
            [w,a]=factory([1e5 1e5 1000],[16 16 65],N2Function=N2);
            trace=assessmentTrace();
            testCase.verifyEqual([trace.nPages],[7 numel(w.khUnique) numel(w.khUnique)])
            testCase.verifyEqual([trace.nEVP],[69 69 104])
            testCase.verifyEqual([trace.referenceNEVP],[104 104 156])
            testCase.verifyEqual([trace.faultApplied],[true false false])
            testCase.verifyEqual(a.cost.pilotRejectedAttempts,0)
            testCase.verifyEqual(a.cost.pilotPages,8)
            testCase.verifyEqual(a.cost.waveEigensolves,3*(numel(w.khUnique)+1)+16)
            [control,b]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 65],N2Function=N2,nEVP=104,referenceNEVP=156);
            testCase.verifyEqual(rmfield(w.scientificState(),{'N2Function','rhoFunction'}),rmfield(control.scientificState(),{'N2Function','rhoFunction'}))
            testCase.verifyEqual(withoutAssessmentTimers(rmfield(a,'cost')),withoutAssessmentTimers(rmfield(b,'cost')))
        end

        function unsampledFailureAfterPassingPilotForcesRefinement(testCase)
            [factory,assessmentTrace]=initializationFactoryWithFault(testCase,"unsampled-failure");
            N2=@(z)1e-4+0*z;
            [w,a]=factory([1e5 1e5 1000],[16 16 33],N2Function=N2);
            trace=assessmentTrace();
            testCase.verifyEqual([trace.nPages],[7 numel(w.khUnique) numel(w.khUnique)])
            testCase.verifyEqual([trace.nEVP],[64 64 96])
            testCase.verifyEqual([trace.referenceNEVP],[96 96 144])
            testCase.verifyTrue(trace(1).convergedBeforeFault)
            testCase.verifyFalse(ismember(w.khUnique(2),trace(1).kappa))
            testCase.verifyEqual([trace.faultApplied],[false true false])
            testCase.verifyEqual(a.cost.pilotRejectedAttempts,0)
            testCase.verifyEqual(a.cost.pilotPages,8)
            testCase.verifyEqual(a.cost.waveEigensolves,3*(numel(w.khUnique)+1)+16)
            testCase.verifyTrue(all(a.pages.convergedCount>=a.pages.gridSupportedCount))
            testCase.verifyEqual(a.pages.status,repmat("accepted",numel(w.khUnique),1))
            [control,b]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[16 16 33],N2Function=N2,nEVP=96,referenceNEVP=144);
            testCase.verifyEqual(rmfield(w.scientificState(),{'N2Function','rhoFunction'}),rmfield(control.scientificState(),{'N2Function','rhoFunction'}))
            testCase.verifyEqual(withoutAssessmentTimers(rmfield(a,'cost')),withoutAssessmentTimers(rmfield(b,'cost')))
        end
    end
end

function [factory,assessmentTrace]=initializationFactoryWithFault(testCase,fault)
% Redirect copied entry points to an isolated fault wrapper, preserving real solvers.
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[~,suffix]=fileparts(folder.Folder);
namespace=matlab.lang.makeValidName("WVInitializationFault_"+string(suffix));
packageFolder=fullfile(folder.Folder,"+"+namespace);
mkdir(packageFolder);
root=fileparts(fileparts(mfilename('fullpath')));
source=string(fileread(fullfile(root,'@WVTransformFreeSurfaceBoussinesq','fromStratification.m')));
testCase.assertEqual(count(source,"WVInternal.assessFreeSurfaceWavePilot"),1)
testCase.assertEqual(count(source,"WVInternal.assessWaveModeConstruction"),1)
source=replace(source,"WVInternal.assessFreeSurfaceWavePilot",namespace+".assessFreeSurfaceWavePilot");
source=replace(source,"WVInternal.assessWaveModeConstruction",namespace+".assessWaveModeConstruction");
% The copied factory cannot attach a class-private transient report. Its
% complete returned assessment is compared below, independently of storage.
testCase.assertEqual(count(source,"self.constructionAssessment=assessment;"),1)
source=replace(source,"self.constructionAssessment=assessment;","");
writelines(source,fullfile(packageFolder,'fromStratification.m'));
source=string(fileread(fullfile(root,'+WVInternal','assessFreeSurfaceWavePilot.m')));
testCase.assertEqual(count(source,"WVInternal.assessWaveModeConstruction"),1)
source=replace(source,"WVInternal.assessWaveModeConstruction",namespace+".assessWaveModeConstruction");
writelines(source,fullfile(packageFolder,'assessFreeSurfaceWavePilot.m'));
wrapper=[
    "function [assessment,reference,convergence]=assessWaveModeConstruction(varargin)"
    "persistent calls"
    "if nargin==0, assessment=calls; reference=[]; convergence=[]; return; end"
    "[assessment,reference,convergence,entry]=assessInitializationWithFault("""+fault+""",varargin{:});"
    "if isempty(calls), calls=entry; else, calls(end+1,1)=entry; end"
    "end"
    ];
writelines(wrapper,fullfile(packageFolder,'assessWaveModeConstruction.m'));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'UnitTests','Fixtures')));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder.Folder));
factory=str2func(namespace+".fromStratification");
assessmentTrace=str2func(namespace+".assessWaveModeConstruction");
end

function value=withoutAssessmentTimers(value)
% Only elapsed assessment time varies inside the scientific reports.
if isstruct(value)
    if isfield(value,'assessmentSeconds'), value=rmfield(value,'assessmentSeconds'); end
    for i=1:numel(value)
        for name=string(fieldnames(value)).'
            value(i).(name)=withoutAssessmentTimers(value(i).(name));
        end
    end
elseif iscell(value)
    value=cellfun(@withoutAssessmentTimers,value,UniformOutput=false);
elseif istable(value)
    for name=string(value.Properties.VariableNames)
        value.(name)=withoutAssessmentTimers(value.(name));
    end
end
end
