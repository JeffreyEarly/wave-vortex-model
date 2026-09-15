classdef TestThermalReadinessWindows < matlab.unittest.TestCase
    properties
        scientificState
        initial
        manifest
    end
    methods (TestClassSetup)
        function manufacturedWindowState(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
            c=struct(Nx=8,Ny=8,Nz=65,thermalCount=17,mdaCount=4,inverseScale=0,domainSize=[5e5 5e5 1000],N0=.01,shouldIncludeSeasonal=false,shouldIncludeBottomDrag=false);
            [w,testCase.manifest]=thermalReadinessCase(c);
            testCase.scientificState=w.scientificState; testCase.initial=w.coefficientState();
        end
    end
    methods (Test,TestTags="full")
        function closureScreenRetainsOppositelySignedWork(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            [a,b]=savePair(folder.Folder,testCase,"closure bias",1.01);
            r=compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'screen'),kind="closure bias",comparisonCount=65);
            testCase.verifyEqual(r.status,"WITHIN BIAS SCREEN");
            work=r.processWork(r.processWork.role=="candidate" & r.processWork.inventory=="totalEnergy",:);
            testCase.verifyEqual(work.signedIntegratedWork,[-.5;1]);
            testCase.verifyEqual(work.positiveIntegratedWork,[0;1]);
            testCase.verifyEqual(work.negativeIntegratedWork,[-.5;0]);
            testCase.verifyEqual(work.samplingUncertainty,[0;0]);
            testCase.verifyTrue(all(r.comparisons.relativeAllowance==.05));
            testCase.verifyEqual(r.candidateInitialCaseId,r.referenceInitialCaseId);
            testCase.verifyNotEqual(r.candidateExecutionId,r.referenceExecutionId);
            testCase.verifyError(@()compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'screen'),kind="closure bias"),'WV:ReadinessWindowOutput');
        end
        function activityUsesFiveCompleteSpatialAllowances(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            [a,b]=savePair(folder.Folder,testCase,"nonlinear activity",2);
            r=compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'activity'),kind="nonlinear activity",comparisonCount=65);
            testCase.verifyEqual(r.status,"MEASURABLE NONLINEAR ACTIVITY");
            testCase.verifyEqual(r.activity.activityThreshold,5*(r.activity.absoluteFloor+.01*r.activity.referenceNorm));
            testCase.verifyTrue(all(r.activity.status(r.activity.time==0)=="NOT MEASURABLE AT THIS TIME"));
            testCase.verifyTrue(any(r.activity.status(r.activity.time==2)=="MEASURABLE"));
            candidate=r.regime(r.regime.role=="candidate" & r.regime.time==2,:);
            reference=r.regime(r.regime.role=="reference" & r.regime.time==2,:);
            names={'maximumEtaOverDepth','maximumInteriorEtaOverDepth','maximumVorticityOverF','maximumSurfaceSlope'};
            testCase.verifyGreaterThan(reference{1,names},zeros(1,4));
            testCase.verifyEqual(candidate{1,names},2*reference{1,names},RelTol=2e-12);
        end
        function largeBiasAndUnmatchedMechanismsStayVisible(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            [a,b]=savePair(folder.Folder,testCase,"closure bias",2);
            r=compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'bias'),kind="closure bias",comparisonCount=65);
            testCase.verifyEqual(r.status,"EXCEEDS BIAS SCREEN");
            testCase.verifyError(@()compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'wrong-kind'),kind="nonlinear activity"),'WV:ReadinessWindowPair');
            saved=load(a,'run'); run=saved.run; run.executionId="changed"; save(a,'run');
            testCase.verifyError(@()compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'changed-execution'),kind="closure bias"),'WV:ReadinessWindowIdentity');
            run=saved.run; run.snapshots{1}.state.Amda(1)=run.snapshots{1}.state.Amda(1)+1; save(a,'run');
            testCase.verifyError(@()compareThermalReadinessWindows(a,b,fullfile(folder.Folder,'changed-initial'),kind="closure bias"),'WV:ReadinessWindowIdentity');
        end
    end
end

function [a,b]=savePair(folder,testCase,kind,scale)
% These are deliberately manufactured records: test reporting arithmetic,
% not a physical integration or scientific accuracy claim.
names=["candidate","reference"]; runs=cell(1,2);
prototype=struct(name="",configuration=struct(),step=.5,adaptive=false,relTolerance=1e-6,physicalAbsTolerance=[1e-13 1e-11 1e-8 1e-8 1e-9],dampingVariant="none");
cases=repmat(prototype,1,2);
for j=1:2
    manifest=testCase.manifest; variant="none";
    if kind=="closure bias" && j==1, variant="apv"; end
    if kind=="nonlinear activity" && j==2, manifest.configuration.shouldIncludeAdvection=false; end
    manifest=rmfield(manifest,'caseId'); manifest.caseId=thermalReadinessIdentity(manifest);
    snapshots=cell(1,3);
    labels="density diffusion"; rate=0;
    if variant=="apv", labels=["horizontal damping","vertical damping"]; rate=[-.25;.5]; end
    for k=1:3
        state=testCase.initial;
        if j==1 && k>1, state.Ath=scale*state.Ath; state.Amda=scale*state.Amda; end
        inventory=struct();
        for name=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
            inventory.(name+"Tendency")=rate;
        end
        snapshots{k}=struct(t=k-1,state=state,inventory=inventory,processLabels=labels);
    end
    runs{j}=struct(manifest=manifest,scientificState=testCase.scientificState,snapshots={snapshots},dampingVariant=variant);
    cases(j).name=names(j); cases(j).configuration=manifest.configuration; cases(j).dampingVariant=variant;
end
contract=struct(schema="thermal-readiness-window-v2",cases=cases,options=struct(canonicalDamping=struct())); contract.runId=thermalReadinessIdentity(contract);
save(fullfile(folder,'run-contract.mat'),'contract');
for j=1:2
    run=runs{j}; run.runId=contract.runId; run.initialCaseId=run.manifest.caseId;
    run.executionId=thermalReadinessIdentity(struct(runId=contract.runId,caseName=names(j)));
    caseFolder=fullfile(folder,names(j)); mkdir(caseFolder); save(fullfile(caseFolder,'window.mat'),'run');
end
a=fullfile(folder,'candidate','window.mat'); b=fullfile(folder,'reference','window.mat');
end
