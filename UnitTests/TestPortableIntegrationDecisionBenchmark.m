classdef TestPortableIntegrationDecisionBenchmark < matlab.unittest.TestCase
    properties
        benchmarkFolder
        temporaryFolder
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.benchmarkFolder));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test,TestTags="full")
        function decisionsAreIndependentAndUseInclusiveThresholds(testCase)
            comparison = comparisonFixture;
            adaptive = adaptiveFixture;
            decision = portableIntegrationDecision(comparison,adaptive);
            testCase.verifyEqual(decision.runtimePreviewStatus,"RUNTIME-PREVIEW-READY")
            testCase.verifyEqual(decision.orchestrationStatus,"ORCHESTRATION-EFFICIENT")
            testCase.verifyEqual(decision.adaptiveStatus,"ADAPTIVE-RK23-AVAILABLE")

            comparison(1).builtinSpeedup = 1.249;
            decision = portableIntegrationDecision(comparison,adaptive);
            testCase.verifyEqual(decision.runtimePreviewStatus,"RUNTIME-PREVIEW-NOT-READY")
            testCase.verifyEqual(decision.orchestrationStatus,"ORCHESTRATION-EFFICIENT")
            testCase.verifyEqual(decision.adaptiveStatus,"ADAPTIVE-RK23-AVAILABLE")

            comparison = comparisonFixture;
            comparison(1).standaloneToCompiledMatlabRatio = 1.031;
            decision = portableIntegrationDecision(comparison,adaptive);
            testCase.verifyEqual(decision.runtimePreviewStatus,"RUNTIME-PREVIEW-READY")
            testCase.verifyEqual(decision.orchestrationStatus,"ORCHESTRATION-NOT-EFFICIENT")

            adaptive.continuousOutputPassed = false;
            decision = portableIntegrationDecision(comparisonFixture,adaptive);
            testCase.verifyEqual(decision.adaptiveStatus,"ADAPTIVE-RK23-NOT-AVAILABLE")
            testCase.verifyEqual(decision.runtimePreviewStatus,"RUNTIME-PREVIEW-READY")
        end

        function correctnessIdentityAndStorageAreRequired(testCase)
            adaptive = adaptiveFixture;
            comparison = comparisonFixture;
            comparison(1).maximumRelativeError = 1.01e-12;
            decision = portableIntegrationDecision(comparison,adaptive);
            testCase.verifyFalse(decision.runtimePreviewReady)
            testCase.verifyFalse(decision.orchestrationEfficient)

            comparison = comparisonFixture;
            comparison(1).noFallback = false;
            testCase.verifyFalse(portableIntegrationDecision(comparison,adaptive).runtimePreviewReady)
            comparison = comparisonFixture;
            comparison(1).persistentFullHermitianBytes = 16;
            testCase.verifyFalse(portableIntegrationDecision(comparison,adaptive).runtimePreviewReady)
        end

        function completedArtifactNormalizesFixedAndAdaptiveDatasets(testCase)
            raw = portableArtifactFixture;
            rawPath = fullfile(testCase.temporaryFolder,"portable.json");
            writeJson(rawPath,raw)
            [fixed,adaptive] = publishedPortableIntegrationBenchmarksFromArtifact(rawPath,provenancePath="Benchmarks/results/reference/portable-integration-v1-m5-max-r2026a/portable-integration-decision.json");

            testCase.verifyNumElements(fixed,3)
            testCase.verifyEqual(string(arrayfun(@(dataset)dataset.benchmark.suiteId,fixed)),repmat("portable-rk4-v1",1,3))
            testCase.verifyEqual(fixed(1).cases{1}.configuration.integration.initialTime,2)
            testCase.verifyEqual(fixed(1).cases{1}.configuration.integration.finalTime,10)
            testCase.verifyEqual(fixed(1).cases{1}.work.rightHandSideEvaluations,32)
            testCase.verifyEqual(adaptive.benchmark.method,"adaptive-rk23")
            testCase.verifyEqual(adaptive.benchmark.correctnessTolerance,1e-2)
            testCase.verifyNumElements(adaptive.cases,2)
            testCase.verifyEqual(adaptive.cases{1}.configuration.sampleCount,3)
        end
    end

    methods (Test,TestTags="optional")
        function reducedDecisionBenchmarkRunsAllImplementations(testCase)
            result = runPortableIntegrationDecisionBenchmark(sizes=[8 6 7],hydrostatic=[true false],processRunCount=1,warmupStepCount=1,stepCount=1,deltaT=0.01,samplingIntervalSeconds=0.01,plateauSeconds=0.03,shouldWriteArtifacts=false,shouldRunAdaptiveEvidence=false);
            testCase.verifyEqual(result.status,"complete")
            testCase.verifyEqual(numel(result.fixedRuns),6)
            testCase.verifyEqual(string({result.fixedComparison.status}),["complete" "complete"])
            testCase.verifyLessThanOrEqual(max([result.fixedComparison.maximumRelativeError]),1e-12)
            testCase.verifyTrue(all([result.fixedComparison.nativeIdentityPassed]))
            testCase.verifyTrue(all([result.fixedComparison.noFallback]))
        end

        function failureWritesPartialArtifact(testCase)
            outputDirectory = fullfile(testCase.temporaryFolder,"partial");
            testCase.verifyError(@()runPortableIntegrationDecisionBenchmark(sizes=[8 6 7],hydrostatic=true,processRunCount=1,warmupStepCount=0,stepCount=1,deltaT=0.01,outputDirectory=outputDirectory,injectWorkerFailure=true,shouldRunAdaptiveEvidence=false),"WaveVortexBenchmark:PortableIntegrationWorkers")
            artifact = jsondecode(fileread(fullfile(outputDirectory,"portable-integration-decision.json")));
            testCase.verifyEqual(string(artifact.status),"failed")
            testCase.verifyEqual(string(artifact.failure.stage),"fixed-workers")
            testCase.verifyTrue(isfile(fullfile(outputDirectory,"summary.md")))
        end
    end
end

function value = comparisonFixture
record = struct("status","complete","builtinSpeedup",1.25,"standaloneToCompiledMatlabRatio",1.03,"maximumRelativeError",1e-15,"nativeIdentityPassed",true,"noFallback",true,"planCount",17,"persistentFullHermitianBytes",0);
value = repmat(record,4,1);
end

function value = adaptiveFixture
value = struct("status","complete","convergencePassed",true,"toleranceControlPassed",true,"rejectionPassed",true,"forcingSemanticsPassed",true,"continuousOutputPassed",true,"restartReconstructionPassed",true);
end

function value = portableArtifactFixture
definition = struct("id","constant-hydrostatic-256x256x65","Lxyz",[15000 15000 1300],"Nxyz",[256 256 65],"isHydrostatic",true,"shouldAntialias",true,"seed",187);
implementations = ["matlab-builtin" "matlab-compiled-preview" "standalone-cpp"];
runs = repmat(struct("implementation","","case",definition,"integrationSeconds",0,"rss",struct("steadyRetainedBytes",100,"operationPeakBytes",120,"operationPeakIncrementBytes",20)),3,1);
for iRun = 1:3
    runs(iRun).implementation = implementations(iRun);
    runs(iRun).integrationSeconds = iRun;
end
comparison = struct("id",definition.id,"maximumRelativeError",1e-14);
correctness = struct("id",definition.id,"repeatIndex",1,"maximumRelativeError",1e-14,"compiledMatlabRelativeError",8e-15,"standaloneRelativeError",1e-14);
record = struct("fixture","forcing-mixed-hydrostatic.nc","isHydrostatic",true,"repeatIndex",1,"configuration",struct("Lxyz",definition.Lxyz,"Nxyz",definition.Nxyz,"shouldAntialias",true,"seed",187,"initialTime",0),"relativeTolerance",1e-2,"absoluteTolerance",1e-5,"relativeInfinityError",1e-3,"acceptedStepCount",4,"rejectedStepCount",1,"rightHandSideEvaluationCount",14,"integrationSeconds",0.1);
records = repmat(record,6,1);
for iRecord = 1:6
    records(iRecord).repeatIndex = mod(iRecord-1,3)+1;
    if iRecord > 3
        records(iRecord).relativeTolerance = 1e-3;
        records(iRecord).absoluteTolerance = 1e-6;
        records(iRecord).relativeInfinityError = 1e-4;
    end
end
value = struct("schemaVersion","portable-integration-decision-v1","status","complete","runId","20260813T120000000Z","source",struct("commit",repmat('a',1,40),"isDirty",false),"environment",struct("physicalMemoryBytes",64*2^30,"computer","macOS","architecture","maca64","threads",18,"matlabVersion","26.1","release","R2026a"),"provider",struct("provider",struct("id","native-neon-pthreads","version","3.3.11"),"compiler",struct("mexVersion","Apple Clang 21")),"configuration",struct("correctnessTolerance",1e-12,"warmupStepCount",2,"stepCount",8,"deltaT",1),"cases",definition,"fixedRuns",runs,"correctness",correctness,"fixedComparison",comparison,"adaptive",struct("initialStep",1e-5,"duration",2e-5,"records",records));
end

function writeJson(pathname,value)
file = fopen(pathname,"w");
cleanup = onCleanup(@()fclose(file));
fprintf(file,"%s\n",jsonencode(value));
clear cleanup
end
