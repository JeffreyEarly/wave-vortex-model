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
            testCase.verifyEqual(wvt.apvModeCount,wvt.apvCertifiedModeCount)
            testCase.verifyEqual(wvt.mdaModeCount,wvt.mdaCertifiedModeCount)
            testCase.verifyNotEqual(wvt.apvModeCount,wvt.mdaModeCount)
            testCase.verifySize(wvt.Ag_q,[wvt.apvModeCount length(wvt.klNonzero)])
            testCase.verifySize(wvt.Amda,[wvt.mdaModeCount 1])
            testCase.verifyEqual(wvt.apvGramTolerance,1e-2,AbsTol=0)
            testCase.verifyEqual(wvt.mdaGramTolerance,0.1,AbsTol=0)
            testCase.verifyEqual(wvt.quadraticAliasingTolerance,0.1,AbsTol=0)
            testCase.verifyEqual(wvt.muTolerance,sqrt(eps),AbsTol=0)
            testCase.verifyLessThanOrEqual(wvt.quadraticAliasingError,wvt.quadraticAliasingTolerance)
            testCase.verifyTrue(ismember(wvt.quadraticAliasingLimitingChannel,["FF->F" "FG->G" "GG->F"]))
            testCase.verifyTrue(wvt.hasPositiveQuadrature)
            testCase.verifyLessThanOrEqual(wvt.apvGramError,wvt.apvGramTolerance)
            testCase.verifyLessThanOrEqual(wvt.mdaGramError,wvt.mdaGramTolerance)
            testCase.verifyEqual(wvt.mdaInitialModeCount,wvt.Nz)
            testCase.verifyEqual(wvt.verticalGridKind,"modeRoot")
            testCase.verifyEqual(wvt.verticalGridSourceEVP,"geostrophicAPVModes")
            testCase.verifyEqual(wvt.verticalGridGeneratingVariable,"F")
            testCase.verifySubstring(wvt.verticalGridInterpretation,"G-extrema-like")
            testCase.verifyEqual(wvt.z_int,wvt.apvQuadratureWeights,AbsTol=0)
            testCase.verifySize(wvt.mdaQuadratureWeights,[wvt.Nz 1])
            testCase.verifyNotEqual(wvt.apvQuadratureWeights,wvt.mdaQuadratureWeights)

            rejectedCount = wvt.apvCertifiedModeCount+1;
            testCase.verifyError(@()WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=rejectedCount,g0=0.02,gd=Inf,mdaGramTolerance=0.1), ...
                'WVTransformFreeSurfaceQG:UncertifiedModeCount')
        end

        function explicitFamilyCountsAreIndependentPrefixes(testCase)
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=1,mdaModeCount=2,g0=0.02,gd=0.03);
            testCase.verifyEqual(wvt.apvModeCount,1)
            testCase.verifyEqual(wvt.mdaModeCount,2)
            testCase.verifyEqual(wvt.Nj,1)
            testCase.verifySize(wvt.Ag_q,[1 length(wvt.klNonzero)])
            testCase.verifySize(wvt.Amda,[2 1])

            testCase.verifyError(@()WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,Nj=2,g0=0.02,gd=0.03), ...
                'MATLAB:TooManyInputs')
        end

        function initializationTolerancesArePersisted(testCase)
            z = linspace(-1000,0,33).';
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=1,mdaModeCount=1, ...
                g0=0.02,gd=0.03,apvGramTolerance=0.02,mdaGramTolerance=0.03, ...
                quadraticAliasingTolerance=0.2,muTolerance=1e-7,z=z);
            testCase.verifyEqual(wvt.apvGramTolerance,0.02,AbsTol=0)
            testCase.verifyEqual(wvt.mdaGramTolerance,0.03,AbsTol=0)
            testCase.verifyEqual(wvt.quadraticAliasingTolerance,0.2,AbsTol=0)
            testCase.verifyEqual(wvt.muTolerance,1e-7,AbsTol=0)
            testCase.verifyLessThanOrEqual(wvt.apvGramError,wvt.apvGramTolerance)
            testCase.verifyLessThanOrEqual(wvt.mdaGramError,wvt.mdaGramTolerance)
            testCase.verifyGreaterThan(wvt.minimumRelativeMuSeparation,wvt.muTolerance)
            testCase.verifyEqual(wvt.verticalGridKind,"explicit")
            testCase.verifyEqual(wvt.verticalGridGeneratingVariable,"")
            testCase.verifyTrue(isnan(wvt.verticalGridGeneratingModeNumber))
            testCase.verifyEqual(wvt.z,z,AbsTol=0)
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
            testCase.verifyEqual(actual.Ag_0,expectedAg0,AbsTol=2e-17)
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

        function axialAndObliqueEntriesReuseTheirKhPage(testCase)
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[16 16 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=2,mdaModeCount=2, ...
                g0=0.02,gd=0.03,mdaGramTolerance=0.1);
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

        function retainedNonlinearTendencyIsStableUnderGridRefinement(testCase)
            coarse = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=2,mdaModeCount=2, ...
                g0=0.02,gd=0.03,mdaGramTolerance=0.1);
            horizontalReference = WVTransformFreeSurfaceQG([100e3 100e3 1000],[16 16 33], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=2,mdaModeCount=2, ...
                g0=0.02,gd=0.03,mdaGramTolerance=0.1);
            verticalReference = WVTransformFreeSurfaceQG([100e3 100e3 1000],[16 16 65], ...
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=2,mdaModeCount=2, ...
                g0=0.02,gd=0.03,mdaGramTolerance=0.1);

            for stateKind = ["apv" "endpoint" "mixed"]
                TestWVTransformFreeSurfaceQG.setRefinementState(coarse,stateKind);
                TestWVTransformFreeSurfaceQG.setRefinementState(horizontalReference,stateKind);
                TestWVTransformFreeSurfaceQG.setRefinementState(verticalReference,stateKind);
                coarseTendency = TestWVTransformFreeSurfaceQG.retainedRefinementTendency(coarse);
                horizontalTendency = TestWVTransformFreeSurfaceQG.retainedRefinementTendency(horizontalReference);
                verticalTendency = TestWVTransformFreeSurfaceQG.retainedRefinementTendency(verticalReference);
                testCase.verifyGreaterThan(norm(verticalTendency),0,stateKind)
                referenceScale = max(norm(verticalTendency),realmin);
                testCase.verifyLessThanOrEqual(norm(coarseTendency-horizontalTendency)/referenceScale,2e-10,stateKind)
                testCase.verifyLessThanOrEqual(norm(horizontalTendency-verticalTendency)/referenceScale,0.1,stateKind)
            end
        end

        function snapshotPersistsRepresentationAndDirectConstructionSkipsModeSolver(testCase)
            path = fullfile(testCase.temporaryFolder,"snapshot.nc");
            scientific = TestWVTransformFreeSurfaceQG.newTransform(0.02,0.03);
            TestWVTransformFreeSurfaceQG.setMixedState(scientific,2);
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
                'zeroAPVSourceSolve','zeroAPVGramReciprocalCondition','zeroAPVGramRelativeSeparation'};
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
                N2Function=@(z)1e-4*ones(size(z)),latitude=30,apvModeCount=2,mdaModeCount=1, ...
                g0=g0,gd=gd,mdaGramTolerance=0.1);
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

        function values = retainedRefinementTendency(wvt)
            tendency = wvt.coefficientTendency();
            i11 = TestWVTransformFreeSurfaceQG.nonzeroIndexForMode(wvt,1,1);
            values = [tendency.Ag_q(:,i11);tendency.Ag_0(:,i11)];
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
                'mdaG','mdaGForward','mdaEquivalentDepth','apvQuadratureWeights', ...
                'mdaQuadratureWeights','verticalGridKind','verticalGridSourceEVP', ...
                'verticalGridGeneratingVariable','verticalGridGeneratingModeNumber', ...
                'verticalGridRepresentedModeCount','verticalGridInterpretation','zeroAPVF','zeroAPVG', ...
                'zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve', ...
                'apvInitialModeCount','mdaInitialModeCount','apvCertifiedModeCount', ...
                'mdaCertifiedModeCount','apvGramError', ...
                'apvRoundTripError','mdaGramError','mdaRoundTripError', ...
                'apvGramTolerance','mdaGramTolerance', ...
                'quadraticAliasingTolerance','quadraticAliasingError', ...
                'quadraticAliasingLimitingChannel','quadraticAliasingLimitingModeNumberI', ...
                'quadraticAliasingLimitingModeNumberJ', ...
                'minimumRelativeMuSeparation','muTolerance','zeroAPVGramReciprocalCondition', ...
                'zeroAPVGramRelativeSeparation','hasPositiveQuadrature', ...
                'certificationMethod','Ag_q','Ag_0','Amda'};
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
                'apvQuadratureWeights','mdaQuadratureWeights','verticalGridKind', ...
                'verticalGridSourceEVP','verticalGridGeneratingVariable', ...
                'verticalGridGeneratingModeNumber','verticalGridRepresentedModeCount', ...
                'verticalGridInterpretation', ...
                'zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve', ...
                'apvInitialModeCount','mdaInitialModeCount','apvCertifiedModeCount', ...
                'mdaCertifiedModeCount','apvGramError', ...
                'apvRoundTripError','mdaGramError','mdaRoundTripError', ...
                'apvGramTolerance','mdaGramTolerance', ...
                'quadraticAliasingTolerance','quadraticAliasingError', ...
                'quadraticAliasingLimitingChannel','quadraticAliasingLimitingModeNumberI', ...
                'quadraticAliasingLimitingModeNumberJ', ...
                'minimumRelativeMuSeparation','muTolerance','zeroAPVGramReciprocalCondition', ...
                'zeroAPVGramRelativeSeparation','hasPositiveQuadrature','certificationMethod'};
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
