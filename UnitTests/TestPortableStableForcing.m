classdef TestPortableStableForcing < matlab.unittest.TestCase
    properties (SetAccess=private)
        root (1,1) string
        folder (1,1) string
        runner (1,1) string
        executable (1,1) string
        providers (1,:) string
    end
    methods (TestClassSetup)
        function buildProbe(testCase)
            testCase.root = string(fileparts(fileparts(mfilename("fullpath"))));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.folder = string(fixture.Folder);
            testCase.executable = string(getenv("WV_STABLE_FORCING_DUMP"));
            testCase.runner = string(getenv("WV_STABLE_FORCING_RUNNER"));
            testCase.providers = "reference";
            if getenv("WV_STABLE_FORCING_NATIVE") == "1", testCase.providers = ["reference","native"]; end
            if testCase.executable == ""
                build = fullfile(testCase.folder,"build");
                [status,output] = cleanSystem("cmake -S "+shellQuote(fullfile(testCase.root,"PortableRuntime"))+" -B "+shellQuote(build)+" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DWV_ENABLE_ACCELERATE=OFF");
                testCase.assertEqual(status,0,output);
                [status,output] = cleanSystem("cmake --build "+shellQuote(build)+" --parallel 4 --target WVStableForcingDump wave-vortex-run");
                testCase.assertEqual(status,0,output);
                testCase.executable = fullfile(build,"WVStableForcingDump");
                testCase.runner = fullfile(build,"wave-vortex-run");
            end
            testCase.assertTrue(isfile(testCase.executable));
            if testCase.runner == "", testCase.runner = fullfile(fileparts(testCase.executable),"wave-vortex-run"); end
            testCase.assertTrue(isfile(testCase.runner));
        end
    end
    methods (Test,TestTags="full")
        function fullGridWaveTendenciesMatchMatlab(testCase)
            for family = ["constant-hydrostatic","constant-nonhydrostatic","hydrostatic","boussinesq"]
                for antialias = [false true]
                    for grid = {[8 6 9],[9 7 10]}
                        wvt = diagnosticWaveTransform(family,grid{1},antialias);
                        fixed = WVFixedAmplitudeForcing(wvt,name="held-coefficients",Ap_indices=uint64(2),Apbar=wvt.Ap(2),A0_indices=uint64(2),A0bar=wvt.A0(2));
                        terrain = 2*cos(2*pi*reshape(wvt.x,[],1)/wvt.Lx)+sin(2*pi*reshape(wvt.y,1,[])/wvt.Ly);
                        tidal = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=terrain,barotropicVelocityAmplitude=[.01;.005],frequency=1e-4,rampDuration=0);
                        forces = [WVNonlinearAdvection(wvt),WVBottomFrictionLinear(wvt,r=2.5e-7),WVBottomFrictionQuadratic(wvt,Cd=.002),WVHorizontalDamping(wvt,nu=.125,kappa=.002),WVVerticalDamping(wvt,nu=.125,kappa=.002),WVVerticalDiffusivity(wvt,kappa_z=.002),WVAdaptiveDamping(wvt),WVBetaPlanePVAdvection(wvt),tidal,fixed];
                        if ~antialias, forces = [forces,WVAntialiasing(wvt,Nj=3)]; end %#ok<AGROW>
                        wvt.setForcing(forces);
                        before = {wvt.Ap,wvt.Am,wvt.A0};
                        verticalCancellationScale = 0;
                        if ~wvt.isHydrostatic
                            % Tidal Ap/Am contributions to Fw cancel analytically.
                            % Use their separate physical magnitudes to condition
                            % this zero-channel comparison, retaining the 1e-12
                            % bound without dividing by a roundoff-only residual.
                            zero = zeros(size(wvt.Ap));
                            [tidalFp,tidalFm,~] = tidal.addSpectralForcing(wvt,zero,zero,zero);
                            plus = wvt.transformToSpatialDomainWithG(Apm=wvt.WAp.*wvt.phase.*tidalFp);
                            minus = wvt.transformToSpatialDomainWithG(Apm=wvt.WAm.*wvt.conjPhase.*tidalFm);
                            verticalCancellationScale = max(abs([plus(:);minus(:)]));
                            testCase.assertGreaterThan(verticalCancellationScale,0);
                            testCase.verifyLessThanOrEqual(max(abs(plus(:)+minus(:))),1e-12*verticalCancellationScale);
                        end
                        operation = SpatialForcingOperation(wvt);
                        expected = cell(1,operation.nVarOut);
                        [expected{:}] = operation.compute(wvt);
                        names = string({operation.outputVariables.name});
                        source = testCase.writeInitialModel(wvt);
                        resultPath = fullfile(testCase.folder,"tendencies.json");
                        for provider = testCase.providers
                            [status,output] = cleanSystem(shellQuote(testCase.executable)+" "+shellQuote(source)+" "+shellQuote(resultPath)+" "+provider+" tendencies");
                            testCase.assertEqual(status,0,family+" "+provider+": "+output);
                            actual = jsondecode(fileread(resultPath));
                            testCase.verifyEqual(actual.diagnosticWorkspaceLiveBytes,0);
                            testCase.verifyEqual(actual.diagnosticForcingEvaluationCount,numel(wvt.forcing));
                            comparisons = 0;
                            maximumError = 0;
                            for instance = reshape(actual.tendencies,1,[])
                                suffix = replace(string(instance.name),[" ","-"],"_");
                                for channel = string(fieldnames(instance.fields))'
                                    name = channel+"_"+suffix;
                                    index = find(names==name);
                                    testCase.assertNumElements(index,1,name);
                                    reference = expected{index};
                                    values = instance.fields.(channel);
                                    absoluteError = max(abs(values(:)-reference(:)));
                                    scale = max(abs(reference(:)));
                                    if channel=="Fw" && string(instance.type)=="WVPseudoTopographicWaveGeneration"
                                        testCase.verifyLessThanOrEqual(scale,1e-12*verticalCancellationScale,"MATLAB tidal Fw must remain a cancellation residual");
                                        testCase.verifyLessThanOrEqual(max(abs(values(:))),1e-12*verticalCancellationScale,"C++ tidal Fw must remain a cancellation residual");
                                        scale = verticalCancellationScale;
                                    end
                                    error = absoluteError/max(scale,realmin);
                                    if error > 1e-12
                                        fprintf('FORCING_DIAGNOSTIC_ERROR %s %s abs=%.17g reference=%.17g\n',family,name,absoluteError,scale);
                                    end
                                    testCase.verifyLessThanOrEqual(error,1e-12,family+" aa="+antialias+" "+provider+" "+name);
                                    maximumError = max(maximumError,error);
                                    comparisons = comparisons+1;
                                end
                            end
                            testCase.verifyEqual(comparisons,operation.nVarOut);
                            fprintf('FORCING_DIAGNOSTICS %s aa=%d grid=%s provider=%s comparisons=%d max_relative=%.17g\n',family,antialias,mat2str(grid{1}),provider,comparisons,maximumError);
                        end
                        testCase.verifyEqual({wvt.Ap,wvt.Am,wvt.A0},before);
                    end
                end
            end
        end
        function explicitAntialiasingMatchesMatlab(testCase)
            for family = ["hydrostatic","nonhydrostatic","barotropic"]
                for grid = {[8 6 5],[9 7 7]}
                    for retained = [0 1 3]
                        wvt = testCase.transform(family,grid{1},false);
                        nonlinear = WVNonlinearAdvection(wvt);
                        filter = WVAntialiasing(wvt,Nj=retained);
                        wvt.setForcing([nonlinear,filter]);
                        testCase.compareTendency(wvt);
                    end
                end
            end
        end
        function explicitFilterPreservesOrderingAndFixedAmplitudes(testCase)
            for family = ["hydrostatic","nonhydrostatic","barotropic"]
                for reverseOrder = [false true]
                    wvt = testCase.transform(family,[9 6 5],false);
                    filter = WVAntialiasing(wvt,Nj=2);
                    adaptive = WVAdaptiveDamping(wvt);
                    fixed = WVFixedAmplitudeForcing(wvt,name="fixed",A0_indices=uint64(2),A0bar=wvt.A0(2));
                    forces = [adaptive,WVNonlinearAdvection(wvt),filter,fixed];
                    if reverseOrder, forces = fliplr(forces); end
                    wvt.setForcing(forces);
                    before = wvt.A0;
                    testCase.compareTendency(wvt);
                    testCase.verifyEqual(wvt.A0,before);
                end
            end
        end
    end
    methods (Test,TestTags="full")
        function adaptiveClosuresUseMatlabEffectiveResolution(testCase)
            for family = ["hydrostatic","nonhydrostatic","barotropic"]
                wvt = testCase.transform(family,[8 6 5],false);
                forces = [WVNonlinearAdvection(wvt),WVAntialiasing(wvt,Nj=3),WVAdaptiveDamping(wvt),testCase.forcing(wvt,"WVFixedAmplitudeForcing")];
                if family ~= "barotropic"
                    forces = [forces,WVHorizontalDamping(wvt,nu=.125,kappa=.002),WVVerticalDamping(wvt,nu=.125,kappa=.002),WVVerticalDiffusivity(wvt,kappa_z=.002)]; %#ok<AGROW>
                end
                wvt.setForcing(forces);
                source = testCase.writeInitialModel(wvt);
                originalTime = wvt.t;
                control = WVModel(wvt);
                expectedStep = control.timeStepForCFL(.5);
                expectedResolution = wvt.effectiveHorizontalGridResolution;
                control.setupIntegrator();
                control.integrateToTime(originalTime+1,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
                for provider = testCase.providers
                    runtimePath = fullfile(testCase.folder,"adaptive.nc");
                    copyfile(source,runtimePath);
                    requestPath = fullfile(testCase.folder,"request.json");
                    reportPath = fullfile(testCase.folder,"report.json");
                    WVModel.writePortableRunRequest(requestPath,runtimePath,finalTime=originalTime+1,fftProvider=replace(provider,"native","native-fftw"),reportPath=reportPath);
                    [status,output] = cleanSystem(shellQuote(testCase.runner)+" --request "+shellQuote(requestPath));
                    testCase.assertEqual(status,0,output);
                    report = jsondecode(fileread(reportPath));
                    testCase.verifyEqual(report.integrationRequest.candidates.effectiveHorizontalGridResolution,expectedResolution,RelTol=1e-12);
                    testCase.verifyEqual(report.integrationRequest.selectedStep,expectedStep,RelTol=1e-12);
                    actual = WVModel.modelFromFile(char(runtimePath));
                    cleanup = onCleanup(@()actual.closeNetCDFFile());
                    families = "A0";
                    if family ~= "barotropic", families = ["Ap","Am","A0"]; end
                    for name = families
                        expected = control.wvt.(name);
                        testCase.verifyLessThanOrEqual(max(abs(actual.wvt.(name)-expected),[],"all"),2e-10*max(abs(expected),[],"all")+1e-16,provider+" adaptive "+name);
                    end
                    clear cleanup
                end
            end
        end
        function malformedClosuresLeaveAppendTargetsUnchanged(testCase)
            for identity = ["WVAntialiasing","WVHorizontalDamping","WVVerticalDamping","WVVerticalDiffusivity"]
                wvt = testCase.transform("nonhydrostatic",[8 6 5],false);
                wvt.setForcing(testCase.forcing(wvt,identity));
                source = testCase.writeInitialModel(wvt);
                group = forcingGroup(ncinfo(source),identity);
                testCase.assertNotEmpty(group);
                parameter = "nu";
                if identity == "WVAntialiasing", parameter = "Nj";
                elseif identity == "WVVerticalDiffusivity", parameter = "kappa_z"; end
                ncwrite(source,group+"/"+parameter,-1);
                before = readBytes(source);
                [status,~] = cleanSystem(shellQuote(testCase.runner)+" "+shellQuote(source)+" --restart-mode model --output-policy append --integrator fixed-rk4 --delta-t 0.5 --final-time 38 --fft-provider reference");
                testCase.verifyNotEqual(status,0);
                testCase.verifyEqual(readBytes(source),before,identity+" mutated an invalid append target.");
            end
        end
        function catalogPairsMatchMatlabAndAppend(testCase)
            matrix = jsondecode(fileread(fullfile(testCase.root,"PortableRuntime","contracts","portable-forcing-compatibility-v1.json")));
            for row = reshape(matrix.rows,1,[])
                if string(row.matlab.applicability) ~= "applicable" || startsWith(string(row.configuration),"stratified-qg"), continue; end
                config = matrix.configurations(string({matrix.configurations.id}) == string(row.configuration));
                family = "hydrostatic";
                if string(config.transform) == "WVTransformBarotropicQG", family = "barotropic";
                elseif ~config.isHydrostatic, family = "nonhydrostatic"; end
                wvt = testCase.transform(family,[8 6 7],config.shouldAntialias);
                wvt.setForcing(testCase.forcing(wvt,string(row.forcing)));
                testCase.compareTendency(wvt);
                testCase.compareContinuation(wvt,false);
            end
        end
        function orderedClosureGraphsRestartAndConvertResolution(testCase)
            for family = ["hydrostatic","nonhydrostatic","barotropic"]
                wvt = testCase.transform(family,[8 6 5],false);
                forces = [WVAdaptiveDamping(wvt),WVNonlinearAdvection(wvt),WVAntialiasing(wvt,Nj=3),testCase.forcing(wvt,"WVFixedAmplitudeForcing")];
                if family ~= "barotropic"
                    forces = [forces,WVHorizontalDamping(wvt,nu=.125,kappa=.002),WVVerticalDamping(wvt,nu=.125,kappa=.002),WVVerticalDiffusivity(wvt,kappa_z=.002)]; %#ok<AGROW>
                end
                wvt.setForcing(forces);
                testCase.compareContinuation(wvt,true);
                targetGrid = [9 8 7];
                if family == "barotropic", targetGrid = targetGrid(1:2); end
                converted = wvt.waveVortexTransformWithResolution(targetGrid);
                testCase.compareTendency(converted);
                testCase.compareContinuation(converted,false);
            end
        end
        function laplacianDampingMatchesMatlab(testCase)
            for family = ["hydrostatic","nonhydrostatic"]
                for grid = {[8 6 5],[9 7 7]}
                    for antialias = [false true]
                        for rates = {[0 0],[.125 2.5e-5]}
                            for direction = ["horizontal","vertical"]
                                wvt = testCase.transform(family,grid{1},antialias);
                                values = rates{1};
                                if direction == "horizontal"
                                    force = WVHorizontalDamping(wvt,nu=values(1),kappa=values(2));
                                else
                                    force = WVVerticalDamping(wvt,nu=values(1),kappa=values(2));
                                end
                                wvt.setForcing(force);
                                testCase.compareTendency(wvt);
                            end
                        end
                    end
                end
            end
        end
        function verticalDiffusivityMatchesMatlab(testCase)
            for family = ["hydrostatic","nonhydrostatic"]
                for grid = {[8 6 5],[9 7 7]}
                    for antialias = [false true]
                        for flag = [false true]
                            wvt = testCase.transform(family,grid{1},antialias);
                            wvt.setForcing(WVVerticalDiffusivity(wvt,kappa_z=.0025,shouldForceMeanDensityAnomaly=flag));
                            testCase.compareTendency(wvt);
                        end
                    end
                end
            end
        end
        function constantNarrowBandAndOrderedClosuresMatchMatlab(testCase)
            for family = ["hydrostatic","nonhydrostatic"]
                for antialias = [false true]
                    wvt = testCase.transform(family,[9 6 5],antialias);
                    narrow = WVNarrowBandGeostrophicForcing(wvt,initialPV="none",k_f=2*wvt.dk,j_f=1);
                    wvt.setForcing(narrow);
                    testCase.compareTendency(wvt);
                    forces = [WVVerticalDiffusivity(wvt),WVHorizontalDamping(wvt),WVNonlinearAdvection(wvt),WVVerticalDamping(wvt),WVAdaptiveDamping(wvt),narrow];
                    if ~antialias, forces(end+1) = WVAntialiasing(wvt,Nj=2); end %#ok<AGROW>
                    wvt.setForcing(forces);
                    testCase.compareTendency(wvt);
                end
            end
        end
    end

    methods (Access=private)
        function force = forcing(~,wvt,identity)
            switch identity
                case "WVFixedAmplitudeForcing"
                    force = WVFixedAmplitudeForcing(wvt,name="catalog fixed",A0_indices=uint64(2),A0bar=wvt.A0(2));
                case "WVNarrowBandGeostrophicForcing"
                    force = WVNarrowBandGeostrophicForcing(wvt,initialPV="none",k_f=2*wvt.dk,j_f=1);
                case "WVPseudoTopographicWaveGeneration"
                    force = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=2*cos(2*pi*reshape(wvt.x,[],1)/wvt.Lx)*ones(1,wvt.Ny),barotropicVelocityAmplitude=[.01;.005],frequency=1e-4,rampDuration=0);
                case "WVAntialiasing"
                    force = WVAntialiasing(wvt,Nj=2);
                case {"WVHorizontalDamping","WVVerticalDamping"}
                    force = feval(identity,wvt,nu=.125,kappa=.002);
                case "WVVerticalDiffusivity"
                    force = WVVerticalDiffusivity(wvt,kappa_z=.002);
                otherwise
                    force = feval(identity,wvt);
            end
        end
        function source = writeInitialModel(testCase,wvt)
            model = WVModel(wvt);
            source = fullfile(testCase.folder,"source.nc");
            outputFile = model.createNetCDFFileForModelOutput(source,outputInterval=.5,shouldOverwriteExisting=true);
            outputFile.outputTimesForIntegrationPeriod(wvt.t,wvt.t+2);
            outputFile.writeTimeStepToOutputFile(wvt.t);
            model.closeNetCDFFile();
        end
        function compareContinuation(testCase,wvt,segmented)
            source = testCase.writeInitialModel(wvt);
            originalTime = wvt.t;
            controlPath = fullfile(testCase.folder,"control.nc");
            copyfile(source,controlPath);
            control = WVModel.modelFromFile(char(controlPath));
            cleanup = onCleanup(@()control.closeNetCDFFile());
            control.setupIntegrator(integratorType="fixed",deltaT=.5);
            duration = 1+double(segmented);
            control.integrateToTime(originalTime+duration,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
            control.closeNetCDFFile();
            clear cleanup
            for provider = testCase.providers
                runtimeProvider = replace(provider,"native","native-fftw");
                runtimePath = fullfile(testCase.folder,"runtime.nc");
                copyfile(source,runtimePath);
                for stop = 1:duration
                    command = shellQuote(testCase.runner)+" "+shellQuote(runtimePath)+" --restart-mode model --output-policy append --integrator fixed-rk4 --delta-t 0.5 --final-time "+string(originalTime+stop)+" --fft-provider "+runtimeProvider;
                    [status,output] = cleanSystem(command);
                    testCase.assertEqual(status,0,output);
                end
                actual = WVModel.modelFromFile(char(runtimePath));
                cleanup = onCleanup(@()actual.closeNetCDFFile());
                families = "A0";
                if ~isa(wvt,"WVTransformBarotropicQG"), families = ["Ap","Am","A0"]; end
                for name = families
                    expected = control.wvt.(name);
                    testCase.verifyLessThanOrEqual(max(abs(actual.wvt.(name)-expected),[],"all"),2e-10*max(abs(expected),[],"all")+1e-16,provider+" "+name);
                end
                testCase.verifyEqual(string({actual.wvt.forcing.name}),string({wvt.forcing.name}));
                for i = 1:numel(wvt.forcing)
                    testCase.verifyEqual(string(class(actual.wvt.forcing(i))),string(class(wvt.forcing(i))));
                end
                if segmented
                    uninterruptedPath = fullfile(testCase.folder,"uninterrupted.nc");
                    copyfile(source,uninterruptedPath);
                    [status,output] = cleanSystem(shellQuote(testCase.runner)+" "+shellQuote(uninterruptedPath)+" --restart-mode model --output-policy append --integrator fixed-rk4 --delta-t 0.5 --final-time "+string(originalTime+duration)+" --fft-provider "+runtimeProvider);
                    testCase.assertEqual(status,0,output);
                    uninterrupted = WVModel.modelFromFile(char(uninterruptedPath));
                    otherCleanup = onCleanup(@()uninterrupted.closeNetCDFFile());
                    for name = families
                        testCase.verifyEqual(actual.wvt.(name),uninterrupted.wvt.(name));
                    end
                    clear otherCleanup
                end
                clear cleanup
            end
        end
        function wvt = transform(~,family,grid,antialias)
            if family == "barotropic"
                wvt = WVTransformBarotropicQG([17000 11000],grid(1:2),j=1,shouldAntialias=antialias);
            else
                wvt = WVTransformConstantStratification([17000 11000 1000],grid,N0=5.2e-3,isHydrostatic=family == "hydrostatic",shouldAntialias=antialias);
            end
            originalStream = rng;
            cleanup = onCleanup(@()rng(originalStream));
            rng(9321);
            wvt.initWithRandomFlow(uvMax=.01);
            wvt.t = 37;
            wvt.removeAllForcing();
        end
        function compareTendency(testCase,wvt)
            if isa(wvt,"WVTransformBarotropicQG")
                expected = struct(F0=wvt.nonlinearFlux());
            else
                [Fp,Fm,F0] = wvt.nonlinearFlux();
                expected = struct(Fp=Fp,Fm=Fm,F0=F0);
            end
            source = testCase.writeInitialModel(wvt);
            outputPath = fullfile(testCase.folder,"rhs.json");
            for provider = testCase.providers
                [status,output] = cleanSystem(shellQuote(testCase.executable)+" "+shellQuote(source)+" "+shellQuote(outputPath)+" "+provider);
                testCase.assertEqual(status,0,output);
                actual = jsondecode(fileread(outputPath));
                % The direct reference FFT intentionally uses per-line scratch vectors.
                if provider == "native"
                    testCase.verifyEqual(actual.applicationAllocations,0,"Prepared native forcing execution allocated application memory.");
                end
                for name = string(fieldnames(expected))'
                    reference = expected.(name)(:);
                    result = complex(actual.(name).real,actual.(name).imag);
                    tolerance = 2e-11*max(abs(reference))+1e-18;
                    err = max(abs(result(:)-reference));
                    testCase.verifyLessThanOrEqual(err,tolerance,provider+" "+name);
                end
            end
        end
    end
end

function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end
function [status,output] = cleanSystem(command)
[status,output] = system("env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FRAMEWORK_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+command);
end

function result = forcingGroup(info,identity)
result = "";
for attribute = reshape(info.Attributes,1,[])
    if string(attribute.Name) == "AnnotatedClass" && string(attribute.Value) == identity
        result = string(info.Name);
        return
    end
end
for group = reshape(info.Groups,1,[])
    result = forcingGroup(group,identity);
    if result ~= "", return; end
end
end
function bytes = readBytes(path)
file = fopen(path,"r");
cleanup = onCleanup(@()fclose(file));
bytes = fread(file,Inf,"*uint8");
end

function wvt = diagnosticWaveTransform(family,grid,antialias)
switch family
    case "hydrostatic"
        wvt = WVTransformHydrostatic([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
    case "boussinesq"
        wvt = WVTransformBoussinesq([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
    otherwise
        wvt = WVTransformConstantStratification([17000 11000 1000],grid,N0=5.2e-3,isHydrostatic=family=="constant-hydrostatic",shouldAntialias=antialias);
end
n = reshape(1:numel(wvt.A0),size(wvt.A0));
wave = wvt.J>0 & (wvt.K.^2+wvt.L.^2)>0;
inertial = (wvt.K.^2+wvt.L.^2)==0;
wvt.Ap = .001*(sin(.7*n)+1i*cos(.3*n))./(1+wvt.J).*(wave|inertial);
wvt.Am = .002*(sin(.3*n)+1i*cos(.7*n))./(1+wvt.J).*wave;
wvt.Am(inertial) = conj(wvt.Ap(inertial));
wvt.A0 = 1e-6*(sin(.7*n)+1i*cos(.3*n));
wvt.A0(inertial) = .003*sin(n(inertial)).*(wvt.J(inertial)>0);
wvt.t0 = 17;
wvt.t = 37;
wvt.removeAllForcing();
end
