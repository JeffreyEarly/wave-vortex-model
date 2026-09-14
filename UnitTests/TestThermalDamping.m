classdef TestThermalDamping < matlab.unittest.TestCase
    properties
        scientificState
        apv
        configuration
    end
    methods (TestClassSetup)
        function setup(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(2*z/1300),thermalModeCount=17,mdaModeCount=4,shouldCheckQuadraticAliasing=true);
            testCase.scientificState=w.scientificState;
            testCase.apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny 129],N2Function=w.N2Function,latitude=w.latitude,g=w.g,apvModeCount=6,mdaModeCount=4);
            f=WVThermalAPVDamping.fromAPVTransform(w,testCase.apv,apvCutoffFraction=.5);
            for name=string(f.classRequiredPropertyNames()), testCase.configuration.(name)=f.(name); end
        end
    end
    methods (Test,TestTags="full")
        function frozenAPVCoordinatesAndCompleteComplement(testCase)
            [w,f]=testCase.makeCase(); thermalManufacturedState(w,[2 3 4],1000);
            d=f.coefficientDampingData(); apv=testCase.apv;
            r=WVInternal.thermalPolynomialFields(apv.z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
            e=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
            q=complex(zeros(numel(apv.z),size(w.Ath,2))); endpoint=complex(zeros(2,size(w.Ath,2)));
            projected=complex(zeros(numel(d.verticalRates),size(w.Ath,2)));
            for p=1:numel(w.khUnique)
                columns=w.klNonzeroKhUniqueIndex==p; polynomial=w.thermalToPolynomial(:,:,p)*w.Ath(:,columns);
                q(:,columns)=(r.qgpv-w.khUnique(p)^2*r.psi)*polynomial;
                endpoint(:,columns)=e.eta_i*polynomial;
                projected(:,columns)=d.pages{p}.projection*w.Ath(:,columns);
            end
            [aq,a0]=apv.transformStateForward(q,endpoint);
            testCase.verifyEqual(projected,[aq;a0],RelTol=1e-9,AbsTol=1e-14);
            speed=1.7; [horizontal,vertical]=f.quasigeostrophicDampingContributions(w,struct(uvMax=speed));
            testCase.verifyEqual(horizontal.Ath,speed*d.horizontalRates.*w.Ath);
            testCase.verifyEqual(horizontal.Amda,zeros(size(w.Amda))); testCase.verifyEqual(vertical.Amda,zeros(size(w.Amda)));
            for p=1:numel(w.khUnique)
                columns=w.klNonzeroKhUniqueIndex==p; page=d.pages{p};
                expected=speed*d.verticalRates.*projected(:,columns);
                testCase.verifyLessThan(norm(page.projection*vertical.Ath(:,columns)-expected,'fro'),1e-9*max(norm(expected,'fro'),1e-20));
                complement=eye(w.thermalModeCount)-page.lift*page.projection;
                testCase.verifyLessThan(norm(complement*vertical.Ath(:,columns),'fro'),1e-8*max(norm(vertical.Ath(:,columns),'fro'),1e-20));
                testCase.verifyLessThan(norm(page.projection*complement*w.Ath(:,columns),'fro'),1e-9*max(norm(projected(:,columns),'fro'),1e-20));
            end
            legacy=WVAdaptiveDamping(apv,apvCutoffFraction=.5);
            testCase.verifyEqual(d.horizontalRates,legacy.dampAg_0(1,:),AbsTol=1e-18);
            testCase.verifyEqual(d.verticalRates(1:end-2),legacy.dampAg_q(:,1)-legacy.dampAg_0(1,1));
            testCase.verifyEqual([f.sourceG0 f.sourceGd],[apv.g0 apv.gd]);
        end
        function physicalOperatorBoundAndActualProcesses(testCase)
            [w,f]=testCase.makeCase(); thermalManufacturedState(w,[2 3 4],1000);
            w.addForcing(WVNonlinearAdvection(w)); w.addForcing(f);
            ordinary=w.coefficientTendency(); [actual,speed,processes]=w.coefficientTendency();
            total=processes.tendencies(1);
            for k=2:numel(processes.tendencies)
                total.Ath=total.Ath+processes.tendencies(k).Ath; total.Amda=total.Amda+processes.tendencies(k).Amda;
            end
            testCase.verifyEqual(actual,ordinary);
            testCase.verifyEqual(total.Ath,actual.Ath,AbsTol=1e-17); testCase.verifyEqual(total.Amda,actual.Amda,AbsTol=1e-17);
            testCase.verifyEqual(processes.labels(end-1:end),[string(f.name)+": horizontal",string(f.name)+": vertical"]);
            [h,v]=f.quasigeostrophicDampingContributions(w,struct(uvMax=speed));
            testCase.verifyEqual(processes.tendencies(end-1).Ath,h.Ath,AbsTol=1e-18);
            testCase.verifyEqual(processes.tendencies(end).Ath,v.Ath,AbsTol=1e-18);
            d=f.coefficientDampingData(); metrics=w.physicalMetricOperators();
            for p=1:numel(w.khUnique)
                factors=metrics.pages{p}.factors;
                [~,R]=qr([factors.kineticEnergy;factors.interiorPotentialEnergy;factors.surfacePotentialEnergy],0);
                columns=w.klNonzeroKhUniqueIndex==p; page=d.pages{p};
                action=page.lift*(d.verticalRates.*page.projection)+d.horizontalRates(find(columns,1))*eye(w.thermalModeCount);
                testCase.verifyLessThanOrEqual(norm(R*action/R,2),d.maximumUnitSpeedRate*(1+1e-7));
            end
            testCase.verifyEqual(f.maximumExplicitDampingRate(struct(uvMax=speed)),speed*d.maximumUnitSpeedRate);
            testCase.verifyEqual(f.maximumExplicitDampingRate(struct(uvMax=0)),0);
        end
        function closureOnlyStageSpeedAndZeroCallback(testCase)
            [w,f]=testCase.makeCase(); thermalManufacturedState(w,[2 3 4],1000); w.addForcing(f);
            [linear,linearSpeed]=w.coefficientTendency(linearDynamics=true);
            testCase.verifyGreaterThan(linearSpeed,0);
            testCase.verifyEqual(linearSpeed,w.uvMax);
            testCase.verifyGreaterThan(f.maximumExplicitDampingRate(struct(uvMax=linearSpeed)),0);
            testCase.verifyGreaterThan(norm(linear.Ath,'fro'),0);
            w=ThermalReconstructionCounter(testCase.scientificState); thermalManufacturedState(w,[2 3 4],1000);
            args=namedargs2cell(testCase.configuration); f=WVThermalAPVDamping(w,args{:});
            w.addForcing(WVNonlinearAdvection(w)); w.addForcing(f);
            [before,speed]=w.coefficientTendency();
            zero=ThermalProcessForcing(w,254); zero.multiplier=1;
            w.nativeSpeedMultiplier=100; w.addForcing(zero);
            [after,withCallbackSpeed]=w.coefficientTendency();
            testCase.verifyEqual(after,before); testCase.verifyEqual(withCallbackSpeed,speed);
            testCase.verifyEqual(zero.lastSpeed,speed);
        end
        function apvProcessSplitMatchesActualCallback(testCase)
            w=testCase.apv; original=w.coefficientState(); originalForcing=w.forcing;
            cleanup=onCleanup(@()restoreAPV(w,original,originalForcing));
            w.removeAllForcing(); w.Ag_q(:)=0; w.Ag_0(:)=0; w.Amda(:)=0;
            w.Ag_q(:,1)=1e-8*(1:w.apvModeCount)'; w.Ag_0(:,1)=1e-8*[1;-2];
            force=WVAdaptiveDamping(w,apvCutoffFraction=.5); w.addForcing(force);
            ordinary=w.coefficientTendency(); [actual,speed,processes]=w.coefficientTendency();
            testCase.verifyEqual(actual,ordinary);
            testCase.verifyEqual(processes.labels,string(force.name)+[": horizontal",": vertical"]);
            blank=struct(Ag_q=zeros(size(w.Ag_q)),Ag_0=zeros(size(w.Ag_0)),Amda=zeros(size(w.Amda)));
            [direct,horizontal,vertical]=force.addQuasigeostrophicSpectralForcing(w,blank,struct(uvMax=speed));
            testCase.verifyEqual(actual,direct);
            for name=string(fieldnames(blank)).'
                total=processes.tendencies(1).(name)+processes.tendencies(2).(name);
                testCase.verifyEqual(total,actual.(name),AbsTol=1e-18);
                testCase.verifyEqual(processes.tendencies(1).(name),horizontal.(name),AbsTol=1e-18);
                testCase.verifyEqual(processes.tendencies(2).(name),vertical.(name),AbsTol=1e-18);
            end
        end
        function nonlinearSelectionUsesImplementationIdentity(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificState);
            spoof=ThermalProcessForcing(w,255,'nonlinear advection'); spoof.multiplier=1; w.addForcing(spoof);
            model=WVModel(w);
            testCase.verifyError(@()model.setupIntegrator(integratorType="exponential"),'WVModel:ThermalLinearSelection');
            testCase.verifyError(@()w.coefficientTendency(),'WV:ThermalEvolutionUnavailable');
            model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true);
            model.integrateToTime(1,shouldShowIntegrationDiagnostics=false);
            w.removeAllForcing(); w.addForcing(RenamedThermalAdvection(w));
            model=WVModel(w); model.setupIntegrator(integratorType="exponential");
            model.integrateToTime(2,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(w.t,2);
            testCase.verifyError(@()w.coefficientTendency(linearDynamics=true),'WV:ThermalLinearConflict');
        end
        function frozenConfigurationAndValidation(testCase)
            [w,f]=testCase.makeCase(); target=w.withDiffusivity(0); copy=f.forcingWithResolutionOfTransform(target);
            for name=string(f.classRequiredPropertyNames()), testCase.verifyEqual(copy.(name),f.(name)); end
            testCase.verifyEqual(copy.coefficientDampingData(),f.coefficientDampingData());
            testCase.verifyError(@()copy.quasigeostrophicDampingContributions(w),'WV:ThermalDampingOwner');
            invalid=testCase.configuration; invalid.sourceN20=2*invalid.sourceN20; args=namedargs2cell(invalid);
            testCase.verifyError(@()WVThermalAPVDamping(w,args{:}),'WV:ThermalDampingPhysics');
            invalid=testCase.configuration; invalid.apvForward(:)=0; args=namedargs2cell(invalid);
            testCase.verifyError(@()WVThermalAPVDamping(w,args{:}),'WV:ThermalDampingBand');
            invalid=testCase.configuration; invalid.horizontalCutoff=2*pi/invalid.horizontalResolution; args=namedargs2cell(invalid);
            testCase.verifyError(@()WVThermalAPVDamping(w,args{:}),'WV:ThermalDampingFilter');
            invalid=testCase.configuration; invalid.dampingAPVMode(end)=invalid.dampingAPVMode(1); args=namedargs2cell(invalid);
            testCase.verifyError(@()WVThermalAPVDamping(w,args{:}),'WV:ThermalDampingShape');
        end
        function trialStateBoundsRejectAndRecover(testCase)
            s=testCase.scientificState; s.kappa_z=0; w=WVTransformFreeSurfaceThermalQG(scientificState=s);
            w.Ath(2,1)=1e-8+1e-8i; initial=w.Ath;
            force=ThermalStageBoundForcing(w); w.addForcing(force); model=WVModel(w);
            model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=1,maximumStep=1,exponentialAdaptive=false);
            model.integrateToTime(1,shouldShowIntegrationDiagnostics=false);
            testCase.verifyGreaterThan(model.exponentialStatistics.rejectedSteps,0);
            testCase.verifyLessThanOrEqual(model.exponentialStatistics.maximumDampingNumber,1.2);
            testCase.verifyTrue(any(force.observed(:,2)>1.2 & force.observed(:,3)==100));
            testCase.verifyTrue(any(diff(force.observed(:,1))<0));
            testCase.verifyEqual(w.Ath,exp(1)*initial,RelTol=2e-6,AbsTol=1e-17);
        end
        function coincidentHorizontalCutoffHasFiniteLimit(testCase)
            testCase.verifyEqual(WVInternal.horizontalVanishingFilter([0 1 2],1,1),[0 0 1]);
            w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[4 4 65],N2Function=@(z)1e-4*ones(size(z)),thermalModeCount=17,mdaModeCount=4);
            apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[4 4 129],N2Function=w.N2Function,apvModeCount=6,mdaModeCount=4);
            legacy=WVAdaptiveDamping(apv,apvCutoffFraction=.5);
            testCase.verifyTrue(all(isfinite(legacy.dampAg_q),'all'));
            f=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5);
            testCase.verifyTrue(isfinite(f.coefficientDampingData().maximumUnitSpeedRate));
        end
    end
    methods
        function [w,f]=makeCase(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificState);
            args=namedargs2cell(testCase.configuration); f=WVThermalAPVDamping(w,args{:});
        end
    end
end

function restoreAPV(w,state,forces)
w.Ag_q=state.Ag_q; w.Ag_0=state.Ag_0; w.Amda=state.Amda; w.setForcing(forces);
end
