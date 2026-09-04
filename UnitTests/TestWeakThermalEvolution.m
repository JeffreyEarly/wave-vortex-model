classdef TestWeakThermalEvolution < matlab.unittest.TestCase
    % Algebra and lifecycle checks, distinct from spatial qualification.
    methods (Test, TestTags="full")
        function completeCoordinatesAndZeroDiffusion(testCase)
            w=TestWeakThermalEvolution.transform();
            e=WVWeakThermalEvolution(w,0);
            testCase.verifyEqual(e.rates,zeros(size(e.rates)))
            for p=1:length(e.operators.pages)
                page=e.operators.pages{p};
                testCase.verifySize(page.generator,[w.apvModeCount+2,w.apvModeCount+2])
                testCase.verifyEqual(page.generator,zeros(size(page.generator)))
            end
            testCase.verifyEqual(e.operators.mda.generator,zeros(w.mdaModeCount))
            % All columns, including highest modes and zero-valued families.
            full=TestWeakThermalEvolution.state(w);
            names=["Ag_q" "Ag_0" "Amda"];
            for family=["zero" names "mixed"]
                state=full;
                for name=names
                    if family~="mixed" && family~=name, state.(name)(:)=0; end
                end
                restored=e.fromModes(e.toModes(state));
                for name=names
                    error=norm(restored.(name)-state.(name),'fro');
                    testCase.verifyLessThanOrEqual(error,1e-9*norm(full.(name),'fro'))
                end
            end
        end

        function weakIdentityAndPhysicalPropagation(testCase)
            w=TestWeakThermalEvolution.transform(); e=WVWeakThermalEvolution(w,1e-5);
            times=[0 3600 86400 30*86400 365.25*86400];
            for p=unique([1,ceil(length(w.khUnique)/2),length(w.khUnique)])
                page=e.operators.pages{p}; n=size(page.generator,1);
                testCase.verifyGreaterThan(min(eig(page.energy)),0)
                testCase.verifyLessThan(page.diagnostics.eigenResidual,1e-11)
                testCase.verifyLessThan(page.diagnostics.weakResidual,1e-11)
                % Compare full operators, not just a favorable initial vector.
                for t=times
                    modal=page.toEnergy*page.fromModes*diag(exp(t*page.rates))*page.toModes*page.fromEnergy;
                    direct=expm(t*page.energyGenerator);
                    testCase.verifyLessThan(norm(modal-direct,'fro')/max(norm(direct,'fro'),realmin),1e-9)
                end
                testCase.verifyLessThan(norm(page.toModes*page.fromModes-eye(n),2),1e-9)
            end
        end

        function mdaHeatAndVariance(testCase)
            w=TestWeakThermalEvolution.transform(); e=WVWeakThermalEvolution(w,1e-5);
            m=e.operators.mda;
            testCase.verifyLessThan(m.diagnostics.heatResidual,1e-11)
            testCase.verifyEqual(m.rates(1),0)
            testCase.verifyLessThanOrEqual(max(m.rates),0)
            testCase.verifyLessThan(norm(m.generator*m.fromModes(:,1))/max(norm(m.generator)*norm(m.fromModes(:,1)),realmin),1e-11)
            initial=cos((1:w.mdaModeCount).');
            heat0=m.heat'*initial;
            initialVariance=real(initial'*m.energy*initial);
            for years=[0 1 3 30]
                state=m.fromModes*(exp(m.rates*years*365.25*86400).*(m.toModes*initial));
                testCase.verifyLessThan(abs(m.heat'*state-heat0)/max(norm(m.heat)*norm(initial),realmin),1e-10)
                testCase.verifyLessThanOrEqual(real(state'*m.energy*state),initialVariance*(1+1e-12))
            end
        end

        function strictSeasonalSourceAndResponse(testCase)
            for kappa=[0 1e-5]
                w=TestWeakThermalEvolution.transform(); w.removeAllForcing();
                pattern=repmat(sin(2*pi*w.y.'/w.Ly),w.Nx,1);
                force=WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=1e-7);
                w.addForcing(force); e=WVWeakThermalEvolution(w,kappa);
                w.t=force.period/4; source=w.coefficientTendency();
                testCase.verifyEqual(source.Ag_q,zeros(size(w.Ag_q)))
                testCase.verifyEqual(source.Amda,zeros(size(w.Amda)))
                testCase.verifyEqual(source.Ag_0(2,:),zeros(size(w.Ag_0(2,:))))
                transformed=e.toModes(source); omega=2*pi/force.period;
                for years=[0 .25 1 3]
                    t=years*force.period; response=e.seasonalCoefficients(t);
                    if kappa==0
                        expected=transformed*(1-cos(omega*t))/omega;
                        testCase.verifyLessThan(norm(response-expected)/max(norm(transformed)/omega,realmin),1e-11)
                    end
                    % Independent augmented exponential for a genuinely forced page.
                    [~,column]=max(vecnorm(source.Ag_0)); p=w.klNonzeroKhUniqueIndex(column);
                    page=e.operators.pages{p}; n=size(page.generator,1);
                    forcing=page.toEnergy*[source.Ag_q(:,column);source.Ag_0(:,column)];
                    augmented=[page.energyGenerator,forcing,zeros(n,1);zeros(1,n),0,omega;zeros(1,n),-omega,0];
                    direct=expm(t*augmented)*[zeros(n+1,1);1];
                    state=e.fromModes(response); actual=page.toEnergy*[state.Ag_q(:,column);state.Ag_0(:,column)];
                    testCase.verifyLessThan(norm(actual-direct(1:n))/max(norm(forcing)/omega,realmin),1e-9)
                end
                [explicit,~]=e.nonthermalCoefficientTendency(true);
                testCase.verifyLessThan(norm(explicit)/max(norm(transformed),realmin),1e-12)
                w.removeForcing(force);
                testCase.verifyEqual(abs(e.seasonalCoefficients(force.period/4)),zeros(size(e.rates)))
                w.addForcing(WVVerticalDiffusivity(w,kappa_z=1e-5));
                testCase.verifyError(@()e.seasonalCoefficients(0),'WV:WeakThermalDoubleDiffusion')
            end
        end

        function existingNonthermalCallbacks(testCase)
            w=TestWeakThermalEvolution.transform();
            e=WVWeakThermalEvolution(w,1e-5);
            state=TestWeakThermalEvolution.state(w); e.setModalState(e.toModes(state));
            nonlinear=w.forcingWithName('nonlinear advection');
            beta=WVBetaPlanePVAdvection(w); drag=WVBottomFrictionQuadratic(w);
            forces={nonlinear,beta,drag};
            for selection=1:4
                w.removeAllForcing();
                if selection==4, selected=1:3; else, selected=selection; end
                for k=selected, w.addForcing(forces{k}); end
                expected=w.coefficientTendency();
                [amplitudes,speed]=e.nonthermalCoefficientTendency(true);
                actual=e.fromModes(amplitudes);
                for name=["Ag_q" "Ag_0" "Amda"]
                    testCase.verifyLessThanOrEqual(norm(actual.(name)-expected.(name),'fro'),1e-9*max(norm(expected.(name),'fro'),realmin))
                end
                testCase.verifyEqual(speed,w.uvMax)
                testCase.verifyGreaterThan(norm(expected.Ag_q,'fro'),0)
            end
        end

        function canonicalSnapshotAndNoScientificFactory(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=TestWeakThermalEvolution.transform(); e=WVWeakThermalEvolution(w,1e-5);
            e.setModalState(e.toModes(TestWeakThermalEvolution.state(w)));
            file=fullfile(fixture.Folder,'canonical.nc'); nc=w.writeToFile(file); nc.close();
            profile clear; profile on
            restored=WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
            other=WVWeakThermalEvolution(restored,1e-5);
            profile off; info=profile('info');
            testCase.verifyFalse(any(contains(string({info.FunctionTable.FunctionName}),["IMSolver" "IMInternalModes"])))
            testCase.verifyEqual(other.operators,e.operators)
            testCase.verifyEqual(other.modalState(),e.modalState())
            testCase.verifyEqual(restored.Ag_q,w.Ag_q)
            testCase.verifyEqual(restored.Ag_0,w.Ag_0)
            testCase.verifyEqual(restored.Amda,w.Amda)
            model=WVModel(restored);
            testCase.verifyEmpty(model.weakThermalEvolution)
        end

        function exponentialPureThermalAndFailureRestore(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            w=TestWeakThermalEvolution.transform(); w.removeAllForcing();
            model=WVModel(w); model.setupWeakThermalIntegrator(1e-5);
            e=model.weakThermalEvolution;
            e.setModalState(e.toModes(TestWeakThermalEvolution.state(w)));
            initial=e.modalState();
            model.integrateToTime(86400,shouldShowIntegrationDiagnostics=false);
            expected=exp(e.rates*86400).*initial;
            testCase.verifyLessThan(max(e.physicalErrorNorms(e.modalState()-expected)./e.physicalErrorNorms(expected)),1e-9)
            testCase.verifyError(@()model.setupIntegrator(integratorType="adaptive"),'WVModel:WeakThermalIntegratorRequired')
            model.setupIntegrator(maximumStep=3600);
            w.addForcing(ThermalFailureForcing(w));
            accepted=e.modalState(); time=w.t;
            testCase.verifyError(@()model.integrateToTime(time+3600,shouldShowIntegrationDiagnostics=false),'ThermalFailureForcing:ExpectedFailure');
            testCase.verifyEqual(w.t,time)
            testCase.verifyLessThan(norm(e.modalState()-accepted)/norm(accepted),1e-9)
        end

        function sampledCanonicalOutputAndExplicitRestart(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=TestWeakThermalEvolution.transform(); w.removeAllForcing();
            model=WVModel(w); model.setupWeakThermalIntegrator(1e-5,initialStep=10000,maximumStep=20000);
            e=model.weakThermalEvolution; e.setModalState(e.toModes(TestWeakThermalEvolution.state(w)));
            file=fullfile(fixture.Folder,'model.nc');
            model.createNetCDFFileForModelOutput(file,outputInterval=4000);
            model.integrateToTime(40000,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
            restart=WVModel.modelFromFile(file); cleanup=onCleanup(@()restart.closeNetCDFFile());
            testCase.verifyEmpty(restart.weakThermalEvolution)
            for name=["Ag_q" "Ag_0" "Amda"], testCase.verifyEqual(restart.wvt.(name),w.(name)); end
            restart.setupWeakThermalIntegrator(1e-5,initialStep=10000,maximumStep=20000);
            restart.integrateToTime(60000,shouldShowIntegrationDiagnostics=false); restart.closeNetCDFFile();
            referenceModel=WVModel(w);
            referenceModel.setupWeakThermalIntegrator(1e-5,initialStep=10000,maximumStep=20000);
            referenceModel.integrateToTime(60000,shouldShowIntegrationDiagnostics=false);
            error=e.physicalErrorNorms(restart.weakThermalEvolution.modalState()-e.modalState());
            testCase.verifyLessThan(max(error./e.physicalErrorNorms(e.modalState())),1e-9)
            nc=NetCDFFile(file); closeFile=onCleanup(@()nc.close());
            testCase.verifyEmpty(nc.variablePathsWithName('Ag_T'))
            for name=["Ag_q" "Ag_0" "Amda"]
                testCase.verifyEqual(nc.variablePathsWithName(name),"wave-vortex/"+name)
            end
            clear closeFile cleanup
        end

        function endpointScopeIsExplicit(testCase)
            for endpoint=[-.1 Inf;Inf .1;Inf Inf].'
                w=WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),g0=endpoint(1),gd=endpoint(2),mdaGramTolerance=.1);
                testCase.verifyError(@()WVWeakThermalEvolution(w,0),'WV:WeakThermalEndpoints')
            end
        end

        function constantStratificationHeatCorrectionIsNeutral(testCase)
            w=WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),mdaGramTolerance=.1);
            e=WVWeakThermalEvolution(w,1e-5); o=e.operators; m=o.mda;
            derivative=m.reconstruction.q/(-w.f);
            Bz=-o.N2.*derivative;
            stiffness=Bz'*(1e-5*o.weights.*Bz);
            original=-(m.energy\stiffness);
            relative=norm(m.toEnergy*(original-m.generator)*m.fromEnergy,'fro')/norm(m.energyGenerator,'fro');
            testCase.verifyLessThan(relative,1e-9)
            testCase.verifyLessThan(m.diagnostics.heatResidual,1e-11)
            for p=1:length(o.pages)
                testCase.verifyLessThan(o.pages{p}.diagnostics.energyWeakResidual,1e-11)
            end
        end
    end
    methods (Static, Access = private)
        function w=transform()
            w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300));
        end
        function state=state(w)
            nq=w.apvModeCount; nk=length(w.klNonzero);
            q=reshape(sin(1:nq*nk)+1i*cos((1:nq*nk)/3),nq,nk)*1e-9;
            endpoint=reshape(cos(1:2*nk)+1i*sin((1:2*nk)/3),2,nk)*1e-12;
            state=struct(Ag_q=q,Ag_0=endpoint,Amda=.01*cos((1:w.mdaModeCount).'));
        end
    end
end
