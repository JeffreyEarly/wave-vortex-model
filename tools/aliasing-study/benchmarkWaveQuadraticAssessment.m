function result = benchmarkWaveQuadraticAssessment(outputDirectory,options)
% Measure preparation/reuse costs and calibrate sparse products on small grids.
arguments (Input)
    outputDirectory (1,1) string = string(tempname)
    options.repetitions (1,1) double {mustBeInteger,mustBePositive} = 3
end
arguments (Output)
    result (1,1) struct
end
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('WVStudy:OutputAlreadyExists','Choose a new directory for benchmark evidence.')
end
costs=cell(0,1); comparisons=cell(0,1);
for id=["cal-constant-17","cal-exponential-17"]
    for repetition=1:options.repetitions
        config=resolveStudyCase(id);
        timer=tic; data=prepareSourceStudy(config); sourceSeconds=toc(timer);
        timer=tic; prepared=WVInternal.prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true); evidenceSeconds=toc(timer);
        k=prepared.inventory.magnitudes; k=k(k>0);
        timer=tic; first=assessWaveQuadraticResolution(prepared,waveModeKappa=k,waveModeCount=3); firstSeconds=toc(timer);
        timer=tic; second=assessWaveQuadraticResolution(prepared,waveModeKappa=flipud(k),waveModeCount=flipud(mod((1:numel(k)).',4))); secondSeconds=toc(timer);
        c=prepared.cost; phase=data.preparationCost;
        costs{end+1}=table(id,repetition,sourceSeconds,phase.candidateSolveSeconds,phase.referenceSolveSeconds,phase.candidateSolves,phase.referenceSolves,sourceSeconds-phase.candidateSolveSeconds-phase.referenceSolveSeconds,evidenceSeconds,c.projectionPreparationSeconds,c.productEvaluationSeconds,c.projectionCount,firstSeconds,secondSeconds,c.reservedProducts,c.largestProductBatch,c.retainedBytes,c.workingMemoryEstimateBytes,first.status,second.status, ...
            VariableNames=["caseId","repetition","sourcePreparationSeconds","candidateSolveSeconds","referenceSolveSeconds","candidateSolveCalls","referenceSolveCalls","gridEvaluationAndOtherSeconds","evidencePreparationSeconds","projectionPreparationSeconds","productEvaluationSeconds","preparedProjectionCount","firstAssessmentSeconds","repeatAssessmentSeconds","reservedProducts","largestProductBatch","retainedBytes","workingMemoryEstimateBytes","firstStatus","repeatStatus"]); %#ok<AGROW>
    end
    % This intentionally small all-products control changes neither the
    % scientific modes nor reference rules between sparse/dense measurements.
    config.Nxy=[6 6]; data=prepareSourceStudy(config);
    sparse=WVInternal.prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true);
    dense=WVInternal.prepareWaveQuadraticAssessment(data,policy="dense");
    for count=1:config.waveCount
        a=assessWaveQuadraticResolution(sparse,waveModeCount=count);
        b=assessWaveQuadraticResolution(dense,waveModeCount=count);
        delta=max(b.pages.quadraticError-a.pages.quadraticError);
        comparisons{end+1}=table(id,count,max(a.pages.quadraticError),max(b.pages.quadraticError),delta,a.status,b.status,a.cost.selectedProducts,b.cost.selectedProducts, ...
            VariableNames=["caseId","commonWaveCount","sparseMaximumError","denseMaximumError","maximumPageUnderestimate","sparseStatus","denseStatus","sparseProducts","denseProducts"]); %#ok<AGROW>
    end
end
costs=vertcat(costs{:}); comparisons=vertcat(comparisons{:});
[~,hardware]=system('sysctl -n machdep.cpu.brand_string');
result=struct(costs=costs,denseControl=comparisons,matlabVersion=string(version),hardware=strtrim(string(hardware)),computer=string(computer),scope="Unprofiled elapsed times; all repetitions retained. Working memory is a conservative estimate, not measured process RSS. Logical solve-call counts include one bulk boundary solve per resolution.");
mkdir(outputDirectory); writetable(costs,fullfile(outputDirectory,'costs.csv')); writetable(comparisons,fullfile(outputDirectory,'dense-control.csv'));
writelines(jsonencode(rmfield(result,{'costs','denseControl'}),PrettyPrint=true),fullfile(outputDirectory,'environment.json'));
disp(costs); disp(comparisons);
end
