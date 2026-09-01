classdef TestWVTransformFreeSurfaceQG < matlab.unittest.TestCase
    properties
        temporaryFolder string
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test, TestTags="full")
        function coefficientAnnotationsDriveIntegratorState(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            annotations = wvt.coefficientStateAnnotations();
            testCase.verifyEqual(string({annotations.name}),["Ag_q" "Ag_0" "Amda"])
            testCase.verifyEqual(string(annotations(1).dimensions),["apvMode" "klNonzero"])
            testCase.verifyEqual(string(annotations(2).dimensions),["activeEndpoint" "klNonzero"])
            testCase.verifyEqual(string(annotations(3).dimensions),"mdaMode")
            testCase.verifyEqual(annotations(1).canonicalBasis,"generalized-energy APV modes")
            testCase.verifyEqual(annotations(2).emptyFamilyPolicy,"omit")

            model = WVModel(wvt,shouldUseLinearDynamics=false);
            coefficients = model.wvCoefficientFluxedObservingSystem();
            testCase.verifyEqual(double(coefficients.nFluxComponents),3)
            testCase.verifyEqual(coefficients.lengthOfFluxComponents(), ...
                [numel(wvt.Ag_q);numel(wvt.Ag_0);numel(wvt.Amda)])
            testCase.verifyEqual(coefficients.initialConditions(),{wvt.Ag_q;wvt.Ag_0;wvt.Amda})
            portableContract = coefficients.portableImplementationContract();
            testCase.verifyEqual(portableContract.capabilityStatus,"unavailable")

            updatedState = {complex(ones(size(wvt.Ag_q)));complex(2*ones(size(wvt.Ag_0)));3*ones(size(wvt.Amda))};
            coefficients.updateIntegratorValues(11,updatedState);
            testCase.verifyEqual(wvt.t,11)
            testCase.verifyEqual(wvt.Ag_q,updatedState{1})
            testCase.verifyEqual(wvt.Ag_0,updatedState{2})
            testCase.verifyEqual(wvt.Amda,updatedState{3})
            tendencyValues = coefficients.fluxAtTime(11,updatedState);
            testCase.verifyEqual(length(tendencyValues),3)
            testCase.verifyTrue(all(isfinite([tendencyValues{1}(:);tendencyValues{2}(:);tendencyValues{3}(:)])))
            testCase.verifyEqual(tendencyValues{3},zeros(size(wvt.Amda)),AbsTol=0)
            testCase.verifyEqual(wvt.forcingNames(),"nonlinear advection")

            wvt.addToVariableCache('u',17);
            testCase.verifyEqual(wvt.fetchFromVariableCache('u'),17)
            wvt.Ag_q = 4*wvt.Ag_q;
            testCase.verifyEmpty(wvt.fetchFromVariableCache('u'))
            testCase.verifyError(@()setInvalidMDA(wvt), ...
                'WVTransformFreeSurfaceQG:InvalidCoefficient')
        end

        function endpointConfigurationsHaveCanonicalShapesAndMDAConstraints(testCase)
            endpointValues = [Inf Inf;0.02 Inf;Inf 0.03;0.02 0.03];
            expectedCodes = {zeros(0,1),1,2,[1;2]};
            expectedCounts = [0 1 1 2];
            for iCase = 1:size(endpointValues,1)
                wvt = TestWVTransformFreeSurfaceQG.newTransform(endpointValues(iCase,1),endpointValues(iCase,2));
                testCase.verifyEqual(wvt.activeEndpointCount,expectedCounts(iCase))
                testCase.verifyEqual(wvt.activeEndpoint,expectedCodes{iCase})
                testCase.verifyEqual(size(wvt.Ag_0),[expectedCounts(iCase),length(wvt.klNonzero)])
                testCase.verifyEqual(wvt.apvMode,(1:wvt.apvModeCount).')
                testCase.verifyEqual(wvt.mdaMode,(1:wvt.mdaModeCount).')
                if expectedCounts(iCase) == 0
                    testCase.verifyTrue(isnan(wvt.apvZeroAPVQuadraticError))
                    testCase.verifyEqual(wvt.apvZeroAPVLimitingEndpoint,"")
                else
                    testCase.verifyLessThanOrEqual(wvt.apvZeroAPVQuadraticError,wvt.quadraticAliasingTolerance)
                    testCase.verifyTrue(ismember(wvt.apvZeroAPVLimitingEndpoint,["surface" "bottom"]))
                end
                if isinf(endpointValues(iCase,1))
                    testCase.verifyEqual(wvt.mdaG(end,:),zeros(1,wvt.mdaModeCount),AbsTol=2e-12)
                end
                if isinf(endpointValues(iCase,2))
                    testCase.verifyEqual(wvt.mdaG(1,:),zeros(1,wvt.mdaModeCount),AbsTol=2e-12)
                end
                if all(isfinite(endpointValues(iCase,:)))
                    testCase.verifyEqual(wvt.mdaModeNumber(1),0)
                    testCase.verifyEqual(wvt.mdaG(:,1),wvt.mdaG(1,1)*ones(wvt.Nz,1),AbsTol=2e-12)
                else
                    testCase.verifyFalse(any(wvt.mdaModeNumber == 0))
                end
            end
        end

        function automaticModeCountsAreSelectedIndependently(testCase)
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=Inf,mdaGramTolerance=0.1);
            testCase.verifyGreaterThan(wvt.apvModeCount,0)
            testCase.verifyGreaterThan(wvt.mdaModeCount,0)
            testCase.verifyEqual(wvt.Nj,wvt.apvModeCount)
            testCase.verifyNotEqual(wvt.apvModeCount,wvt.mdaModeCount)
            testCase.verifySize(wvt.Ag_q,[wvt.apvModeCount length(wvt.klNonzero)])
            testCase.verifySize(wvt.Amda,[wvt.mdaModeCount 1])
            testCase.verifyEqual(wvt.apvGramTolerance,1e-2,AbsTol=0)
            testCase.verifyEqual(wvt.mdaGramTolerance,0.1,AbsTol=0)
            testCase.verifyEqual(wvt.quadraticAliasingTolerance,0.1,AbsTol=0)
            testCase.verifyEqual(wvt.muTolerance,sqrt(eps),AbsTol=0)
            testCase.verifyLessThanOrEqual(wvt.quadraticAliasingError,wvt.quadraticAliasingTolerance)
            testCase.verifyTrue(ismember(wvt.quadraticAliasingLimitingChannel,["FF->F" "FG->G" "GG->F"]))
            testCase.verifyTrue(all(wvt.verticalQuadratureWeights > 0))
            testCase.verifyLessThanOrEqual(wvt.apvGramError,wvt.apvGramTolerance)
            testCase.verifyLessThanOrEqual(wvt.mdaGramError,wvt.mdaGramTolerance)
            testCase.verifyEqual(wvt.verticalGridKind,"chebyshevLobatto")
            testCase.verifyEqual(wvt.verticalGridCoordinate,"wkb")
            testCase.verifyEqual(wvt.modeSelectionMethod,"fixed-native-quadrature-v1")
            testCase.verifyEqual(wvt.z_int,wvt.verticalQuadratureWeights,AbsTol=0)
            testCase.verifyEqual(sum(wvt.verticalQuadratureWeights),wvt.Lz,AbsTol=64*eps(wvt.Lz))
        end

        function storedTransformsMatchOnePassFixedQuadratureSelection(testCase)
            D = 1000;
            Nz = 33;
            N2 = @(z) 1e-4*ones(size(z));
            g0 = 0.02;
            gd = Inf;
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 D],[8 8 Nz],N2Function=N2,latitude=30,g0=g0,gd=gd,mdaGramTolerance=0.1);
            solver = IMSolverSpectral(nEVP=max(96,3*(Nz+4)));
            apvBasis = solver.solveEVP(IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=wvt.g,g0=g0,gd=gd,surfaceBoundary="freeSurface"),nModes=Nz+4);
            mdaBasis = solver.solveEVP(IMInternalModes.meanDensityAnomalyModes(N2=N2,zDomain=[-D 0],g=wvt.g,g0=g0,gd=gd),nModes=Nz+4);
            apvTransform = apvBasis.discreteTransform(z=wvt.z,weights=wvt.verticalQuadratureWeights,variables=["F","G"], ...
                gramTolerance=wvt.apvGramTolerance,quadraticAliasingTolerance=wvt.quadraticAliasingTolerance);
            mdaTransform = mdaBasis.discreteTransform(z=wvt.z,weights=wvt.verticalQuadratureWeights,variables="G",gramTolerance=wvt.mdaGramTolerance);

            testCase.verifyEqual(wvt.apvModeNumber,apvTransform.modeNumber(:),AbsTol=0)
            testCase.verifyEqual(wvt.mdaModeNumber,mdaTransform.modeNumber(:),AbsTol=0)
            testCase.verifyEqual(wvt.apvF,apvTransform.inverseMatrix(variable="F"),AbsTol=0)
            testCase.verifyEqual(wvt.apvGForward,apvTransform.forwardMatrix(variable="G"),AbsTol=0)
            testCase.verifyEqual(wvt.mdaGForward,mdaTransform.forwardMatrix(variable="G"),AbsTol=0)
        end

        function verticalResolutionAssessmentBracketsTheHorizontalLimit(testCase)
            N2 = @(z) 1e-4*ones(size(z));
            assessment = WVTransformFreeSurfaceQG.assessVerticalResolution(4000,17,N2Function=N2,latitude=30,g0=0.02,gd=Inf);
            testCase.verifyTrue(assessment.isHorizontalLimitApplicable)
            testCase.verifyLessThanOrEqual(assessment.maximumSupportedError,assessment.quadraticAliasingTolerance)
            testCase.verifyGreaterThan(assessment.firstRejectedError,assessment.quadraticAliasingTolerance)
            testCase.verifyLessThanOrEqual(assessment.firstRejectedKh/assessment.maximumSupportedKh-1,0.01)
            testCase.verifyEqual(assessment.minimumHorizontalWavelength,2*pi/assessment.maximumSupportedKh,RelTol=10*eps)
            testCase.verifyError(@()WVTransformFreeSurfaceQG([150e3 150e3 4000],[256 256 17], ...
                N2Function=N2,latitude=30,g0=0.02,gd=Inf),'WVTransformFreeSurfaceQG:UnderresolvedVerticalGrid')
        end

        function omittedEndpointDefaultsRetainSignedAPVAndUseMajorant(testCase)
            D = 4000;
            N2 = @(z) (5.2e-3)^2*exp(2*z/1300);
            expectedG0 = -integral(N2,-D,0);
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 D],[8 8 33], ...
                N2Function=N2,latitude=30);

            testCase.verifyEqual(wvt.g0,expectedG0,AbsTol=0)
            testCase.verifyEqual(wvt.gd,Inf,AbsTol=0)
            testCase.verifyEqual(wvt.quadraticAliasingTolerance,0.1,AbsTol=0)
            testCase.verifyEqual(wvt.apvModeNumber(1),-1,AbsTol=0)
            testCase.verifyTrue(isfinite(wvt.quadraticAliasingError))
            testCase.verifyLessThanOrEqual(wvt.quadraticAliasingError,0.1)
            testCase.verifyEqual(wvt.modeSelectionMethod,"fixed-native-quadrature-v1")
        end

        function scientificGridAndModeCountsAreNotCallerSelected(testCase)
            testCase.verifyError(@()WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,Nj=2,g0=0.02,gd=0.03), ...
                'MATLAB:TooManyInputs')
            z = linspace(-1000,0,33).';
            testCase.verifyError(@()WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03,z=z), ...
                'WVTransformFreeSurfaceQG:CustomVerticalGridUnavailable')
        end

        function initializationTolerancesArePersisted(testCase)
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03, ...
                apvGramTolerance=0.02,mdaGramTolerance=0.03,quadraticAliasingTolerance=0.2,muTolerance=1e-7);
            testCase.verifyEqual(wvt.apvGramTolerance,0.02,AbsTol=0)
            testCase.verifyEqual(wvt.mdaGramTolerance,0.03,AbsTol=0)
            testCase.verifyEqual(wvt.quadraticAliasingTolerance,0.2,AbsTol=0)
            testCase.verifyEqual(wvt.muTolerance,1e-7,AbsTol=0)
            testCase.verifyLessThanOrEqual(wvt.apvGramError,wvt.apvGramTolerance)
            testCase.verifyLessThanOrEqual(wvt.mdaGramError,wvt.mdaGramTolerance)
            testCase.verifyGreaterThan(wvt.minimumRelativeMuSeparation,wvt.muTolerance)
            testCase.verifyEqual(wvt.verticalGridKind,"chebyshevLobatto")
            testCase.verifyEqual(wvt.verticalGridCoordinate,"wkb")
        end

        function densityOnlyConstructionUsesDomainSafeStratification(testCase)
            rho0 = 1025;
            g = 9.81;
            N2 = 1e-4;
            rho = @(z) rho0-(rho0/g)*N2*z;
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                rhoFunction=rho,rho0=rho0,g=g,latitude=30,g0=0.02,gd=Inf,mdaGramTolerance=0.1);
            testCase.verifyGreaterThan(wvt.Nj,0)
            testCase.verifyEqual(wvt.N2,N2*ones(wvt.Nz,1),RelTol=3e-9)
            testCase.verifyEqual(wvt.rho_nm0,rho(wvt.z),RelTol=2e-14)
        end

        function canonicalFamiliesRoundTripIndependentlyAndTogether(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            Ag_q = TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_q),0.01);
            Ag_0 = TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_0),0.02);
            Amda = reshape((1:length(wvt.mdaMode))/7,[],1);

            [APV,endpointAnomalies] = wvt.transformStateBack(Ag_q,zeros(size(Ag_0)));
            [actualAPV,actualZero] = wvt.transformStateForward(APV,endpointAnomalies);
            testCase.verifyEqual(actualAPV,Ag_q,AbsTol=2e-12)
            testCase.verifyEqual(actualZero,zeros(size(Ag_0)),AbsTol=2e-11)

            [APV,endpointAnomalies] = wvt.transformStateBack(zeros(size(Ag_q)),Ag_0);
            [actualAPV,actualZero] = wvt.transformStateForward(APV,endpointAnomalies);
            testCase.verifyEqual(actualAPV,zeros(size(Ag_q)),AbsTol=2e-12)
            testCase.verifyEqual(actualZero,Ag_0,AbsTol=2e-11)

            [APV,endpointAnomalies] = wvt.transformStateBack(Ag_q,Ag_0);
            [actualAPV,actualZero] = wvt.transformStateForward(APV,endpointAnomalies);
            testCase.verifyEqual(actualAPV,Ag_q,AbsTol=2e-12)
            testCase.verifyEqual(actualZero,Ag_0,AbsTol=2e-11)

            etaMean = wvt.transformMDABack(Amda);
            testCase.verifyEqual(wvt.transformMDAForward(etaMean),Amda,AbsTol=2e-12)

            wvt.Ag_q = Ag_q;
            wvt.Ag_0 = Ag_0;
            wvt.Amda = Amda;
            [psiHat,etaHat,qHat] = wvt.reconstructSpectralState();
            testCase.verifySize(psiHat,[wvt.Nz,wvt.Nkl])
            testCase.verifySize(etaHat,[wvt.Nz,wvt.Nkl])
            testCase.verifySize(qHat,[wvt.Nz,wvt.Nkl])
            testCase.verifyTrue(all(isfinite([psiHat(:);etaHat(:);qHat(:)])))
        end

        function nonlinearAdvectionSuppliesAndProjectsTheCompleteQGState(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            TestWVTransformFreeSurfaceQG.setMixedState(wvt,1);
            nonlinear = wvt.forcingWithName('nonlinear advection');
            [q,u,v,b,ub,vb] = wvt.quasigeostrophicSpatialState();
            [psiHat,~,~] = wvt.reconstructSpectralState();
            endpointVerticalIndex = [wvt.Nz 1];
            endpointVerticalIndex = endpointVerticalIndex(wvt.activeEndpoint);
            expectedUb = TestWVTransformFreeSurfaceQG.endpointSpectralToSpatial(wvt, ...
                -sqrt(-1)*reshape(wvt.l,1,[]).*psiHat(endpointVerticalIndex,:));
            expectedVb = TestWVTransformFreeSurfaceQG.endpointSpectralToSpatial(wvt, ...
                sqrt(-1)*reshape(wvt.k,1,[]).*psiHat(endpointVerticalIndex,:));
            testCase.verifyEqual(ub,expectedUb,AbsTol=32*eps(max(1,max(abs(expectedUb),[],"all"))))
            testCase.verifyEqual(vb,expectedVb,AbsTol=32*eps(max(1,max(abs(expectedVb),[],"all"))))
            expectedFq = -(u.*wvt.diffX(q)+v.*wvt.diffY(q));
            expectedFb = -(ub.*wvt.diffX(b)+vb.*wvt.diffY(b));
            [Fq,Fb] = nonlinear.addQuasigeostrophicSpatialForcing(wvt,zeros(size(q)),zeros(size(b)));
            testCase.verifyEqual(Fq,expectedFq,AbsTol=5e-14)
            testCase.verifyEqual(Fb,expectedFb,AbsTol=5e-14)
            testCase.verifyTrue(isreal(Fq))
            testCase.verifyTrue(isreal(Fb))

            expected = wvt.projectQuasigeostrophicSpatialTendency(expectedFq,expectedFb);
            actual = wvt.coefficientTendency();
            testCase.verifyEqual(actual.Ag_q,expected.Ag_q,AbsTol=5e-13)
            testCase.verifyEqual(actual.Ag_0,expected.Ag_0,AbsTol=5e-11)
            testCase.verifyEqual(actual.Amda,zeros(size(wvt.Amda)),AbsTol=0)
            testCase.verifyGreaterThan(norm(actual.Ag_q(:))+norm(actual.Ag_0(:)),0)
        end

        function sharedPhysicalStateMatchesDirectForcingEvaluation(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            TestWVTransformFreeSurfaceQG.setMixedState(wvt,2);
            [q,u,v,b,ub,vb] = wvt.quasigeostrophicSpatialState();
            physicalState = struct('q',q,'u',u,'v',v,'b',b,'ub',ub,'vb',vb, ...
                'uvMax',max(hypot(u,v),[],"all"));

            nonlinear = wvt.forcingWithName('nonlinear advection');
            [directFq,directFb] = nonlinear.addQuasigeostrophicSpatialForcing(wvt,zeros(size(q)),zeros(size(b)));
            [sharedFq,sharedFb] = nonlinear.addQuasigeostrophicSpatialForcing(wvt,zeros(size(q)),zeros(size(b)),physicalState);
            testCase.verifyEqual(sharedFq,directFq,AbsTol=0)
            testCase.verifyEqual(sharedFb,directFb,AbsTol=0)

            beta = WVBetaPlanePVAdvection(wvt);
            [directFq,directFb] = beta.addQuasigeostrophicSpatialForcing(wvt,zeros(size(q)),zeros(size(b)));
            [sharedFq,sharedFb] = beta.addQuasigeostrophicSpatialForcing(wvt,zeros(size(q)),zeros(size(b)),physicalState);
            testCase.verifyEqual(sharedFq,directFq,AbsTol=0)
            testCase.verifyEqual(sharedFb,directFb,AbsTol=0)

            damping = WVAdaptiveDamping(wvt);
            incoming = struct('Ag_q',complex(zeros(size(wvt.Ag_q))), ...
                'Ag_0',complex(zeros(size(wvt.Ag_0))),'Amda',zeros(size(wvt.Amda)));
            direct = damping.addQuasigeostrophicSpectralForcing(wvt,incoming);
            shared = damping.addQuasigeostrophicSpectralForcing(wvt,incoming,physicalState);
            testCase.verifyEqual(shared,direct,AbsTol=0)
        end

        function manufacturedPhysicalTendencyRecoversBothCanonicalFamilies(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            expectedAgq = TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_q),2e-7);
            expectedAg0 = TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_0),3e-7);
            [FqNonzero,FbNonzero] = wvt.transformStateBack(expectedAgq,expectedAg0);
            FqHat = complex(zeros(wvt.Nz,wvt.Nkl));
            FqHat(:,wvt.klNonzero) = FqNonzero;
            FbHat = complex(zeros(wvt.activeEndpointCount,wvt.Nkl));
            FbHat(:,wvt.klNonzero) = FbNonzero;
            Fq = wvt.transformToSpatialDomainWithFourier(FqHat);
            Fb = TestWVTransformFreeSurfaceQG.endpointSpectralToSpatial(wvt,FbHat);

            actual = wvt.projectQuasigeostrophicSpatialTendency(Fq,Fb);
            testCase.verifyEqual(actual.Ag_q,expectedAgq,AbsTol=2e-18)
            testCase.verifyEqual(actual.Ag_0,expectedAg0,AbsTol=1e-16)
            testCase.verifyEqual(actual.Amda,zeros(size(wvt.Amda)),AbsTol=0)
        end

        function nonlinearTendencyRespectsEveryEndpointConfiguration(testCase)
            endpointValues = [Inf Inf;0.02 Inf;Inf 0.03;0.02 0.03];
            for iCase = 1:size(endpointValues,1)
                wvt = TestWVTransformFreeSurfaceQG.newTransform(endpointValues(iCase,1),endpointValues(iCase,2));
                TestWVTransformFreeSurfaceQG.setMixedState(wvt,iCase);
                tendency = wvt.coefficientTendency();
                testCase.verifySize(tendency.Ag_q,size(wvt.Ag_q))
                testCase.verifyEqual(size(tendency.Ag_0),size(wvt.Ag_0))
                testCase.verifyEqual(tendency.Amda,zeros(size(wvt.Amda)),AbsTol=0)
                testCase.verifyTrue(all(isfinite([tendency.Ag_q(:);tendency.Ag_0(:)])))

                wvt.removeAllForcing();
                tendency = wvt.coefficientTendency();
                testCase.verifyEqual(tendency.Ag_q,zeros(size(wvt.Ag_q)),AbsTol=0)
                testCase.verifyEqual(tendency.Ag_0,zeros(size(wvt.Ag_0)),AbsTol=0)
                testCase.verifyEqual(tendency.Amda,zeros(size(wvt.Amda)),AbsTol=0)
            end
        end

        function shiftedGaussianEddyPopulatesEveryCanonicalFamily(testCase)
            endpointValues = [Inf Inf;0.02 Inf;Inf 0.03;0.02 0.03];
            U = 0.05;
            Le = 20e3;
            He = 250;
            zc = 75;
            center = [0.35 0.65].*[100e3 100e3];
            for iCase = 1:size(endpointValues,1)
                wvt = TestWVTransformFreeSurfaceQG.newTransform(endpointValues(iCase,1),endpointValues(iCase,2));
                TestWVTransformFreeSurfaceQG.setMixedState(wvt,iCase);
                wvt.addToVariableCache('u',17);
                wvt.initWithGaussianEddy(maximumSpeed=U,horizontalRadius=Le,verticalScale=He,zCenter=zc,center=center);

                testCase.verifyGreaterThan(norm(wvt.Ag_q(:)),0)
                testCase.verifyGreaterThan(norm(wvt.Amda(:)),0)
                testCase.verifyEqual(size(wvt.Ag_0),[wvt.activeEndpointCount length(wvt.klNonzero)])
                if wvt.activeEndpointCount > 0
                    testCase.verifyGreaterThan(norm(wvt.Ag_0(:)),0)
                else
                    testCase.verifyEmpty(wvt.Ag_0)
                end
                testCase.verifyEmpty(wvt.fetchFromVariableCache('u'))

                [qNonzero,bNonzero] = wvt.transformStateBack(wvt.Ag_q,wvt.Ag_0);
                [AgqRoundTrip,Ag0RoundTrip] = wvt.transformStateForward(qNonzero,bNonzero);
                testCase.verifyEqual(AgqRoundTrip,wvt.Ag_q,AbsTol=2e-12*max(1,max(abs(wvt.Ag_q),[],"all")))
                if isempty(wvt.Ag_0)
                    testCase.verifyEqual(Ag0RoundTrip,wvt.Ag_0)
                else
                    testCase.verifyEqual(Ag0RoundTrip,wvt.Ag_0,AbsTol=2e-11*max(1,max(abs(wvt.Ag_0),[],"all")))
                end

                etaMean = wvt.transformMDABack(wvt.Amda);
                testCase.verifyEqual(wvt.transformMDAForward(etaMean),wvt.Amda,AbsTol=2e-12*max(1,max(abs(wvt.Amda),[],"all")))
                expectedMean = TestWVTransformFreeSurfaceQG.gaussianMeanDisplacement(wvt,U,Le,He,zc);
                if isfinite(wvt.g0) && isfinite(wvt.gd)
                    relativeMeanError = norm(etaMean-expectedMean)/max(norm(expectedMean),realmin);
                    testCase.verifyLessThanOrEqual(relativeMeanError,wvt.mdaGramTolerance)
                end
                if isinf(wvt.g0)
                    testCase.verifyEqual(etaMean(end),0,AbsTol=2e-12)
                end
                if isinf(wvt.gd)
                    testCase.verifyEqual(etaMean(1),0,AbsTol=2e-12)
                end
            end
        end

        function gaussianVerticalCenterExposesSurfaceDisplacement(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            U = 0.05;
            Le = 20e3;
            He = 250;
            centeredMean = TestWVTransformFreeSurfaceQG.gaussianMeanDisplacement(wvt,U,Le,He,0);
            shiftedMean = TestWVTransformFreeSurfaceQG.gaussianMeanDisplacement(wvt,U,Le,He,75);
            testCase.verifyEqual(centeredMean(end),0,AbsTol=0)
            testCase.verifyNotEqual(shiftedMean(end),0)

            wvt.initWithGaussianEddy(maximumSpeed=U,horizontalRadius=Le,verticalScale=He,zCenter=75);
            actualMean = wvt.transformMDABack(wvt.Amda);
            testCase.verifyEqual(sign(actualMean(end)),sign(shiftedMean(end)))
            testCase.verifyGreaterThan(abs(actualMean(end)),0)
        end

        function adaptiveGaussianEvolutionUsesDirectSpeedDiagnostic(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            wvt.initWithGaussianEddy(maximumSpeed=0.05,horizontalRadius=20e3,verticalScale=250,zCenter=75);
            expectedSpeed = max(hypot(wvt.u,wvt.v),[],"all");
            testCase.verifyEqual(wvt.uvMax,expectedSpeed,AbsTol=32*eps(expectedSpeed))

            initialAmda = wvt.Amda;
            wvt.addForcing(WVBetaPlanePVAdvection(wvt));
            wvt.addForcing(WVAdaptiveDamping(wvt));
            testCase.verifyTrue(wvt.hasClosure)
            model = WVModel(wvt,shouldUseLinearDynamics=false);
            model.setupIntegrator(integratorType="adaptive",relTolerance=1e-3,absTolerance=1e-6);
            model.integrateToTime(2000,shouldShowIntegrationDiagnostics=false);

            testCase.verifyEqual(wvt.t,2000,AbsTol=0)
            testCase.verifyEqual(wvt.Amda,initialAmda,AbsTol=0)
            testCase.verifyTrue(all(isfinite([wvt.Ag_q(:);wvt.Ag_0(:);wvt.Amda(:)])))
        end

        function adaptiveDampingActsOnFreeSurfaceCoefficientFamilies(testCase)
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            wvt.removeAllForcing();
            wvt.Ag_q = TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_q),2e-3);
            wvt.Ag_0 = TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_0),3e-3);
            wvt.Amda = reshape((1:wvt.mdaModeCount)/11,[],1);
            damping = WVAdaptiveDamping(wvt);
            wvt.addForcing(damping);

            testCase.verifySize(damping.dampAg_q,size(wvt.Ag_q))
            testCase.verifySize(damping.dampAg_0,size(wvt.Ag_0))
            testCase.verifyTrue(all(damping.dampAg_q <= 0,"all"))
            testCase.verifyTrue(all(damping.dampAg_0 <= 0,"all"))
            testCase.verifyTrue(any(damping.dampAg_q < 0,"all"))
            testCase.verifyTrue(any(damping.dampAg_0 < 0,"all"))

            expected = struct('Ag_q',complex(zeros(size(wvt.Ag_q))), ...
                'Ag_0',complex(zeros(size(wvt.Ag_0))),'Amda',zeros(size(wvt.Amda)));
            expected = damping.addQuasigeostrophicSpectralForcing(wvt,expected);
            actual = wvt.coefficientTendency();
            testCase.verifyEqual(actual.Ag_q,expected.Ag_q,AbsTol=0)
            testCase.verifyEqual(actual.Ag_0,expected.Ag_0,AbsTol=0)
            testCase.verifyEqual(actual.Amda,zeros(size(wvt.Amda)),AbsTol=0)
            testCase.verifyGreaterThan(norm(actual.Ag_q(:))+norm(actual.Ag_0(:)),0)

            noEndpointTransform = TestWVTransformFreeSurfaceQG.newTransform(Inf,Inf);
            noEndpointDamping = WVAdaptiveDamping(noEndpointTransform);
            testCase.verifySize(noEndpointDamping.dampAg_0,size(noEndpointTransform.Ag_0))
        end

        function betaPlaneGaussianEvolutionConvergesUnderRefinement(testCase)
            horizontalCounts = [12 24 48];
            verticalCounts = [33 65 129];
            initialValues = cell(3,1);
            finalValues = cell(3,1);
            timeRefinedReference = [];
            for iResolution = 1:3
                wvt = WVTransformFreeSurfaceQG([200e3 200e3 1000], ...
                    [horizontalCounts(iResolution) horizontalCounts(iResolution) verticalCounts(iResolution)], ...
                    N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03,mdaGramTolerance=0.1);
                wvt.initWithGaussianEddy(maximumSpeed=0.05,horizontalRadius=40e3,verticalScale=250,zCenter=75);
                initialValues{iResolution} = TestWVTransformFreeSurfaceQG.lowModeSurfaceStreamfunction(wvt,2);
                initialAmda = wvt.Amda;
                initialAgq = wvt.Ag_q;
                initialAg0 = wvt.Ag_0;

                wvt.addForcing(WVBetaPlanePVAdvection(wvt));
                model = WVModel(wvt,shouldUseLinearDynamics=false);
                model.setupIntegrator(integratorType="fixed",deltaT=500);
                model.integrateToTime(4000,shouldShowIntegrationDiagnostics=false);

                finalValues{iResolution} = TestWVTransformFreeSurfaceQG.lowModeSurfaceStreamfunction(wvt,2);
                testCase.verifyEqual(wvt.Amda,initialAmda,AbsTol=0)
                if iResolution == 3
                    wvt.Ag_q = initialAgq;
                    wvt.Ag_0 = initialAg0;
                    wvt.Amda = initialAmda;
                    wvt.t = 0;
                    refinedModel = WVModel(wvt,shouldUseLinearDynamics=false);
                    refinedModel.setupIntegrator(integratorType="fixed",deltaT=250);
                    refinedModel.integrateToTime(4000,shouldShowIntegrationDiagnostics=false);
                    timeRefinedReference = TestWVTransformFreeSurfaceQG.lowModeSurfaceStreamfunction(wvt,2);
                    testCase.verifyEqual(wvt.Amda,initialAmda,AbsTol=0)
                end
            end

            referenceChange = timeRefinedReference-initialValues{3};
            coarseError = norm((finalValues{1}-initialValues{1})-referenceChange)/max(norm(referenceChange),realmin);
            mediumError = norm((finalValues{2}-initialValues{2})-referenceChange)/max(norm(referenceChange),realmin);
            timeError = norm((finalValues{3}-initialValues{3})-referenceChange)/max(norm(referenceChange),realmin);
            testCase.verifyLessThan(mediumError,coarseError)
            testCase.verifyLessThanOrEqual(mediumError,0.1)
            testCase.verifyLessThanOrEqual(timeError,max(0.25*mediumError,1e-10))
        end

        function axialAndObliqueEntriesReuseTheirKhPage(testCase)
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[16 16 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03,mdaGramTolerance=0.1);
            dk = 2*pi/wvt.Lx;
            axial = find(abs(wvt.kNonzero-5*dk) < 50*eps(dk) & abs(wvt.lNonzero) < 10*eps(dk),1);
            oblique = find(abs(wvt.kNonzero-3*dk) < 30*eps(dk) & abs(wvt.lNonzero-4*dk) < 40*eps(dk),1);
            testCase.assertNotEmpty(axial)
            testCase.assertNotEmpty(oblique)
            testCase.verifyEqual(wvt.klNonzeroKhUniqueIndex(axial),wvt.klNonzeroKhUniqueIndex(oblique))
            iKh = wvt.klNonzeroKhUniqueIndex(axial);
            testCase.verifyEqual(wvt.zeroAPVF(:,:,iKh),wvt.zeroAPVF(:,:,wvt.klNonzeroKhUniqueIndex(oblique)),AbsTol=0)
            testCase.verifyEqual(wvt.zeroAPVG(:,:,iKh),wvt.zeroAPVG(:,:,wvt.klNonzeroKhUniqueIndex(oblique)),AbsTol=0)
        end

        function maximumKhZeroAPVResponsesRemainBoundaryNormalized(testCase)
            endpointValues = [0.02 Inf;Inf 0.03;0.02 0.03];
            for iCase = 1:size(endpointValues,1)
                wvt = TestWVTransformFreeSurfaceQG.newTransform(endpointValues(iCase,1),endpointValues(iCase,2));
                iKh = length(wvt.khUnique);
                surfaceResponse = reshape(wvt.zeroAPVG(end,:,iKh)-wvt.zeroAPVF(end,:,iKh),1,[]);
                bottomResponse = reshape(wvt.zeroAPVG(1,:,iKh),1,[]);
                endpointResponse = [surfaceResponse;bottomResponse];
                testCase.verifyEqual(endpointResponse(wvt.activeEndpoint,:),eye(wvt.activeEndpointCount),AbsTol=2e-10)
                inactiveEndpoint = setdiff((1:2).',wvt.activeEndpoint);
                testCase.verifyEqual(endpointResponse(inactiveEndpoint,:),zeros(length(inactiveEndpoint),wvt.activeEndpointCount),AbsTol=2e-10)
            end
        end

        function constantStratificationZeroAPVModesMatchAnalyticSolution(testCase)
            D = 1000;
            N0 = 1e-2;
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 D],[16 16 33], ...
                N2Function=@(z)N0^2*ones(size(z)),latitude=30,g0=0.02,gd=0.03,mdaGramTolerance=0.1);
            kh = wvt.khUnique(end);
            [expectedF,expectedG] = TestWVTransformFreeSurfaceQG.constantZeroAPVExactModes(wvt.z,["surface" "bottom"],kh,D,N0,wvt.f,wvt.g);
            testCase.verifyEqual(wvt.zeroAPVF(:,:,end),expectedF,RelTol=2e-9,AbsTol=2e-10)
            testCase.verifyEqual(wvt.zeroAPVG(:,:,end),expectedG,RelTol=2e-9,AbsTol=2e-10)
        end

        function variableStratificationZeroAPVModesConvergeSpectrally(testCase)
            D = 4000;
            Nz = 33;
            N0 = 5.2e-3;
            N2 = @(z) N0^2*exp(2*z/1300);
            wvt = WVTransformFreeSurfaceQG([150e3 150e3 D],[64 64 Nz],N2Function=N2,latitude=30,g0=NaN,gd=Inf);
            kh = wvt.khUnique(end);
            problem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2,zDomain=[-D 0],f0=wvt.f,g=wvt.g,k=kh,endpoints="surface",surfaceBoundary="freeSurface");
            productionOrder = max(96,3*(Nz+4));
            actualModes = IMSolverSpectral(nEVP=productionOrder).solveGeostrophicZeroAPVModes(problem);
            referenceSolver = IMSolverSpectral(nEVP=2*productionOrder).configuredForGeostrophicZeroAPVModes(problem);
            [zReference,~] = referenceSolver.nativeQuadratureRule(problem.zDomain);
            referenceModes = referenceSolver.solveGeostrophicZeroAPVModes(problem);
            actualF = actualModes.F(zReference);
            actualG = actualModes.G(zReference);
            referenceF = referenceModes.F(zReference);
            referenceG = referenceModes.G(zReference);
            relativeFError = max(abs(actualF-referenceF),[],'all')/max(abs(referenceF),[],'all');
            relativeGError = max(abs(actualG-referenceG),[],'all')/max(abs(referenceG),[],'all');

            testCase.verifyLessThan(relativeFError,1e-7)
            testCase.verifyLessThan(relativeGError,1e-7)
            sampledF = actualModes.F(wvt.z);
            sampledG = actualModes.G(wvt.z);
            testCase.verifyLessThan(max(abs(wvt.zeroAPVF(:,:,end)-sampledF),[],'all')/max(abs(sampledF),[],'all'),1e-10)
            testCase.verifyLessThan(max(abs(wvt.zeroAPVG(:,:,end)-sampledG),[],'all')/max(abs(sampledG),[],'all'),1e-10)
        end

        function selectedNonlinearTendencyIsStableUnderGridRefinement(testCase)
            coarse = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03,mdaGramTolerance=0.1);
            horizontalReference = WVTransformFreeSurfaceQG([100e3 100e3 1000],[16 16 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03,mdaGramTolerance=0.1);
            verticalReference = WVTransformFreeSurfaceQG([100e3 100e3 1000],[16 16 65], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=0.02,gd=0.03,mdaGramTolerance=0.1);

            for stateKind = ["apv" "endpoint" "mixed"]
                TestWVTransformFreeSurfaceQG.setRefinementState(coarse,stateKind);
                TestWVTransformFreeSurfaceQG.setRefinementState(horizontalReference,stateKind);
                TestWVTransformFreeSurfaceQG.setRefinementState(verticalReference,stateKind);
                coarseTendency = TestWVTransformFreeSurfaceQG.selectedRefinementTendency(coarse);
                horizontalTendency = TestWVTransformFreeSurfaceQG.selectedRefinementTendency(horizontalReference);
                verticalTendency = TestWVTransformFreeSurfaceQG.selectedRefinementTendency(verticalReference);
                testCase.verifyGreaterThan(norm(verticalTendency),0,stateKind)
                referenceScale = max(norm(verticalTendency),realmin);
                testCase.verifyLessThanOrEqual(norm(coarseTendency-horizontalTendency)/referenceScale,2e-10,stateKind)
                testCase.verifyLessThanOrEqual(norm(horizontalTendency-verticalTendency)/referenceScale,0.1,stateKind)
            end
        end

        function nearLimitAPVEndpointCrossTendencyMeetsVerticalTolerance(testCase)
            D = 4000;
            N2 = @(z) (5.2e-3)^2*exp(2*z/1300);
            gd = 0.03;
            assessment = WVTransformFreeSurfaceQG.assessVerticalResolution(D,33,N2Function=N2,latitude=30,g0=NaN,gd=gd);

            unitGeometry = WVGeometryDoublyPeriodic(2*pi*[1 1],[16 16],shouldAntialias=true,Nz=1, ...
                shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            kIndex = round(unitGeometry.k/unitGeometry.dk);
            lIndex = round(unitGeometry.l/unitGeometry.dl);
            khIndex = hypot(kIndex,lIndex);
            maximumKhIndex = max(khIndex);
            targetIndex = find(kIndex > 0 & lIndex > 0 & abs(khIndex-maximumKhIndex) <= 32*eps(maximumKhIndex),1);
            testCase.assertNotEmpty(targetIndex)
            targetKIndex = kIndex(targetIndex);
            targetLIndex = lIndex(targetIndex);
            dk = 0.95*assessment.maximumSupportedKh/maximumKhIndex;
            L = 2*pi/dk;

            NzValues = [33 65 129];
            transforms = cell(size(NzValues));
            crossTendencies = cell(size(NzValues));
            limitingEndpointCode = find(["surface" "bottom"] == assessment.limitingEndpoint,1);
            testCase.assertNotEmpty(limitingEndpointCode)
            for iResolution = 1:length(NzValues)
                transforms{iResolution} = WVTransformFreeSurfaceQG([L L D],[16 16 NzValues(iResolution)], ...
                    N2Function=N2,latitude=30,g0=NaN,gd=gd);
                crossTendencies{iResolution} = TestWVTransformFreeSurfaceQG.isolatedAPVEndpointCrossTendency( ...
                    transforms{iResolution},assessment.limitingAPVModeNumber,limitingEndpointCode, ...
                    [0 targetLIndex],[targetKIndex 0]);
            end
            testCase.verifyEqual(max(transforms{1}.khUnique)/assessment.maximumSupportedKh,0.95,RelTol=64*eps)

            reference = transforms{end};
            referenceTendency = crossTendencies{end};
            referenceOutputIndex = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(reference,targetKIndex,targetLIndex);
            relativeErrors = zeros(2,2);
            for iResolution = 1:2
                wvt = transforms{iResolution};
                tendency = crossTendencies{iResolution};
                outputIndex = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,targetKIndex,targetLIndex);
                [hasReferenceMode,referenceModeIndex] = ismember(wvt.apvModeNumber,reference.apvModeNumber);
                testCase.assertTrue(all(hasReferenceMode))
                referenceAgq = referenceTendency.Ag_q(referenceModeIndex,referenceOutputIndex);
                referenceAg0 = referenceTendency.Ag_0(:,referenceOutputIndex);
                testCase.verifyGreaterThan(norm(referenceAgq),0)
                testCase.verifyGreaterThan(norm(referenceAg0),0)
                relativeErrors(iResolution,1) = norm(tendency.Ag_q(:,outputIndex)-referenceAgq)/norm(referenceAgq);
                relativeErrors(iResolution,2) = norm(tendency.Ag_0(:,outputIndex)-referenceAg0)/norm(referenceAg0);
                testCase.verifyLessThanOrEqual(relativeErrors(iResolution,:),wvt.quadraticAliasingTolerance)
                testCase.verifyEqual(tendency.Amda,zeros(size(wvt.Amda)),AbsTol=0)
            end
            testCase.verifyLessThan(relativeErrors(2,:),relativeErrors(1,:))
        end

        function snapshotPersistsRepresentationAndDirectConstructionSkipsModeSolver(testCase)
            path = fullfile(testCase.temporaryFolder,"snapshot.nc");
            scientific = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            TestWVTransformFreeSurfaceQG.setMixedState(scientific,2);
            scientific.addForcing(WVAdaptiveDamping(scientific));
            ncfile = scientific.writeToFile(char(path));
            ncfile.close();

            restored = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(char(path));
            TestWVTransformFreeSurfaceQG.verifySameRepresentation(testCase,restored,scientific)
            testCase.verifyEmpty(restored.verticalModes)
            [actualPsi,actualEta,actualQ] = restored.reconstructSpectralState();
            [expectedPsi,expectedEta,expectedQ] = scientific.reconstructSpectralState();
            testCase.verifyEqual(actualPsi,expectedPsi)
            testCase.verifyEqual(actualEta,expectedEta)
            testCase.verifyEqual(actualQ,expectedQ)
            restoredDamping = restored.forcingWithName('adaptive damping');
            scientificDamping = scientific.forcingWithName('adaptive damping');
            testCase.verifyClass(restoredDamping,"WVAdaptiveDamping")
            testCase.verifyEqual(restoredDamping.dampAg_q,scientificDamping.dampAg_q,AbsTol=0)
            testCase.verifyEqual(restoredDamping.dampAg_0,scientificDamping.dampAg_0,AbsTol=0)

            directOptions = TestWVTransformFreeSurfaceQG.directOptions(scientific);
            directArguments = namedargs2cell(directOptions);
            direct = WVTransformFreeSurfaceQG([scientific.Lx scientific.Ly scientific.Lz], ...
                [scientific.Nx scientific.Ny scientific.Nz],directArguments{:});
            TestWVTransformFreeSurfaceQG.verifySameRepresentation(testCase,direct,scientific)
            testCase.verifyEmpty(direct.verticalModes)
        end

        function inactiveZeroFamilyIsPhysicallyOmitted(testCase)
            path = fullfile(testCase.temporaryFolder,"no-endpoints.nc");
            wvt = TestWVTransformFreeSurfaceQG.newTransform(Inf,Inf);
            ncfile = wvt.writeToFile(char(path));
            cleanup = onCleanup(@()TestWVTransformFreeSurfaceQG.closeIfOpen(ncfile));
            omittedNames = {'activeEndpoint','sourceEndpoint','Ag_0','apvEndpointResponse', ...
                'zeroAPVF','zeroAPVG','zeroAPVFPairing','zeroAPVGPairing', ...
                'zeroAPVSourceSolve','zeroAPVGramReciprocalCondition','zeroAPVGramRelativeSeparation', ...
                'apvZeroAPVQuadraticError','apvZeroAPVLimitingEndpoint','apvZeroAPVLimitingModeNumber'};
            for iName = 1:length(omittedNames)
                testCase.verifyFalse(ncfile.hasVariableWithName(omittedNames{iName}),omittedNames{iName})
            end
            testCase.verifyEqual(ncfile.readVariables('activeEndpointCount'),0)
            testCase.verifyTrue(all(ncfile.hasVariableWithName('Ag_q','Amda')))
            ncfile.close();
            clear cleanup

            restored = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(char(path));
            testCase.verifyEqual(size(restored.Ag_0),[0,length(restored.klNonzero)])
            testCase.verifyEmpty(restored.activeEndpoint)
        end

        function modelOutputUsesOneFlatCommittedCoefficientStream(testCase)
            path = fullfile(testCase.temporaryFolder,"model-output.nc");
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            model = WVModel(wvt,shouldUseLinearDynamics=false);
            outputFile = model.createNetCDFFileForModelOutput(path,outputInterval=1,shouldOverwriteExisting=true);
            fieldsGroup = outputFile.addNewEvenlySpacedOutputGroup("fields",outputInterval=2);
            fieldsGroup.addObservingSystem(WVEulerianFields(model,fieldNames={'u'}));
            times = outputFile.outputTimesForIntegrationPeriod(0,2);
            for iTime = 1:length(times)
                TestWVTransformFreeSurfaceQG.setMixedState(wvt,iTime);
                wvt.t = times(iTime);
                outputFile.writeTimeStepToOutputFile(times(iTime));
            end
            model.closeNetCDFFile();

            ncfile = NetCDFFile(char(path));
            cleanup = onCleanup(@()TestWVTransformFreeSurfaceQG.closeIfOpen(ncfile));
            testCase.verifyEqual(ncfile.variablePathsWithName('Ag_q'),"wave-vortex/Ag_q")
            testCase.verifyEqual(ncfile.variablePathsWithName('Ag_0'),"wave-vortex/Ag_0")
            testCase.verifyEqual(ncfile.variablePathsWithName('Amda'),"wave-vortex/Amda")
            testCase.verifyEqual(ncfile.readVariables('wave-vortex/t'),(0:2).')
            testCase.verifyEqual(ncfile.readVariables('fields/t'),[0;2])
            testCase.verifyEqual(WVModelOutputGroup.committedRecordCountForGroup(ncfile.groupWithName('wave-vortex')),3)
            ncfile.close();
            clear cleanup

            restored = WVModel.modelFromFile(char(path));
            restoredCleanup = onCleanup(@()restored.closeNetCDFFile());
            testCase.verifyEqual(restored.wvt.t,2)
            expected = TestWVTransformFreeSurfaceQG.stateForIndex(restored.wvt,3);
            testCase.verifyEqual(restored.wvt.Ag_q,expected.Ag_q)
            testCase.verifyEqual(restored.wvt.Ag_0,expected.Ag_0)
            testCase.verifyEqual(restored.wvt.Amda,expected.Amda)
            testCase.verifyTrue(restored.outputFileWithName('model-output.nc'). ...
                outputGroupWithName('wave-vortex').observingSystemWithName('wave-vortex coefficient flux') ...
                == restored.wvCoefficientFluxedObservingSystem())
            restored.closeNetCDFFile();
            clear restoredCleanup
        end

        function partialRecordIsIgnoredAndOverwrittenOnResume(testCase)
            path = fullfile(testCase.temporaryFolder,"partial-record.nc");
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            model = WVModel(wvt,shouldUseLinearDynamics=false);
            outputFile = model.createNetCDFFileForModelOutput(path,outputInterval=1,shouldOverwriteExisting=true);
            outputFile.outputTimesForIntegrationPeriod(0,1);

            TestWVTransformFreeSurfaceQG.setMixedState(wvt,1);
            wvt.t = 0;
            outputFile.writeTimeStepToOutputFile(0);
            TestWVTransformFreeSurfaceQG.setMixedState(wvt,2);
            outputGroup = outputFile.outputGroupWithName('wave-vortex');
            outputGroup.stageTimeStepToNetCDFFile(outputFile.ncfile,1);
            outputFile.ncfile.sync();
            model.closeNetCDFFile();

            restored = WVModel.modelFromFile(char(path));
            cleanup = onCleanup(@()restored.closeNetCDFFile());
            testCase.verifyEqual(restored.wvt.t,0)
            committed = TestWVTransformFreeSurfaceQG.stateForIndex(restored.wvt,1);
            testCase.verifyEqual(restored.wvt.Ag_q,committed.Ag_q)

            restoredFile = restored.outputFileWithName('partial-record.nc');
            testCase.verifyEqual(restoredFile.outputTimesForIntegrationPeriod(0,1),1)
            TestWVTransformFreeSurfaceQG.setMixedState(restored.wvt,3);
            restored.wvt.t = 1;
            restoredFile.writeTimeStepToOutputFile(1);
            restored.closeNetCDFFile();
            clear cleanup

            ncfile = NetCDFFile(char(path));
            fileCleanup = onCleanup(@()TestWVTransformFreeSurfaceQG.closeIfOpen(ncfile));
            testCase.verifyEqual(ncfile.readVariables('wave-vortex/t'),[0;1])
            expected = TestWVTransformFreeSurfaceQG.stateForIndex(restored.wvt,3);
            actual = ncfile.readVariablesAtIndexAlongDimension('t',2,'wave-vortex/Ag_q');
            testCase.verifyEqual(actual,expected.Ag_q)
        end

        function finiteTimePrefixRejectsHoles(testCase)
            path = fullfile(testCase.temporaryFolder,"record-hole.nc");
            ncfile = NetCDFFile(char(path),shouldOverwriteExisting=true);
            cleanup = onCleanup(@()TestWVTransformFreeSurfaceQG.closeIfOpen(ncfile));
            group = ncfile.addGroup('stream');
            attributes = containers.Map(KeyType='char',ValueType='any');
            attributes('_FillValue') = NaN;
            attributes('wvm_record_commit_protocol') = 'finite_time_prefix_v1';
            [~,timeVariable] = group.addDimension('t',length=Inf,type='double',attributes=attributes);
            payload = group.addVariable('payload',{'t'},[],type='double',isComplex=false);

            payload.setValueAlongDimensionAtIndex(20,'t',2);
            testCase.verifyEqual(WVModelOutputGroup.committedRecordCountForGroup(group),0)
            ncfile.sync();
            testCase.verifyEqual(WVModelOutputGroup.committedRecordCountForGroup(group),0)
            timeVariable.setValueAlongDimensionAtIndex(0,'t',1);
            ncfile.sync();
            testCase.verifyEqual(WVModelOutputGroup.committedRecordCountForGroup(group),1)
            timeVariable.setValueAlongDimensionAtIndex(2,'t',3);
            ncfile.sync();
            testCase.verifyError(@()WVModelOutputGroup.committedRecordCountForGroup(group), ...
                'WVModelOutputGroup:NoncontiguousCommittedRecords')
        end

        function timeCommitIsAcceptedWithoutAnExplicitFinalSync(testCase)
            path = fullfile(testCase.temporaryFolder,"committed-before-final-sync.nc");
            ncfile = NetCDFFile(char(path),shouldOverwriteExisting=true);
            attributes = containers.Map(KeyType='char',ValueType='any');
            attributes('_FillValue') = NaN;
            attributes('wvm_record_commit_protocol') = 'finite_time_prefix_v1';
            group = ncfile.addGroup('stream');
            [~,timeVariable] = group.addDimension('t',length=Inf,type='double',attributes=attributes);
            payload = group.addVariable('payload',{'t'},[],type='double',isComplex=false);
            payload.setValueAlongDimensionAtIndex(42,'t',1);
            ncfile.sync();
            timeVariable.setValueAlongDimensionAtIndex(5,'t',1);
            ncfile.close();

            reopened = NetCDFFile(char(path));
            cleanup = onCleanup(@()TestWVTransformFreeSurfaceQG.closeIfOpen(reopened));
            reopenedGroup = reopened.groupWithName('stream');
            testCase.verifyEqual(WVModelOutputGroup.committedRecordCountForGroup(reopenedGroup),1)
            testCase.verifyEqual(reopenedGroup.readVariables('t'),5)
            testCase.verifyEqual(reopenedGroup.readVariables('payload'),42)
        end

        function multipleCompleteStreamsAreRejectedBeforeCreation(testCase)
            path = fullfile(testCase.temporaryFolder,"duplicate-stream.nc");
            wvt = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            model = WVModel(wvt,shouldUseLinearDynamics=false);
            outputFile = model.createNetCDFFileForModelOutput(path,outputInterval=1,shouldOverwriteExisting=true);
            duplicate = outputFile.addNewEvenlySpacedOutputGroup('duplicate',outputInterval=1);
            names = wvt.coefficientStateVariableNamesForPersistence();
            duplicate.addObservingSystem(WVEulerianFields(model,fieldNames=names));
            outputFile.outputTimesForIntegrationPeriod(0,0);
            testCase.verifyError(@()outputFile.writeTimeStepToOutputFile(0), ...
                'WVModelOutputFile:MultipleCompleteCoefficientStreams')
            testCase.verifyFalse(isfile(path))
        end
    end

    methods (Static, Access=private)
        function wvt = newTransform(g0,gd)
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=g0,gd=gd,mdaGramTolerance=0.1);
        end

        function [F,G] = constantZeroAPVExactModes(z,endpoints,kh,D,N0,f0,g)
            z = z(:);
            verticalWavenumber = kh*N0/abs(f0);
            derivativeScale = g*verticalWavenumber/N0^2;
            oppositeBoundaryDecay = exp(-verticalWavenumber*D);
            responseMatrix = [ ...
                -(derivativeScale+1), (derivativeScale-1)*oppositeBoundaryDecay; ...
                -derivativeScale*oppositeBoundaryDecay, derivativeScale];
            coefficients = responseMatrix\eye(2);
            endpointColumns = zeros(1,numel(endpoints));
            endpointColumns(endpoints == "surface") = 1;
            endpointColumns(endpoints == "bottom") = 2;
            coefficients = coefficients(:,endpointColumns);
            surfaceDecay = exp(verticalWavenumber*z);
            bottomDecay = exp(-verticalWavenumber*(z+D));
            F = [surfaceDecay bottomDecay]*coefficients;
            G = -derivativeScale*[surfaceDecay -bottomDecay]*coefficients;
        end

        function value = complexState(matrixSize,scale)
            count = prod(matrixSize);
            value = scale*complex(reshape(1:count,matrixSize),reshape(count:-1:1,matrixSize));
        end

        function state = stateForIndex(wvt,index)
            state = struct();
            state.Ag_q = index*TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_q),0.01);
            state.Ag_0 = index*TestWVTransformFreeSurfaceQG.complexState(size(wvt.Ag_0),0.02);
            state.Amda = index*reshape((1:numel(wvt.Amda))/9,size(wvt.Amda));
        end

        function setMixedState(wvt,index)
            state = TestWVTransformFreeSurfaceQG.stateForIndex(wvt,index);
            wvt.Ag_q = state.Ag_q;
            wvt.Ag_0 = state.Ag_0;
            wvt.Amda = state.Amda;
        end

        function etaMean = gaussianMeanDisplacement(wvt,U,Le,He,zc)
            horizontalMean = pi*Le^2/(wvt.Lx*wvt.Ly);
            verticalStructure = exp(-((wvt.z-zc).^2)/(2*He^2));
            verticalDerivative = -((wvt.z-zc)/He^2).*verticalStructure;
            streamfunctionScale = U*(Le/sqrt(2))*exp(1/2);
            etaMean = -(wvt.f./wvt.N2).*(streamfunctionScale*horizontalMean*verticalDerivative);
        end

        function values = lowModeSurfaceStreamfunction(wvt,maximumMode)
            [psiHat,~,~] = wvt.reconstructSpectralState();
            kMode = reshape(wvt.kMode_wv,[],1);
            lMode = reshape(wvt.lMode_wv,[],1);
            selected = find(abs(kMode) <= maximumMode & abs(lMode) <= maximumMode);
            [~,order] = sortrows([kMode(selected) lMode(selected)],[1 2]);
            values = reshape(psiHat(end,selected(order)),[],1);
        end

        function values = endpointSpectralToSpatial(wvt,spectralValues)
            padded = complex(zeros(wvt.Nz,wvt.Nkl));
            padded(1:wvt.activeEndpointCount,:) = spectralValues;
            values = wvt.transformToSpatialDomainWithFourier(padded);
            values = values(:,:,1:wvt.activeEndpointCount);
        end

        function setRefinementState(wvt,stateKind)
            wvt.Ag_q = complex(zeros(size(wvt.Ag_q)));
            wvt.Ag_0 = complex(zeros(size(wvt.Ag_0)));
            wvt.Amda = zeros(size(wvt.Amda));
            i10 = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,1,0);
            i01 = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,0,1);
            if stateKind == "apv" || stateKind == "mixed"
                wvt.Ag_q(1,i10) = 2e-4+3e-4i;
                wvt.Ag_q(2,i01) = -1e-4+4e-4i;
            end
            if stateKind == "endpoint" || stateKind == "mixed"
                wvt.Ag_0(1,i10) = -3e-4+2e-4i;
                wvt.Ag_0(2,i01) = 4e-4-1e-4i;
            end
        end

        function tendency = isolatedAPVEndpointCrossTendency(wvt,apvModeNumber,endpointCode,apvHorizontalIndex,endpointHorizontalIndex)
            apvModeIndex = find(wvt.apvModeNumber == apvModeNumber,1);
            endpointIndex = find(wvt.activeEndpoint == endpointCode,1);
            testAPVIndex = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,apvHorizontalIndex(1),apvHorizontalIndex(2));
            testEndpointIndex = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,endpointHorizontalIndex(1),endpointHorizontalIndex(2));
            if isempty(apvModeIndex) || isempty(endpointIndex)
                error('TestWVTransformFreeSurfaceQG:MissingCrossTendencyMode','The requested APV mode or active endpoint is absent.');
            end

            Ag_q = complex(zeros(size(wvt.Ag_q)));
            Ag_0 = complex(zeros(size(wvt.Ag_0)));
            Ag_q(apvModeIndex,testAPVIndex) = 2e-4+3e-4i;
            Ag_0(endpointIndex,testEndpointIndex) = -3e-4+2e-4i;
            wvt.Amda = zeros(size(wvt.Amda));

            wvt.Ag_q = Ag_q;
            wvt.Ag_0 = Ag_0;
            mixedTendency = wvt.coefficientTendency();
            wvt.Ag_0 = complex(zeros(size(Ag_0)));
            apvTendency = wvt.coefficientTendency();
            wvt.Ag_q = complex(zeros(size(Ag_q)));
            wvt.Ag_0 = Ag_0;
            endpointTendency = wvt.coefficientTendency();

            tendency = struct();
            tendency.Ag_q = mixedTendency.Ag_q-apvTendency.Ag_q-endpointTendency.Ag_q;
            tendency.Ag_0 = mixedTendency.Ag_0-apvTendency.Ag_0-endpointTendency.Ag_0;
            tendency.Amda = mixedTendency.Amda-apvTendency.Amda-endpointTendency.Amda;
        end

        function values = selectedRefinementTendency(wvt)
            tendency = wvt.coefficientTendency();
            i11 = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,1,1);
            values = [tendency.Ag_q(1:2,i11);tendency.Ag_0(:,i11)];
        end

        function index = nonzeroIndexForMode(wvt,kIndex,lIndex)
            tolerance = 64*eps(max([abs(kIndex*wvt.dk),abs(lIndex*wvt.dl),wvt.dk,wvt.dl]));
            index = find(abs(wvt.kNonzero-kIndex*wvt.dk) <= tolerance ...
                & abs(wvt.lNonzero-lIndex*wvt.dl) <= tolerance,1);
            if isempty(index)
                error('TestWVTransformFreeSurfaceQG:MissingFourierMode','The requested retained Fourier mode is absent.');
            end
        end

        function verifySameRepresentation(testCase,actual,expected)
            names = {'g0','gd','activeEndpointCount','activeEndpoint','sourceEndpoint', ...
                'apvModeCount','mdaModeCount','apvMode','apvModeNumber','mdaMode','mdaModeNumber','klNonzero', ...
                'kNonzero','lNonzero','khNonzero','khUnique','klNonzeroKhUniqueIndex', ...
                'apvF','apvG','apvFForward','apvGForward','apvEquivalentDepth','apvMu', ...
                'apvEndpointResponse','apvFSourcePairing','apvGSourcePairing','mdaF', ...
                'mdaG','mdaGForward','mdaEquivalentDepth','verticalQuadratureWeights', ...
                'verticalGridKind','verticalGridCoordinate','zeroAPVF','zeroAPVG', ...
                'zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve', ...
                'apvGramError','apvRoundTripError','mdaGramError','mdaRoundTripError', ...
                'apvGramTolerance','mdaGramTolerance', ...
                'quadraticAliasingTolerance','quadraticAliasingError', ...
                'quadraticAliasingLimitingChannel','quadraticAliasingLimitingModeNumberI', ...
                'quadraticAliasingLimitingModeNumberJ', ...
                'minimumRelativeMuSeparation','muTolerance','zeroAPVGramReciprocalCondition', ...
                'zeroAPVGramRelativeSeparation','apvZeroAPVQuadraticError', ...
                'apvZeroAPVLimitingEndpoint','apvZeroAPVLimitingModeNumber', ...
                'modeSelectionMethod','Ag_q','Ag_0','Amda'};
            for iName = 1:length(names)
                testCase.verifyEqual(actual.(names{iName}),expected.(names{iName}),names{iName})
            end
        end

        function options = directOptions(wvt)
            names = {'shouldAntialias','N2Function','rhoFunction','rho0','planetaryRadius', ...
                'rotationRate','latitude','g','z','j','dLnN2','PF0inv','QG0inv', ...
                'PF0','QG0','P0','Q0','h_0','z_int','Ag_q','Ag_0','Amda','g0','gd', ...
                'activeEndpointCount','activeEndpoint','sourceEndpoint','apvMode', ...
                'apvModeNumber','mdaMode','mdaModeNumber','klNonzero','kNonzero', ...
                'lNonzero','khNonzero','khUnique','klNonzeroKhUniqueIndex','apvF', ...
                'apvG','apvFForward','apvGForward','apvEquivalentDepth','apvMu', ...
                'apvEndpointResponse','apvFSourcePairing','apvGSourcePairing','mdaF', ...
                'mdaG','mdaGForward','mdaEquivalentDepth','zeroAPVF','zeroAPVG', ...
                'verticalQuadratureWeights','verticalGridKind','verticalGridCoordinate', ...
                'zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve', ...
                'apvGramError','apvRoundTripError','mdaGramError','mdaRoundTripError', ...
                'apvGramTolerance','mdaGramTolerance', ...
                'quadraticAliasingTolerance','quadraticAliasingError', ...
                'quadraticAliasingLimitingChannel','quadraticAliasingLimitingModeNumberI', ...
                'quadraticAliasingLimitingModeNumberJ', ...
                'minimumRelativeMuSeparation','muTolerance','zeroAPVGramReciprocalCondition', ...
                'zeroAPVGramRelativeSeparation','apvZeroAPVQuadraticError', ...
                'apvZeroAPVLimitingEndpoint','apvZeroAPVLimitingModeNumber','modeSelectionMethod'};
            options = struct();
            for iName = 1:length(names)
                options.(names{iName}) = wvt.(names{iName});
            end
        end

        function closeIfOpen(ncfile)
            if ~isempty(ncfile) && isvalid(ncfile) && ~isempty(ncfile.id)
                ncfile.close();
            end
        end
    end
end

function setInvalidMDA(wvt)
wvt.Amda = complex(ones(size(wvt.Amda)),ones(size(wvt.Amda)));
end
