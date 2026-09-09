classdef TestPortableDiagnostics < matlab.unittest.TestCase
    properties (SetAccess=private)
        root (1,1) string
        folder (1,1) string
        executable (1,1) string
        providers (1,:) string
    end
    methods (TestClassSetup)
        function setup(testCase)
            testCase.root = string(fileparts(fileparts(mfilename("fullpath"))));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.folder = string(fixture.Folder);
            testCase.executable = string(getenv("WV_DIAGNOSTIC_DUMP"));
            testCase.providers = "reference";
            if getenv("WV_DIAGNOSTIC_NATIVE") == "1", testCase.providers = ["reference","native"]; end
            if testCase.executable == ""
                build = fullfile(testCase.folder,"build");
                [status,output] = cleanSystem("cmake -S "+shellQuote(fullfile(testCase.root,"PortableRuntime"))+" -B "+shellQuote(build)+" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DWV_ENABLE_ACCELERATE=OFF");
                testCase.assertEqual(status,0,output);
                [status,output] = cleanSystem("cmake --build "+shellQuote(build)+" --parallel 4 --target WVDiagnosticFieldDump");
                testCase.assertEqual(status,0,output);
                testCase.executable = fullfile(build,"WVDiagnosticFieldDump");
            end
        end
    end
    methods (Test,TestTags="full")
        function allTransformDiagnosticsMatchMatlab(testCase)
            catalog = jsondecode(fileread(fullfile(testCase.root,"PortableRuntime","contracts","portable-variable-catalog-v1.json")));
            families = ["constant-hydrostatic","constant-nonhydrostatic","barotropic","stratified-qg","hydrostatic","boussinesq"];
            evidenceRows = struct(configuration={},grid={},provider={},maximumRelativeError={},variableCount={}, ...
                retainedBytes={},scratchHighWaterBytes={},scratchLiveBytes={},primitiveOutputCount={});
            for family = families
                for antialias = [false true]
                    for odd = [false true]
                        grid = [8+double(odd),6+double(odd),9+double(odd)];
                        wvt = testCase.transform(family,grid,antialias);
                        configuration = family+"-aa"+double(antialias);
                        rows = catalog.contracts(string({catalog.contracts.configuration})==configuration);
                        names = reshape(arrayfun(@(row)string(row.metadata.name),rows),1,[]);
                        rejected = intersect(names,["phase","conjPhase","rho_nm","eta_true","ape","apv"],"stable");
                        names = names(~endsWith(names,"_portable_catalog_forcing") & ~ismember(names,["Ap","Am","A0",rejected]));
                        for row = reshape(rows,1,[])
                            if string(row.authority)=="known-variable-factory"
                                if string(row.component)==""
                                    operation = wvt.operationForKnownVariable('energy');
                                else
                                    operation = wvt.operationForKnownVariable('energy',flowComponent=wvt.flowComponentWithName(string(row.component)));
                                end
                                wvt.addOperation(operation);
                            end
                        end
                        expected = struct;
                        for name = reshape(names,1,[])
                            value = wvt.(name);
                            expected.(name) = value(:);
                        end
                        model = WVModel(wvt,shouldUseLinearDynamics=family~="barotropic");
                        checkpoint = fullfile(testCase.folder,"source.nc");
                        file = model.createNetCDFFileForModelOutput(checkpoint,outputInterval=.5,shouldOverwriteExisting=true);
                        file.outputTimesForIntegrationPeriod(wvt.t,wvt.t+1);
                        file.writeTimeStepToOutputFile(wvt.t);
                        model.closeNetCDFFile();
                        request = fullfile(testCase.folder,"request.json");
                        writeText(request,jsonencode(struct(fields=names,rejected=rejected)));
                        for provider = testCase.providers
                            resultPath = fullfile(testCase.folder,"result.json");
                            [status,output] = cleanSystem(shellQuote(testCase.executable)+" "+shellQuote(checkpoint)+" "+shellQuote(request)+" "+shellQuote(resultPath)+" "+provider);
                            testCase.assertEqual(status,0,configuration+" odd="+odd+" "+provider+": "+output);
                            actual = jsondecode(fileread(resultPath));
                            maximumError = 0;
                            for name = reshape(names,1,[])
                                value = actual.fields.(name).real;
                                if isfield(actual.fields.(name),'imag'), value = complex(value,actual.fields.(name).imag); end
                                scale = max(abs(expected.(name)));
                                error = max(abs(value(:)-expected.(name)))/max(scale,realmin);
                                maximumError = max(maximumError,error);
                                testCase.verifyLessThanOrEqual(error,1e-12,configuration+" odd="+odd+" "+provider+" "+name);
                            end
                            evidenceRows(end+1) = struct(configuration=configuration,grid=grid,provider=provider, ...
                                maximumRelativeError=maximumError,variableCount=numel(names), ...
                                retainedBytes=actual.retainedBytes,scratchHighWaterBytes=actual.scratchHighWaterBytes, ...
                                scratchLiveBytes=actual.scratchLiveBytes,primitiveOutputCount=actual.primitiveOutputs); %#ok<AGROW>
                            testCase.verifyEqual(actual.scratchLiveBytes,0);
                            testCase.verifyEqual(actual.diagnosticEvaluations,1);
                            testCase.verifyLessThan(actual.primitiveOutputs,numel(names));
                            if ~isempty(rejected), testCase.verifyEqual(sort(string(fieldnames(actual.rejected))),sort(rejected(:))); end
                        end
                    end
                end
            end
            reportPath = string(getenv("WV_DIAGNOSTIC_REPORT"));
            if reportPath~=""
                [status,commit] = cleanSystem("git -C "+shellQuote(testCase.root)+" rev-parse HEAD");
                testCase.assertEqual(status,0,commit);
                report = struct(schema="portable-diagnostic-numerical-v1",issue=305,sourceCommit=string(strtrim(commit)), ...
                    matlabRelease=string(version('-release')),rows=evidenceRows, ...
                    passes=all([evidenceRows.maximumRelativeError]<=1e-12));
                writeText(reportPath,jsonencode(report,PrettyPrint=true));
            end
        end
        function outputContinuationMatchesMatlab(testCase)
            catalog = jsondecode(fileread(fullfile(testCase.root,"PortableRuntime","contracts","portable-variable-catalog-v1.json")));
            runner = fullfile(fileparts(testCase.executable),"wave-vortex-run");
            for family = ["constant-hydrostatic","constant-nonhydrostatic","barotropic","stratified-qg","hydrostatic","boussinesq"]
                wvt = testCase.transform(family,[8 6 9],true);
                rows = catalog.contracts(string({catalog.contracts.configuration})==family+"-aa1");
                % Forcing templates require actual instance bindings, covered
                % by TestPortableStableForcing's output continuation matrix.
                rows = rows([rows.ordinal]>=23 & string({rows.runtimeStatus})=="implemented" & string({rows.authority})~="forcing-instance-template");
                names = reshape(arrayfun(@(row)string(row.metadata.name),rows),1,[]);
                for row = reshape(rows,1,[])
                    if string(row.authority)=="known-variable-factory"
                        wvt.addOperation(wvt.operationForKnownVariable('energy',flowComponent=wvt.flowComponentWithName(string(row.component))));
                    end
                end
                model = WVModel(wvt,shouldUseLinearDynamics=family~="barotropic");
                model.eulerianObservingSystem.addNetCDFOutputVariables(names{:});
                source = fullfile(testCase.folder,"lifecycle-source.nc");
                file = model.createNetCDFFileForModelOutput(source,outputInterval=.5,shouldOverwriteExisting=true);
                dense = file.addNewEvenlySpacedOutputGroup("dense",outputInterval=.125,initialTime=37,finalTime=38);
                dense.addObservingSystem(WVEulerianFields(model,fieldNames=cellstr(names)));
                secondSource = fullfile(testCase.folder,"lifecycle-second-source.nc");
                model.createNetCDFFileForModelOutput(secondSource,outputInterval=.5,shouldOverwriteExisting=true);
                for outputFile = reshape(model.outputFiles,1,[])
                    outputFile.outputTimesForIntegrationPeriod(37,38);
                    outputFile.writeTimeStepToOutputFile(37);
                end
                model.closeNetCDFFile();
                ncwriteatt(source,"/","portableFileIdentifier","diagnostic-primary");
                ncwriteatt(secondSource,"/","portableFileIdentifier","diagnostic-secondary");
                controlPath = fullfile(testCase.folder,"lifecycle-matlab.nc"); copyfile(source,controlPath);
                control = WVModel.modelFromFile(char(controlPath));
                control.setupIntegrator(integratorType="fixed",deltaT=.25);
                control.integrateToTime(38,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                control.closeNetCDFFile();
                for provider = testCase.providers
                    for scenario = 1:3
                        segmented = scenario==2;
                        outputPath = fullfile(testCase.folder,"lifecycle-runtime.nc"); copyfile(source,outputPath);
                        secondOutput = fullfile(testCase.folder,"lifecycle-second-runtime.nc"); copyfile(secondSource,secondOutput);
                        times = 38;
                        if segmented, times = [37.5 38]; end
                        for finalTime = times
                            requestPath = fullfile(testCase.folder,"lifecycle-request.json");
                            if scenario==3
                                WVModel.writePortableRunRequest(requestPath,[outputPath,secondOutput],method="adaptive-rk45",finalTime=finalTime,initialStep=.25,maximumStep=.25,fftProvider=replace(provider,"native","native-fftw"),reportPath="lifecycle-report.json");
                            else
                                WVModel.writePortableRunRequest(requestPath,[outputPath,secondOutput],method="fixed-rk4",finalTime=finalTime,initialStep=.25,fftProvider=replace(provider,"native","native-fftw"),reportPath="lifecycle-report.json");
                            end
                            [status,output] = cleanSystem(shellQuote(runner)+" --request "+shellQuote(requestPath));
                            testCase.assertEqual(status,0,family+" "+provider+" segmented="+segmented+": "+output);
                            report = jsondecode(fileread(fullfile(testCase.folder,"lifecycle-report.json")));
                            testCase.verifyEqual(report.state.stepCount,4-2*double(segmented));
                            testCase.verifyEqual(report.diagnosticEvaluation.workspaceLiveBytes,0);
                            testCase.verifyGreaterThan(report.diagnosticEvaluation.evaluationCount,0);
                            if family~="stratified-qg"
                                testCase.verifyGreaterThan(report.diagnosticEvaluation.workspaceHighWaterBytes,0);
                            end
                            testCase.verifyGreaterThanOrEqual(report.livenessBytes.fullModelMaximumLive, ...
                                report.livenessBytes.fullModelRetained+report.diagnosticEvaluation.workspaceHighWaterBytes);
                        end
                        for groupName = ["wave-vortex","dense"]
                            info = ncinfo(controlPath,"/"+groupName);
                            for variable = reshape(info.Variables,1,[])
                                name = string(variable.Name);
                                if ~ismember(erase(name,["_real","_imag"]),[names,"t","Ap","Am","A0"]), continue; end
                                expected = ncread(controlPath,"/"+groupName+"/"+name);
                                actual = ncread(outputPath,"/"+groupName+"/"+name);
                                testCase.verifySize(actual,size(expected),family+" "+name);
                                error = max(abs(actual(:)-expected(:)))/max(max(abs(expected(:))),realmin);
                                testCase.verifyLessThanOrEqual(error,1e-12,family+" "+provider+" scenario="+scenario+" "+groupName+" "+name);
                                if groupName=="wave-vortex"
                                    second = ncread(secondOutput,"/wave-vortex/"+name);
                                    error = max(abs(second(:)-expected(:)))/max(max(abs(expected(:))),realmin);
                                    testCase.verifyLessThanOrEqual(error,1e-12,family+" "+provider+" scenario="+scenario+" second file "+name);
                                end
                            end
                        end
                    end
                end
            end
        end

        function existingComponentOperationIsPreserved(testCase)
            wvt = testCase.transform("constant-hydrostatic",[8 6 9],false);
            operation = wvt.operationForKnownVariable('energy',flowComponent=wvt.flowComponentWithName("wave"));
            wvt.addOperation(operation);
            model = WVModel(wvt,shouldUseLinearDynamics=true);
            observer = WVEulerianFields(model,fieldNames={'energy_w'});
            testCase.verifyEqual(wvt.propertyAnnotationWithName('energy_w').modelOp,operation);
            testCase.verifyEqual(observer.fieldNames,"energy_w");
        end

        function incompatibilitiesPreserveMatlabContracts(testCase)
            wvt = testCase.transform("hydrostatic",[8 6 9],false);
            for name = ["phase","conjPhase"]
                testCase.verifyTrue(wvt.propertyAnnotationWithName(name).isComplex);
                testCase.verifyFalse(isreal(wvt.(name)));
            end
            testCase.verifyFalse(ismember('shouldUseTrueNoMotionProfile',wvt.annotatedPropertyNames));
            solver = WVNoMotionProfileOperation();
            testCase.verifyTrue(ismember(solver.solver,["lsqnonlin","fminsearch"]));
            testCase.verifyFalse(ismember('solver',wvt.annotatedPropertyNames));
            wvt.shouldUseTrueNoMotionProfile = true;
            filePath = fullfile(testCase.folder,"profile-contract.nc");
            file = wvt.writeToFile(filePath,shouldOverwriteExisting=true); file.close();
            [restored,file] = WVTransform.waveVortexTransformFromFile(filePath);
            cleanup = onCleanup(@()file.close());
            testCase.verifyFalse(restored.shouldUseTrueNoMotionProfile);
        end
    end
    methods (Static,Access=private)
        function wvt = transform(family,grid,antialias)
            switch family
                case "barotropic"
                    wvt = WVTransformBarotropicQG([17000 11000],grid(1:2),j=1,shouldAntialias=antialias);
                case "stratified-qg"
                    wvt = WVTransformStratifiedQG([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
                case "hydrostatic"
                    wvt = WVTransformHydrostatic([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
                case "boussinesq"
                    wvt = WVTransformBoussinesq([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
                otherwise
                    wvt = WVTransformConstantStratification([17000 11000 1000],grid,N0=5.2e-3,isHydrostatic=family=="constant-hydrostatic",shouldAntialias=antialias);
            end
            n = reshape(1:numel(wvt.A0),size(wvt.A0));
            wvt.A0 = 1e-6*(sin(.7*n)+1i*cos(.3*n));
            if ~ismember(family,["barotropic","stratified-qg"])
                wave = wvt.J>0 & (wvt.K.^2+wvt.L.^2)>0;
                inertial = (wvt.K.^2+wvt.L.^2)==0;
                wvt.Ap = .001*(sin(.7*n)+1i*cos(.3*n))./(1+wvt.J).*(wave|inertial);
                wvt.Am = .002*(sin(.3*n)+1i*cos(.7*n))./(1+wvt.J).*wave;
                wvt.Am(inertial) = conj(wvt.Ap(inertial));
                mda = inertial & wvt.J>0;
                wvt.A0(mda) = .003*sin(n(mda));
            end
            if family=="barotropic"
                wvt.A0(wvt.Kh==0) = 0;
                selfConjugate = wvt.dftPrimaryIndices2D==wvt.dftConjugateIndices2D;
                wvt.A0(selfConjugate) = real(wvt.A0(selfConjugate));
            elseif family=="stratified-qg"
                wvt.A0(:,wvt.k==0 & wvt.l==0) = 0;
            end
            wvt.t0 = 17;
            wvt.t = 37;
            wvt.removeAllForcing();
        end
    end
end
function writeText(path,text)
file = fopen(path,'w');
cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);
end
function [status,output] = cleanSystem(command)
[status,output] = system("env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FRAMEWORK_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+command);
end
function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end
