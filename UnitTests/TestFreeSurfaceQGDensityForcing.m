classdef TestFreeSurfaceQGDensityForcing < matlab.unittest.TestCase
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
        function persistedRuleHasWeakDiffusionIdentities(testCase)
            wvt = TestFreeSurfaceQGDensityForcing.constantTransform(0.02,0.03,33);
            z = wvt.z;
            weights = wvt.verticalQuadratureWeights;
            Dz = wvt.verticalDerivativeMatrix;
            kappaT = 7e-6;

            testCase.verifySize(Dz,[wvt.Nz wvt.Nz])
            testCase.verifyEqual(Dz*ones(size(z)),zeros(size(z)),AbsTol=5e-10)
            testCase.verifyEqual(Dz*z,ones(size(z)),RelTol=2e-6)

            buoyancy = z.^2;
            weakTendency = -Dz.'*(weights.*(kappaT*(Dz*buoyancy)));
            surfaceFlux = kappaT*(2*z(end));
            bottomFlux = -kappaT*(2*z(1));
            weakTendency(end) = weakTendency(end)+surfaceFlux;
            weakTendency(1) = weakTendency(1)+bottomFlux;
            buoyancyTendency = weakTendency./weights;
            testCase.verifyEqual(buoyancyTendency,2*kappaT*ones(size(z)),RelTol=1.5e-4,AbsTol=2e-11)
            testCase.verifyEqual(sum(weights.*buoyancyTendency),surfaceFlux+bottomFlux,RelTol=2e-10)

            testBuoyancy = sin(pi*(z+wvt.Lz)/wvt.Lz)+0.2*cos(2*pi*z/wvt.Lz);
            quadraticForm = testBuoyancy.'*(-Dz.'*(weights.*(kappaT*(Dz*testBuoyancy))));
            expectedForm = -kappaT*sum(weights.*(Dz*testBuoyancy).^2);
            testCase.verifyEqual(quadraticForm,expectedForm,RelTol=2e-13,AbsTol=2e-13)
            testCase.verifyLessThanOrEqual(quadraticForm,0)
        end

        function endpointConfigurationsEnforceFluxContract(testCase)
            endpointValues = [Inf Inf;0.02 Inf;Inf 0.03;0.02 0.03];
            surfaceFlux = ones(8,8);
            bottomFlux = 2*ones(8,8);
            for iCase = 1:size(endpointValues,1)
                wvt = TestFreeSurfaceQGDensityForcing.newTransform(endpointValues(iCase,1),endpointValues(iCase,2));
                zeroTendency = wvt.boundaryBuoyancyFluxTendency();
                TestFreeSurfaceQGDensityForcing.verifyZeroTendency(testCase,zeroTendency)

                if isfinite(endpointValues(iCase,1))
                    surfaceTendency = wvt.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=surfaceFlux);
                    etaInterior = TestFreeSurfaceQGDensityForcing.interiorDisplacementTendency(wvt,surfaceTendency);
                    testCase.verifyLessThan(real(etaInterior(end,TestFreeSurfaceQGDensityForcing.meanIndex(wvt))),0)
                else
                    testCase.verifyError(@()wvt.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=surfaceFlux), ...
                        'WVTransformFreeSurfaceQG:InactiveSurfaceFlux')
                end

                if isfinite(endpointValues(iCase,2))
                    bottomTendency = wvt.boundaryBuoyancyFluxTendency(bottomBuoyancyFlux=bottomFlux);
                    etaInterior = TestFreeSurfaceQGDensityForcing.interiorDisplacementTendency(wvt,bottomTendency);
                    testCase.verifyLessThan(real(etaInterior(1,TestFreeSurfaceQGDensityForcing.meanIndex(wvt))),0)
                else
                    testCase.verifyError(@()wvt.boundaryBuoyancyFluxTendency(bottomBuoyancyFlux=bottomFlux), ...
                        'WVTransformFreeSurfaceQG:InactiveBottomFlux')
                end
            end
        end

        function verticalDiffusivityProjectsAllFamiliesAndFlagOnlySuppressesMDA(testCase)
            wvt = TestFreeSurfaceQGDensityForcing.newTransform(0.02,0.03);
            wvt.Ag_q = TestFreeSurfaceQGDensityForcing.complexState(size(wvt.Ag_q),2e-3);
            wvt.Ag_0 = TestFreeSurfaceQGDensityForcing.complexState(size(wvt.Ag_0),3e-3);
            wvt.Amda = 0.2*sin((1:wvt.mdaModeCount).');
            withMDA = WVVerticalDiffusivity(wvt,kappa_z=7e-6,shouldForceMeanDensityAnomaly=true);
            withoutMDA = WVVerticalDiffusivity(wvt,kappa_z=7e-6,shouldForceMeanDensityAnomaly=false);
            incoming = TestFreeSurfaceQGDensityForcing.zeroTendency(wvt);

            actualWith = withMDA.addQuasigeostrophicSpectralForcing(wvt,incoming,struct());
            actualWithout = withoutMDA.addQuasigeostrophicSpectralForcing(wvt,incoming,struct());
            testCase.verifyTrue(withMDA.isClosure)
            testCase.verifyEqual(string(withMDA.forcingType),"QGSpectral")
            testCase.verifyGreaterThan(norm(actualWith.Ag_q(:)),0)
            testCase.verifyGreaterThan(norm(actualWith.Ag_0(:)),0)
            testCase.verifyGreaterThan(norm(actualWith.Amda(:)),0)
            testCase.verifyEqual(actualWithout.Ag_q,actualWith.Ag_q,AbsTol=0)
            testCase.verifyEqual(actualWithout.Ag_0,actualWith.Ag_0,AbsTol=0)
            testCase.verifyEqual(actualWithout.Amda,zeros(size(wvt.Amda)),AbsTol=0)
        end

        function seasonalForcingUsesExactPatternAmplitudePhaseAndPeriod(testCase)
            wvt = TestFreeSurfaceQGDensityForcing.newTransform(0.02,Inf);
            [~,Y] = ndgrid(wvt.x,wvt.y);
            pattern = 1+0.25*sin(2*pi*Y/wvt.Ly);
            amplitude = 3e-8;
            period = 20;
            forcing = WVSeasonalSurfaceBuoyancyFlux(wvt,pattern=pattern,amplitude=amplitude,period=period,phase=pi/2);
            unitTendency = wvt.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=pattern);
            incoming = TestFreeSurfaceQGDensityForcing.zeroTendency(wvt);

            testCase.verifyEqual(forcing.pattern,pattern,AbsTol=0)
            wvt.t = 0;
            positive = forcing.addQuasigeostrophicSpectralForcing(wvt,incoming,struct());
            TestFreeSurfaceQGDensityForcing.verifyScaledTendency(testCase,positive,unitTendency,amplitude)
            wvt.t = period/2;
            negative = forcing.addQuasigeostrophicSpectralForcing(wvt,incoming,struct());
            TestFreeSurfaceQGDensityForcing.verifyScaledTendency(testCase,negative,unitTendency,-amplitude)
            testCase.verifyGreaterThan(norm(unitTendency.Amda(:)),0)

            defaultForcing = WVSeasonalSurfaceBuoyancyFlux(wvt,amplitude=1,phase=pi/2);
            wvt.t = 0;
            defaultTendency = defaultForcing.addQuasigeostrophicSpectralForcing(wvt,incoming,struct());
            familyScale = max([norm(defaultTendency.Ag_q(:)),norm(defaultTendency.Ag_0(:)),1]);
            testCase.verifyLessThanOrEqual(norm(defaultTendency.Amda(:)),2e-12*familyScale)

            inactive = TestFreeSurfaceQGDensityForcing.newTransform(Inf,0.03);
            testCase.verifyError(@()WVSeasonalSurfaceBuoyancyFlux(inactive,amplitude=amplitude), ...
                'WVSeasonalSurfaceBuoyancyFlux:InactiveSurface')
        end

        function forcingAndDifferentiationRuleRoundTripThroughNetCDF(testCase)
            wvt = TestFreeSurfaceQGDensityForcing.newTransform(0.02,0.03);
            [X,Y] = ndgrid(wvt.x,wvt.y);
            pattern = 0.4+sin(2*pi*X/wvt.Lx).*cos(2*pi*Y/wvt.Ly);
            wvt.Amda = 0.1*cos((1:wvt.mdaModeCount).');
            wvt.removeAllForcing();
            wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=4e-6,shouldForceMeanDensityAnomaly=false));
            wvt.addForcing(WVSeasonalSurfaceBuoyancyFlux(wvt,pattern=pattern,amplitude=2e-8,period=40,phase=0.3));
            wvt.t = 7;
            expectedTendency = wvt.coefficientTendency();

            path = fullfile(testCase.temporaryFolder,"density-forcing.nc");
            ncfile = wvt.writeToFile(char(path),shouldOverwriteExisting=true);
            ncfile.close();
            restored = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(char(path));
            testCase.verifyEqual(restored.verticalDerivativeMatrix,wvt.verticalDerivativeMatrix,AbsTol=0)
            testCase.verifyEqual(restored.forcingNames,wvt.forcingNames)
            restoredDiffusivity = restored.forcingWithName("vertical diffusivity");
            testCase.verifyEqual(restoredDiffusivity.kappa_z,4e-6)
            testCase.verifyFalse(restoredDiffusivity.shouldForceMeanDensityAnomaly)
            restoredSeasonal = restored.forcingWithName("seasonal surface buoyancy flux");
            testCase.verifyEqual(restoredSeasonal.pattern,pattern,AbsTol=0)
            testCase.verifyEqual(restoredSeasonal.amplitude,2e-8)
            testCase.verifyEqual(restoredSeasonal.period,40)
            testCase.verifyEqual(restoredSeasonal.phase,0.3)
            actualTendency = restored.coefficientTendency();
            testCase.verifyEqual(actualTendency.Ag_q,expectedTendency.Ag_q,AbsTol=0)
            testCase.verifyEqual(actualTendency.Ag_0,expectedTendency.Ag_0,AbsTol=0)
            testCase.verifyEqual(actualTendency.Amda,expectedTendency.Amda,AbsTol=0)
        end

        function shortAdaptiveIntegrationRemainsFinite(testCase)
            wvt = TestFreeSurfaceQGDensityForcing.newTransform(0.02,0.03);
            wvt.initWithGaussianEddy(maximumSpeed=0.03,horizontalRadius=20e3,verticalScale=250,zCenter=50);
            wvt.removeAllForcing();
            wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=2e-6));
            wvt.addForcing(WVSeasonalSurfaceBuoyancyFlux(wvt,amplitude=2e-9,phase=pi/2));
            model = WVModel(wvt,shouldUseLinearDynamics=false);
            model.setupIntegrator(integratorType="adaptive",relTolerance=1e-6,absTolerance=1e-9);
            model.integrateToTime(600,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(wvt.t,600)
            testCase.verifyTrue(all(isfinite(wvt.Ag_q),"all"))
            testCase.verifyTrue(all(isfinite(wvt.Ag_0),"all"))
            testCase.verifyTrue(all(isfinite(wvt.Amda),"all"))
        end

        function adaptiveSeasonalResponseMatchesExactCoefficientSolution(testCase)
            day = 86400;
            period = 20*day;
            kappaT = 1e-5;
            amplitude = 1e-9;
            relTolerance = 1e-3;
            absTolerance = 1e-6;
            wvt = TestFreeSurfaceQGDensityForcing.variableTransform(0.02,0.03,33);
            [~,Y] = ndgrid(wvt.x,wvt.y);
            pattern = sin(2*pi*Y/wvt.Ly);
            spectralPattern = TestFreeSurfaceQGDensityForcing.horizontalTransform(wvt,pattern);
            [~,localIndex] = max(abs(spectralPattern(wvt.klNonzero)));

            [L,r] = TestFreeSurfaceQGDensityForcing.densityPageSystem(wvt,localIndex,kappaT,pattern,amplitude);
            expected = TestFreeSurfaceQGDensityForcing.exactSeasonalResponse(L,r,2*pi/period,0,period);

            wvt.removeAllForcing();
            wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=kappaT));
            wvt.addForcing(WVSeasonalSurfaceBuoyancyFlux(wvt,pattern=pattern,amplitude=amplitude,period=period,phase=0));
            model = WVModel(wvt,shouldUseLinearDynamics=false);
            model.setupIntegrator(integratorType="adaptive",relTolerance=relTolerance,absTolerance=absTolerance);
            model.odeOptions = odeset(model.odeOptions,"MaxStep",day);
            model.integrateToTime(period,shouldShowIntegrationDiagnostics=false);

            actual = [wvt.Ag_q(:,localIndex);wvt.Ag_0(:,localIndex)];
            tolerances = wvt.coefficientAbsoluteTolerances(absTolerance);
            localAbsoluteTolerance = [tolerances.Ag_q(:,localIndex);tolerances.Ag_0(:,localIndex)];
            normalizedError = abs(actual-expected)./(localAbsoluteTolerance+relTolerance*abs(expected));
            testCase.verifyLessThanOrEqual(max(normalizedError),20)
            testCase.verifyEqual(wvt.Amda,zeros(size(wvt.Amda)),AbsTol=1e-14)
            testCase.verifyEqual(wvt.t,period)
        end

    end

    methods (Static, Access=private)
        function wvt = newTransform(g0,gd)
            wvt = TestFreeSurfaceQGDensityForcing.variableTransform(g0,gd,33);
        end

        function wvt = variableTransform(g0,gd,Nz)
            N2 = @(z) 2e-5*exp(z/4000);
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 Nz],N2Function=N2,latitude=30,g0=g0,gd=gd,mdaGramTolerance=0.1);
        end

        function wvt = constantTransform(g0,gd,Nz)
            N2 = @(z) 2e-5*ones(size(z));
            wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 Nz],N2Function=N2,latitude=30,g0=g0,gd=gd,mdaGramTolerance=0.1);
        end

        function tendency = zeroTendency(wvt)
            tendency = struct('Ag_q',zeros(size(wvt.Ag_q)),'Ag_0',zeros(size(wvt.Ag_0)),'Amda',zeros(size(wvt.Amda)));
        end

        function verifyZeroTendency(testCase,tendency)
            testCase.verifyEqual(tendency.Ag_q,zeros(size(tendency.Ag_q)),AbsTol=0)
            testCase.verifyEqual(tendency.Ag_0,zeros(size(tendency.Ag_0)),AbsTol=0)
            testCase.verifyEqual(tendency.Amda,zeros(size(tendency.Amda)),AbsTol=0)
        end

        function verifyScaledTendency(testCase,actual,unit,scale)
            testCase.verifyEqual(actual.Ag_q,scale*unit.Ag_q,AbsTol=0)
            testCase.verifyEqual(actual.Ag_0,scale*unit.Ag_0,AbsTol=0)
            testCase.verifyEqual(actual.Amda,scale*unit.Amda,AbsTol=0)
        end

        function verifyTendencyRelative(testCase,actual,expected,tolerance)
            names = {'Ag_q','Ag_0','Amda'};
            for iName = 1:length(names)
                name = names{iName};
                scale = max(norm(expected.(name)(:)),realmin);
                relativeError = norm(actual.(name)(:)-expected.(name)(:))/scale;
                testCase.verifyLessThanOrEqual(relativeError,tolerance,sprintf('%s relative error is %.3g.',name,relativeError))
            end
        end

        function [L,r] = densityPageSystem(wvt,localIndex,kappaT,surfaceFlux,amplitude)
            force = WVVerticalDiffusivity(wvt,kappa_z=kappaT);
            operators = force.densityDiffusionOperators();
            L = operators.pages{wvt.klNonzeroKhUniqueIndex(localIndex)}.generator;
            unitTendency = wvt.boundaryBuoyancyFluxTendency(surfaceBuoyancyFlux=surfaceFlux);
            r = amplitude*[unitTendency.Ag_q(:,localIndex);unitTendency.Ag_0(:,localIndex)];
        end

        function x = exactSeasonalResponse(L,r,omega,phase,t)
            identity = eye(size(L));
            propagator = expm(L*t);
            positive = exp(1i*phase)*((1i*omega*identity-L)\((exp(1i*omega*t)*identity-propagator)*r));
            negative = exp(-1i*phase)*((-1i*omega*identity-L)\((exp(-1i*omega*t)*identity-propagator)*r));
            x = (positive-negative)/(2i);
        end

        function spectralFlux = horizontalTransform(wvt,flux)
            padded = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
            padded(:,:,1) = flux;
            spectralFlux = wvt.transformFromSpatialDomainWithFourier(padded);
            spectralFlux = spectralFlux(1,:);
        end

        function etaInterior = interiorDisplacementTendency(wvt,tendency)
            savedAgq = wvt.Ag_q;
            savedAg0 = wvt.Ag_0;
            savedAmda = wvt.Amda;
            cleanup = onCleanup(@()TestFreeSurfaceQGDensityForcing.restoreState(wvt,savedAgq,savedAg0,savedAmda));
            wvt.Ag_q = tendency.Ag_q;
            wvt.Ag_0 = tendency.Ag_0;
            wvt.Amda = tendency.Amda;
            [psiHat,etaHat] = wvt.reconstructSpectralState();
            etaInterior = etaHat-(wvt.f/wvt.g)*(1+wvt.z/wvt.Lz)*psiHat(end,:);
            clear cleanup
        end

        function restoreState(wvt,Ag_q,Ag_0,Amda)
            wvt.Ag_q = Ag_q;
            wvt.Ag_0 = Ag_0;
            wvt.Amda = Amda;
        end

        function index = meanIndex(wvt)
            index = find(hypot(wvt.k,wvt.l) == 0,1);
        end

        function values = complexState(sz,scale)
            index = reshape(1:prod(sz),sz);
            values = scale*(sin(index/5)+sqrt(-1)*cos(index/7));
        end
    end
end
