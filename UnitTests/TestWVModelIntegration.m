classdef TestWVModelIntegration < matlab.unittest.TestCase
    properties (TestParameter)
        integratorType = struct(fixed="fixed",adaptive="adaptive")
    end

    properties
        tempFolder
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.tempFolder = string(fixture.Folder);
        end
    end

    methods (Test, TestTags = "full")
        function fixedStepOutputAcceptsRoundedEndpoint(testCase)
            outputTimes = [];
            outputValues = [];
            % A CFL-derived five-second step can land one ulp below five.
            % At t=67 the stored endpoint rounds up, so (t-previousT)/dt > 1.
            dt = 5-eps(5);
            integrator = WVArrayIntegrator(@(~,~) {2},[17 42 67],{3},dt,OutputFcn=@collectOutput);

            testCase.verifyEqual(outputTimes,[42 67])
            testCase.verifyEqual(outputValues,[53 103],AbsTol=64*eps(103))
            testCase.verifyEqual(integrator.totalIterations,10)
            testCase.verifyEqual(integrator.currentTime,67)

            function collectOutput(t,y,flag)
                if isempty(flag)
                    outputTimes(end+1) = t;
                    outputValues(end+1) = y{1};
                elseif strcmp(flag,"done")
                    testCase.verifyEqual(t,67)
                    testCase.verifyEqual(y{1},103,AbsTol=64*eps(103))
                end
            end
        end

        function fixedStepInterpolationPreservesEndpointStates(testCase)
            initialState = {[1 2;3 4],complex([5;6],[7;8])};
            rate = {[2 3;4 5],complex([6;7],[8;9])};
            for dt = [5-eps(5),5+eps(5)]
                integrator = WVArrayIntegrator(@(~,~) rate,[17 67],initialState,dt);
                testCase.verifyEqual(integrator.valueAtTime(integrator.previousT),integrator.previousY)
                testCase.verifyEqual(integrator.valueAtTime(integrator.currentTime),integrator.currentY)
            end
        end

        function fixedStepInterpolationPreservesInteriorValues(testCase)
            integrator = WVArrayIntegrator(@(t,~) {2*t,complex([2;4]*t,[6;8]*t)},[0 2],{0,complex([0;0])},1);
            for t = [1.125 1.5 1.875]
                actual = integrator.valueAtTime(t);
                testCase.verifyEqual(actual{1},t^2,AbsTol=8*eps(t^2))
                expected = complex([1;2],[3;4])*t^2;
                testCase.verifyEqual(actual{2},expected,AbsTol=8*eps(max(abs(expected))))
            end
        end

        function fixedStepInterpolationAcceptsRoundedInteriorTime(testCase)
            integrator = WVArrayIntegrator(@(~,~) {2},[-17,-17+11*1.1],{0},1.1);
            t = integrator.currentTime-eps(integrator.currentTime);
            testCase.verifyGreaterThan(t,integrator.previousT)
            testCase.verifyLessThan(t,integrator.currentTime)
            actual = integrator.valueAtTime(t);
            testCase.verifyEqual(actual{1},2*(t+17),AbsTol=8*eps(2*(t+17)))
        end

        function fixedStepInterpolationRejectsOutsideStep(testCase)
            integrator = WVArrayIntegrator(@(~,~) {2},[17 67],{3},5-eps(5));
            for t = [integrator.previousT-eps(integrator.previousT),integrator.currentTime+eps(integrator.currentTime),NaN,Inf,-Inf]
                testCase.verifyError(@()integrator.valueAtTime(t),"WaveVortexModel:InvalidInterpolationTime")
            end
        end

        function fixedStepConvergesToAdaptiveReference(testCase)
            adaptiveModel = TestWVModelIntegration.newModel("adaptive");
            coarseFixedModel = TestWVModelIntegration.newModel("fixed",deltaT=20);
            fineFixedModel = TestWVModelIntegration.newModel("fixed",deltaT=10);

            TestWVModelIntegration.integrateToFinalTime(adaptiveModel);
            TestWVModelIntegration.integrateToFinalTime(coarseFixedModel);
            TestWVModelIntegration.integrateToFinalTime(fineFixedModel);

            coarseError = TestWVModelIntegration.normalizedCoefficientError(coarseFixedModel.wvt,adaptiveModel.wvt);
            fineError = TestWVModelIntegration.normalizedCoefficientError(fineFixedModel.wvt,adaptiveModel.wvt);
            convergenceRatio = coarseError/fineError;

            testCase.verifyLessThanOrEqual(fineError,2e-8)
            testCase.verifyGreaterThanOrEqual(convergenceRatio,8)
            testCase.verifyLessThanOrEqual(convergenceRatio,24)
            TestWVModelIntegration.verifyStateInvariants(testCase,adaptiveModel.wvt)
            TestWVModelIntegration.verifyStateInvariants(testCase,coarseFixedModel.wvt)
            TestWVModelIntegration.verifyStateInvariants(testCase,fineFixedModel.wvt)
        end

        function segmentedIntegrationMatchesUninterrupted(testCase,integratorType)
            uninterruptedModel = TestWVModelIntegration.newModel(integratorType);
            segmentedModel = TestWVModelIntegration.newModel(integratorType);

            TestWVModelIntegration.integrateToFinalTime(uninterruptedModel);
            TestWVModelIntegration.integrateToTime(segmentedModel,TestWVModelIntegration.checkpointTime());
            TestWVModelIntegration.integrateToFinalTime(segmentedModel);

            TestWVModelIntegration.verifyEquivalentStates(testCase,segmentedModel.wvt,uninterruptedModel.wvt,integratorType)
        end

        function restartedIntegrationMatchesUninterrupted(testCase,integratorType)
            uninterruptedModel = TestWVModelIntegration.newModel(integratorType);
            checkpointModel = TestWVModelIntegration.newModel(integratorType);
            restartPath = fullfile(testCase.tempFolder,"model-integration-"+integratorType+".nc");
            checkpointModel.createNetCDFFileForModelOutput(restartPath,outputInterval=TestWVModelIntegration.checkpointTime(),shouldOverwriteExisting=true);
            checkpointCleanup = onCleanup(@()checkpointModel.closeNetCDFFile());

            TestWVModelIntegration.integrateToFinalTime(uninterruptedModel);
            TestWVModelIntegration.integrateToTime(checkpointModel,TestWVModelIntegration.checkpointTime());
            checkpointModel.closeNetCDFFile();
            clear checkpointCleanup

            resumedModel = WVModel.modelFromFile(char(restartPath));
            resumedCleanup = onCleanup(@()resumedModel.closeNetCDFFile());
            TestWVModelIntegration.configureIntegrator(resumedModel,integratorType,10);
            TestWVModelIntegration.integrateToFinalTime(resumedModel);
            resumedModel.closeNetCDFFile();
            clear resumedCleanup

            TestWVModelIntegration.verifyEquivalentStates(testCase,resumedModel.wvt,uninterruptedModel.wvt,integratorType)
            TestWVModelIntegration.verifyForcingState(testCase,resumedModel.wvt,uninterruptedModel.wvt)
        end
    end

    methods (Static, Access = private)
        function model = newModel(integratorType,options)
            arguments
                integratorType (1,1) string {mustBeMember(integratorType,["fixed","adaptive"])}
                options.deltaT (1,1) double {mustBePositive} = 10
            end
            wvt = WVTransformBoussinesq([40e3 30e3 2e3],[8 6 5],N2=@(z) 2e-5*exp(z/4000),latitude=45,shouldAntialias=false);
            [x,y] = ndgrid(wvt.x,wvt.y);
            topographicHeight = 30*cos(2*pi*x/wvt.Lx)+17*sin(2*pi*y/wvt.Ly)+11*cos(2*pi*(2*x/wvt.Lx+y/wvt.Ly));
            generation = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=topographicHeight,barotropicVelocityAmplitude=[0.05; -0.01],rampDuration=100,startTime=0,name="integrator test terrain");
            wvt.removeAllForcing();
            wvt.addForcing(generation);
            wvt.addForcing(WVAdaptiveDamping(wvt));

            model = WVModel(wvt);
            TestWVModelIntegration.configureIntegrator(model,integratorType,options.deltaT);
        end

        function configureIntegrator(model,integratorType,deltaT)
            if integratorType == "adaptive"
                model.setupIntegrator(integratorType="adaptive",absTolerance=1e-12,relTolerance=1e-10);
            else
                model.setupIntegrator(integratorType="fixed",deltaT=deltaT);
            end
        end

        function integrateToFinalTime(model)
            TestWVModelIntegration.integrateToTime(model,TestWVModelIntegration.finalTime());
        end

        function integrateToTime(model,finalTime)
            model.integrateToTime(finalTime,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
        end

        function errorValue = normalizedCoefficientError(actual,reference)
            absoluteError = max([max(abs(actual.Ap-reference.Ap),[],"all"),max(abs(actual.Am-reference.Am),[],"all"),max(abs(actual.A0-reference.A0),[],"all")]);
            referenceScale = max([max(abs(reference.Ap),[],"all"),max(abs(reference.Am),[],"all"),max(abs(reference.A0),[],"all"),eps]);
            errorValue = absoluteError/referenceScale;
        end

        function verifyEquivalentStates(testCase,actual,reference,integratorType)
            testCase.verifyEqual(actual.t,TestWVModelIntegration.finalTime())
            testCase.verifyEqual(reference.t,TestWVModelIntegration.finalTime())
            if integratorType == "fixed"
                testCase.verifyEqual(actual.Ap,reference.Ap)
                testCase.verifyEqual(actual.Am,reference.Am)
                testCase.verifyEqual(actual.A0,reference.A0)
                testCase.verifyEqual(actual.totalEnergy,reference.totalEnergy)
            else
                testCase.verifyLessThanOrEqual(TestWVModelIntegration.normalizedCoefficientError(actual,reference),2e-8)
                testCase.verifyEqual(actual.totalEnergy,reference.totalEnergy,RelTol=5e-8)
            end
            TestWVModelIntegration.verifyStateInvariants(testCase,actual)
            TestWVModelIntegration.verifyStateInvariants(testCase,reference)
        end

        function verifyStateInvariants(testCase,wvt)
            testCase.verifyGreaterThan(max(abs(wvt.Ap),[],"all"),0)
            testCase.verifyGreaterThan(max(abs(wvt.Am),[],"all"),0)
            testCase.verifyEqual(wvt.A0,zeros(size(wvt.A0)))
            testCase.verifyEqual(wvt.Ap(~logical(wvt.waveComponent.maskAp)),zeros(nnz(~logical(wvt.waveComponent.maskAp)),1))
            testCase.verifyEqual(wvt.Am(~logical(wvt.waveComponent.maskAm)),zeros(nnz(~logical(wvt.waveComponent.maskAm)),1))
            testCase.verifyTrue(isfinite(wvt.totalEnergy))
            testCase.verifyGreaterThan(wvt.totalEnergy,0)
        end

        function verifyForcingState(testCase,actual,reference)
            testCase.verifyEqual(actual.forcingNames,reference.forcingNames)
            generation = actual.forcingWithName("integrator test terrain");
            referenceGeneration = reference.forcingWithName("integrator test terrain");
            testCase.verifyClass(generation,"WVPseudoTopographicWaveGeneration")
            testCase.verifyClass(actual.forcingWithName("adaptive damping"),"WVAdaptiveDamping")
            testCase.verifyEqual(generation.topographicHeight,referenceGeneration.topographicHeight)
            testCase.verifyEqual(generation.barotropicVelocityAmplitude,complex(referenceGeneration.barotropicVelocityAmplitude))
            testCase.verifyEqual(generation.frequency,referenceGeneration.frequency)
            testCase.verifyEqual(generation.darwinSymbol,referenceGeneration.darwinSymbol)
            testCase.verifyEqual(generation.rampDuration,referenceGeneration.rampDuration)
            testCase.verifyEqual(generation.startTime,referenceGeneration.startTime)
            testCase.verifyEqual(generation.shouldAvoidAdaptiveDamping,referenceGeneration.shouldAvoidAdaptiveDamping)
            testCase.verifyEqual(generation.maximumForcedHorizontalWavenumber,referenceGeneration.maximumForcedHorizontalWavenumber)
            testCase.verifyEqual(generation.maximumForcedVerticalMode,referenceGeneration.maximumForcedVerticalMode)
        end

        function t = checkpointTime()
            t = 300;
        end

        function t = finalTime()
            t = 600;
        end
    end
end
