classdef TestThreeInterfaceBenchmark < matlab.unittest.TestCase
    properties
        RepositoryRoot (1,1) string
        TemporaryFolder (1,1) string
    end

    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            testCase.RepositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.RepositoryRoot,"Benchmarks")));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test,TestTags="full")
        function normalizationPreservesThreeMatchedInterfaces(testCase)
            raw = rawFixture;
            rawPath = fullfile(testCase.TemporaryFolder,"three-interface-benchmark.json");
            writelines(jsonencode(raw),rawPath);
            dataset = publishedThreeInterfaceBenchmarkFromArtifact(rawPath,platformId="m5-max",platformName="Apple M5 Max",provenancePath="Benchmarks/results/reference/three-interface/raw.json");
            testCase.verifyEqual(dataset.schemaVersion,"published-three-interface-v1")
            testCase.verifyEqual(dataset.datasetId,"three-interface--m5-max--20260815T120000Z")
            testCase.verifyNumElements(dataset.cases,3)
            for benchmarkCase = dataset.cases
                testCase.verifyNumElements(benchmarkCase{1}.interfaces,3)
                testCase.verifyTrue(benchmarkCase{1}.correctness.passed)
                testCase.verifyEqual(benchmarkCase{1}.interfaces{2}.integrationRatio,0.5)
                testCase.verifyEqual(benchmarkCase{1}.interfaces{3}.totalRSSRatio,0.25)
            end
        end

        function dirtyOrIncompleteArtifactsCannotBePublished(testCase)
            raw = rawFixture;
            rawPath = fullfile(testCase.TemporaryFolder,"raw.json");
            raw.source.isDirty = true;
            writelines(jsonencode(raw),rawPath);
            testCase.verifyError(@()publishedThreeInterfaceBenchmarkFromArtifact(rawPath,provenancePath="raw.json"),"WaveVortexBenchmark:InvalidThreeInterfaceArtifact")
            raw.source.isDirty = false; raw.status = "failed";
            writelines(jsonencode(raw),rawPath);
            testCase.verifyError(@()publishedThreeInterfaceBenchmarkFromArtifact(rawPath,provenancePath="raw.json"),"WaveVortexBenchmark:InvalidThreeInterfaceArtifact")
        end

        function integratorMismatchCannotBePublished(testCase)
            raw = rawFixture;
            raw.runs(2).integrator.actual = "adaptive-rk23";
            raw.runs(2).integrator.matched = false;
            rawPath = fullfile(testCase.TemporaryFolder,"raw.json");
            writelines(jsonencode(raw),rawPath);
            testCase.verifyError(@()publishedThreeInterfaceBenchmarkFromArtifact(rawPath,provenancePath="raw.json"),"WaveVortexBenchmark:IntegratorMismatch")
        end

        function incomparableMemoryCannotBePublished(testCase)
            raw = rawFixture;
            raw.runs(1).memory.status = "failed";
            rawPath = fullfile(testCase.TemporaryFolder,"raw.json");
            writelines(jsonencode(raw),rawPath);
            testCase.verifyError(@()publishedThreeInterfaceBenchmarkFromArtifact(rawPath,provenancePath="raw.json"),"WaveVortexBenchmark:IncomparableMemory")
        end

        function outputGraphMismatchCannotBePublished(testCase)
            raw = rawFixture;
            raw.comparison(2).outputGraph.categories(4).passed = false;
            raw.comparison(2).outputGraph.passed = false;
            rawPath = fullfile(testCase.TemporaryFolder,"raw.json");
            writelines(jsonencode(raw),rawPath);
            testCase.verifyError(@()publishedThreeInterfaceBenchmarkFromArtifact(rawPath,provenancePath="raw.json"),"WaveVortexBenchmark:OutputGraphMismatch")
        end

        function benchmarkWorkerRemainsAuthorOnly(testCase)
            manifest = string(fileread(fullfile(testCase.RepositoryRoot,"resources","mpackage.json")));
            testCase.verifyFalse(contains(manifest,"Benchmarks"))
            cmake = string(fileread(fullfile(testCase.RepositoryRoot,"PortableRuntime","CMakeLists.txt")));
            testCase.verifySubstring(cmake,"WV_RUNTIME_BUILD_BENCHMARKS")
            testCase.verifySubstring(cmake,"wv-standalone-nonlinear-flux-benchmark")
        end

        function completeOutputGraphRejectsPayloadAndMetadataDifferences(testCase)
            reference = fullfile(testCase.TemporaryFolder,"reference.nc");
            candidate = fullfile(testCase.TemporaryFolder,"candidate.nc");
            createOutputGraphFixture(reference,false,false);
            copyfile(reference,candidate)
            ncwrite(candidate,"/particles/float_x",[1; 9]);
            comparison = compareWaveVortexOutputGraphs(reference,candidate);
            testCase.verifyFalse(comparison.passed)
            testCase.verifyTrue(any(contains(comparison.differences,"float_x payload")))
            copyfile(reference,candidate,"f")
            ncwriteatt(candidate,"/particles","outputInterval",2);
            comparison = compareWaveVortexOutputGraphs(reference,candidate);
            testCase.verifyFalse(comparison.passed)
            testCase.verifyTrue(any(contains(comparison.differences,"outputInterval")))
        end

        function completeOutputGraphRejectsShapeOrderAndExtraOutput(testCase)
            reference = fullfile(testCase.TemporaryFolder,"reference.nc");
            reordered = fullfile(testCase.TemporaryFolder,"reordered.nc");
            wrongShape = fullfile(testCase.TemporaryFolder,"wrong-shape.nc");
            createOutputGraphFixture(reference,false,false);
            createOutputGraphFixture(reordered,true,false);
            createOutputGraphFixture(wrongShape,false,true);
            testCase.verifyFalse(compareWaveVortexOutputGraphs(reference,reordered).passed)
            testCase.verifyFalse(compareWaveVortexOutputGraphs(reference,wrongShape).passed)
            copyfile(reference,reordered,"f")
            nccreate(reordered,"/particles/extra",Dimensions={"id",2});
            ncwrite(reordered,"/particles/extra",[1; 2]);
            testCase.verifyFalse(compareWaveVortexOutputGraphs(reference,reordered).passed)
        end
    end

    methods (Test,TestTags="optional")
        function reducedMatchedBenchmarkRunsAllInterfaces(testCase)
            if ~isCanonicalNativePlatform
                testCase.verifyError(@()runThreeInterfaceBenchmark(shouldWriteArtifacts=false),"WaveVortexBenchmark:ThreeInterfaceUnsupportedPlatform")
                return
            end
            result = runThreeInterfaceBenchmark(Nxyz=[8 6 5],processRunCount=1,deltaT=1e-4,samplingIntervalSeconds=0.01,plateauSeconds=0.02,shouldWriteArtifacts=false);
            testCase.verifyEqual(result.status,"complete")
            testCase.verifyEqual(string({result.comparison.id}),["nonlinear-flux" "fixed-rk4-continuation" "adaptive-rk23-observer-output"])
            testCase.verifyTrue(all([result.comparison.outputAgreementPassed]))
            testCase.verifyLessThanOrEqual(max([result.comparison.maximumRelativeError]),1e-12)
            testCase.verifyTrue(all(arrayfun(@(item)item.matchedContractPassed,result.comparison)))
        end
    end
end

function createOutputGraphFixture(pathname,reordered,wrongShape)
if reordered
    variableNames = ["u" "t"];
else
    variableNames = ["t" "u"];
end
for name = variableNames
    if name == "t"
        nccreate(pathname,"/wave-vortex/t",Dimensions={"t",2});
        ncwrite(pathname,"/wave-vortex/t",[0; 1]);
    else
        nccreate(pathname,"/wave-vortex/u",Dimensions={"x",2,"t",2});
        ncwrite(pathname,"/wave-vortex/u",reshape(1:4,2,2));
    end
end
ncwriteatt(pathname,"/wave-vortex","outputInterval",1);
nccreate(pathname,"/wave-vortex/Ap_real",Dimensions={"kl",2,"j",2,"t",2});
ncwrite(pathname,"/wave-vortex/Ap_real",reshape(1:8,2,2,2));
nccreate(pathname,"/wave-vortex/mooring_u",Dimensions={"id",2,"t",2});
ncwrite(pathname,"/wave-vortex/mooring_u",reshape(1:4,2,2));
ncwriteatt(pathname,"/wave-vortex/mooring_u","mooringName","mooring");
nccreate(pathname,"/particles/t",Dimensions={"t",2});
ncwrite(pathname,"/particles/t",[0; 1]);
particleCount = conditional(wrongShape,3,2);
nccreate(pathname,"/particles/float_x",Dimensions={"id",particleCount});
ncwrite(pathname,"/particles/float_x",(1:particleCount)');
ncwriteatt(pathname,"/particles/float_x","isParticle","1");
ncwriteatt(pathname,"/particles","outputInterval",1);
nccreate(pathname,"/tracers/t",Dimensions={"t",2});
ncwrite(pathname,"/tracers/t",[0; 1]);
nccreate(pathname,"/tracers/dye",Dimensions={"x",2,"y",2,"t",2});
ncwrite(pathname,"/tracers/dye",reshape(1:8,2,2,2));
ncwriteatt(pathname,"/tracers/dye","isTracer","1");
end

function value = isCanonicalNativePlatform
value = ismac && computer("arch") == "maca64";
end

function value = conditional(condition,trueValue,falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function raw = rawFixture
interfaces = [interfaceRecord("matlab-builtin",1,1,1,1); interfaceRecord("matlab-compiled",0.5,0.5,2,2); interfaceRecord("standalone-compiled",0.25,0.25,0.25,0.25)];
definitions = [caseDefinition("nonlinear-flux","nonlinearFlux","none"); caseDefinition("fixed-rk4-continuation","model-continuation","fixed-rk4"); caseDefinition("adaptive-rk23-observer-output","model-continuation","adaptive-rk23")];
comparison = repmat(struct("id","","interfaces",interfaces,"maximumRelativeError",1e-14,"outputAgreementPassed",true,"outputGraph",modelOutputGraph,"integratorAgreementPassed",true,"memoryAgreementPassed",true,"matchedContractPassed",true),3,1);
runs = repmat(runRecord("matlab-builtin",definitions(1)),0,1);
for iCase = 1:3
    comparison(iCase).id = definitions(iCase).id;
    if definitions(iCase).operation == "nonlinearFlux"
        comparison(iCase).outputGraph = fluxOutputGraph;
    end
    for identifier = ["matlab-builtin" "matlab-compiled" "standalone-compiled"]
        runs(end+1,1) = runRecord(identifier,definitions(iCase)); %#ok<AGROW>
    end
end
provider = struct("provider",struct("id","native-neon-pthreads","version","3.3.11","threadBackend","pthreads"),"module",struct("sha256",repmat('b',1,64),"identityValidated",true),"libraries",struct("openmp",struct("detected",false)));
environment = struct("processor","Apple M5 Max","physicalMemoryBytes",64*2^30,"os","macOS","architecture","maca64","matlabVersion","R2026a Update 4");
source = struct("commit",repmat('a',1,40),"tree",repmat('c',1,40),"isDirty",false);
configuration = struct("Lxyz",[15000 15000 1300],"processRunCount",1,"warmupCount",0,"samplesPerProcess",1,"threadCount",18);
raw = struct("schemaVersion","three-interface-benchmark-v1","status","complete","runId","20260815T120000000Z","source",source,"environment",environment,"configuration",configuration,"provider",provider,"cases",definitions,"runs",runs,"comparison",comparison);
end

function value = modelOutputGraph
names = ["coefficients" "eulerianFields" "moorings" "particles" "tracers" "times"];
categories = arrayfun(@(name)struct("name",name,"variableCount",1,"maximumAbsoluteError",0,"maximumRelativeError",1e-14,"passed",true),names);
value = struct("kind","complete-netcdf-output-graph","passed",true,"maximumRelativeError",1e-14,"maximumAbsoluteError",0,"variableCount",6,"recordCount",12,"categories",categories,"differences",strings(0,1));
end

function value = fluxOutputGraph
category = struct("name","coefficients","variableCount",3,"maximumAbsoluteError",0,"maximumRelativeError",1e-14,"passed",true);
value = struct("kind","flux-arrays","passed",true,"maximumRelativeError",1e-14,"maximumAbsoluteError",0,"variableCount",3,"recordCount",0,"categories",category,"differences",strings(0,1));
end

function value = caseDefinition(identifier,operation,integrator)
value = struct("id",identifier,"operation",operation,"requestedIntegrator",integrator,"Nxyz",[256 256 129],"forcing","default WVNonlinearAdvection","shouldAntialias",true,"deltaT",1e-3,"finalTime",2e-3,"relativeTolerance",1e-3,"absoluteTolerance",1e-6,"outputInterval",5e-4,"observerGraph","fields, particles, tracers");
end

function value = interfaceRecord(identifier,processRatio,integrationRatio,totalRatio,incrementRatio)
value = struct("id",identifier,"processWallSeconds",processRatio,"interfaceTotalSeconds",processRatio,"integrationSeconds",integrationRatio,"totalPeakRSSBytes",totalRatio*2^30,"incrementalPeakRSSBytes",incrementRatio*2^28,"finalRSSBytes",totalRatio*2^29,"processWallRatio",processRatio,"integrationRatio",integrationRatio,"totalRSSRatio",totalRatio,"incrementalRSSRatio",incrementRatio);
end

function value = runRecord(identifier,definition)
value = struct("interface",identifier,"case",definition,"processWallSeconds",1,"integrationSeconds",1,"memory",struct("status","complete","provider","macos-ps-process-tree","totalPeakRSSBytes",2^30),"integrator",struct("requested",definition.requestedIntegrator,"actual",definition.requestedIntegrator,"matched",true));
end
