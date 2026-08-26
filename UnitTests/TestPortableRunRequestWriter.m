classdef TestPortableRunRequestWriter < matlab.unittest.TestCase
    properties (SetAccess=private)
        RepositoryRoot (1,1) string
        TemporaryFolder (1,1) string
        ModelPath (1,1) string
    end

    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.RepositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = string(fixture.Folder);
            testCase.ModelPath = fullfile(testCase.TemporaryFolder,"model bundle Ω.nc");
            copyfile(testCase.fixturePath(),testCase.ModelPath);
            ncwriteatt(testCase.ModelPath,"/","portableFileIdentifier","primary");
        end
    end

    methods (Test, TestTags="full")
        function writesEveryAcceptedSchemaFormDeterministically(testCase)
            requestFolder = fullfile(testCase.TemporaryFolder,"requests with Ω");
            mkdir(requestFolder)
            copyfile(testCase.ModelPath,fullfile(requestFolder,"model bundle Ω.nc"));
            modelReference = "model bundle Ω.nc";

            requests = [
                testCase.writeRequest(requestFolder,"v1-fixed",1,"fixed-rk4",initialStep=.25)
                testCase.writeRequest(requestFolder,"v1-rk23",1,"adaptive-rk23",initialStep=.25,maximumStep=1,relativeTolerance=1e-3,absoluteToleranceScale=1e-6)
                testCase.writeRequest(requestFolder,"v2-fixed",2,"fixed-rk4",initialStep=.25)
                testCase.writeRequest(requestFolder,"v2-cfl-advective",2,"fixed-rk4",cfl=.25,timeStepConstraint="advective")
                testCase.writeRequest(requestFolder,"v2-cfl-oscillatory",2,"fixed-rk4",cfl=.25,timeStepConstraint="oscillatory")
                testCase.writeRequest(requestFolder,"v2-cfl-min",2,"fixed-rk4",cfl=.25,timeStepConstraint="min")
                testCase.writeRequest(requestFolder,"v2-rk23",2,"adaptive-rk23",initialStep=.25,maximumStep=1,relativeTolerance=1e-3,absoluteToleranceScale=1e-6)
                testCase.writeRequest(requestFolder,"v2-rk45",2,"adaptive-rk45",initialStep=.25,maximumStep=1,relativeTolerance=1e-3,absoluteToleranceScale=1e-6)
                testCase.writeRequest(requestFolder,"v2-rk78",2,"adaptive-rk78",initialStep=.25,maximumStep=1,relativeTolerance=1e-3,absoluteToleranceScale=1e-6)
                ];

            for iRequest = 1:numel(requests)
                document = jsondecode(fileread(requests(iRequest)));
                testCase.verifyEqual(string(document.modelFiles),modelReference)
                testCase.verifyEqual(string(fieldnames(document)), ...
                    ["schemaIdentifier";"schemaVersion";"modelFiles";"integration";"output";"execution";"report"])
                text = string(fileread(requests(iRequest)));
                for forbidden = ["transform","forcing","observer","schedule","restart","state"]
                    quote = string(char(34));
                    testCase.verifyFalse(contains(lower(text),quote+forbidden+quote))
                end
            end
        end

        function pathsMapsAndOrderFollowDocumentContract(testCase)
            folderA = fullfile(testCase.TemporaryFolder,"A Ω");
            folderB = fullfile(testCase.TemporaryFolder,"B Ω");
            mkdir(folderA)
            mkdir(folderB)
            for folder = [folderA folderB]
                copyfile(testCase.ModelPath,fullfile(folder,"first model.nc"));
                second = fullfile(folder,"second model.nc");
                copyfile(testCase.ModelPath,second);
                ncwriteatt(second,"/","portableFileIdentifier","secondary");
            end
            destinations = configureDictionary("string","string");
            destinations(["secondary","primary"]) = ["second output Ω.nc","first output.nc"];
            requestA = fullfile(folderA,"request.json");
            requestB = fullfile(folderB,"request.json");
            originalFolder = string(pwd);
            folderCleanup = onCleanup(@()cd(originalFolder));
            cd(tempdir)
            for request = [requestA requestB]
                WVModel.writePortableRunRequest(request,["second model.nc","first model.nc"], ...
                    schemaVersion=2,method="fixed-rk4",finalTime=4,initialStep=.25, ...
                    outputPolicy="create",destinations=destinations,fftProvider="reference",threads=1, ...
                    reportPath="report Ω.json");
            end
            clear folderCleanup

            testCase.verifyEqual(testCase.fileBytes(requestA),testCase.fileBytes(requestB))
            document = jsondecode(fileread(requestA));
            testCase.verifyEqual(string(document.modelFiles),["second model.nc";"first model.nc"])
            destinationText = extractBetween(string(fileread(requestA)), ...
                '"destinations": {','    }');
            testCase.verifyLessThan(strfind(destinationText,'"primary"'),strfind(destinationText,'"secondary"'))
        end

        function rejectsInvalidContractsOptionsAndAliases(testCase)
            request = fullfile(testCase.TemporaryFolder,"request.json");
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=1,method="adaptive-rk45",finalTime=1,initialStep=.1,maximumStep=1,relativeTolerance=1e-3,absoluteToleranceScale=1e-6), ...
                "WaveVortexModel:PortableRunRequestIntegration")
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1,cfl=.2), ...
                "WaveVortexModel:PortableRunRequestIntegration")
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=2,method="adaptive-rk45",finalTime=1,initialStep=.1,maximumStep=1,relativeTolerance=1e-3,absoluteToleranceScale=1e-6,cfl=.2), ...
                "WaveVortexModel:PortableRunRequestIntegration")
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,[testCase.ModelPath testCase.ModelPath], ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1), ...
                "WaveVortexModel:PortableRunRequestDuplicateFile")
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,[testCase.ModelPath fullfile(testCase.TemporaryFolder,"missing.nc")], ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1), ...
                "WaveVortexModel:PortableRunRequestMissingFile")

            second = fullfile(testCase.TemporaryFolder,"inconsistent.nc");
            copyfile(testCase.ModelPath,second);
            ncwriteatt(second,"/","portableFileIdentifier","secondary");
            ncwrite(second,"Lx",2*ncread(second,"Lx"));
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,[testCase.ModelPath second], ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1), ...
                "WaveVortexModel:PortableRunRequestInconsistentBundle")

            unsupported = fullfile(testCase.TemporaryFolder,"unsupported.nc");
            copyfile(testCase.ModelPath,unsupported);
            ncwriteatt(unsupported,"/","model_version","5.0.0");
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,unsupported, ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1), ...
                "WaveVortexModel:PortableRunRequestContract")

            emptyMap = configureDictionary("string","string");
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1,outputPolicy="create",destinations=emptyMap), ...
                "WaveVortexModel:PortableRunRequestDestinations")
            aliasMap = configureDictionary("string","string");
            aliasMap("primary") = testCase.ModelPath;
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1,outputPolicy="replace",destinations=aliasMap), ...
                "WaveVortexModel:PortableRunRequestAlias")
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1,reportPath=request), ...
                "WaveVortexModel:PortableRunRequestAlias")

            configuration = testCase.baseConfiguration();
            configuration.unknownField = true;
            testCase.verifyError(@()WVModel.writePortableRunRequestForTesting( ...
                request,testCase.ModelPath,configuration,""), ...
                "WaveVortexModel:PortableRunRequestOptions")

            appendTarget = fullfile(testCase.TemporaryFolder,"append target.nc");
            copyfile(testCase.ModelPath,appendTarget);
            ncwrite(appendTarget,"Lx",2*ncread(appendTarget,"Lx"));
            appendMap = configureDictionary("string","string");
            appendMap("primary") = appendTarget;
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,testCase.ModelPath, ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1, ...
                outputPolicy="append",destinations=appendMap), ...
                "WaveVortexModel:PortableRunRequestInconsistentBundle")

            multiSecond = fullfile(testCase.TemporaryFolder,"multi second.nc");
            copyfile(testCase.ModelPath,multiSecond);
            ncwriteatt(multiSecond,"/","portableFileIdentifier","secondary");
            collisionMap = configureDictionary("string","string");
            collisionMap(["primary","secondary"]) = ["same.nc","./same.nc"];
            testCase.verifyError(@()WVModel.writePortableRunRequest(request,[testCase.ModelPath multiSecond], ...
                schemaVersion=2,method="fixed-rk4",finalTime=1,initialStep=.1, ...
                outputPolicy="create",destinations=collisionMap), ...
                "WaveVortexModel:PortableRunRequestAlias")
        end

        function everyInjectedFailurePreservesOldRequest(testCase)
            request = fullfile(testCase.TemporaryFolder,"request.json");
            oldBytes = uint8('old request bytes')';
            testCase.writeBytes(request,oldBytes);
            configuration = testCase.baseConfiguration();
            beforeFiles = string({dir(testCase.TemporaryFolder).name});
            for stage = ["validation","encoding","temporary-file","replacement","cleanup"]
                testCase.verifyError(@()WVModel.writePortableRunRequestForTesting( ...
                    request,testCase.ModelPath,configuration,stage), ...
                    "WaveVortexModel:PortableRunRequestInjectedFailure")
                testCase.verifyEqual(testCase.fileBytes(request),oldBytes)
                testCase.verifyEqual(string({dir(testCase.TemporaryFolder).name}),beforeFiles)
            end
        end
    end

    methods (Access=private)
        function request = writeRequest(testCase,folder,name,schemaVersion,method,options)
            arguments
                testCase
                folder
                name
                schemaVersion
                method
                options.initialStep = NaN
                options.cfl = NaN
                options.timeStepConstraint = ""
                options.maximumStep = NaN
                options.relativeTolerance = NaN
                options.absoluteToleranceScale = NaN
            end
            request = fullfile(folder,name+".json");
            WVModel.writePortableRunRequest(request,"model bundle Ω.nc", ...
                schemaVersion=schemaVersion,method=method,finalTime=12, ...
                initialStep=options.initialStep,cfl=options.cfl,timeStepConstraint=options.timeStepConstraint, ...
                maximumStep=options.maximumStep,relativeTolerance=options.relativeTolerance, ...
                absoluteToleranceScale=options.absoluteToleranceScale,reportPath=name+" report Ω.json");
            firstBytes = testCase.fileBytes(request);
            WVModel.writePortableRunRequest(request,"model bundle Ω.nc", ...
                schemaVersion=schemaVersion,method=method,finalTime=12, ...
                initialStep=options.initialStep,cfl=options.cfl,timeStepConstraint=options.timeStepConstraint, ...
                maximumStep=options.maximumStep,relativeTolerance=options.relativeTolerance, ...
                absoluteToleranceScale=options.absoluteToleranceScale,reportPath=name+" report Ω.json");
            testCase.verifyEqual(testCase.fileBytes(request),firstBytes)
        end

        function configuration = baseConfiguration(~)
            configuration = struct( ...
                "schemaVersion",2,"method","fixed-rk4","finalTime",12, ...
                "initialStep",.25,"cfl",NaN,"timeStepConstraint","", ...
                "maximumStep",NaN,"relativeTolerance",NaN,"absoluteToleranceScale",NaN, ...
                "outputPolicy","append","destinations",configureDictionary("string","string"), ...
                "fftProvider","reference","threads",1,"reportPath","report.json");
        end

        function path = fixturePath(testCase)
            path = fullfile(testCase.RepositoryRoot,"PortableRuntime","tests","fixtures","time-series-hydrostatic.nc");
        end

        function bytes = fileBytes(~,path)
            fileIdentifier = fopen(path,"rb");
            cleanup = onCleanup(@()fclose(fileIdentifier));
            bytes = fread(fileIdentifier,Inf,"*uint8");
            clear cleanup
        end

        function writeBytes(~,path,bytes)
            fileIdentifier = fopen(path,"wb");
            cleanup = onCleanup(@()fclose(fileIdentifier));
            fwrite(fileIdentifier,bytes,"uint8");
            clear cleanup
        end
    end
end
