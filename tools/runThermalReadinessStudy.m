function report = runThermalReadinessStudy(outputRoot,block,options)
% Execute one reproducible, bounded T10 study block in an immutable directory.
% Blocks are invoked separately so MATLAB releases scientific maps between
% comparisons. None launches a production campaign or a full seasonal cycle.
% - Topic: Developer utilities
% - Parameter outputRoot: parent for new named block directories
% - Parameter block: declared one-axis or mechanism comparison
% - Parameter options.scientificCache: optional matching baseline MAT arrays
% - Parameter options.closureCache: frozen six-mode canonical damping MAT file
% - Returns report: qualification evidence, including incomplete gates
arguments (Input)
    outputRoot (1,1) string
    block (1,1) string {mustBeMember(block,["time","product","native","horizontal","thermal","mean","closures","activity","cold10","cold100","peak10","zero10","zero100"])}
    options.scientificCache (1,1) string = ""
    options.closureCache (1,1) string = ""
    options.durationSeconds (1,1) double {mustBeFinite,mustBePositive} = 21600
    options.observationCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.observationCount,5)} = 9
    options.observationOffsets (1,:) double = []
    options.wallTimeBudgetSeconds (1,1) double {mustBeFinite,mustBePositive} = 1800
end
arguments (Output)
    report (1,1) struct
end
c=struct(velocityRMS=.1,seasonalM=100,phase=pi/2);
base=struct(name="",configuration=c,step=900,adaptive=false,scientificState=struct(),dampingVariant="none");
cases=repmat(base,1,3); pairs=struct('candidate',{},'reference',{},'axis',{},'refinement',{});
switch block
    case "time"
        cases=repmat(base,1,4);
        for j=1:3, cases(j).name="step"+string(1800/2^(j-1)); cases(j).step=1800/2^(j-1); end
        cases(4)=cases(1); cases(4).name="adaptive"; cases(4).adaptive=true;
        pairs=[pair(cases,"time"),struct(candidate="adaptive",reference="step900",axis="time",refinement="step450")];
    case "product"
        counts=[769 1537 3074];
        for j=1:3, cases(j).name="product"+string(counts(j)); cases(j).configuration.productCount=counts(j); end
        pairs=pair(cases,"product sampling");
    case "native"
        counts=[385 513 769];
        for j=1:3, cases(j).name="native"+string(counts(j)); cases(j).configuration.Nz=counts(j); end
        pairs=pair(cases,"native sampling");
    case "horizontal"
        counts=[32 64 96];
        for j=1:3, cases(j).name="horizontal"+string(counts(j)); cases(j).configuration.Nx=counts(j); cases(j).configuration.Ny=counts(j); end
        pairs=pair(cases,"horizontal bandwidth");
    case "thermal"
        counts=[257 385 513];
        for j=1:3
            cases(j).name="thermal"+string(counts(j)); cases(j).configuration.thermalCount=counts(j);
            cases(j).configuration.Nz=769;
        end
        pairs=pair(cases,"thermal bandwidth");
    case "mean"
        counts=[4 8 16];
        for j=1:3, cases(j).name="mean"+string(counts(j)); cases(j).configuration.mdaCount=counts(j); end
        pairs=pair(cases,"mean bandwidth");
    case "closures"
        variants=["none","horizontal","apv"];
        for j=1:3, cases(j).name=variants(j); cases(j).dampingVariant=variants(j); end
    case "activity"
        cases=cases(1:2); cases(1).name="nonlinear"; cases(2).name="companion";
        cases(2).configuration.shouldIncludeAdvection=false;
    case {"cold10","cold100"}
        cases=base; cases.name=block; cases.configuration=struct(kind="cold",seasonalM=str2double(extractAfter(block,"cold")));
    case "peak10"
        cases=base; cases.name=block; cases.configuration.seasonalM=10; cases.configuration.velocityRMS=.01;
    case "zero10"
        cases=base; cases.name=block; cases.configuration.seasonalM=10; cases.configuration.velocityRMS=.01; cases.configuration.phase=0;
    case "zero100"
        cases=base; cases.name=block; cases.configuration.phase=0;
end
if options.scientificCache~=""
    cache=load(options.scientificCache,'scientificState');
    defaults=struct(Nx=64,Ny=64,Nz=385,thermalCount=257,mdaCount=4,assemblyCount=2057,productCount=1537);
    for j=1:numel(cases)
        matches=true;
        for name=string(fieldnames(defaults)).'
            if isfield(cases(j).configuration,name), matches=matches && cases(j).configuration.(name)==defaults.(name); end
        end
        if matches, cases(j).scientificState=cache.scientificState; end
    end
end
canonical=struct();
if block=="closures"
    if options.closureCache=="", error('WV:ReadinessClosureCache','The closure comparison requires one frozen canonical six-mode law.'); end
    saved=load(options.closureCache,'canonical'); canonical=saved.canonical;
end
offsets=options.observationOffsets;
if isempty(offsets), offsets=linspace(0,options.durationSeconds,options.observationCount); end
report=qualifyThermalReadiness(fullfile(outputRoot,block),cases,durationSeconds=options.durationSeconds,observationOffsets=offsets,pairs=pairs,wallTimeBudgetSeconds=options.wallTimeBudgetSeconds,caseWallTimeBudgetSeconds=min(1800,options.wallTimeBudgetSeconds),canonicalDamping=canonical);
end

function value=pair(cases,axis)
value=struct(candidate=cases(1).name,reference=cases(2).name,axis=axis,refinement=cases(3).name);
end
