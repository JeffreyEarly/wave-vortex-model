function result = runPortableAdaptiveRK23Validation(options)
% Validate portable adaptive RK3(2) work, error control, and restart output.
%
% This authoring benchmark compares the standalone adaptive integrator with a
% tight MATLAB `ode78` reference for the mixed hydrostatic and nonhydrostatic
% forcing fixtures. It does not publish a runtime-readiness decision.
arguments
    options.relativeTolerances (1,:) double {mustBePositive} = [1e-2 3e-3 1e-3 3e-4]
    options.absoluteTolerances (1,:) double {mustBePositive} = [1e-5 3e-6 1e-6 3e-7]
    options.initialStep (1,1) double {mustBePositive} = 1e-5
    options.duration (1,1) double {mustBePositive} = 2e-5
    options.referenceRelativeTolerance (1,1) double {mustBePositive} = 1e-10
    options.referenceAbsoluteTolerance (1,1) double {mustBePositive} = 1e-10
    options.repeatCount (1,1) double {mustBeInteger,mustBePositive} = 3
    options.outputCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.runnerPath (1,1) string = ""
    options.outputDirectory (1,1) string = ""
end

if numel(options.relativeTolerances) ~= numel(options.absoluteTolerances)
    error("WaveVortexBenchmark:InvalidAdaptiveTolerancePairs","Relative and absolute tolerance arrays must have equal lengths.")
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
if strlength(options.runnerPath) == 0
    buildScript = fullfile(repositoryRoot,"tools","portable-runtime","buildWaveVortexRun.sh");
    [status,output] = system(sprintf('"%s"',buildScript));
    if status ~= 0
        error("WaveVortexBenchmark:AdaptiveRunnerBuildFailed","Unable to build the adaptive runtime:\n%s",output)
    end
    lines = splitlines(strtrim(string(output)));
    options.runnerPath = lines(end);
end
if strlength(options.outputDirectory) == 0
    runIdentifier = string(datetime("now",TimeZone="UTC",Format="yyyyMMdd'T'HHmmss'Z'"));
    options.outputDirectory = fullfile(repositoryRoot,"Benchmarks","results","experiments","issue186",runIdentifier);
end
mkdir(options.outputDirectory)
temporaryDirectory = string(tempname);
mkdir(temporaryDirectory)
temporaryCleanup = onCleanup(@()rmdir(temporaryDirectory,"s"));

fixtureDirectory = fullfile(repositoryRoot,"tools","portable-runtime","fixtures");
fixtureNames = ["forcing-mixed-hydrostatic.nc" "forcing-mixed-nonhydrostatic.nc"];
records = repmat(struct( ...
    fixture="", ...
    isHydrostatic=false, ...
    repeatIndex=0, ...
    configuration=struct, ...
    relativeTolerance=0, ...
    absoluteTolerance=0, ...
    relativeInfinityError=0, ...
    acceptedStepCount=0, ...
    rejectedStepCount=0, ...
    rightHandSideEvaluationCount=0, ...
    integrationSeconds=0, ...
    fsalReuseCount=0, ...
    fsalInvalidationCount=0, ...
    workspaceBytes=0, ...
    errorPolicyBytes=0, ...
    provider=struct, ...
    execution=struct),0,1);
outputScheduleRecords = repmat(struct( ...
    fixture="", ...
    relativeTolerance=0, ...
    noOutputAcceptedSteps=0, ...
    outputAcceptedSteps=0, ...
    noOutputRejectedSteps=0, ...
    outputRejectedSteps=0, ...
    noOutputRightHandSideEvaluations=0, ...
    outputRightHandSideEvaluations=0, ...
    interpolatedOutputCount=0, ...
    interpolationSeconds=0, ...
    noOutputCheckpointWriteSeconds=0, ...
    scheduledCheckpointWriteSeconds=0, ...
    finalStateRelativeError=NaN, ...
    passed=false),0,1);
for fixtureName = fixtureNames
    fixturePath = fullfile(fixtureDirectory,fixtureName);
    [wvt,ncfile] = WVTransform.waveVortexTransformFromFile(fixturePath,shouldReadOnly=true);
    transformCleanup = onCleanup(@()closeIfOpen(ncfile));
    initialTime = wvt.t;
    finalTime = initialTime+options.duration;
    reference = tightReference(wvt,finalTime,options.referenceRelativeTolerance,options.referenceAbsoluteTolerance);
    caseConfiguration = struct("Lxyz",[wvt.Lx wvt.Ly wvt.Lz],"Nxyz",[wvt.Nx wvt.Ny wvt.Nz],"shouldAntialias",wvt.shouldAntialias,"seed",0,"initialTime",initialTime);
    ncfile.close();
    clear transformCleanup
    for iTolerance = 1:numel(options.relativeTolerances)
        for iRepeat = 1:options.repeatCount
            outputPath = fullfile(temporaryDirectory,erase(fixtureName,".nc")+"-"+iTolerance+"-"+iRepeat+".nc");
            reportPath = outputPath+".json";
            command = sanitizedCommand(sprintf('"%s" "%s" "%s" --integrator adaptive-rk23 --delta-t %.17g --final-time %.17g --relative-tolerance %.17g --absolute-tolerance %.17g --fft-provider native-fftw --threads 18 --report "%s"',options.runnerPath,fixturePath,outputPath,options.initialStep,finalTime,options.relativeTolerances(iTolerance),options.absoluteTolerances(iTolerance),reportPath));
            [status,output] = system(command);
            if status ~= 0
                error("WaveVortexBenchmark:AdaptiveExecutionFailed","Adaptive runtime failed for %s:\n%s",fixtureName,output)
            end
            report = jsondecode(fileread(reportPath));
            [actual,actualFile] = WVTransform.waveVortexTransformFromFile(outputPath,shouldReadOnly=true);
            actualCleanup = onCleanup(@()closeIfOpen(actualFile));
            actualVector = [actual.Ap(:);actual.Am(:);actual.A0(:)];
            scale = max(max(abs(reference)),realmin);
            records(end+1,1) = struct( ...
                fixture=fixtureName, ...
                isHydrostatic=actual.isHydrostatic, ...
                repeatIndex=iRepeat, ...
                configuration=caseConfiguration, ...
                relativeTolerance=options.relativeTolerances(iTolerance), ...
                absoluteTolerance=options.absoluteTolerances(iTolerance), ...
                relativeInfinityError=max(abs(actualVector-reference))/scale, ...
                acceptedStepCount=report.state.stepCount, ...
                rejectedStepCount=report.state.rejectedStepCount, ...
                rightHandSideEvaluationCount=report.state.rhsEvaluationCount, ...
                integrationSeconds=report.timingSeconds.integrate, ...
                fsalReuseCount=report.integrator.fsalReuseCount, ...
                fsalInvalidationCount=report.integrator.fsalInvalidationCount, ...
                workspaceBytes=report.storageBytes.integratorWorkspace, ...
                errorPolicyBytes=report.integrator.errorPolicyBytes, ...
                provider=report.provider, ...
                execution=report.execution); %#ok<AGROW>
            actualFile.close();
            clear actualCleanup
        end
    end
    representativeIndex = find(options.relativeTolerances == 1e-3,1);
    if isempty(representativeIndex), representativeIndex = ceil(numel(options.relativeTolerances)/2); end
    outputScheduleRecords(end+1,1) = outputScheduleEvidence(options.runnerPath,fixturePath,fixtureName,finalTime,options.initialStep,options.relativeTolerances(representativeIndex),options.absoluteTolerances(representativeIndex),options.outputCount,temporaryDirectory); %#ok<AGROW>
end
[gitStatus,sourceCommit] = system(sprintf('git -C "%s" rev-parse HEAD',repositoryRoot));
if gitStatus ~= 0
    sourceCommit = "unknown";
end
result = struct( ...
    schemaVersion="portable-adaptive-rk23-validation-v1", ...
    status="complete", ...
    createdUTC=string(datetime("now",TimeZone="UTC",Format="yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
    sourceCommit=strtrim(string(sourceCommit)), ...
    runnerPath=options.runnerPath, ...
    initialStep=options.initialStep, ...
    duration=options.duration, ...
    reference=struct(method="MATLAB ode78",relativeTolerance=options.referenceRelativeTolerance,absoluteToleranceScale=options.referenceAbsoluteTolerance), ...
    repeatCount=options.repeatCount, ...
    outputScheduleRecords=outputScheduleRecords, ...
    records=records);
jsonPath = fullfile(options.outputDirectory,"adaptive-rk23-validation.json");
markdownPath = fullfile(options.outputDirectory,"summary.md");
writeText(jsonPath,jsonencode(result,PrettyPrint=true));
writeText(markdownPath,markdown(result));
clear temporaryCleanup
end

function value = outputScheduleEvidence(runner,fixturePath,fixtureName,finalTime,initialStep,relativeTolerance,absoluteTolerance,outputCount,temporaryDirectory)
variants = ["no-output" "scheduled-output"];
reports = cell(1,2);
outputs = strings(1,2);
for iVariant = 1:2
    outputs(iVariant) = fullfile(temporaryDirectory,erase(fixtureName,".nc")+"-"+variants(iVariant)+".nc");
    reportPath = outputs(iVariant)+".json";
    outputArgument = "";
    if iVariant == 2, outputArgument = " --benchmark-output-count "+outputCount; end
    command = sanitizedCommand(sprintf('"%s" "%s" "%s" --integrator adaptive-rk23 --delta-t %.17g --final-time %.17g --relative-tolerance %.17g --absolute-tolerance %.17g --fft-provider native-fftw --threads 18 --report "%s"%s',runner,fixturePath,outputs(iVariant),initialStep,finalTime,relativeTolerance,absoluteTolerance,reportPath,outputArgument));
    [status,output] = system(command);
    if status ~= 0, error("WaveVortexBenchmark:AdaptiveOutputExecutionFailed","Adaptive output validation failed for %s:\n%s",fixtureName,output), end
    reports{iVariant} = jsondecode(fileread(reportPath));
end
finalStateRelativeError = compareCheckpointStates(outputs(1),outputs(2));
noOutput = reports{1}; scheduled = reports{2};
passed = noOutput.state.stepCount == scheduled.state.stepCount && noOutput.state.rejectedStepCount == scheduled.state.rejectedStepCount && noOutput.state.rhsEvaluationCount == scheduled.state.rhsEvaluationCount && scheduled.authorBenchmark.interpolatedOutputCount == outputCount && finalStateRelativeError <= 1e-12;
value = struct("fixture",fixtureName,"relativeTolerance",relativeTolerance,"noOutputAcceptedSteps",noOutput.state.stepCount,"outputAcceptedSteps",scheduled.state.stepCount,"noOutputRejectedSteps",noOutput.state.rejectedStepCount,"outputRejectedSteps",scheduled.state.rejectedStepCount,"noOutputRightHandSideEvaluations",noOutput.state.rhsEvaluationCount,"outputRightHandSideEvaluations",scheduled.state.rhsEvaluationCount,"interpolatedOutputCount",scheduled.authorBenchmark.interpolatedOutputCount,"interpolationSeconds",scheduled.authorBenchmark.interpolationSeconds,"noOutputCheckpointWriteSeconds",noOutput.timingSeconds.write,"scheduledCheckpointWriteSeconds",scheduled.timingSeconds.write,"finalStateRelativeError",finalStateRelativeError,"passed",passed);
end

function value = compareCheckpointStates(firstPath,secondPath)
[first,firstFile] = WVTransform.waveVortexTransformFromFile(firstPath,shouldReadOnly=true);
firstCleanup = onCleanup(@()closeIfOpen(firstFile));
[second,secondFile] = WVTransform.waveVortexTransformFromFile(secondPath,shouldReadOnly=true);
secondCleanup = onCleanup(@()closeIfOpen(secondFile));
firstValues = [first.Ap(:);first.Am(:);first.A0(:)];
secondValues = [second.Ap(:);second.Am(:);second.A0(:)];
value = max(abs(firstValues-secondValues))/max(max(abs(firstValues)),realmin);
clear firstCleanup secondCleanup
end

function reference = tightReference(wvt,finalTime,relativeTolerance,absoluteTolerance)
initial = [wvt.Ap(:);wvt.Am(:);wvt.A0(:)];
[alpha0,alphapm] = WVCoefficients.errorTolerances(wvt,absoluteTolerance);
absolute = [alphapm(:);alphapm(:);alpha0(:)];
options = odeset(RelTol=relativeTolerance,AbsTol=absolute,InitialStep=(finalTime-wvt.t)/20,MaxStep=(finalTime-wvt.t)/10);
[~,values] = ode78(@rightHandSide,[wvt.t finalTime],initial,options);
count = numel(wvt.Ap);
final = values(end,:).';
wvt.Ap = reshape(final(1:count),size(wvt.Ap));
wvt.Am = reshape(final(count+(1:count)),size(wvt.Am));
wvt.A0 = reshape(final(2*count+(1:count)),size(wvt.A0));
restoreFixedAmplitudes(wvt)
reference = [wvt.Ap(:);wvt.Am(:);wvt.A0(:)];

    function flux = rightHandSide(time,state)
        count = numel(wvt.Ap);
        wvt.t = time;
        wvt.Ap = reshape(state(1:count),size(wvt.Ap));
        wvt.Am = reshape(state(count+(1:count)),size(wvt.Am));
        wvt.A0 = reshape(state(2*count+(1:count)),size(wvt.A0));
        restoreFixedAmplitudes(wvt)
        [Fp,Fm,F0] = wvt.nonlinearFlux();
        flux = [Fp(:);Fm(:);F0(:)];
    end
end

function restoreFixedAmplitudes(wvt)
fixed = wvt.forcing(arrayfun(@(forcing)isa(forcing,"WVFixedAmplitudeForcing"),wvt.forcing));
for forcing = fixed
    wvt.Ap(forcing.Ap_indices) = forcing.Apbar;
    wvt.Am(forcing.Am_indices) = forcing.Ambar;
    wvt.A0(forcing.A0_indices) = forcing.A0bar;
end
end

function value = markdown(result)
lines = [ ...
    "# Portable adaptive RK3(2) validation"; ...
    ""; ...
    "Source commit: `"+result.sourceCommit+"`"; ...
    ""; ...
    "| Fixture | Repeat | RelTol | AbsTol | Relative error | Accepted | Rejected | RHS evaluations | FSAL reuse | Time (s) |"; ...
    "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|" ...
    ];
for record = reshape(result.records,1,[])
    lines(end+1) = sprintf("| %s | %d | %.3g | %.3g | %.3g | %d | %d | %d | %d | %.6g |",record.fixture,record.repeatIndex,record.relativeTolerance,record.absoluteTolerance,record.relativeInfinityError,record.acceptedStepCount,record.rejectedStepCount,record.rightHandSideEvaluationCount,record.fsalReuseCount,record.integrationSeconds); %#ok<AGROW>
end
lines = [lines;"";"## Output schedule invariance";"";"| Fixture | Accepted steps match | Rejected steps match | RHS counts match | Outputs | Final-state error | Interpolation (s) | Final checkpoint, no output (s) | Final checkpoint, scheduled output (s) | Pass |";"|---|---|---|---|---:|---:|---:|---:|---:|---|"];
for record = reshape(result.outputScheduleRecords,1,[])
    lines(end+1) = sprintf("| %s | %s | %s | %s | %d | %.3e | %.6g | %.6g | %.6g | %s |",record.fixture,yesNo(record.noOutputAcceptedSteps==record.outputAcceptedSteps),yesNo(record.noOutputRejectedSteps==record.outputRejectedSteps),yesNo(record.noOutputRightHandSideEvaluations==record.outputRightHandSideEvaluations),record.interpolatedOutputCount,record.finalStateRelativeError,record.interpolationSeconds,record.noOutputCheckpointWriteSeconds,record.scheduledCheckpointWriteSeconds,yesNo(record.passed)); %#ok<AGROW>
end
value = join(lines,newline)+newline;
end

function value = yesNo(condition)
if condition, value = "yes"; else, value = "no"; end
end

function command = sanitizedCommand(command)
if isunix
    command = "/usr/bin/env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+command;
end
end

function writeText(path,value)
file = fopen(path,"w");
if file < 0
    error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s for writing.",path)
end
cleanup = onCleanup(@()fclose(file));
fprintf(file,"%s",value);
end

function closeIfOpen(ncfile)
try
    ncfile.close();
catch
end
end
