classdef TestFreeSurfaceAdaptiveIntegration < matlab.unittest.TestCase
    properties (TestParameter)
        policy = {"energy","family"}
    end
    methods (Test,TestTags="full")
        function reconstructedToleranceIsNormalizationInvariant(testCase)
            wvt=TestFreeSurfaceAdaptiveIntegration.transform();
            scientific=wvt.scientificState(); scale=8;
            % A reconstruction-only change of coordinates: rescale the synthesis
            % bases and their inverse analysis maps, without a new mode solve.
            for name=["apvF","apvG","apvEndpointResponse","zeroAPVF","zeroAPVG","waveF","waveG","inertialF","mdaG","mdaPressureMode"]
                scientific.(name)=scale*scientific.(name);
            end
            for name=["apvFForward","waveGForward","inertialFForward","mdaGForward"]
                scientific.(name)=scientific.(name)/scale;
            end
            rescaled=WVTransformFreeSurfaceBoussinesq(scientific);
            models={WVModel(wvt),WVModel(rescaled)};
            for tolerancePolicy=["energy","family"]
                first=WVCoefficients(models{1},tolerancePolicy=tolerancePolicy);
                second=WVCoefficients(models{2},tolerancePolicy=tolerancePolicy);
                a=first.absErrorTolerance(); b=second.absErrorTolerance();
                for k=1:numel(a)
                    testCase.verifyEqual(scale*b{k},a{k},RelTol=1e-12)
                end
                % The same normalized local error represents the same field.
                names=string({wvt.coefficientStateAnnotations().name});
                state=wvt.coefficientState(); scaledState=rescaled.coefficientState();
                for k=1:numel(names)
                    state.(names(k))=a{k}; scaledState.(names(k))=b{k};
                end
                f=wvt.reconstructSpectralState(state=state);
                g=rescaled.reconstructSpectralState(state=scaledState);
                for name=["u","v","w","eta","qgpv","ssh"]
                    testCase.verifyLessThan(norm(f.(name)-g.(name),'fro')/max(norm(f.(name),'fro'),realmin),1e-12)
                end
            end
        end

        function familyScalesAndRadialAllocation(testCase)
            transforms={TestFreeSurfaceAdaptiveIntegration.transform(),WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,g0=-.1,gd=.2)};
            for k=1:numel(transforms)
                wvt=transforms{k}; model=WVModel(wvt);
                observer=WVCoefficients(model,tolerancePolicy="family");
                automatic=observer.absErrorTolerance();
                energy=wvt.coefficientAbsoluteTolerances(1e-6);
                names=string({wvt.coefficientStateAnnotations().name});
                [~,column]=min(wvt.khNonzero);
                for name=["Ag_q","Ag_0"]
                    values=automatic{names==name};
                    testCase.verifyEqual(values(1,column),energy.(name)(1,column),RelTol=1e-12)
                    if name=="Ag_0"
                        testCase.verifyEqual(values(:,column),energy.Ag_0(:,column),RelTol=1e-12)
                    end
                end
                observer.pvAbsTolerance=2e-10; observer.surfaceAbsTolerance=3e-7; observer.bottomAbsTolerance=7e-7;
                alpha=observer.absErrorTolerance();
                observer.surfaceAbsTolerance=6e-7;
                doubled=observer.absErrorTolerance();
                boundary=find(names=="Ag_0");
                testCase.verifyEqual(doubled{boundary}(1,:),2*alpha{boundary}(1,:),RelTol=1e-14)
                testCase.verifyEqual(doubled{boundary}(2,:),alpha{boundary}(2,:))
                testCase.verifyEqual(doubled{names=="Ag_q"},alpha{names=="Ag_q"})
                % Directly recover the prescribed boundary invariant spectrum.
                dk=wvt.kRadial(2)-wvt.kRadial(1);
                C=reshape((wvt.f./(wvt.g*wvt.khNonzero.^2)).^2,1,[]);
                for b=1:numel(wvt.kRadial)
                    selected=wvt.khNonzero>wvt.kRadial(b)-dk/2 & wvt.khNonzero<=wvt.kRadial(b)+dk/2;
                    if ~any(selected), continue; end
                    width=wvt.kRadial(b)+dk/2-max(wvt.kRadial(b)-dk/2,0);
                    testCase.verifyEqual(sum(C(selected).*alpha{boundary}(1,selected).^2)/width,(3e-7)^2,RelTol=1e-10)
                end
            end
        end

        function familyPolicyPersistsAndLegacyDefaultsRemain(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            wvt=TestFreeSurfaceAdaptiveIntegration.transform(); model=WVModel(wvt);
            model.setupIntegrator(tolerancePolicy="family",pvAbsTolerance=2e-10,surfaceAbsTolerance=3e-7);
            expected=model.odeOptions.AbsTol;
            file=fullfile(fixture.Folder,'family.nc');
            model.createNetCDFFileForModelOutput(file,outputInterval=1);
            model.integrateToTime(1,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
            resumed=WVModel.modelFromFile(file); cleanup=onCleanup(@()resumed.closeNetCDFFile());
            resumed.setupIntegrator();
            testCase.verifyEqual(resumed.odeOptions.AbsTol,expected,RelTol=1e-12)
            % A file containing only the historical scalar reconstructs energy defaults.
            legacy=NetCDFFile(fullfile(fixture.Folder,'legacy.nc'),shouldOverwriteExisting=true);
            legacyCleanup=onCleanup(@()legacy.close());
            observer=WVCoefficients(model);
            observer.writeToGroup(legacy,observer.propertyAnnotationWithName({'absTolerance'}));
            restored=WVObservingSystem.observingSystemFromGroup(legacy,model,WVModelOutputGroup.empty);
            testCase.verifyEqual(restored.tolerancePolicy,"energy")
            testCase.verifyEmpty(restored.surfaceAbsTolerance)
        end

        function invalidFamilyOptionsAreRejected(testCase)
            wvt=TestFreeSurfaceAdaptiveIntegration.transform(); model=WVModel(wvt);
            testCase.verifyError(@()model.setupIntegrator(tolerancePolicy="family",integratorType="adaptive-cell"),'WVModel:InvalidTolerancePolicy')
            testCase.verifyError(@()model.setupIntegrator(surfaceAbsTolerance=1e-7),'WVCoefficients:InvalidTolerancePolicy')
            testCase.verifyError(@()model.setupIntegrator(tolerancePolicy="family",pvAbsTolerance=[1 2]),'WVCoefficients:InvalidToleranceScale')
        end

        function tolerancesMatchUnitFieldEnergy(testCase)
            wvt=TestFreeSurfaceAdaptiveIntegration.transform();
            alpha=wvt.coefficientAbsoluteTolerances(1e-6);
            empty=wvt.coefficientState();
            dk=wvt.kRadial(2)-wvt.kRadial(1);
            for name=string(fieldnames(empty)).'
                values=alpha.(name);
                testCase.verifyTrue(all(isfinite(values) & values>0,'all'))
                wvt.removeAll();
                state=empty; state.(name)(1)=values(1);
                for family=string(fieldnames(state)).', wvt.(family)=state.(family); end
                if ismember(name,["Aio","Amda"])
                    expected=1e-12*dk/2;
                else
                    radial=wvt.kRadial;
                    b=find(wvt.khNonzero(1)>radial-dk/2 & wvt.khNonzero(1)<=radial+dk/2,1);
                    inBin=wvt.khNonzero>radial(b)-dk/2 & wvt.khNonzero<=radial(b)+dk/2;
                    expected=1e-12*dk/nnz(inBin);
                end
                energy=wvt.physicalEnergy();
                testCase.verifyEqual(energy.totalEnergy,expected,RelTol=1e-10)
            end
        end

        function meanOnlyGridReceivesZeroBinAllocation(testCase)
            wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[2 2 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=2,inertialModeCount=1,waveModeCount=0,nEVP=128,g0=Inf,gd=Inf);
            testCase.verifyEmpty(wvt.khNonzero)
            model=WVModel(wvt); model.setupIntegrator(tolerancePolicy="family");
            testCase.verifyTrue(all(isfinite(model.odeOptions.AbsTol)))
            alpha=wvt.coefficientAbsoluteTolerances(1e-6);
            wvt.Amda(1)=alpha.Amda(1);
            testCase.verifyEqual(wvt.physicalEnergy().totalEnergy,1e-12*pi/1e5,RelTol=1e-12)
            wvt.Amda(:)=0;
            model.integrateToTime(1,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(wvt.t,1)
        end

        function zeroFlowWithoutOscillatorsHasFiniteStep(testCase)
            wvt=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,g0=-.1,gd=.2);
            model=WVModel(wvt); model.setupIntegrator(tolerancePolicy="family");
            testCase.verifyTrue(isfinite(model.odeOptions.InitialStep))
            testCase.verifyGreaterThan(model.odeOptions.InitialStep,0)
            model.integrateToTime(10,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(wvt.t,10)
        end

        function zeroFlowHasFiniteAdaptiveStep(testCase,policy)
            wvt=TestFreeSurfaceAdaptiveIntegration.transform();
            model=WVModel(wvt); model.setupIntegrator(integratorType="adaptive",tolerancePolicy=policy);
            testCase.verifyGreaterThan(model.odeOptions.InitialStep,0)
            testCase.verifyTrue(isfinite(model.odeOptions.InitialStep))
            model.integrateToTime(10,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(wvt.t,10)
            testCase.verifyTrue(isreal(wvt.Amda))
            testCase.verifyEqual(wvt.physicalEnergy().totalEnergy,0)
        end

        function absentWavesAndBoundariesRemainSupported(testCase,policy)
            wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=3,inertialModeCount=1,waveModeCount=0,nEVP=128,g0=Inf,gd=Inf);
            alpha=wvt.coefficientAbsoluteTolerances(1e-6);
            testCase.verifyEmpty(alpha.Aw_p)
            testCase.verifyEmpty(alpha.Ag_0)
            testCase.verifySize(alpha.Amda,size(wvt.Amda))
            model=WVModel(wvt); model.setupIntegrator(integratorType="adaptive",tolerancePolicy=policy);
            model.integrateToTime(10,shouldShowIntegrationDiagnostics=false);
            testCase.verifyTrue(isfinite(wvt.t))
        end

        function variableWaveCountsHaveFiniteUnusedPadding(testCase,policy)
            base=TestFreeSurfaceAdaptiveIntegration.transform();
            counts=3*ones(size(base.khUnique)); counts(1)=0;
            wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=counts,waveModeKappa=base.khUnique,nEVP=128);
            alpha=wvt.coefficientAbsoluteTolerances(1e-6);
            testCase.verifyTrue(all(isfinite(alpha.Aw_p) & alpha.Aw_p>0,'all'))
            testCase.verifyEqual(alpha.Aw_p(~wvt.activeWaveModes),1e-6*ones(nnz(~wvt.activeWaveModes),1))
            model=WVModel(wvt); model.setupIntegrator(integratorType="adaptive",tolerancePolicy=policy);
            model.integrateToTime(10,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(wvt.Aw_p(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
        end

        function nonlinearDampedRestartAgreesWithContinuation(testCase,policy)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,nEVP=128,shouldAntialias=true,quadraticDealiasing="fixedFraction");
            wvt.Amda(1:2)=wvt.mdaG([end 1],1:2)\[2;-2];
            wvt.Aw_p(1,1)=1e-4*exp(.3i); wvt.Aw_m(2,2)=2e-4*exp(.7i);
            wvt.Ag_q(1,2)=1e-9; wvt.Ag_0(1,1)=1e-10;
            wvt.Aio(1)=1e-3;
            wvt.addForcing(WVNonlinearAdvection(wvt));
            wvt.addForcing(WVAdaptiveDamping(wvt));
            model=WVModel(wvt);
            model.setupIntegrator(integratorType="adaptive",tolerancePolicy=policy,absTolerance=1e-9,relTolerance=1e-9);
            filename=fullfile(fixture.Folder,'adaptive-nonlinear.nc');
            model.createNetCDFFileForModelOutput(filename,outputInterval=10);
            model.integrateToTime(20,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
            resumed=WVModel.modelFromFile(filename);
            cleanup=onCleanup(@()resumed.closeNetCDFFile());
            resumed.setupIntegrator(integratorType="adaptive",tolerancePolicy=policy,absTolerance=1e-9,relTolerance=1e-9);
            resumed.integrateToTime(40,shouldShowIntegrationDiagnostics=false);
            % Continue a transform copy without attaching the original output file.
            reference=WVModel(wvt);
            reference.setupIntegrator(integratorType="adaptive",tolerancePolicy=policy,absTolerance=1e-10,relTolerance=1e-10);
            reference.integrateToTime(40,shouldShowIntegrationDiagnostics=false);
            expected=wvt.reconstructFields(["u","v","eta"]);
            actual=resumed.wvt.reconstructFields(["u","v","eta"]);
            for name=["u","v","eta"]
                testCase.verifyLessThan(norm(actual.(name)(:)-expected.(name)(:))/norm(expected.(name)(:)),1e-5)
            end
            testCase.verifyTrue(isreal(resumed.wvt.Amda))
        end
    end
    methods (Static)
        function wvt=transform()
            wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,nEVP=128);
        end
    end
end
