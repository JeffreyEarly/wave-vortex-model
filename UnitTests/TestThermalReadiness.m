classdef TestThermalReadiness < matlab.unittest.TestCase
    properties
        configuration
        scientificState
    end
    methods (TestClassSetup)
        function smallQualifiedControl(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
            testCase.configuration=struct(Nx=18,Ny=18,Nz=65,thermalCount=17,mdaCount=4,assemblyCount=0,productCount=0,inverseScale=0,domainSize=[5e5 5e5 1000],N0=.01,kind="developed");
            w=thermalReadinessCase(testCase.configuration);
            testCase.scientificState=w.scientificState;
            delete(w);
        end
    end
    methods (Test,TestTags="full")
        function coldSeedHasAnalyticRMSAndUnambiguousClock(testCase)
            c=testCase.configuration; c.kind="cold"; c.t=123; c.t0=45; c.phase=pi/2;
            [w,manifest]=thermalReadinessCase(c,scientificState=testCase.scientificState);
            fields=w.reconstructFields(["qgpv","endpointAnomalies"]);
            testCase.verifyEqual(sqrt(mean(fields.endpointAnomalies(:,:,1).^2,'all')),.01,AbsTol=1e-9);
            testCase.verifyLessThan(max(abs(fields.endpointAnomalies(:,:,2)),[],'all'),1e-9);
            testCase.verifyLessThan(manifest.initialFit.qgpvRMS,1e-12);
            testCase.verifyEqual(w.Amda,zeros(size(w.Amda)));
            testCase.verifyEqual([w.t w.t0],[123 45]);
            testCase.verifyEqual(manifest.seasonalArgument,2*pi*123/manifest.configuration.period+pi/2);
            testCase.verifyEqual(manifest.normalization.factor,.01/sqrt((1+.49+.09)/2));
            testCase.verifyEqual(sum(arrayfun(@(f)isa(f,'WVNonlinearAdvection'),w.forcing)),1);
            testCase.verifyEqual(sum(arrayfun(@(f)isa(f,'WVSeasonalSurfaceAnomalyForcing'),w.forcing)),1);
            testCase.verifyEqual(sum(arrayfun(@(f)isa(f,'WVBottomFrictionQuadratic'),w.forcing)),1);
        end
        function developedStateNormalizesOnceAndTransfersPhysicalState(testCase)
            [source,manifest]=thermalReadinessCase(testCase.configuration,scientificState=testCase.scientificState);
            testCase.verifyEqual(physicalVelocityRMS(source),.01,RelTol=2e-9);
            testCase.verifyEqual(source.Amda,.1*[1;-2;3;-1]);
            testCase.verifyEqual(manifest.normalization.quadratureCount,513);
            before=source.coefficientState();
            c=testCase.configuration; c.velocityRMS=.4; c.shouldIncludeAdvection=false;
            [target,transferred]=thermalReadinessCase(c,scientificState=testCase.scientificState,source=source);
            testCase.verifyEqual(source.coefficientState(),before);
            testCase.verifyEqual(target.coefficientState(),before);
            testCase.verifyEqual(transferred.initialFit.method,"identical scientific arrays; exact canonical copy");
            testCase.verifyEqual(physicalVelocityRMS(target),.01,RelTol=2e-8);
            testCase.verifyTrue(isnan(transferred.normalization.factor));
            testCase.verifyLessThan(transferred.initialFit.relativeFieldError,1e-8);
            testCase.verifyNotEmpty(transferred.sourceStateHash);
            testCase.verifyFalse(any(arrayfun(@(f)isa(f,'WVNonlinearAdvection'),target.forcing)));
            testCase.verifyEqual(numel(target.forcing),2);
        end
        function canonicalCaseRestoresWithoutProviderAndRejectsChanges(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file=fullfile(folder.Folder,'case.mat');
            [original,manifest]=thermalReadinessCase(testCase.configuration,scientificState=testCase.scientificState,cacheFile=file);
            originalPath=path; cleanup=onCleanup(@()path(originalPath));
            providerRoot=string(fileparts(fileparts(which('IMInternalModes'))));
            paths=string(strsplit(path,pathsep)); selected=startsWith(paths,providerRoot+filesep) | paths==providerRoot;
            rmpath(char(join(paths(selected),pathsep)));
            testCase.assertEmpty(which('IMInternalModes'));
            [restored,restoredManifest]=thermalReadinessCase(testCase.configuration,cacheFile=file);
            testCase.verifyEqual(restored.coefficientState(),original.coefficientState());
            testCase.verifyEqual(restoredManifest,manifest);
            testCase.verifyEmpty(fieldnames(restored.constructionAssessment));
            changed=testCase.configuration; changed.velocityRMS=.02;
            testCase.verifyError(@()thermalReadinessCase(changed,cacheFile=file),'WV:ReadinessCacheIdentity');
            cache=load(file); cache.coefficientState.Amda(1)=cache.coefficientState.Amda(1)+1;
            save(file,'-struct','cache');
            testCase.verifyError(@()thermalReadinessCase(testCase.configuration,cacheFile=file),'WV:ReadinessCacheIdentity');
        end
        function zeroBudgetLeavesAllGatesUnrunAndDoesNotConstruct(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            output=fullfile(folder.Folder,'unrun');
            report=qualifyThermalReadiness(output,wallTimeBudgetSeconds=0);
            testCase.verifyEqual(report.readiness,"CONDITIONAL");
            testCase.verifyEqual(report.cases.status,"NOT RUN");
            testCase.verifyTrue(all(report.coverage.status=="NOT RUN"));
            testCase.verifyFalse(isfile(fullfile(output,'candidate','initial-case.mat')));
            testCase.verifyError(@()qualifyThermalReadiness(output,wallTimeBudgetSeconds=0),'WV:ReadinessRunExists');
        end
        function boundedLinearComparisonRequiresIndependentReference(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            c=testCase.configuration; c.shouldIncludeAdvection=false;
            cases=repmat(struct(name="coarse",configuration=c,step=.5,scientificState=testCase.scientificState),1,2);
            cases(2).name="fine"; cases(2).step=.25;
            report=qualifyThermalReadiness(fullfile(folder.Folder,'window'),cases,durationSeconds=2,observationOffsets=0:.5:2,pairs=struct(candidate="coarse",reference="fine",axis="time"),comparisonCount=65,wallTimeBudgetSeconds=120);
            testCase.assertEqual(report.cases.status,["COMPLETE";"COMPLETE"],join(report.cases.reason,newline));
            testCase.verifyEqual(report.initialPreparation.status,["PREPARED";"PREPARED"]);
            testCase.verifyEqual(height(report.initialComparisons),18);
            testCase.verifyTrue(all(report.initialComparisons.status=="PASS"));
            testCase.verifyEqual(report.initialComparisons.effectiveAllowance,.1*report.initialComparisons.allowance);
            testCase.verifyLessThanOrEqual(report.initialComparisons.quadratureUncertainty,.2*report.initialComparisons.effectiveAllowance);
            testCase.verifyGreaterThan(report.cases.acceptedSteps(2),report.cases.acceptedSteps(1));
            testCase.verifyEqual(report.cases.finalTime,[2;2]);
            testCase.verifyEqual(numel(unique(report.cases.executionId)),2);
            testCase.verifyEqual(report.executions.executionId,report.cases.executionId);
            testCase.verifyTrue(all(strlength(report.cases.initialCaseId)>0));
            testCase.verifyEqual(height(report.comparisons),45);
            testCase.verifyTrue(all(report.comparisons.status=="INCONCLUSIVE"));
            testCase.verifyTrue(all(isnan(report.comparisons.referenceError)));
            testCase.verifyEqual(report.readiness,"CONDITIONAL");
            testCase.verifyEqual(report.coverage.status(report.coverage.axis=="restart"),"NOT RUN");
            testCase.verifyEqual(height(report.budgets),8);
            testCase.verifyEqual(height(report.processWork),24);
            testCase.verifyTrue(any(report.processWork.process=="density diffusion"));
            testCase.verifyTrue(all(isfinite(report.processWork.integratedWork)));
        end
        function initialRepresentationFailureStopsBeforeTrajectory(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            output=fullfile(folder.Folder,'initial-failure');
            c=testCase.configuration; c.shouldIncludeAdvection=false;
            source=thermalReadinessCase(c,scientificState=testCase.scientificState);
            sourceCleanup=onCleanup(@()delete(source));
            cacheFile=fullfile(output,'fine','initial-case.mat');
            target=thermalReadinessCase(c,scientificState=testCase.scientificState,source=source,cacheFile=cacheFile);
            delete(target);
            % Keep the cache internally valid while manufacturing a wrong
            % physical initial representation. Identity alone cannot catch it.
            cache=load(cacheFile);
            cache.coefficientState.Ath=2*cache.coefficientState.Ath;
            cache.manifest.coefficientStateHash=thermalReadinessIdentity(cache.coefficientState);
            cache.manifest.caseId=thermalReadinessIdentity(rmfield(cache.manifest,'caseId'));
            save(cacheFile,'-struct','cache');
            clear sourceCleanup source
            cases=repmat(struct(name="coarse",configuration=c,step=.5,scientificState=testCase.scientificState),1,2);
            cases(2).name="fine"; cases(2).step=.25;
            report=qualifyThermalReadiness(output,cases,durationSeconds=1,pairs=struct(candidate="coarse",reference="fine",axis="time"),comparisonCount=65,wallTimeBudgetSeconds=120);
            testCase.verifyEqual(report.cases.status,["NOT RUN";"FAILED"]);
            testCase.verifySubstring(report.cases.reason(2),"WV:ReadinessInitialRepresentation");
            testCase.verifyTrue(all(strlength(report.cases.initialCaseId)>0));
            testCase.verifyTrue(any(report.initialComparisons.status=="FAIL"));
            testCase.verifyEqual(report.cases.acceptedSteps,[0;0]);
            testCase.verifyFalse(isfile(fullfile(output,'observations.csv')));
            testCase.verifyFalse(isfile(fullfile(output,'coarse','window.mat')));
            testCase.verifyFalse(isfile(fullfile(output,'fine','integration-contract.json')));
        end
        function heldOperatorChangesAreRejectedBeforeTimeOrProductRuns(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            c=testCase.configuration; c.shouldIncludeAdvection=false;
            for axis=["time","product sampling"]
                cases=repmat(struct(name="coarse",configuration=c,step=.5,scientificState=testCase.scientificState,sharedInitialState=false),1,2);
                cases(2).name="fine";
                pair=struct(candidate="coarse",reference="fine",axis=axis);
                if axis=="time"
                    cases(2).step=.25;
                else
                    % Changing only the product count and its qualification
                    % residuals must pass the first edge. A changed diffusion
                    % operator on the next edge must invalidate the whole pair.
                    cases(3)=cases(2); cases(3).name="reference";
                    baseCount=testCase.scientificState.nonlinearQuadratureCount;
                    for j=1:3
                        count=2^(j-1)*baseCount;
                        cases(j).configuration.productCount=count;
                        cases(j).scientificState.nonlinearQuadratureCount=count;
                        cases(j).scientificState.nonlinearQuadratureResidual=0;
                        cases(j).scientificState.nonlinearReferenceResidual=0;
                    end
                    pair.refinement="reference";
                end
                cases(end).scientificState.thermalRatesPerDiffusivity=2*cases(end).scientificState.thermalRatesPerDiffusivity;
                output=fullfile(folder.Folder,replace(axis," ","-"));
                report=qualifyThermalReadiness(output,cases,durationSeconds=1,pairs=pair,comparisonCount=65,wallTimeBudgetSeconds=120);
                testCase.assertEqual(report.cases.status,repmat("FAILED",numel(cases),1),join(report.cases.reason,newline));
                testCase.verifyTrue(all(contains(report.cases.reason,"WV:ReadinessHeldScientificState")));
                testCase.verifyEqual(report.cases.acceptedSteps,zeros(numel(cases),1));
                testCase.verifyFalse(isfile(fullfile(output,'observations.csv')));
                if axis=="product sampling"
                    measured=report.initialComparisons(report.initialComparisons.axis==axis,:);
                    testCase.verifyEqual(height(measured),9);
                    testCase.verifyTrue(all(measured.status=="PASS"));
                end
            end
        end
        function constructionFailureIsRecordedWithoutSubstitution(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            c=testCase.configuration; c.thermalCount=c.thermalCount+1;
            cases=struct(name="mismatched-cache",configuration=c,scientificState=testCase.scientificState);
            report=qualifyThermalReadiness(fullfile(folder.Folder,'failed'),cases,durationSeconds=1,wallTimeBudgetSeconds=30);
            testCase.verifyEqual(report.readiness,"NOT READY");
            testCase.verifyEqual(report.cases.status,"FAILED");
            testCase.verifySubstring(report.cases.reason,"WV:ReadinessScientificState");
            testCase.verifyTrue(all(report.coverage.status=="NOT RUN"));
        end
        function identitiesPreserveCanonicalTypesAndIgnoreFieldOrder(testCase)
            a=struct(z=complex([1 2],[3 4]),a=uint64(intmax('uint64')));
            b=struct(a=a.a,z=a.z);
            testCase.verifyEqual(thermalReadinessIdentity(a),thermalReadinessIdentity(b));
            b.a=b.a-uint64(1);
            testCase.verifyNotEqual(thermalReadinessIdentity(a),thermalReadinessIdentity(b));
            b=a; b.z=single(b.z);
            testCase.verifyNotEqual(thermalReadinessIdentity(a),thermalReadinessIdentity(b));
            testCase.verifyError(@()thermalReadinessIdentity(@sin),'WV:ReadinessIdentityType');
        end
    end
end
function value=physicalVelocityRMS(w)
[x,weights]=legpts(513); z=(x-1)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
C=complex(zeros(w.thermalModeCount,numel(w.klNonzero)));
for page=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==page; C(:,columns)=w.thermalToPolynomial(:,:,page)*w.Ath(:,columns);
end
value=sqrt(sum(weights(:).*abs(r.psi*C).^2.*hypot(w.k(w.klNonzero),w.l(w.klNonzero)).'.^2,'all'));
end
