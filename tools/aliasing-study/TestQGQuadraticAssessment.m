classdef TestQGQuadraticAssessment < matlab.unittest.TestCase
    properties
        source
        prepared
    end
    methods (TestClassSetup)
        function prepare(testCase)
            config=resolveStudyCase("cal-constant-17"); config.Nxy=[6 6]; config.waveCount=3;
            testCase.source=prepareSourceStudy(config);
            testCase.prepared=prepareQGQuadraticAssessment(testCase.source);
        end
    end
    methods (Test)
        function physicalOutputsKeepBothEndpointsAndExactZeros(testCase)
            p=testCase.prepared; r=assessQGQuadraticResolution(p);
            testCase.verifyEqual(r.status,"assessed")
            testCase.verifyEqual(unique(p.boundaries.endpoint),["bottom";"surface"])
            testCase.verifyEqual(unique(p.rows.output),["apv";"bottom";"bottomResidual";"surface";"surfaceResidual"])
            rows=p.rows; boundaryPV=ismember(rows.inputB,["surface","bottom"]) & rows.output=="apv";
            testCase.verifyTrue(all(rows.isZero(boundaryPV)))
            testCase.verifyEqual(rows.samplingError(boundaryPV),zeros(nnz(boundaryPV),1))
            testCase.verifyLessThan(max(rows.samplingError),1e-5)
            testCase.verifyLessThan(max(p.boundaries.endpointIdentityError),1e-12)
        end
        function signedEndpointResponsesAndLocalizedAnalyticalModesAgree(testCase)
            d=testCase.source; c=d.config;
            for p=find(d.inventory.magnitudes>0).'
                k=d.inventory.magnitudes(p); m=k*.01/abs(c.f); a=c.g*m/1e-4; transmission=exp(-m*c.Lz);
                coefficients=[-(a+1),(a-1)*transmission;-a*transmission,a]\eye(2);
                U=exp(m*d.zQ); V=exp(-m*(d.zQ+c.Lz));
                F=[U V]*coefficients; G=a*[-U V]*coefficients;
                testCase.verifyLessThan(norm(d.boundary{p}.Q.F-F,'fro')/norm(F,'fro'),1e-9)
                testCase.verifyLessThan(norm(d.boundary{p}.Q.G-G,'fro')/norm(G,'fro'),1e-9)
                fields=qgStudyFields(d,p,"Q");
                testCase.verifyEqual(fields.b(:,end-1:end),(c.f/c.g)*eye(2))
                testCase.verifyEqual(fields.apvEndpointResponse,-fields.b(:,1:c.apvCount)./fields.mu.')
            end
        end
        function underresolvedFixedBoundariesCannotHideBehindProducts(testCase)
            c=testCase.source.config; c.Lxy=[1e4 1e4]; c.Nz=17;
            p=prepareQGQuadraticAssessment(prepareSourceStudy(c)); r=assessQGQuadraticResolution(p);
            testCase.verifyTrue(r.sampledProductsAccepted)
            testCase.verifyFalse(r.fixedBoundariesAccepted)
            testCase.verifyEqual(r.status,"rejected")
            testCase.verifyGreaterThan(max(p.boundaries.gridError),.05)
        end
        function tinyEndpointOverlapUsesDeclaredAbsoluteReferenceBudget(testCase)
            c=testCase.source.config; c.Lxy=[1e4 1e4];
            d=prepareSourceStudy(c); p=prepareQGQuadraticAssessment(d);
            tiny=ismember(p.rows.output,["surface","bottom"]) & p.rows.usesAbsoluteReference;
            testCase.verifyGreaterThan(nnz(tiny),0)
            testCase.verifyLessThanOrEqual(max(p.rows.referenceFraction(tiny)),1)
            testCase.verifyGreaterThan(max(p.rows.relativeReferenceError(tiny)),c.referenceAllowance)
            d.config.referenceAbsoluteAllowance=0; strict=prepareQGQuadraticAssessment(d);
            testCase.verifyGreaterThan(max(strict.rows.referenceFraction),1)
            testCase.verifyEqual(assessQGQuadraticResolution(strict).status,"reference-inconclusive")
        end
        function preparationBudgetsAndReferenceAllowancesAreExplicit(testCase)
            d=testCase.source;
            testCase.verifyError(@()prepareQGQuadraticAssessment(d,productBudget=1),'WVStudy:ProductBudgetExceeded')
            testCase.verifyError(@()prepareQGQuadraticAssessment(d,workingMemoryBudget=1),'WVStudy:WorkingMemoryBudgetExceeded')
            testCase.verifyError(@()prepareQGQuadraticAssessment(d,interactionIndices=[1 1]),'WVStudy:InvalidInteractions')
            p=testCase.prepared; p.configuration.referenceAbsoluteAllowance=.01;
            testCase.verifyError(@()assessQGQuadraticResolution(p),'WVStudy:ReferenceAllowanceTooLarge')
        end
        function snapshotReuseAndMissingCoverageAreReported(testCase)
            p=testCase.prepared; copy=p; a=assessQGQuadraticResolution(p); b=assessQGQuadraticResolution(p,quadraticTolerance=.05);
            testCase.verifyEqual(a.rows,b.rows)
            testCase.verifyEqual(p,copy)
            testCase.verifyEqual(a.cost.additionalModeSolves,0)
            sparse=prepareQGQuadraticAssessment(testCase.source,interactionIndices=p.coverage.selectedInteractionIndices(1));
            r=assessQGQuadraticResolution(sparse);
            testCase.verifyFalse(r.completeOutputCoverage)
            testCase.verifyEqual(r.status,"inconclusive")
        end
        function materialReferenceErrorsAreInconclusive(testCase)
            d=testCase.source;
            for p=find(d.inventory.magnitudes>0).'
                d.boundary{p}.H.F=1.01*d.boundary{p}.H.F;
                d.boundary{p}.J.F=1.01*d.boundary{p}.J.F;
            end
            p=prepareQGQuadraticAssessment(d); r=assessQGQuadraticResolution(p);
            testCase.verifyGreaterThan(max(p.rows.referenceFraction),1)
            testCase.verifyEqual(r.status,"reference-inconclusive")
            testCase.verifyFalse(r.accepted)
        end
        function physicalVelocityScalingPreservesErrorsAndQuadraticLaw(testCase)
            a=assessQGAssembledTendency(testCase.source,velocityScale=.03);
            b=assessQGAssembledTendency(testCase.source,velocityScale=.003);
            testCase.verifyEqual(a.maximumVelocity,.03,RelTol=1e-12)
            testCase.verifyEqual(b.referenceEnergyNorm/a.referenceEnergyNorm,.01,RelTol=1e-11)
            testCase.verifyEqual(a.energyNormRelativeError,b.energyNormRelativeError,AbsTol=1e-12)
            testCase.verifyLessThan(a.energyNormRelativeError,1e-7)
            testCase.verifyLessThan(a.referenceFraction,1)
            testCase.verifyLessThan(a.cancellationRatio,.5)
            testCase.verifyLessThan(a.referenceWork.enstrophyWorkFraction,1e-12)
            testCase.verifyLessThan(max(a.referenceWork.endpointWorkOverTermBound),1e-12)
        end
        function collinearAndSingleEndpointStatesRespectPhysicalZeros(testCase)
            for kind=["collinear","surface","bottom","apv"]
                r=assessQGAssembledTendency(testCase.source,stateKind=kind);
                testCase.verifyEqual(r.meanSourceNorm,0)
                testCase.verifyLessThan(max(r.referenceWork.endpointWorkOverTermBound),1e-12)
                testCase.verifyLessThan(r.errorOverStateAdvectionScale,1e-7)
                if kind=="collinear"
                    testCase.verifyEqual(r.referenceEnergyNorm,0)
                else
                    testCase.verifyLessThan(r.energyNormRelativeError,1e-6)
                    testCase.verifyLessThan(r.referenceFraction,1)
                end
            end
        end
    end
end
