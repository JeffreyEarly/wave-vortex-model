classdef TestThermalIntegration < matlab.unittest.TestCase
    properties
        state
    end
    methods (TestClassSetup)
        function setup(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=@(z)1e-4*ones(size(z)),thermalModeCount=17,mdaModeCount=4);
            testCase.state=w.scientificState;
        end
    end
    methods (Test, TestTags="full")
        function exactCornerCases(testCase)
            for kappa=[0 1e-5]
                w=makeTransform(testCase.state,kappa); w.Ath(2,1)=1e-3*(1+2i); w.Amda=[.01;-.02;.03;-.01];
                for phase=[0 .7]
                    force=seasonal(w,phase); w.addForcing(force);
                    e=WVDensityDiffusionIntegrator(w); initial=e.modalState();
                    q=zeros(w.spatialMatrixSize); b=zeros(w.Nx,w.Ny,2); b(:,:,1)=force.amplitude*force.pattern;
                    source=e.toModes(w.projectQuasigeostrophicSpatialTendency(q,b));
                    for t=[0 1e-8 10 86400]
                        actual=e.seasonalCoefficients(t);
                        expected=zeros(size(source)); omega=2*pi/force.period;
                        for j=find(source~=0).'
                            A=[e.rates(j),source(j),0;0,0,omega;0,-omega,0];
                            c=expm(A*t)*[0;sin(phase);cos(phase)]; expected(j)=c(1);
                        end
                        testCase.verifyLessThan(norm(actual-expected),1e-12*max(norm(expected),1e-15));
                        recovered=e.fromModes(exp(e.rates*t).*initial);
                        testCase.verifyEqual(recovered.Amda,expm(kappa*w.mdaGeneratorPerDiffusivity*t)*w.Amda,AbsTol=1e-12);
                    end
                end
            end
        end
        function actualModelAndAbsoluteClock(testCase)
            w=makeTransform(testCase.state,1e-5); w.Ath(2,1)=.001+.002i; w.Amda=[.01;-.02;.03;-.01]; w.t=1234;
            w.addForcing(seasonal(w,.7)); model=WVModel(w); configure(model); e=model.densityDiffusionIntegrator;
            initial=e.modalState(); time=w.t; final=20000;
            expected=exp(e.rates*(final-time)).*(initial-e.seasonalCoefficients(time))+e.seasonalCoefficients(final);
            model.integrateToTime(final,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(e.modalState(),expected,AbsTol=2e-12);
            testCase.verifyEqual(w.t,final);
            testCase.verifyTrue(isreal(w.Amda));
            old=w.coefficientState(); model.integrateToTime(final,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(w.coefficientState(),old);
        end
        function ownershipAndNorms(testCase)
            w=makeTransform(testCase.state,1e-5); w.Ath(2,1)=.001+.002i; w.Amda=[.01;-.02;.03;-.01]; w.t=1234;
            force=seasonal(w,.7); w.addForcing(force); e=WVDensityDiffusionIntegrator(w);
            ordinary=w.coefficientTendency(linearDynamics=true); [explicit,~]=e.explicitCoefficientTendency(false);
            testCase.verifyEqual(e.toModes(ordinary),e.rates.*e.modalState()+explicit,AbsTol=1e-15);
            testCase.verifyEqual(e.explicitCoefficientTendency(true),zeros(size(e.rates)),AbsTol=0);
            norms=e.physicalErrorNorms(e.modalState()); fields=w.reconstructFields(["qgpv","buoyancy","u","v","endpointAnomalies"]);
            weights=reshape(w.verticalQuadratureWeights/w.Lz,1,1,[]);
            actual=[sqrt(mean(sum(weights.*fields.qgpv.^2,3),'all')),sqrt(mean(sum(weights.*fields.buoyancy.^2,3),'all')),sqrt(mean(sum(weights.*(fields.u.^2+fields.v.^2),3),'all')),sqrt(mean(fields.endpointAnomalies(:,:,1).^2,'all')),sqrt(mean(fields.endpointAnomalies(:,:,2).^2,'all'))];
            testCase.verifyEqual(norms,actual,RelTol=1e-6,AbsTol=1e-14);
            replacement=seasonal(w,1.1); previous=e.seasonalCoefficients(1000); w.addForcing(replacement);
            testCase.verifyNotEqual(e.seasonalCoefficients(1000),previous);
            w.removeForcing(replacement); testCase.verifyEqual(e.seasonalCoefficients(1000),zeros(size(e.rates)),AbsTol=0);
            model=WVModel(w);
            testCase.verifyError(@()model.setupIntegrator(integratorType="exponential"),'WVModel:ThermalLinearSelection');
            testCase.verifyError(@()w.coefficientTendency(),'WV:ThermalEvolutionUnavailable');
            testCase.verifyError(@()WVVerticalDiffusivity(w),'WV:ThermalDiffusionOwnership');
            closure=ThermalStageForcing(w,true);
            testCase.verifyError(@()w.addForcing(closure),'WV:ThermalForcingUnavailable');
            changed=w.withDiffusivity(0); changedData=changed.linearEvolutionData();
            testCase.verifyEqual(abs(changedData.rates),zeros(size(changedData.rates)));
            testCase.verifyEqual(changedData.toModes(changed.coefficientState()),e.modalState(),AbsTol=1e-14);
            attachedData=w.linearEvolutionData(); w.t=w.t+1; w.Ath=2*w.Ath;
            testCase.verifyEqual(w.linearEvolutionData(),attachedData);

        end
        function adaptiveRefinementAndRejectedSteps(testCase)
            errors=zeros(1,2); steps=errors; rejected=errors;
            for i=1:2
                w=makeTransform(testCase.state,0); w.Ath(2,1)=1e-5*(1+1i); initial=w.Ath;
                force=ThermalStageForcing(w); w.addForcing(force); model=WVModel(w);
                model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=4,maximumStep=4,relTolerance=10^(-3-3*(i-1)),physicalAbsTolerance=1e-25*ones(1,5));
                model.integrateToTime(4,shouldShowIntegrationDiagnostics=false);
                errors(i)=norm(w.Ath-exp(4)*initial,'fro')/norm(exp(4)*initial,'fro');
                steps(i)=model.exponentialStatistics.acceptedSteps; rejected(i)=model.exponentialStatistics.rejectedSteps;
            end
            fprintf("Thermal refinement: errors %.6g %.6g; accepted %d %d; rejected %d %d.\n",errors,steps,rejected);
            testCase.verifyLessThan(errors(2),errors(1)/10);
            testCase.verifyGreaterThan(steps(2),steps(1)); testCase.verifyGreaterThan(min(rejected),0);
        end
        function stageFailureRestoresAcceptedState(testCase)
            w=makeTransform(testCase.state,0); w.Ath(2,1)=1e-5+2e-5i; w.Amda=[.01;-.02;.03;-.01]; w.t=5;
            force=ThermalStageForcing(w); force.failureTime=6; force.rate=.1; w.addForcing(force);
            model=WVModel(w); model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=1,maximumStep=1,exponentialAdaptive=false); before=w.coefficientState();
            testCase.verifyError(@()model.integrateToTime(10,shouldShowIntegrationDiagnostics=false),'ThermalStageForcing:Failure');
            testCase.verifyEqual(w.t,6); testCase.verifyEqual(w.Ath,exp(.1)*before.Ath,AbsTol=1e-11); testCase.verifyEqual(w.Amda,before.Amda,AbsTol=1e-14);
            testCase.verifyEmpty(model.finalIntegrationTime);
        end
        function observationCadenceDoesNotChangeTrajectory(testCase)
            models=cell(1,2);
            for i=1:2
                w=makeTransform(testCase.state,0); w.Ath(2,1)=1e-5+1e-5i;
                force=ThermalStageForcing(w); force.rate=.1; w.addForcing(force);
                model=ThermalObservationModel(w); intervals=[.37 .61]; model.sampleInterval=intervals(i);
                model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=1,maximumStep=2,relTolerance=1e-6);
                model.integrateToTime(4,shouldShowIntegrationDiagnostics=false); models{i}=model;
            end
            testCase.verifyEqual(models{1}.exponentialStatistics.acceptedStepSeconds,models{2}.exponentialStatistics.acceptedStepSeconds);
            testCase.verifyEqual(models{1}.wvt.Ath,models{2}.wvt.Ath);
            for i=1:2
                model=models{i}; initial=model.sampleStates{1}.Ath;
                for j=1:numel(model.sampleTimes)
                    testCase.verifyEqual(model.sampleStates{j}.Ath,exp(.1*model.sampleTimes(j))*initial,AbsTol=1e-11);
                end
            end
        end
    end
end
function w=makeTransform(s,kappa)
s.kappa_z=kappa; w=WVTransformFreeSurfaceThermalQG(scientificState=s);
end
function f=seasonal(w,phase)
f=WVSeasonalSurfaceAnomalyForcing(w,pattern=repmat(sin(2*pi*w.y'/w.Ly)+.3*cos(2*pi*w.y'/w.Ly),w.Nx,1),amplitude=1e-7,period=100000,phase=phase);
end
function configure(model)
model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=1000,maximumStep=10000);
end
