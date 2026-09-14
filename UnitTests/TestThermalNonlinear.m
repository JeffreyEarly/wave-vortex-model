classdef TestThermalNonlinear < matlab.unittest.TestCase
    properties
        constantState
        exponentialState
    end
    methods (TestClassSetup)
        function setup(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            w=construct(0); testCase.constantState=w.scientificState;
            w=construct(1/1300); testCase.exponentialState=w.scientificState;
        end
    end
    methods (Test, TestTags="full")
        function nonparallelInteractionsAndQuadrature(testCase)
            for s={testCase.constantState,testCase.exponentialState}
                w=WVTransformFreeSurfaceThermalQG(scientificState=s{1});
                for degrees={[2 3 4],[2 16 9]}
                    w.Ath(:)=0; modes=thermalManufacturedState(w,degrees{1},1000);
                    [actual,~,diagnostics]=w.nonlinearCoefficientTendency();
                    ref=thermalConvolutionReference(w,modes,1025);
                    fine=thermalConvolutionReference(w,modes,2049);
                    e=w.linearEvolutionData();
                    scale=e.physicalErrorNorms(e.toModes(fine));
                    allowance=[1e-22 1e-19 1e-19 1e-15 1e-15]+1e-8*scale;
                    error=e.physicalErrorNorms(e.toModes(subtract(actual,fine)));
                    control=e.physicalErrorNorms(e.toModes(subtract(ref,fine)));
                    testCase.verifyLessThanOrEqual(max(error./allowance),1);
                    testCase.verifyLessThanOrEqual(max(control./allowance),.2);
                    testCase.verifyGreaterThan(norm(actual.Ath,'fro'),1e-12);
                    testCase.verifyEqual(actual.Amda,zeros(size(w.Amda)));
                    testCase.verifyLessThan(diagnostics.qMean,max(diagnostics.qSourceMaximum,realmin)*1e-12);
                    testCase.verifyTrue(all(isfinite(actual.Ath),'all'));
                    before=w.coefficientState(); w.Amda=[.1;-.2;.3;-.1];
                    withMean=w.nonlinearCoefficientTendency(); testCase.verifyEqual(withMean,actual);
                    w.Amda=before.Amda;
                end
            end
        end
        function retainedCutoffInteractions(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.exponentialState);
            modes=thermalManufacturedState(w,[2 16 9],1000,[3 0;0 3;2 2]);
            actual=w.nonlinearCoefficientTendency(); ref=thermalConvolutionReference(w,modes,2049);
            e=w.linearEvolutionData(); scale=e.physicalErrorNorms(e.toModes(ref));
            delta=e.physicalErrorNorms(e.toModes(subtract(actual,ref)));
            testCase.verifyLessThan(max(delta./([1e-22 1e-19 1e-19 1e-15 1e-15]+1e-8*scale)),1);
        end
        function nullControlsAndCacheMutation(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.constantState);
            w.Ath(3,1)=.01+.02i;
            testCase.verifyLessThan(norm(w.nonlinearCoefficientTendency().Ath,'fro'),1e-20);
            w.Ath(:)=0; thermalManufacturedState(w,[2 3 4],1000);
            first=w.nonlinearCoefficientTendency(); w.Ath=2*w.Ath;
            second=w.nonlinearCoefficientTendency(); testCase.verifyEqual(second.Ath,4*first.Ath,AbsTol=1e-20);
            w.t=10; testCase.verifyEqual(w.nonlinearCoefficientTendency(),second);
        end
        function policyAndLinearCompatibility(testCase)
            s=testCase.constantState; s.shouldCheckQuadraticAliasing=false; s.nonlinearQuadratureCount=0;
            w=WVTransformFreeSurfaceThermalQG(scientificState=s);
            testCase.verifyError(@()w.addForcing(WVNonlinearAdvection(w)),'WV:ThermalNonlinearQualification');
            s=testCase.constantState; s.nonlinearQuadratureResidual=1;
            testCase.verifyError(@()WVTransformFreeSurfaceThermalQG(scientificState=s),'WV:ThermalStoredState');
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.constantState);
            w.addForcing(WVNonlinearAdvection(w)); m=WVModel(w);
            testCase.verifyError(@()m.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true),'WV:ThermalLinearConflict');
            m.setupIntegrator(integratorType="exponential");
            w.removeAllForcing();
            testCase.verifyError(@()m.integrateToTime(1,shouldShowIntegrationDiagnostics=false),'WV:ThermalLinearConflict');
        end
        function nonlinearLifecycleAndSeasonalCompatibility(testCase)
            models=cell(1,2);
            for i=1:2
                w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.constantState);
                thermalManufacturedState(w,[2 3 4],10000); w.addForcing(WVNonlinearAdvection(w));
                model=ThermalObservationModel(w); intervals=[777 1333]; model.sampleInterval=intervals(i);
                model.setupIntegrator(integratorType="exponential",initialStep=20000,maximumStep=20000,relTolerance=1e-10,physicalAbsTolerance=1e-25*ones(1,5));
                model.integrateToTime(20000,shouldShowIntegrationDiagnostics=false); models{i}=model;
            end
            testCase.verifyEqual(models{1}.exponentialStatistics.acceptedStepSeconds,models{2}.exponentialStatistics.acceptedStepSeconds);
            testCase.verifyEqual(models{1}.wvt.Ath,models{2}.wvt.Ath);
            testCase.verifyGreaterThan(models{1}.exponentialStatistics.rejectedSteps,0);
            model=models{1}; w=model.wvt; before=w.coefficientState(); time=w.t;
            failure=ThermalStageForcing(w); failure.rate=0; failure.failureTime=time; w.addForcing(failure);
            testCase.verifyError(@()model.integrateToTime(time+100,shouldShowIntegrationDiagnostics=false),'ThermalStageForcing:Failure');
            testCase.verifyEqual(w.t,time); testCase.verifyEqual(w.Ath,before.Ath);
            w=w.withDiffusivity(1e-5); w.addForcing(WVNonlinearAdvection(w));
            pattern=repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1);
            w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=1e-7,phase=.3));
            model=WVModel(w); model.setupIntegrator(integratorType="exponential"); e=model.densityDiffusionIntegrator;
            full=e.toModes(w.coefficientTendency()); explicit=e.explicitCoefficientTendency(false);
            testCase.verifyEqual(full,e.rates.*e.modalState()+explicit,AbsTol=1e-15);
            model.integrateToTime(w.t+100,shouldShowIntegrationDiagnostics=false);
            testCase.verifyTrue(all(isfinite(w.Ath),'all'));
        end
        function cheapPolicyPersistenceAndMigration(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.exponentialState); thermalManufacturedState(w,[2 3 4],1000);
            before=w.nonlinearCoefficientTendency();
            fileName=[tempname '.nc']; cleanup=onCleanup(@()delete(fileName));
            f=w.writeToFile(fileName); f.close(); r=WVTransform.waveVortexTransformFromFile(fileName);
            testCase.verifyEqual(r.scientificState,w.scientificState);
            testCase.verifyEqual(r.nonlinearCoefficientTendency(),before);
            s=w.scientificState; names={'shouldCheckQuadraticAliasing','nonlinearQuadratureCount','nonlinearQuadratureTolerance','nonlinearQuadratureResidual','nonlinearReferenceResidual'};
            s=rmfield(s,names); s.schemaVersion=1;
            old=WVTransformFreeSurfaceThermalQG(scientificState=s);
            testCase.verifyFalse(old.shouldCheckQuadraticAliasing); testCase.verifyEqual(old.schemaVersion,2);
            testCase.verifyEqual(old.thermalToPolynomial,w.thermalToPolynomial);
            oldFile=[tempname '.nc']; oldCleanup=onCleanup(@()delete(oldFile));
            properties=w.classRequiredPropertyNames(); properties=properties(~ismember(properties,names));
            f=w.writeToFile(oldFile,properties{:},shouldAddRequiredProperties=false); f.close();
            ncwrite(oldFile,'schemaVersion',1);
            restored=WVTransform.waveVortexTransformFromFile(oldFile);
            testCase.verifyFalse(restored.shouldCheckQuadraticAliasing);
            testCase.verifyEqual(restored.Ath,w.Ath);

        end
    end
end
function w=construct(a)
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[12 12 65],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=17,mdaModeCount=4,kappa_z=0,shouldCheckQuadraticAliasing=true);
end
function out=subtract(a,b)
out=struct(Ath=a.Ath-b.Ath,Amda=a.Amda-b.Amda);
end
