classdef TestWVTransformFreeSurfaceQGDiffusion < matlab.unittest.TestCase
    properties
        temporaryFolder
    end
    methods (TestMethodSetup)
        function temporaryDirectory(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder=fixture.Folder;
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
        end
    end
    methods (Test, TestTags="full")
        function sharedRHSMatchesUnsharedForcingPath(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            indices=reshape(1:numel(w.Ag_T),size(w.Ag_T));
            initial=w.Ag_T+1e-3*(cos(indices)+1i*sin(2*indices)); w.t=86400;
            for dealias=[false true]
                w.configureVerticalNumerics(shouldDealias=dealias);
                for damping=[-1 0 1]
                    if damping>=0, w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=damping)); end
                    for amplitude=[0 1]
                        w.Ag_T=amplitude*initial;
                        for exclude=[false true]
                            [expected,referenceSpeed,physical]=thermalQGUnsharedTendency(w,exclude);
                            [actual,speed]=w.nonthermalCoefficientTendency(exclude);
                            TestWVTransformFreeSurfaceQGDiffusion.verifyEquivalentTendency(testCase,w,actual,expected);
                            testCase.verifyEqual(speed,referenceSpeed,RelTol=1e-14)
                            [q,u,v,b]=w.quasigeostrophicSpatialState();
                            testCase.verifyEqual(q,physical.q,RelTol=1e-12,AbsTol=1e-21)
                            testCase.verifyEqual(u,physical.u,RelTol=1e-13,AbsTol=1e-20)
                            testCase.verifyEqual(v,physical.v,RelTol=1e-13,AbsTol=1e-20)
                            testCase.verifyEqual(b,physical.b,RelTol=1e-13,AbsTol=1e-16)
                        end
                    end
                    if damping>=0, w.removeForcing(w.forcingWithName('adaptive damping')); end
                end
            end
        end

        function sharedRHSRespectsCustomSpectralCallbacks(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            for priority=[0 255]
                w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=1));
                w.addForcing(ThermalTendencyMultiplier(w,priority));
                if priority==0
                    testCase.verifyClass(w.spectralFluxForcing(1),'ThermalTendencyMultiplier')
                else
                    testCase.verifyClass(w.spectralFluxForcing(1),'WVAdaptiveDamping')
                end
                expected=thermalQGUnsharedTendency(w); actual=w.nonthermalCoefficientTendency();
                TestWVTransformFreeSurfaceQGDiffusion.verifyEquivalentTendency(testCase,w,actual,expected);
                w.removeForcing(w.forcingWithName('tendency multiplier'));
                w.removeForcing(w.forcingWithName('adaptive damping'));
            end
            w.addForcing(ThermalCustomDamping(w));
            expected=thermalQGUnsharedTendency(w); actual=w.nonthermalCoefficientTendency();
            TestWVTransformFreeSurfaceQGDiffusion.verifyEquivalentTendency(testCase,w,actual,expected);
        end

        function partialReconstructionMatchesCompleteOutputs(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            [phi,eta,q,b]=w.reconstructSpectralState();
            [referencePhi,referenceEta,referenceQ,referenceB]=ThermalUnsharedTransform.reconstruct(w,w.Ag_T);
            testCase.verifyEqual(phi,referencePhi,RelTol=1e-12,AbsTol=1e-12)
            testCase.verifyEqual(eta,referenceEta,RelTol=1e-12,AbsTol=1e-14)
            testCase.verifyEqual(q,referenceQ,RelTol=1e-12,AbsTol=1e-20)
            testCase.verifyEqual(b,referenceB,RelTol=1e-12,AbsTol=1e-16)
            testCase.verifyEqual(w.reconstructSpectralState(),phi)
            [p,e]=w.reconstructSpectralState(); testCase.verifyEqual(p,phi); testCase.verifyEqual(e,eta)
            [p,e,Q]=w.reconstructSpectralState(); testCase.verifyEqual(p,phi); testCase.verifyEqual(e,eta); testCase.verifyEqual(Q,q)
            [~,endpoint]=w.transformStateBack(w.Ag_T);
            testCase.verifyEqual(b,endpoint,RelTol=1e-13,AbsTol=1e-16)
        end

        function tiltedSingleWaveAdvectionHasNoMeanSource(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            pattern=sin(2*pi*(w.X(:,:,1)/w.Lx+w.Y(:,:,1)/w.Ly));
            w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=pi/(365.25*86400)));
            w.t=43200; w.Ag_T=w.seasonalCoefficients(w.t);
            nonlinear=w.forcingWithName('nonlinear advection');
            [Fq,Fb]=nonlinear.addQuasigeostrophicSpatialForcing(w,zeros(w.spatialMatrixSize),zeros(w.Nx,w.Ny));
            testCase.verifyLessThan(max(abs(mean(Fb,[1 2])),[],'all'),1e-12*max(max(abs(Fb),[],'all'),realmin))
            testCase.verifyLessThan(max(abs(mean(Fq,[1 2])),[],'all'),1e-12*max(max(abs(Fq),[],'all'),realmin))
            [withMeanQ,withMeanB]=nonlinear.addQuasigeostrophicSpatialForcing(w,ones(size(Fq)),ones(size(Fb)));
            testCase.verifyEqual(mean(withMeanQ,[1 2]),ones(1,1,w.Nz),AbsTol=1e-14)
            testCase.verifyEqual(mean(withMeanB,'all'),1,AbsTol=1e-14)
            w.nonthermalCoefficientTendency(true);
            w.addForcing(WVBetaPlanePVAdvection(w));
            tendency=w.nonthermalCoefficientTendency(true);
            testCase.verifyTrue(all(isfinite(tendency.Ag_T),'all'))
        end

        function modesAgreeWithIndependentPhysicalOperator(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            n=w.Nj;
            scale=[(w.Lz/abs(w.f))*sqrt(w.verticalQuadratureWeights(2:end-1)/w.Lz);1];
            for ip=unique([1 ceil(length(w.khUnique)/2) length(w.khUnique)])
                [L,phi,eta,Q]=TestWVTransformFreeSurfaceQGDiffusion.physicalOperator(w,ip);
                V=w.scaledStateFromModes(:,:,ip); inverse=w.modesFromScaledState(:,:,ip);
                R=V./scale; lambda=-w.thermalDecayRate(:,ip);
                scaledL=scale.*L./scale.';
                testCase.verifyLessThan(norm(scaledL*V-V.*lambda.','fro')/norm(scaledL,'fro'),1e-11)
                testCase.verifyLessThan(norm(inverse*V-eye(n),'fro')/sqrt(n),1e-10)
                testCase.verifyEqual(w.phiModes(:,:,ip),phi*R,RelTol=1e-10,AbsTol=1e-12)
                testCase.verifyEqual(w.etaModes(:,:,ip),eta*R,RelTol=1e-10,AbsTol=1e-12)
                testCase.verifyEqual(w.qModes(:,:,ip),Q*phi*R,RelTol=1e-8,AbsTol=1e-14)
                testCase.verifyLessThanOrEqual(max(real(lambda)),1e3*eps*norm(scaledL))
                testCase.verifyLessThan(min(abs(lambda)),1e-12)
            end
            testCase.verifyEqual(w.coefficientStateAnnotations().name,'Ag_T')
            testCase.verifyEqual(w.activeEndpoint,1)
        end

        function strictSourceAndZeroDiffusivityControl(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform(0);
            force=TestWVTransformFreeSurfaceQGDiffusion.seasonal(w);
            w.t=force.period/4;
            [Fq,Fb]=force.addQuasigeostrophicSpatialForcing(w,zeros(w.spatialMatrixSize),zeros(w.Nx,w.Ny),struct());
            testCase.verifyEqual(Fq,zeros(size(Fq)))
            testCase.verifyEqual(Fb,force.amplitude*force.pattern,AbsTol=1e-22)
            source=w.projectQuasigeostrophicSpatialTendency(Fq,Fb);
            [q,b]=w.transformStateBack(source.Ag_T);
            testCase.verifyLessThan(max(abs(q),[],'all'),1e-23)
            testCase.verifyEqual(b,w.spectralField(Fb),AbsTol=1e-18)
            w.addForcing(force); w.t=0;
            w.removeAllForcing(); w.addForcing(force);
            model=WVModel(w); model.setupIntegrator(maximumStep=86400*60);
            model.integrateToTime(force.period/2,shouldShowIntegrationDiagnostics=false);
            [q,b]=w.transformStateBack(w.Ag_T);
            expected=force.amplitude*force.period/pi*w.spectralField(force.pattern);
            testCase.verifyLessThan(max(abs(q),[],'all'),1e-16)
            testCase.verifyEqual(b,expected,AbsTol=1e-10)
            testCase.verifyEqual(w.coefficientLinearRates(),zeros(size(w.Ag_T)))
            testCase.verifyEqual(w.Ag_T,force.exactThermalResponse(w,w.t),AbsTol=0)
        end

        function fullSeasonalResponseAndTransientAgreeWithExpm(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            force=TestWVTransformFreeSurfaceQGDiffusion.seasonal(w,0.4);
            w.addForcing(force); omega=2*pi/force.period;
            b=w.spectralField(force.amplitude*force.pattern);
            entry=find(abs(b)>max(abs(b))/2,1); ip=w.klNonzeroKhUniqueIndex(entry);
            [L,~,~,~]=TestWVTransformFreeSurfaceQGDiffusion.physicalOperator(w,ip);
            source=zeros(w.Nj,1); source(end)=b(entry);
            initial=1e-2*cos((1:w.Nj).'); initial(1:end-1)=initial(1:end-1)*1e-7;
            data=zeros(size(w.Ag_T)); data(:,entry)=initial;
            A0=w.transformStateForward(data(1:end-1,:),data(end,:));
            for t=[3600 86400 30*86400 365.25*86400]
                evolution=expm(L*t);
                plus=(1i*omega*eye(w.Nj)-L)\(exp(1i*omega*t)*source-evolution*source);
                minus=(-1i*omega*eye(w.Nj)-L)\(exp(-1i*omega*t)*source-evolution*source);
                expected=evolution*initial+(exp(1i*force.phase)*plus-exp(-1i*force.phase)*minus)/(2i);
                A=exp(w.coefficientLinearRates()*t).*A0+force.exactThermalResponse(w,t);
                [q,endpoint]=w.transformStateBack(A); actual=[q(:,entry);endpoint(entry)];
                testCase.verifyLessThan(norm(actual-expected)/norm(expected),1e-9)
            end
        end

        function snapshotsRestoreAllArraysAndForcing(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            w.addForcing(TestWVTransformFreeSurfaceQGDiffusion.seasonal(w));
            w.addForcing(WVAdaptiveDamping(w));
            w.Ag_T=w.seasonalCoefficients(86400); w.t=86400;
            path=fullfile(testCase.temporaryFolder,'snapshot.nc');
            nc=w.writeToFile(path);
            testCase.verifyTrue(all(nc.hasVariableWithName('kNonzero','lNonzero','khNonzero','activeEndpoint')))
            nc.close();
            r=WVTransform.waveVortexTransformFromFile(path);
            for name=string(w.scientificPropertyNames())
                if isa(w.(name),'WVQGVerticalOperators')
                    for field=string(w.(name).classRequiredPropertyNames())
                        testCase.verifyEqual(r.(name).(field),w.(name).(field))
                    end
                else
                    testCase.verifyEqual(real(r.(name)),real(w.(name)),char(name))
                    testCase.verifyEqual(imag(r.(name)),imag(w.(name)),char(name))
                end
            end
            testCase.verifyEqual(r.Ag_T,w.Ag_T)
            testCase.verifyEqual(r.qgpv,w.qgpv)
            testCase.verifyEqual(r.buoyancy,w.buoyancy)
            testCase.verifyEqual(r.totalEnergy,w.totalEnergy)
            testCase.verifyEqual(r.seasonalCoefficients(2*86400),w.seasonalCoefficients(2*86400))
            % Complete arrays are the only direct-construction inputs.
            options=struct();
            for name=string(w.scientificPropertyNames()), options.(name)=w.(name); end
            options.Ag_T=w.Ag_T; args=namedargs2cell(options);
            direct=WVTransformFreeSurfaceQGDiffusion(args{:});
            testCase.verifyEqual(direct.psi,w.psi)
            testCase.verifyEqual(direct.coefficientLinearRates(),w.coefficientLinearRates())
        end

        function nonlinearOutputSamplingAndRestart(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            model=WVModel(w); model.setupIntegrator(relTolerance=1e-5,initialStep=10000,maximumStep=20000);
            model.integrateToTime(40000,shouldShowIntegrationDiagnostics=false);
            reference=w.Ag_T; referenceSteps=model.exponentialStatistics.acceptedStepSeconds;
            referenceModel=model;

            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            model=WVModel(w); model.setupIntegrator(relTolerance=1e-5,initialStep=10000,maximumStep=20000);
            path=fullfile(testCase.temporaryFolder,'model.nc');
            file=model.createNetCDFFileForModelOutput(path,outputInterval=4000);
            group=file.addNewEvenlySpacedOutputGroup('fields',outputInterval=7000);
            group.addObservingSystem(WVEulerianFields(model,fieldNames={'qgpv','buoyancy','totalEnergy','potentialEnstrophy'}));
            model.integrateToTime(40000,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
            testCase.verifyEqual(w.Ag_T,reference)
            testCase.verifyEqual(model.exponentialStatistics.acceptedStepSeconds,referenceSteps)
            testCase.verifyGreaterThan(model.exponentialStatistics.outputRhsEvaluations,0)
            r=WVModel.modelFromFile(path); cleanup=onCleanup(@()r.closeNetCDFFile());
            testCase.verifyEqual(r.wvt.Ag_T,reference)
            testCase.verifyEqual(r.t,40000)
            r.setupIntegrator(relTolerance=1e-5,initialStep=10000,maximumStep=20000);
            r.integrateToTime(60000,shouldShowIntegrationDiagnostics=false); r.closeNetCDFFile();
            referenceModel.setupIntegrator(relTolerance=1e-5,initialStep=10000,maximumStep=20000);
            referenceModel.integrateToTime(60000,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(r.wvt.Ag_T,referenceModel.wvt.Ag_T,AbsTol=1e-13)
            clear cleanup
            nc=NetCDFFile(path); cleanup=onCleanup(@()nc.close());
            testCase.verifyEqual(nc.variablePathsWithName('Ag_T'),"wave-vortex/Ag_T")
            testCase.verifyEqual(WVModelOutputGroup.committedRecordCountForGroup(nc.groupWithName('wave-vortex')),length(nc.readVariables('wave-vortex/t')))
        end

        function partialRecordIsNotRestarted(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            model=WVModel(w); path=fullfile(testCase.temporaryFolder,'partial.nc');
            file=model.createNetCDFFileForModelOutput(path,outputInterval=1);
            file.outputTimesForIntegrationPeriod(0,1); file.writeTimeStepToOutputFile(0);
            w.Ag_T=ones(size(w.Ag_T));
            group=file.outputGroupWithName('wave-vortex'); group.stageTimeStepToNetCDFFile(file.ncfile,1);
            file.ncfile.sync(); model.closeNetCDFFile();
            r=WVModel.modelFromFile(path); cleanup=onCleanup(@()r.closeNetCDFFile());
            testCase.verifyEqual(r.t,0)
            testCase.verifyEqual(r.wvt.Ag_T,complex(zeros(size(w.Ag_T))))
            r.integrateToTime(1,shouldShowIntegrationDiagnostics=false); r.closeNetCDFFile();
            clear cleanup
            nc=NetCDFFile(path); cleanup=onCleanup(@()nc.close());
            testCase.verifyEqual(nc.readVariables('wave-vortex/t'),[0;1])
        end

        function exponentialWeightsHandleNullStiffAndNoncommutingTerms(testCase)
            lambda=[0;-1e-4;-1]; source=[.2;.1;-.3]; initial=[1;2;3]; h=100;
            c=WVInternal.exponentialRK4Coefficients(lambda,h);
            actual=WVInternal.exponentialRK4Step(initial,0,h,c,@(~,~)deal(source,0));
            expected=exp(lambda*h).*initial; expected(1)=expected(1)+h*source(1);
            expected(2:end)=expected(2:end)+expm1(lambda(2:end)*h)./lambda(2:end).*source(2:end);
            testCase.verifyEqual(actual,expected,AbsTol=1e-12)
            lambda=[0;-.5]; B=[0 .2;-.3 0]; initial=[1;2]; exact=expm(diag(lambda)+B)*initial;
            errors=zeros(1,3);
            for level=1:3
                h=1/(4*2^level); c=WVInternal.exponentialRK4Coefficients(lambda,h); value=initial;
                for step=1:round(1/h), value=WVInternal.exponentialRK4Step(value,(step-1)*h,h,c,@(a,~)deal(B*a,0)); end
                errors(level)=norm(value-exact);
            end
            testCase.verifyGreaterThan(errors(1:2)./errors(2:3),12)
        end

        function fixedExponentialDecayKeepsTheCompleteState(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform(); w.removeAllForcing();
            initial=complex(zeros(size(w.Ag_T))); initial(:,1)=.1*cos((1:w.Nj).'); w.Ag_T=initial;
            model=WVModel(w); model.setupIntegrator(exponentialAdaptive=false,initialStep=10000);
            model.integrateToTime(86400,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(w.Ag_T,exp(w.coefficientLinearRates()*86400).*initial,AbsTol=1e-13)
            testCase.verifyEqual(size(w.Ag_T),size(initial))
        end

        function nonlinearConvergesToOrdinaryReferenceAndRejectsLargeSteps(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            initial=w.Ag_T;
            [~,reference]=ode78(@rhs,[0 86400],initial(:),odeset(RelTol=1e-10,AbsTol=1e-13));
            expected=reshape(reference(end,:),size(initial));
            w.t=0; w.Ag_T=initial;
            model=WVModel(w); model.setupIntegrator(relTolerance=1e-9,physicalAbsTolerance=[1e-17 1e-15 1e-12 1e-12],initialStep=86400,maximumStep=86400);
            model.integrateToTime(86400,shouldShowIntegrationDiagnostics=false);
            errors=w.physicalErrorNorms(w.Ag_T-expected)./w.physicalErrorNorms(expected);
            testCase.verifyLessThan(max(errors),1e-7)
            testCase.verifyGreaterThan(model.exponentialStatistics.rejectedSteps,0)
            testCase.verifyEqual(w.uvMax,max(hypot(w.u,w.v),[],'all'),RelTol=1e-14)
            function F=rhs(t,A)
                w.t=t; w.Ag_T=reshape(A,size(initial)); F=w.coefficientTendency(); F=F.Ag_T(:);
            end
        end

        function unsupportedConfigurationsAreExplicit(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform(); model=WVModel(w);
            testCase.verifyError(@()model.setupIntegrator(integratorType='adaptive'),'WVModel:ExponentialIntegratorRequired')
            testCase.verifyError(@()WVVerticalDiffusivity(w,kappa_z=1e-5),'WVVerticalDiffusivity:DiffusionAlreadyBuiltIn')
            testCase.verifyError(@()w.spectralField(ones(w.Nx,w.Ny)),'WVTransformFreeSurfaceQGDiffusion:MeanUnsupported')
            testCase.verifyError(@()WVSeasonalSurfaceAnomalyForcing(w,pattern=ones(w.Nx,w.Ny),amplitude=1),'WVSeasonalSurfaceAnomalyForcing:MeanUnsupported')
            testCase.verifyError(@()w.coefficientAbsoluteTolerances(1e-6),'WVTransformFreeSurfaceQGDiffusion:ExponentialIntegratorRequired')
            testCase.verifyError(@()w.nonlinearFlux(),'WVTransformFreeSurfaceQGDiffusion:UseThermalState')
            testCase.verifyError(@()w.transformToSpatialDomainWithF([]),'WVTransformFreeSurfaceQGDiffusion:UnsupportedMVP')
            particles=WVLagrangianParticles(model,name='particles',x=0,y=0,z=0,isXYOnly=true);
            model.addFluxedObservingSystem(particles);
            testCase.verifyError(@()model.setupIntegrator(),'WVModel:ExponentialObserverUnsupported')
        end

        function failedStageRestoresLastAcceptedPublicState(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            w.addForcing(ThermalFailureForcing(w));
            model=WVModel(w); initial=w.Ag_T;
            testCase.verifyError(@()model.integrateToTime(86400,shouldShowIntegrationDiagnostics=false),'ThermalFailureForcing:ExpectedFailure')
            testCase.verifyEqual(w.t,0)
            testCase.verifyEqual(w.Ag_T,initial)
        end

        function horizontalDampingUsesOneFactorForEveryThermalMode(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            w.Ag_T=complex(ones(size(w.Ag_T)));
            damping=WVAdaptiveDamping(w);
            actual=damping.addQuasigeostrophicSpectralForcing(w,struct(Ag_T=zeros(size(w.Ag_T))),struct(uvMax=.1));
            testCase.verifyEqual(actual.Ag_T,.1*damping.damp(:,w.klNonzero).*w.Ag_T)
            testCase.verifyEqual(damping.damp,repmat(damping.damp(1,:),w.Nj,1))
            testCase.verifyLessThanOrEqual(max(real(actual.Ag_T),[],'all'),0)
        end
    end
    methods (Static)
        function verifyEquivalentTendency(testCase,w,actual,expected)
            % Reordered linear sums can differ in nearly cancelling modal
            % entries. Check the full coefficient norm and every physical
            % error norm; do not divide by each tiny modal entry separately.
            difference=actual.Ag_T-expected.Ag_T;
            reference=norm(expected.Ag_T,'fro');
            if reference==0
                testCase.verifyEqual(actual.Ag_T,expected.Ag_T)
            else
                testCase.verifyLessThan(norm(difference,'fro')/reference,1e-11)
                physicalReference=w.physicalErrorNorms(expected.Ag_T);
                testCase.verifyLessThan(w.physicalErrorNorms(difference)./max(physicalReference,realmin),1e-11)
            end
        end

        function w=transform(kappa)
            if nargin<1, kappa=1e-5; end
            w=WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 500e3 4000],[8 8 17],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),kappaT=kappa);
        end
        function force=seasonal(w,phase)
            if nargin<2, phase=0; end
            force=WVSeasonalSurfaceAnomalyForcing(w,pattern=sin(2*pi*w.Y(:,:,1)/w.Ly),amplitude=pi/(365.25*86400),phase=phase);
        end
        function initializeNonlinear(w)
            w.addForcing(TestWVTransformFreeSurfaceQGDiffusion.seasonal(w));
            w.addForcing(WVBetaPlanePVAdvection(w));
            x=w.X; y=w.Y; z=w.Z;
            q=1e-6*cos(pi*z/w.Lz).*cos(2*pi*(x/w.Lx+y/w.Ly));
            b=.5*sin(2*pi*x(:,:,1)/w.Lx)+.3*cos(2*pi*y(:,:,1)/w.Ly);
            qhat=w.spectralField(q); bhat=w.spectralField(b);
            w.Ag_T=w.transformStateForward(qhat(2:end-1,:),bhat);
        end
        function [L,phi,eta,Q]=physicalOperator(w,ip)
            nz=w.Nz; Dz=w.verticalDerivativeMatrix; N2=w.N2; weights=w.verticalQuadratureWeights;
            Q=-w.khUnique(ip)^2*eye(nz)+Dz*((w.f^2./N2).*Dz);
            inversion=Q; inversion(1,:)=-(w.f/N2(1))*Dz(1,:);
            inversion(end,:)=-(w.f/N2(end))*Dz(end,:); inversion(end,end)=inversion(end,end)-w.f/w.g;
            rhs=zeros(nz,nz-1); rhs(2:end-1,1:end-1)=eye(nz-2); rhs(end,end)=1;
            phi=inversion\rhs; eta=-(w.f./N2).*(Dz*phi);
            buoyancy=-N2.*(eta-(w.f/w.g)*(1+w.z/w.Lz).*phi(end,:));
            weakDiffusion=-(Dz.'*(weights.*(w.kappaT*Dz)))./weights; weakDiffusion(1,:)=0;
            projection=[w.f*Dz(2:end-1,:)./N2.';zeros(1,nz)]; projection(end,end)=-1/N2(end);
            L=projection*weakDiffusion*buoyancy;
        end
    end
end
