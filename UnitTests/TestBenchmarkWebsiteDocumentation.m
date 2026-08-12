classdef TestBenchmarkWebsiteDocumentation < matlab.unittest.TestCase
    properties
        repositoryRoot
        temporaryFolder
    end

    methods (TestClassSetup)
        function addToolsPath(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.repositoryRoot,"tools")));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.temporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test,TestTags="full")
        function emptyCatalogBuildsUsefulPageWithoutAssets(testCase)
            [root,buildFolder] = testCase.createFixture("empty");
            testCase.writeCatalog(root,struct([]));

            generateBenchmarkWebsiteDocumentation(root,buildFolder);

            page = string(fileread(fullfile(buildFolder,"benchmarks.md")));
            testCase.verifySubstring(page,"No approved benchmark datasets have been published yet");
            testCase.verifySubstring(page,"No approved scaling datasets have been published yet");
            testCase.verifySubstring(page,"No approved computer results have been published yet");
            testCase.verifySubstring(page,"No approved result files have been published yet");
            testCase.verifyFalse(isfolder(fullfile(buildFolder,"assets","benchmarks")));
            testCase.verifyFalse(contains(page,"Performance across releases"));
        end

        function matlabCppAndMissingCasesRenderDeterministically(testCase)
            [root,firstBuild] = testCase.createFixture("multi-platform");
            cases = standardCases(1);
            first = publishedDataset("scaling-standard-v1--matlab-builtin--m5-max--20260810T120000Z","matlab","builtin","m5-max","M5 Max","4.2.1","2026-08-10T12:00:00Z",cases);
            second = publishedDataset("scaling-standard-v1--matlab-builtin--zen4--20260810T130000Z","matlab","builtin","zen4","Zen 4 workstation","4.2.1","2026-08-10T13:00:00Z",standardCases(1.4));
            cppCases = standardCases(0.6);
            cppCases{1} = unavailableCase(cppCases{1},"Transform is not implemented by this backend.");
            cppCases(2) = [];
            third = publishedDataset("scaling-standard-v1--cpp-fftw--m5-max--20260810T140000Z","cpp","fftw","m5-max","M5 Max","0.1.0","2026-08-10T14:00:00Z",cppCases);
            entries = testCase.publishDatasets(root,{first,second,third});
            testCase.writeCatalog(root,entries);

            generateBenchmarkWebsiteDocumentation(root,firstBuild);
            secondBuild = fullfile(root,"second-build");
            mkdir(secondBuild);
            copyfile(fullfile(testCase.repositoryRoot,"Documentation","WebsiteDocumentation","benchmarks.md"),fullfile(secondBuild,"benchmarks.md"));
            generateBenchmarkWebsiteDocumentation(root,secondBuild);

            comparison = compareDocumentationTrees(firstBuild,secondBuild);
            testCase.verifyTrue(comparison.IsEqual,strjoin(comparison.Substantive,newline));
            page = string(fileread(fullfile(firstBuild,"benchmarks.md")));
            testCase.verifySubstring(page,"M5 Max");
            testCase.verifySubstring(page,"Zen 4 workstation");
            testCase.verifySubstring(page,"WaveVortexModel C++");
            testCase.verifySubstring(page,"Transform is not implemented");
            testCase.verifySubstring(page,"Case was not recorded in this dataset");
            testCase.verifySubstring(page,"<details markdown=""1"">");
            testCase.verifyFalse(contains(page,"Performance across releases"));

            chartNames = ["runtime-horizontal" "runtime-vertical" "memory-horizontal" "memory-vertical"];
            for chartName = chartNames
                chartPath = fullfile(firstBuild,"assets","benchmarks",chartName + ".svg");
                testCase.verifyTrue(isfile(chartPath));
                chart = string(fileread(chartPath));
                testCase.verifySubstring(chart,"<title");
                testCase.verifySubstring(chart,"<desc");
                testCase.verifySubstring(chart,"viewBox");
            end
            for dataset = [first second third]
                testCase.verifyTrue(isfile(fullfile(firstBuild,"benchmarks","data",dataset.datasetId + ".json")));
                testCase.verifyTrue(isfile(fullfile(firstBuild,"benchmarks","raw",dataset.datasetId + ".json")));
            end
            report = validateWebsiteDocumentation(firstBuild,ShouldFail=false,ShouldCheckHierarchy=false,ShouldCheckGeneratedContent=false);
            testCase.verifyTrue(report.IsValid,strjoin(report.Diagnostics,newline));
        end

        function comparableVersionsProduceReleaseHistory(testCase)
            [root,buildFolder] = testCase.createFixture("history");
            first = publishedDataset("scaling-standard-v1--matlab-builtin--m5-max--20260810T120000Z","matlab","builtin","m5-max","M5 Max","4.2.1","2026-08-10T12:00:00Z",standardCases(1));
            second = publishedDataset("scaling-standard-v1--matlab-builtin--m5-max--20260811T120000Z","matlab","builtin","m5-max","M5 Max","4.2.2","2026-08-11T12:00:00Z",standardCases(0.9));
            entries = testCase.publishDatasets(root,{first,second});
            testCase.writeCatalog(root,entries);

            generateBenchmarkWebsiteDocumentation(root,buildFolder);

            page = string(fileread(fullfile(buildFolder,"benchmarks.md")));
            testCase.verifySubstring(page,"## Performance across releases");
            testCase.verifySubstring(page,"4.2.1");
            testCase.verifySubstring(page,"4.2.2");
            atGlance = extractBetween(page,"<!-- BENCHMARKS:AT_GLANCE:START -->","<!-- BENCHMARKS:AT_GLANCE:END -->");
            testCase.verifyFalse(contains(atGlance,"4.2.1"));
            testCase.verifySubstring(atGlance,"4.2.2");
        end

        function missingSuiteDatasetIsExplicitlyUnavailable(testCase)
            [root,buildFolder] = testCase.createFixture("missing-suite");
            standard = publishedDataset("scaling-standard-v1--matlab-builtin--m5-max--20260810T120000Z","matlab","builtin","m5-max","M5 Max","4.2.1","2026-08-10T12:00:00Z",standardCases(1));
            large = publishedDataset("scaling-large-v1--matlab-builtin--zen4--20260810T130000Z","matlab","builtin","zen4","Zen 4 workstation","4.2.1","2026-08-10T13:00:00Z",standardCases(1.4));
            large.benchmark.suiteId = "scaling-large-v1";
            entries = testCase.publishDatasets(root,{standard,large});
            testCase.writeCatalog(root,entries);

            generateBenchmarkWebsiteDocumentation(root,buildFolder);

            page = string(fileread(fullfile(buildFolder,"benchmarks.md")));
            testCase.verifySubstring(page,"No scaling-large-v1 dataset was collected for this environment.");
            testCase.verifySubstring(page,"No scaling-standard-v1 dataset was collected for this environment.");
            testCase.verifySubstring(page,"MATLAB R2026a Update 4");
            testCase.verifySubstring(page,"| scaling-large-v1 | Constant nonhydrostatic | M5 Max");
            testCase.verifySubstring(page,"| scaling-standard-v1 | Constant nonhydrostatic | Zen 4 workstation");
            chart = string(fileread(fullfile(buildFolder,"assets","benchmarks","runtime-horizontal.svg")));
            testCase.verifySubstring(chart,"M5 Max — MATLAB R2026a Update 4 — standard — Constant nonhydrostatic");
            testCase.verifySubstring(chart,"Zen 4 workstation — MATLAB R2026a Update 4 — large — Constant nonhydrostatic");
        end

        function unsafeMissingDuplicateAndMismatchedArtifactsFail(testCase)
            [root,buildFolder] = testCase.createFixture("invalid");
            dataset = publishedDataset("scaling-standard-v1--matlab-builtin--m5-max--20260810T120000Z","matlab","builtin","m5-max","M5 Max","4.2.1","2026-08-10T12:00:00Z",standardCases(1));
            entries = testCase.publishDatasets(root,{dataset});

            unsafe = entries;
            unsafe.artifact = "../outside.json";
            testCase.writeCatalog(root,unsafe);
            testCase.verifyError(@()generateBenchmarkWebsiteDocumentation(root,buildFolder),"WaveVortexModel:UnsafeBenchmarkPath");

            missing = entries;
            missing.artifact = "Benchmarks/results/published/missing.json";
            testCase.writeCatalog(root,missing);
            testCase.verifyError(@()generateBenchmarkWebsiteDocumentation(root,buildFolder),"WaveVortexModel:MissingBenchmarkArtifact");

            mismatch = entries;
            mismatch.datasetId = "scaling-standard-v1--matlab-builtin--other--20260810T120000Z";
            testCase.writeCatalog(root,mismatch);
            testCase.verifyError(@()generateBenchmarkWebsiteDocumentation(root,buildFolder),"WaveVortexModel:PublishedBenchmarkIdentityMismatch");

            duplicate = [entries entries];
            testCase.writeCatalog(root,duplicate);
            testCase.verifyError(@()generateBenchmarkWebsiteDocumentation(root,buildFolder),"WaveVortexModel:DuplicatePublishedBenchmark");
        end

        function conflictingComparableCasesFail(testCase)
            [root,buildFolder] = testCase.createFixture("conflict");
            first = publishedDataset("scaling-standard-v1--matlab-builtin--m5-max--20260810T120000Z","matlab","builtin","m5-max","M5 Max","4.2.1","2026-08-10T12:00:00Z",standardCases(1));
            conflictingCases = standardCases(1.2);
            conflictingCases{1}.configuration.seed = 999;
            second = publishedDataset("scaling-standard-v1--matlab-builtin--zen4--20260810T130000Z","matlab","builtin","zen4","Zen 4 workstation","4.2.1","2026-08-10T13:00:00Z",conflictingCases);
            entries = testCase.publishDatasets(root,{first,second});
            testCase.writeCatalog(root,entries);

            testCase.verifyError(@()generateBenchmarkWebsiteDocumentation(root,buildFolder),"WaveVortexModel:ConflictingPublishedBenchmarkCase");
        end
    end

    methods (Access=private)
        function [root,buildFolder] = createFixture(testCase,name)
            root = fullfile(testCase.temporaryFolder,name);
            buildFolder = fullfile(root,"build");
            mkdir(fullfile(root,"Benchmarks","results"));
            mkdir(buildFolder);
            copyfile(fullfile(testCase.repositoryRoot,"Documentation","WebsiteDocumentation","benchmarks.md"),fullfile(buildFolder,"benchmarks.md"));
        end

        function entries = publishDatasets(testCase,root,datasets)
            entries = repmat(struct("datasetId","","artifact",""),1,numel(datasets));
            publishedFolder = fullfile(root,"Benchmarks","results","published");
            rawFolder = fullfile(root,"Benchmarks","results","raw");
            mkdir(publishedFolder);
            mkdir(rawFolder);
            for iDataset = 1:numel(datasets)
                dataset = datasets{iDataset};
                artifact = "Benchmarks/results/published/" + dataset.datasetId + ".json";
                rawArtifact = "Benchmarks/results/raw/" + dataset.datasetId + ".json";
                dataset.provenance.rawArtifact = rawArtifact;
                testCase.writeJson(fullfile(root,artifact),dataset);
                testCase.writeJson(fullfile(root,rawArtifact),struct("fixture",true));
                entries(iDataset) = struct("datasetId",dataset.datasetId,"artifact",artifact);
            end
        end

        function writeCatalog(testCase,root,publishedDatasets)
            references = [ ...
                struct("suiteId","core-v1","backendId","builtin","rawArtifact","Benchmarks/results/reference/core.json"), ...
                struct("suiteId","scaling-standard-v1","backendId","builtin","rawArtifact","Benchmarks/results/reference/standard.json"), ...
                struct("suiteId","scaling-large-v1","backendId","builtin","rawArtifact","Benchmarks/results/reference/large.json")];
            catalog = struct("schemaVersion","benchmark-catalog-v1","scoringReferences",references,"publishedDatasets",publishedDatasets);
            testCase.writeJson(fullfile(root,"Benchmarks","results","catalog.json"),catalog);
        end

        function writeJson(~,path,value)
            parent = fileparts(path);
            if ~isfolder(parent)
                mkdir(parent);
            end
            fileId = fopen(path,"w");
            cleanup = onCleanup(@()fclose(fileId));
            fprintf(fileId,"%s\n",jsonencode(value,PrettyPrint=true));
            clear cleanup
        end
    end
end

function dataset = publishedDataset(datasetId,implementationId,backendId,platformId,platformName,version,collectedAt,cases)
benchmark = struct("suiteId","scaling-standard-v1","suiteVersion",1,"operation","nonlinearFlux","correctnessTolerance",1e-12);
displayName = "WaveVortexModel MATLAB";
toolchain = struct("kind","matlab","name","MATLAB","version","R2026a Update 4","details",struct("release","R2026a"));
if implementationId == "cpp"
    displayName = "WaveVortexModel C++";
    toolchain = struct("kind","cpp","name","Clang","version","18.0.0","details",struct("buildType","Release"));
end
implementation = struct("id",implementationId,"displayName",displayName,"version",version,"repository","https://github.com/JeffreyEarly/wave-vortex-model","commit",repmat('a',1,40),"backend",backendId,"sourceDirty",false);
platform = struct("id",platformId,"displayName",platformName,"processor",platformName + " processor","physicalMemoryBytes",64*2^30,"os","Example OS","architecture","example64","threadCount",16);
provenance = struct("rawArtifact","placeholder.json","rawSchemaVersion","1.1.0");
dataset = struct("schemaVersion","published-benchmark-v1","datasetId",datasetId,"collectedAt",collectedAt,"benchmark",benchmark,"implementation",implementation,"platform",platform,"toolchain",toolchain,"provenance",provenance,"cases",{cases});
end

function cases = standardCases(scale)
definitions = { ...
    "constant-nonhydrostatic-64x64x65","constant-nonhydrostatic",[64 64 65]; ...
    "constant-nonhydrostatic-128x128x65","constant-nonhydrostatic",[128 128 65]; ...
    "constant-nonhydrostatic-256x256x65","constant-nonhydrostatic",[256 256 65]; ...
    "constant-nonhydrostatic-128x128x33","constant-nonhydrostatic",[128 128 33]; ...
    "constant-nonhydrostatic-128x128x129","constant-nonhydrostatic",[128 128 129]; ...
    "barotropic-qg-128x128","barotropic-qg",[128 128]; ...
    "barotropic-qg-256x256","barotropic-qg",[256 256]};
cases = cell(1,size(definitions,1));
for iCase = 1:numel(cases)
    cases{iCase} = completeCase(definitions{iCase,1},definitions{iCase,2},definitions{iCase,3},100+iCase,scale*iCase/100);
end
end

function benchmarkCase = completeCase(id,transformId,Nxyz,seed,medianSeconds)
Lxyz = [15e3 15e3 1300];
if numel(Nxyz) == 2
    Lxyz = Lxyz(1:2);
end
configuration = struct("Lxyz",Lxyz,"Nxyz",Nxyz,"isHydrostatic",transformId ~= "constant-nonhydrostatic","shouldAntialias",true,"seed",seed,"warmupCount",2,"sampleCount",3);
timing = struct("medianSeconds",medianSeconds,"samplesSeconds",medianSeconds*[0.9 1 1.1]);
correctness = struct("passed",true,"relativeError",0);
peak = (2+iScale(Nxyz))*2^30;
memory = struct("status","complete","provider","fixture-rss","baselineProcessBytes",2^30,"peakProcessBytes",peak,"peakIncrementBytes",peak-2^30);
benchmarkCase = struct("id",id,"transformId",transformId,"scoreFamily",transformId,"configuration",configuration,"status","complete","timing",timing,"correctness",correctness,"memory",memory);
end

function scale = iScale(Nxyz)
scale = prod(double(Nxyz))/prod([64 64]);
end

function benchmarkCase = unavailableCase(complete,reason)
benchmarkCase = struct("id",complete.id,"transformId",complete.transformId,"scoreFamily",complete.scoreFamily,"configuration",complete.configuration,"status","unavailable","unavailableReason",reason);
end
