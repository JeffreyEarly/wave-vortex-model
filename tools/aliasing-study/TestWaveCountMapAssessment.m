classdef TestWaveCountMapAssessment < matlab.unittest.TestCase
    properties
        data
        prepared
        covered
    end
    methods (TestClassSetup)
        function prepare(testCase)
            testCase.data=prepareSourceStudy(resolveStudyCase("cal-constant-17"));
            testCase.prepared=WVInternal.prepareWaveQuadraticAssessment(testCase.data);
            testCase.covered=WVInternal.prepareWaveQuadraticAssessment(testCase.data,ensureOutputCoverage=true);
        end
    end
    methods (Test)
        function unmeasuredConstructionPrefixRemainsInconclusive(testCase)
            sourceData=testCase.data;
            sourceData.config.constructionPolicy=true; sourceData.config.selectInertial=true;
            snapshot=WVInternal.prepareWaveQuadraticAssessment(sourceData,ensureOutputCoverage=true);
            report=WVInternal.assessWaveCountMap(snapshot,waveModeCount=3);
            testCase.verifyFalse(report.requestedCountAccepted)
            testCase.verifyEqual(report.status,"inconclusive")
            testCase.verifyNotEmpty(report.coverage.unmeasuredOutputPrefixKappa)
        end

        function absoluteReferenceBudgetMustBeSmallRelativeToSamplingTolerance(testCase)
            p=testCase.covered; p.configuration.referenceAllowance=1e-14;
            p.configuration.referenceAbsoluteAllowance=1e-10;
            testCase.verifyError(@()assessWaveQuadraticResolution(p,quadraticTolerance=1e-12),'WVStudy:ReferenceAllowanceTooLarge')
            sourceData=testCase.data; sourceData.config.referenceAllowance=1e-14;
            sourceData.config.referenceAbsoluteAllowance=1e-10;
            testCase.verifyError(@()assessWaveQuadraticResolution(sourceData,quadraticTolerance=1e-12),'WVStudy:ReferenceAllowanceTooLarge')
        end

        function uniformMapsPreserveHistoricalProductErrors(testCase)
            old=assessWaveQuadraticResolution(testCase.data);
            p=testCase.prepared;
            for n=1:p.configuration.waveCount
                r=assessWaveQuadraticResolution(p,waveModeCount=n);
                testCase.verifyEqual(max(r.pages.quadraticError),old.prefixDiagnostics.quadraticError(n),AbsTol=1e-7)
                testCase.verifyEqual(sum(r.pages.nonzeroProductCount),old.prefixDiagnostics.nonzeroProductCount(n))
            end
            r=assessWaveQuadraticResolution(p,waveModeCount=3);
            testCase.verifyEqual(r.status,"inconclusive")
            testCase.verifyNotEmpty(r.coverage.missingOutputKappa)
            r=assessWaveQuadraticResolution(testCase.covered,waveModeCount=3);
            testCase.verifyEqual(r.status,"assessed")
            testCase.verifyTrue(r.requestedCountAccepted)
            testCase.verifyEmpty(r.coverage.missingOutputKappa)
        end

        function mapsPreservePhysicalKeysAndZeroPages(testCase)
            p=testCase.covered; k=p.inventory.magnitudes; k=k(k>0); counts=mod((1:numel(k)).',4);
            r=assessWaveQuadraticResolution(p,waveModeKappa=[flipud(k);k(1)],waveModeCount=[flipud(counts);counts(1)]);
            testCase.verifyEqual(r.pages.requestedWaveCount,[0;counts])
            zero=r.pages.kappa>0 & r.pages.requestedWaveCount==0;
            testCase.verifyEqual(r.pages.status(zero),"not-requested")
            testCase.verifyEqual(r.pages.testedProductCount(zero),0)
            testCase.verifyEqual(r.fixedFamilyCounts,p.fixedFamilyCounts)
            for j=find(~cellfun(@isempty,r.pages.limitingInteraction)).'
                record=r.pages.limitingInteraction{j};
                testCase.verifyEqual(sum(record.integerWavevectors(1:2,:),1),record.integerWavevectors(3,:))
                for input=1:2
                    if record.inputFamilies(input)=="wave"
                        kInput=norm(record.physicalWavevectors(input,:));
                        [~,page]=min(abs(p.inventory.magnitudes-kInput));
                        ordinal=find(p.waveLabels{page}==record.inputModeLabels(input));
                        testCase.verifyLessThanOrEqual(ordinal,r.pages.requestedWaveCount(page))
                        testCase.verifyTrue(ismember(record.inputFrequencySigns(input),[-1 1]))
                    end
                end
            end
        end

        function storedErrorsMatchDirectUnequalPrefixProjection(testCase)
            p=testCase.covered; products=p.products;
            % Select unequal input and output ordinals. Compute this physical
            % u*d_x(u) product directly, with a separately prepared projection.
            rows=find(p.rows.inputA=="wave" & p.rows.inputB=="wave" & p.rows.output=="wave" & p.rows.channel=="u*dx(u)");
            selected=find(ismember(products.row,rows) & products.positionA==1 & products.positionB==2 & ~products.isZero,1);
            testCase.assertNotEmpty(selected)
            row=p.rows(products.row(selected),:); triad=p.inventory.interactions(row.interaction,:);
            integers=reshape(table2array(triad(1,1:6)),2,3).';
            [~,v]=ismember(integers,p.inventory.vectors,'rows');
            a=WVInternal.sourceStudyFields(testCase.data,"wave",v(1)); b=WVInternal.sourceStudyFields(testCase.data,"wave",v(2));
            ia=find(a.positions==products.positionA(selected) & a.signs==products.signA(selected));
            ib=find(b.positions==products.positionB(selected) & b.signs==products.signB(selected));
            sample=-a.S.u(:,ia).*(1i*p.inventory.physicalVectors(v(2),1)*b.S.u(:,ib));
            reference=-a.Q.u(:,ia).*(1i*p.inventory.physicalVectors(v(2),1)*b.Q.u(:,ib));
            context=WVInternal.sourceProjectionContext(testCase.data,v(3),"u","Q");
            direct=WVInternal.measureProductProjection(context,sample,reference,zeros(2,1),6);
            testCase.verifyEqual(double(products.error(3,selected)),direct.error,RelTol=1e-6,AbsTol=1e-12)
            testCase.verifyEqual(sort(unique(products.signA(products.waveA))),[-1 1])
        end

        function emptyWaveFamilyRetainsMeanAndBoundaryInputChecks(testCase)
            r=assessWaveQuadraticResolution(testCase.covered,waveModeCount=0);
            testCase.verifyEqual(r.pages.status(r.pages.kappa>0),repmat("not-requested",height(r.pages)-1,1))
            testCase.verifyGreaterThan(r.pages.testedProductCount(1),0)
            testCase.verifyEqual(r.fixedFamilyCounts.boundary,2)
            testCase.verifyEqual(r.fixedFamilyCounts.inertial,3)
            testCase.verifyEqual(r.cost.newEigensolves,0)
            testCase.verifyEqual(r.cost.newProductEvaluations,0)
        end

        function badReferencesAndFixedFamiliesDoNotPass(testCase)
            p=testCase.covered;
            p.referenceDiagnostics.referencesStable=false;
            r=assessWaveQuadraticResolution(p,waveModeCount=3);
            testCase.verifyEqual(r.status,"reference-inconclusive")
            testCase.verifyFalse(r.requestedCountAccepted)
            p=testCase.covered; p.referenceDiagnostics.fixedFamiliesGramAccepted=false;
            r=assessWaveQuadraticResolution(p,waveModeCount=0);
            testCase.verifyEqual(r.status,"rejected")
            r=assessWaveQuadraticResolution(testCase.covered,waveModeCount=4);
            testCase.verifyEqual(r.status,"rejected")
            testCase.verifyTrue(any(r.pages.gramError>r.gramTolerance))
        end

        function invalidRequestsFailBeforeAssessment(testCase)
            p=testCase.prepared; k=p.inventory.magnitudes; k=k(k>0);
            testCase.verifyError(@()assessWaveQuadraticResolution(p,waveModeCount=[1;2]),'WVStudy:InvalidWaveCountMap')
            testCase.verifyError(@()assessWaveQuadraticResolution(p,waveModeKappa=[k;k(1)],waveModeCount=[ones(size(k));2]),'WVStudy:InvalidWaveCountMap')
            testCase.verifyError(@()assessWaveQuadraticResolution(p,waveModeKappa=k(2:end),waveModeCount=2),'WVStudy:InvalidWaveCountMap')
            testCase.verifyError(@()assessWaveQuadraticResolution(p,waveModeKappa=2*k,waveModeCount=2),'WVStudy:InvalidWaveCountMap')
            testCase.verifyError(@()assessWaveQuadraticResolution(p,waveModeCount=9),'WVStudy:InvalidWaveCountMap')
            testCase.verifyError(@()assessWaveQuadraticResolution(p,requestedWaveCount=3),'WVStudy:InvalidWaveCountMap')
            testCase.verifyError(@()assessWaveQuadraticResolution(testCase.data,waveModeCount=3),'WVStudy:InvalidPreparation')
            testCase.verifyError(@()assessWaveQuadraticResolution(p,quadraticTolerance=.001),'WVStudy:ReferenceAllowanceTooLarge')
        end

        function budgetsPrecedeProductPreparation(testCase)
            data=testCase.data; data.wave={};
            testCase.verifyError(@()WVInternal.prepareWaveQuadraticAssessment(data,productBudget=1),'WVStudy:ProductBudgetExceeded')
            testCase.verifyError(@()WVInternal.prepareWaveQuadraticAssessment(data,workingMemoryBudget=1),'WVStudy:WorkingMemoryBudgetExceeded')
            testCase.verifyError(@()WVInternal.prepareWaveQuadraticAssessment(data,interactionIndices=[1 1]),'WVStudy:InvalidInteractions')
        end

        function smallDenseControlContainsSparseEvidence(testCase)
            config=resolveStudyCase("cal-constant-17"); config.Nxy=[6 6];
            data=prepareSourceStudy(config);
            sparse=WVInternal.prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true);
            dense=WVInternal.prepareWaveQuadraticAssessment(data,policy="dense");
            testCase.verifyTrue(any(dense.products.waveOut))
            for count=[3 8]
                a=assessWaveQuadraticResolution(sparse,waveModeCount=count);
                b=assessWaveQuadraticResolution(dense,waveModeCount=count);
                tested=~isnan(a.pages.quadraticError);
                testCase.verifyLessThanOrEqual(a.pages.quadraticError(tested),b.pages.quadraticError(tested)+1e-7)
                testCase.verifyEqual(a.status,b.status)
                testCase.verifyLessThanOrEqual(a.cost.selectedProducts,b.cost.selectedProducts)
            end
        end

        function changedGridRequiresFreshEvidence(testCase)
            config=testCase.data.config; config.Nz=25;
            data=prepareSourceStudy(config);
            fresh=WVInternal.prepareWaveQuadraticAssessment(data);
            a=assessWaveQuadraticResolution(testCase.prepared,waveModeCount=3);
            b=assessWaveQuadraticResolution(fresh,waveModeCount=3);
            testCase.verifySize(a.physicalGrid.z,[17 1])
            testCase.verifySize(b.physicalGrid.z,[25 1])
            testCase.verifyEqual(a.configuration.Nz,17)
            testCase.verifyEqual(b.configuration.Nz,25)
            testCase.verifyLessThan(max(b.pages.gramError),max(a.pages.gramError))
            testCase.verifyGreaterThan(fresh.cost.projectionCount,0)
        end

        function evidenceSnapshotNeedsNoLivePreparation(testCase)
            original=testCase.prepared;
            % Runtime reporting accepts only numeric/table evidence; it has
            % no source-study/profile/solver argument to become stale.
            a=assessWaveQuadraticResolution(original,waveModeCount=2);
            b=assessWaveQuadraticResolution(original,waveModeCount=3);
            again=assessWaveQuadraticResolution(original,waveModeCount=2);
            testCase.verifyEqual(a.pages,again.pages)
            testCase.verifyEqual(original,testCase.prepared)
            testCase.verifyNotEqual(a.pages.requestedWaveCount,b.pages.requestedWaveCount)
            testCase.verifyFalse(isfield(original,'wave'))
            testCase.verifyTrue(a.cost.reusedPreparation)
        end
    end
end
