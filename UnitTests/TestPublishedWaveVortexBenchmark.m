classdef TestPublishedWaveVortexBenchmark < matlab.unittest.TestCase
    properties
        repositoryRoot
        benchmarkFolder
        temporaryFolder
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.benchmarkFolder = fullfile(testCase.repositoryRoot,"Benchmarks");
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
        function schemasDefineTheExternalPublicationBoundary(testCase)
            publishedSchema = jsondecode(fileread(fullfile(testCase.benchmarkFolder,"schemas","published-benchmark-v1.schema.json")));
            catalogSchema = jsondecode(fileread(fullfile(testCase.benchmarkFolder,"schemas","benchmark-catalog-v1.schema.json")));
            testCase.verifyEqual(string(publishedSchema.title),"WaveVortexModel published benchmark v1");
            testCase.verifyEqual(string(catalogSchema.title),"WaveVortexModel benchmark catalog v1");
        end


        function legacyArtifactNormalizesWithoutMutation(testCase)
            rawRelativePath = "reference.json";
            rawPath = fullfile(testCase.temporaryFolder,rawRelativePath);
            writeJson(rawPath,rawMatlabFixture);
            originalBytes = fileread(rawPath);
            dataset = publishedWaveVortexBenchmarkFromMatlabArtifact(rawPath,suiteId="scaling-standard-v1",platformId="m5-max",platformName="Apple M5 Max",provenancePath=rawRelativePath,processorName="Apple M5 Max",implementationVersion="4.2.1");

            expectedFields = ["schemaVersion" "datasetId" "collectedAt" "benchmark" "implementation" "platform" "toolchain" "provenance" "cases"];
            testCase.verifyEqual(string(fieldnames(dataset))',expectedFields);
            testCase.verifyEqual(dataset.datasetId,"scaling-standard-v1--matlab-builtin--m5-max--20260808T180708Z");
            testCase.verifyEqual(dataset.benchmark.operation,"nonlinearFlux");
            testCase.verifyEqual(dataset.implementation.version,"4.2.1");
            testCase.verifyEqual(dataset.platform.processor,"Apple M5 Max");
            testCase.verifyNumElements(dataset.cases,2);
            testCase.verifyEqual(fileread(rawPath),originalBytes);

            first = dataset.cases{1};
            testCase.verifyEqual(first.status,"complete");
            testCase.verifyEqual(first.timing.medianSeconds,median(first.timing.samplesSeconds),AbsTol=1e-15);
            testCase.verifyEqual(first.memory.peakIncrementBytes,first.memory.peakProcessBytes-first.memory.baselineProcessBytes);
        end

        function futureArtifactUsesAddedMetadataAndMarksMissingBackend(testCase)
            raw = rawMatlabFixture;
            raw.schemaVersion = "1.1.0";
            raw.environment.packageName = "WaveVortexModel";
            raw.environment.packageVersion = "4.2.1";
            raw.environment.processorName = "Future Reference CPU";
            raw.suites.cases(1).backends = struct([]);
            fixturePath = fullfile(testCase.temporaryFolder,"raw.json");
            writeJson(fixturePath,raw);

            dataset = publishedWaveVortexBenchmarkFromMatlabArtifact(fixturePath,suiteId="scaling-standard-v1",platformId="future-host",platformName="Future host",provenancePath="future/benchmark.json");
            testCase.verifyEqual(dataset.implementation.displayName,"WaveVortexModel MATLAB");
            testCase.verifyEqual(dataset.implementation.version,"4.2.1");
            testCase.verifyEqual(dataset.platform.processor,"Future Reference CPU");
            testCase.verifyEqual(dataset.provenance.rawSchemaVersion,"1.1.0");
            testCase.verifyEqual(dataset.cases{1}.status,"unavailable");
            testCase.verifySubstring(dataset.cases{1}.unavailableReason,"builtin");
            testCase.verifyEqual(dataset.cases{2}.status,"complete");
        end

        function cppDocumentUsesTheSameLanguageNeutralVocabulary(testCase)
            cpp = exampleCppDataset;
            encoded = jsonencode(cpp);
            decoded = jsondecode(encoded);
            expectedFields = ["schemaVersion" "datasetId" "collectedAt" "benchmark" "implementation" "platform" "toolchain" "provenance" "cases"];

            testCase.verifyEqual(string(fieldnames(decoded))',expectedFields);
            testCase.verifyEqual(string(decoded.schemaVersion),"published-benchmark-v1");
            testCase.verifyEqual(string(decoded.implementation.id),"cpp");
            testCase.verifyEqual(string(decoded.toolchain.kind),"cpp");
            testCase.verifyFalse(isfield(decoded.toolchain.details,"matlabRelease"));
            testCase.verifyEqual(string(decoded.cases.status),"unavailable");
        end

        function runnerContainsNoMachineSpecificReferenceSelection(testCase)
            source = lower(string(fileread(fullfile(testCase.benchmarkFolder,"runWaveVortexBenchmark.m"))));
            testCase.verifySubstring(source,"scoringreferencefromcatalog");
            testCase.verifyFalse(contains(source,"m5-max"));
            testCase.verifyFalse(contains(source,"r2026a"));
            testCase.verifyFalse(contains(source,"referenceartifactpath"));
        end
    end
end

function dataset = exampleCppDataset
benchmark = struct("suiteId","scaling-standard-v1","suiteVersion",1,"operation","nonlinearFlux","correctnessTolerance",1e-12);
implementation = struct("id","cpp","displayName","WaveVortexModel C++","version","0.1.0","repository","https://github.com/JeffreyEarly/wave-vortex-model-cpp","commit",repmat('a',1,40),"backend","fftw","sourceDirty",false);
platform = struct("id","example-host","displayName","Example host","processor","Example CPU","physicalMemoryBytes",16*2^30,"os","Example OS","architecture","example64","threadCount",8);
toolchain = struct("kind","cpp","name","Clang","version","18.0.0","details",struct("buildType","Release"));
provenance = struct("rawArtifact","external/cpp/example.json","rawSchemaVersion","cpp-v1");
configuration = struct("Lxyz",[15e3 15e3 1300],"Nxyz",[64 64 65],"isHydrostatic",false,"shouldAntialias",true,"seed",1,"warmupCount",2,"sampleCount",3);
benchmarkCase = struct("id","boussinesq-64x64x65","transformId","boussinesq","scoreFamily","boussinesq","configuration",configuration,"status","unavailable","unavailableReason","Transform not implemented by this backend.");
dataset = struct("schemaVersion","published-benchmark-v1","datasetId","scaling-standard-v1--cpp-fftw--example-host--20260810T123456Z","collectedAt","2026-08-10T12:34:56Z","benchmark",benchmark,"implementation",implementation,"platform",platform,"toolchain",toolchain,"provenance",provenance,"cases",{{benchmarkCase}});
end

function writeJson(pathname,value)
fileId = fopen(pathname,"w");
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s\n",jsonencode(value,PrettyPrint=true));
clear cleanup
end

function raw = rawMatlabFixture
% Synthetic inputs verify normalization without retaining measured datasets.
memory = struct(status="complete",provider="synthetic",baselineBytes=100,peakBytes=300,peakIncrementBytes=200);
backend = struct(id="builtin",status="complete",correctnessPassed=true,relativeError=0,rawSeconds=[1 2 3],medianSeconds=2,memory=memory);
item = struct(id="first",operation="nonlinearFlux",transformId="boussinesq",scoreFamily="boussinesq",Lxyz=[100 100 10],Nxyz=[8 8 5],isHydrostatic=false,shouldAntialias=true,seed=1,warmupCount=1,sampleCount=3,status="complete",backends=backend);
second = item; second.id = "second";
environment = struct(sourceDirty=false,sourceCommit=repmat('a',1,40),physicalMemoryBytes=2^30,os="test",architecture="test",requestedThreads=1,matlabRelease="R2025b",matlabVersion="test");
suite = struct(id="scaling-standard-v1",version=1,operation="nonlinearFlux",cases=[item second]);
raw = struct(schemaVersion="1.0.0",runId="20260808T180708Z",environment=environment,configuration=struct(correctnessTolerance=1e-12),suites=suite);
end
