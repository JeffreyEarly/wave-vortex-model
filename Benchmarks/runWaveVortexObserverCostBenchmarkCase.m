function result = runWaveVortexObserverCostBenchmarkCase(caseId,options)
% Run one profileable observer-integration/dense-output cost case.
arguments
    caseId (1,1) string
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [64 64 33]
    options.Lxyz (1,3) double {mustBePositive} = [150e3 150e3 1300]
    options.deltaT (1,1) double {mustBePositive} = 128
    options.integrationStepCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.denseOutputPointsPerStep (1,1) double {mustBeInteger,mustBePositive} = 3
    options.seed (1,1) double {mustBeInteger,mustBeNonnegative} = 4001
    options.outputPath (1,1) string = ""
    options.phasePath (1,1) string = ""
    options.plateauSeconds (1,1) double {mustBeNonnegative} = 0
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalPath = path;
originalRng = rng;
temporaryFolder = "";
outputPath = options.outputPath;
stateCleanup = onCleanup(@()restoreState(originalPath,originalRng));
addRepositoryPaths(repositoryRoot,benchmarkFolder);

definition = waveVortexObserverCostBenchmarkCases(caseIds=caseId,deltaT=options.deltaT,integrationStepCount=options.integrationStepCount,denseOutputPointsPerStep=options.denseOutputPointsPerStep);
if outputPath == ""
    temporaryFolder = string(tempname);
    mkdir(temporaryFolder);
    outputPath = fullfile(temporaryFolder,"observer-cost.nc");
else
    outputFolder = string(fileparts(outputPath));
    if outputFolder ~= "" && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
end
outputCleanup = onCleanup(@()cleanupOutput(outputPath,temporaryFolder));

writePhase(options.phasePath,"construction");
wvt = WVTransformConstantStratification(options.Lxyz,options.Nxyz,N0=sqrt(2e-5),latitude=45,isHydrostatic=false,shouldAntialias=true);
wvtCleanup = onCleanup(@()closeTransform(wvt));
initializeThreeInterfaceIntegratorState(wvt,options.seed);
model = WVModel(wvt);
modelCleanup = onCleanup(@()closeModel(model));
if definition.integratesObserverState
    model.setFloatPositions([10e3 70e3],[9e3 65e3],[-250 -850],'u');
    model.addTracer(sin(2*pi*wvt.X/wvt.Lx).*cos(2*pi*wvt.Y/wvt.Ly),"dye");
end
configureOutputGraph(model,char(outputPath),definition);
model.setupIntegrator(integratorType="fixed",deltaT=options.deltaT);

integratedState = integratedStateRecord(model);
writePhase(options.phasePath,"steady-retained");
pauseIfPositive(options.plateauSeconds);
rhsEvaluationsBefore = double(model.nFluxComputations);
writePhase(options.phasePath,"integrate");
waitForPhaseSample(options.phasePath,"integrate");
operationTimer = tic;
model.integrateToTime(definition.finalTime,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
elapsedSeconds = toc(operationTimer);
writePhase(options.phasePath,"integration-complete");

rhsEvaluationCount = double(model.nFluxComputations)-rhsEvaluationsBefore;
acceptedStepCount = double(model.rk4Integrator.totalIterations);
finalState = struct("t",wvt.t,"ApNorm",norm(wvt.Ap(:)),"AmNorm",norm(wvt.Am(:)),"A0Norm",norm(wvt.A0(:)));
model.closeNetCDFFile();
outputRecordCounts = readOutputRecordCounts(outputPath);
result = struct( ...
    "schemaVersion","observer-cost-case-v1", ...
    "status","complete", ...
    "case",definition, ...
    "timing",struct("boundary","fixed-RK4 integration plus scheduled output delivery","elapsedSeconds",elapsedSeconds), ...
    "work",struct("acceptedStepCount",acceptedStepCount,"rhsEvaluationCount",rhsEvaluationCount,"scheduledInteriorOutputCount",definition.scheduledInteriorOutputCount,"outputRecordCounts",outputRecordCounts,"integratedState",integratedState), ...
    "finalState",finalState);
validateCaseResult(result);
writePhase(options.phasePath,"outputs-held");
pauseIfPositive(options.plateauSeconds);
writePhase(options.phasePath,"complete");
clear modelCleanup wvtCleanup outputCleanup stateCleanup
end

function configureOutputGraph(model,outputPath,definition)
outputFile = model.createNetCDFFileForModelOutput(outputPath,outputInterval=definition.finalTime,shouldOverwriteExisting=true);
if ~definition.usesDenseOutput
    return
end
denseGroup = outputFile.addNewEvenlySpacedOutputGroup("dense",outputInterval=definition.denseOutputInterval,initialTime=definition.denseOutputStartTime,finalTime=definition.denseOutputEndTime);
if definition.denseOutputTarget == "coefficients"
    denseGroup.addObservingSystem(model.wvCoefficientFluxedObservingSystem);
    return
end

defaultGroup = outputFile.outputGroupWithName(model.defaultOutputGroupName());
particles = model.fluxedObservingSystemWithName("float");
tracer = model.fluxedObservingSystemWithName("dye");
defaultGroup.removeObservingSystem([particles tracer]);
denseGroup.addObservingSystem(WVEulerianFields(model,fieldNames={'u'}));
denseGroup.addObservingSystem(WVMooring(model,name="mooring",x=[0 50e3],y=[0 40e3],trackedFieldNames={'u'}));
particleGroup = outputFile.addNewEvenlySpacedOutputGroup("particles",outputInterval=definition.denseOutputInterval,initialTime=definition.denseOutputStartTime,finalTime=definition.denseOutputEndTime);
particleGroup.addObservingSystem(particles);
tracerGroup = outputFile.addNewEvenlySpacedOutputGroup("tracers",outputInterval=definition.denseOutputInterval,initialTime=definition.denseOutputStartTime,finalTime=definition.denseOutputEndTime);
tracerGroup.addObservingSystem(tracer);
end

function value = integratedStateRecord(model)
componentLengths = zeros(model.nFluxComponents,1);
iComponent = 0;
for observingSystem = reshape(model.fluxedObservingSystems,1,[])
    lengths = observingSystem.lengthOfFluxComponents();
    componentLengths(iComponent+(1:numel(lengths))) = lengths;
    iComponent = iComponent+numel(lengths);
end
elementCount = sum(componentLengths);
value = struct("observingSystemNames",string({model.fluxedObservingSystems.name}),"fluxComponentCount",model.nFluxComponents,"elementCount",elementCount,"nominalBytes",8*elementCount,"scope","integrated double-precision state only; solver, allocator, transform, and output buffers excluded");
end

function validateCaseResult(result)
definition = result.case;
if result.work.acceptedStepCount~=definition.integrationStepCount || result.work.rhsEvaluationCount~=1+4*definition.integrationStepCount
    error("WaveVortexBenchmark:ObserverCostWorkMismatch","Case %s did not execute its required fixed-RK4 work.",definition.id);
end
if ~isequal(orderfields(result.work.outputRecordCounts),orderfields(definition.expectedOutputRecordCounts))
    error("WaveVortexBenchmark:ObserverCostOutputMismatch","Case %s did not deliver its configured output graph.",definition.id);
end
end

function value = readOutputRecordCounts(pathname)
value = struct("waveVortex",recordCount(pathname,"/wave-vortex/t"),"dense",recordCount(pathname,"/dense/t"),"particles",recordCount(pathname,"/particles/t"),"tracers",recordCount(pathname,"/tracers/t"));
end

function value = recordCount(pathname,variable)
try
    value = numel(ncread(pathname,variable));
catch
    value = 0;
end
end

function writePhase(pathname,phase)
if pathname == "", return, end
temporaryPath = pathname+".tmp";
writeText(temporaryPath,phase);
movefile(temporaryPath,pathname,"f");
end

function waitForPhaseSample(phasePath,expectedPhase)
if phasePath == "", return, end
acknowledgementPath = string(getenv("WV_RSS_PHASE_ACK"));
if acknowledgementPath == "", return, end
timer = tic;
while toc(timer) < 5
    if isfile(acknowledgementPath) && strtrim(string(fileread(acknowledgementPath))) == expectedPhase
        return
    end
    pause(0.001)
end
error("WaveVortexBenchmark:RSSPhaseHandshake","The external RSS sampler did not acknowledge phase %s.",expectedPhase);
end

function addRepositoryPaths(repositoryRoot,benchmarkFolder)
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for item = reshape(metadata.folders,1,[]), folder=fullfile(repositoryRoot,item.path); if isfolder(folder), addpath(folder); end, end
addpath(repositoryRoot);
addpath(benchmarkFolder);
end

function closeModel(model)
if isempty(model) || ~isvalid(model), return, end
try
    model.closeNetCDFFile();
catch
end
delete(model);
end

function closeTransform(wvt)
if ~isempty(wvt) && isvalid(wvt), delete(wvt); end
end

function cleanupOutput(outputPath,temporaryFolder)
if isfile(outputPath), delete(outputPath); end
if temporaryFolder~="" && isfolder(temporaryFolder), rmdir(temporaryFolder,"s"); end
end

function restoreState(originalPath,originalRng), path(originalPath); rng(originalRng); end
function pauseIfPositive(seconds), if seconds>0, pause(seconds); end, end

function writeText(pathname,contents)
fileId = fopen(pathname,"w");
if fileId<0, error("WaveVortexBenchmark:ArtifactWriteFailed","Unable to open %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",contents);
clear cleanup
end
