function definitions = waveVortexObserverCostBenchmarkCases(options)
% Define the matched observer-integration and dense-output cost cases.
arguments
    options.caseIds (1,:) string = strings(1,0)
    options.deltaT (1,1) double {mustBePositive} = 128
    options.integrationStepCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.denseOutputPointsPerStep (1,1) double {mustBeInteger,mustBePositive} = 3
end

finalTime = options.integrationStepCount*options.deltaT;
denseOutputInterval = options.deltaT/(options.denseOutputPointsPerStep+1);
denseRecordCount = options.denseOutputPointsPerStep+2;
common = struct( ...
    "deltaT",options.deltaT, ...
    "finalTime",finalTime, ...
    "integrationStepCount",options.integrationStepCount, ...
    "denseOutputPointsPerStep",options.denseOutputPointsPerStep, ...
    "denseOutputInterval",denseOutputInterval, ...
    "denseOutputStartTime",0, ...
    "denseOutputEndTime",options.deltaT);

definitions = [ ...
    definition(common,"coefficient-endpoint","Coefficients | endpoint output","coefficients only","endpoint output",false,false,"none",struct("waveVortex",2,"dense",0,"particles",0,"tracers",0)); ...
    definition(common,"coefficient-dense-output","Coefficients | dense coefficient output","coefficients only","first-step dense coefficient output",false,true,"coefficients",struct("waveVortex",2,"dense",denseRecordCount,"particles",0,"tracers",0)); ...
    definition(common,"integrated-observer-endpoint","Integrated tracer/particles | endpoint output","coefficients plus tracer and particles","endpoint output",true,false,"none",struct("waveVortex",2,"dense",0,"particles",0,"tracers",0)); ...
    definition(common,"composite-dense-output","Integrated tracer/particles | composite dense output","coefficients plus tracer and particles","first-step composite dense-output graph",true,true,"composite",struct("waveVortex",2,"dense",denseRecordCount,"particles",denseRecordCount,"tracers",denseRecordCount))];

if isempty(options.caseIds)
    return
end
knownIds = string({definitions.id});
unknownIds = setdiff(options.caseIds,knownIds,"stable");
if ~isempty(unknownIds)
    error("WaveVortexBenchmark:UnknownObserverCostCase","Unknown observer-cost benchmark case: %s",strjoin(unknownIds,", "));
end
if numel(unique(options.caseIds,"stable")) ~= numel(options.caseIds)
    error("WaveVortexBenchmark:DuplicateObserverCostCase","Observer-cost benchmark case IDs must be unique.");
end
definitions = definitions(arrayfun(@(id)find(knownIds==id,1),options.caseIds));
end

function value = definition(common,id,label,integrationLabel,outputLabel,integratesObserverState,usesDenseOutput,denseOutputTarget,expectedOutputRecordCounts)
value = common;
value.id = id;
value.label = label;
value.integrationLabel = integrationLabel;
value.outputLabel = outputLabel;
value.integratesObserverState = integratesObserverState;
value.usesDenseOutput = usesDenseOutput;
value.denseOutputTarget = denseOutputTarget;
value.scheduledInteriorOutputCount = double(usesDenseOutput)*common.denseOutputPointsPerStep;
value.expectedOutputRecordCounts = expectedOutputRecordCounts;
end
