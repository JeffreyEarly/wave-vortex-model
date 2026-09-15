classdef TestBoussinesqAdaptiveDamping < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function ratesProtectLargeScalesAndShareHorizontalFilter(testCase)
            w=newTransform(); force=WVAdaptiveDamping(w); w.addForcing(force);
            testCase.verifyTrue(w.hasClosure);
            d=force.coefficientDampingOperator();
            for name=string(fieldnames(d)).'
                testCase.verifySize(d.(name),size(w.(name)));
                testCase.verifyTrue(all(isfinite(d.(name)) & d.(name)<=0,'all'));
            end
            testCase.verifyEqual(d.Aw_p,d.Aw_m);
            testCase.verifyEqual(d.Aio(1),0);
            testCase.verifyEqual(d.Amda(1:2),[0;0]);
            testCase.verifyEqual(d.Aio,zeros(size(w.Aio)));
            testCase.verifyEqual(d.Amda,zeros(size(w.Amda)));
            low=w.khNonzero<=force.k_no_damp;
            testCase.verifyEqual(d.Ag_q(1,low),zeros(1,nnz(low)));
            testCase.verifyEqual(d.Aw_p(1,low),zeros(1,nnz(low)));
            testCase.verifyEqual(d.Ag_q(end,:)-d.Ag_0(1,:),zeros(1,numel(w.klNonzero)),AbsTol=1e-18);
            testCase.verifyGreaterThanOrEqual(1/force.dampingTimeScale(),max(abs(d.Aio)));
            [rate,speed]=w.coefficientTendency();
            testCase.verifyEqual(speed,0);
            for name=string(fieldnames(rate)).', testCase.verifyEqual(rate.(name),zeros(size(rate.(name)))); end
        end

        function phasesAdditivityAndUnsupportedVerticalOption(testCase)
            w=newTransform(); force=WVAdaptiveDamping(w); w.addForcing(force);
            w.Ag_q(:)=1e-9; w.Ag_0(:)=1e-12; w.Aw_p(:)=1e-4*(1+2i); w.Aw_m(:)=1e-4*(2-1i); w.Aio(:)=1e-4i; w.Amda(:)=.001;
            zero=structfun(@(a)zeros(size(a)),w.coefficientState(),UniformOutput=false);
            testCase.verifyError(@()WVAdaptiveDamping(w,apvCutoffFraction=.2),"WVAdaptiveDamping:APVCutoff");
            for repeat=1:2
                testCase.verifyEqual(force.j_no_damp,Inf);
                d=force.coefficientDampingOperator();
                for t=[0 12345]
                    w.t=t;
                    expected=force.addBoussinesqSpectralForcing(w,zero);
                    actual=w.coefficientTendency();
                    for name=string(fieldnames(actual)).'
                        testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-18);
                        testCase.verifyLessThanOrEqual(real(sum(conj(w.(name)).*actual.(name),'all')),0);
                    end
                    doubled=force.addBoussinesqSpectralForcing(w,expected);
                    for name=string(fieldnames(actual)).', testCase.verifyEqual(doubled.(name),2*actual.(name),AbsTol=1e-18); end
                end
                force.buildDampingOperator(); testCase.verifyEqual(force.coefficientDampingOperator(),d);
            end
        end

        function nonlinearUniformFlowIsPreservedAndRestarts(testCase)
            w=newTransform(); force=WVAdaptiveDamping(w);
            w.addForcing(WVNonlinearAdvection(w)); w.addForcing(force);
            w.Aio(end)=1;
            u=w.reconstructFields(["u","v"]); speed=max(hypot(u.u,u.v),[],'all');
            amplitude=.3/speed; w.Aio(end)=amplitude;
            d=force.coefficientDampingOperator(); lambda=-d.Aio(end)*.3;
            model=WVModel(w); model.setupIntegrator(integratorType="fixed",deltaT=50);
            model.integrateToTime(10000,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(w.Aio(end),amplitude/(1+lambda*10000),RelTol=1e-11);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            filePath=fullfile(fixture.Folder,'damped.nc'); nc=w.writeToFile(filePath); nc.close();
            restored=WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(filePath);
            clone=restored.forcingWithName("adaptive damping");
            testCase.verifyTrue(isnan(clone.apvCutoffFraction));
            testCase.verifyEqual(clone.coefficientDampingOperator(),force.coefficientDampingOperator());
            testCase.verifyEqual(restored.coefficientTendency(),w.coefficientTendency());
            resumed=WVModel(restored); resumed.setupIntegrator(integratorType="fixed",deltaT=50);
            resumed.integrateToTime(20000,shouldShowIntegrationDiagnostics=false);
            model.integrateToTime(20000,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(restored.coefficientState(),w.coefficientState());
            testCase.verifyEqual(w.Aio(end),amplitude/(1+lambda*20000),RelTol=1e-11);
        end

        function raggedWavePrefixesAndMinimalFamilies(testCase)
            base=newTransform();
            counts=5*ones(size(base.khUnique)); counts(1)=0; counts(2)=3;
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,waveModeCount=counts,waveModeKappa=base.khUnique,inertialModeCount=1,mdaModeCount=2,shouldAntialias=true,quadraticDealiasing="fixedFraction");
            force=WVAdaptiveDamping(w); w.addForcing(force); d=force.coefficientDampingOperator();
            testCase.verifyEqual(d.Aio,0); testCase.verifyEqual(d.Amda,[0;0]);
            testCase.verifyEqual(d.Aw_p(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1));
            for page=2:numel(w.khUnique)
                column=find(w.klNonzeroKhUniqueIndex==page,1); count=counts(page);
                testCase.verifyEqual(d.Aw_p(count,column)-d.Ag_0(1,column),0,AbsTol=1e-18);
                testCase.verifyEqual(d.Aw_p(1,column),d.Ag_0(1,column));
            end
            rate=w.coefficientTendency(); testCase.verifyTrue(all(isfinite(rate.Aw_p),'all'));
        end

        function energyDiagnosticIncludesClosureAndPortableSupportIsExplicit(testCase)
            w=newTransform(); force=WVAdaptiveDamping(w);
            w.addForcing(WVNonlinearAdvection(w)); w.addForcing(force); [~,column]=max(w.khNonzero); w.Aw_p(1,column)=.01;
            [~,speed,diagnostics]=w.coefficientTendency();
            d=force.coefficientDampingOperator();
            % The nonlinear diagnostic is not the quadratic wave-energy budget.
            testCase.verifyLessThan(diagnostics.energyTendency,0);
            initialEnergy=w.totalEnergy;
            factor=1+10*speed*d.Aw_p(1,column);
            w.Aw_p=factor*w.Aw_p;
            testCase.verifyEqual(w.totalEnergy,factor^2*initialEnergy,RelTol=1e-12);
            testCase.verifyLessThan(w.totalEnergy,initialEnergy);
            testCase.verifyEqual(diagnostics.prescribedWork,0);
            contract=force.portableImplementationContract();
            testCase.verifyEqual(contract.capabilityStatus,"unavailable");
        end

        function commonRatePreservesMixedBoundaryCancellation(testCase)
            w=newTransform(); force=WVAdaptiveDamping(w); w.addForcing(force);
            [~,column]=max(w.khNonzero);
            w.Ag_q(:,column)=1e-9; w.Ag_0(:,column)=[2;-3]*1e-12;
            w.Aw_p(:,column)=1e-4*(1+2i); w.Aw_m(:,column)=1e-4*(2-1i);
            w.t=12345;
            before=w.reconstructSpectralState();
            state=w.coefficientState(); zero=structfun(@(a)zeros(size(a)),state,UniformOutput=false);
            rate=force.addBoussinesqSpectralForcing(w,zero,struct(uvMax=.3));
            for name=string(fieldnames(state)).', w.(name)=rate.(name); end
            after=w.reconstructSpectralState();
            d=force.coefficientDampingOperator(); r=.3*d.Ag_q(1,column);
            testCase.verifyLessThan(r,0);
            for name=["u","v","w","eta","p","ssh","qgpv"]
                testCase.verifyEqual(after.(name),r*before.(name),AbsTol=1e-16);
            end
            boundary=[before.eta(end,:)-before.ssh(end,:);before.eta(1,:)];
            boundaryRate=[after.eta(end,:)-after.ssh(end,:);after.eta(1,:)];
            testCase.verifyEqual(real(sum(conj(boundary).*boundaryRate,'all')),r*sum(abs(boundary).^2,'all'),RelTol=1e-11);
            testCase.verifyEqual(real(sum(conj(before.qgpv).*after.qgpv,'all')),r*sum(abs(before.qgpv).^2,'all'),RelTol=1e-11);
        end

        function resolutionConversionRebuildsRates(testCase)
            w=newTransform(); force=WVAdaptiveDamping(w); w.addForcing(force);
            finer=w.waveVortexTransformWithResolution([16 16 65],apvModeCount=4,mdaModeCount=4,inertialModeCount=4,waveModeCount=5);
            copied=finer.forcingWithName("adaptive damping");
            testCase.verifyTrue(isnan(copied.apvCutoffFraction));
            d=copied.coefficientDampingOperator();
            testCase.verifyEqual(d.Aio,zeros(size(finer.Aio)));
            testCase.verifyNotEqual(min(d.Ag_q,[],'all'),min(force.dampAg_q,[],'all'));
            testCase.verifyNotEqual(copied.assumedEffectiveHorizontalGridResolution,force.assumedEffectiveHorizontalGridResolution);
        end
    end
end

function w=newTransform()
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=4,waveModeCount=5,inertialModeCount=4,mdaModeCount=4,shouldAntialias=true,quadraticDealiasing="fixedFraction");
end
