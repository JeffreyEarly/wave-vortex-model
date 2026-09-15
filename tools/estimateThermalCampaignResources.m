function report = estimateThermalCampaignResources(benchmarks,outputDirectory,options)
% Scale measured workload samples into explicitly conditional campaign scenarios.
%
% Each benchmark descriptor supplies directory, forcingMultiplier (10 or 100),
% and stateRegime. Only that multiplier's measured samples contribute to its
% timing range. Missing M100 measurements never inherit M10 throughput. The
% combined scenario runs both cases serially and sums their individual bounds.
% A year is options.seasonalPeriod seconds. Counts include the time-zero record:
% 48 coefficient records and 384 scalar records per complete subsequent year.
%
% The benchmark's logical payload sizes are computed from stored array shapes;
% they are not measured allocated bytes per record. The payload scenario adds
% them to the measured initial file, which already includes both first records.
% File-format growth, extra restart files and offline analysis are separate.
% Optional io.csv columns staticFileBytes, coefficientRecordAllocatedBytes,
% scalarRecordAllocatedBytes, checkpointFileBytes, checkpointWriteSeconds and
% analysisSecondsPerCoefficientRecord supply separate measured components.
% Absent measurements remain NaN; no restart cadence is silently assumed.
% Setup columns constructionSeconds, restorationSeconds, initialStateWriteSeconds,
% integratorSetupSeconds and firstRhsSeconds are reported separately. The
% measured startup subtotal adds canonical restoration, integrator setup,
% first RHS and (for output timings) sample output setup once per campaign.
% Missing components are counted, never interpreted as measured zero. Scientific
% construction and the optional initial-state snapshot are separate costs:
% constructing a basis and restoring one are alternative preparation paths.
% The startup subtotal describes benchmark preparation, not a complete production
% estimate; sample output setup is not a qualification of production cadence.
%
% Rates describe only the supplied states, integrator settings and sample I/O
% cadences. Scaling manufactured controls does not qualify mature seasonal
% throughput. Production wall/disk acceptance remains unspecified/conditional.
%
% - Topic: Developer utilities
% - Parameter benchmarks: explicit directory, forcingMultiplier and stateRegime records
% - Parameter outputDirectory: new destination for provenance and scenario tables
% - Parameter options.years: positive integer campaign lengths; default 1,5,20
% - Parameter options.seasonalPeriod: model seconds per year; default 365.25 days
% - Parameter options.workloadDescription: caller's common geometry and workload scope
% - Returns report: original samples, measured ranges, component costs and conditional scenarios
arguments (Input)
    benchmarks (1,:) struct
    outputDirectory (1,1) string
    options.years (1,:) double {mustBeInteger,mustBePositive,mustBeFinite} = [1 5 20]
    options.seasonalPeriod (1,1) double {mustBePositive,mustBeFinite} = 365.25*86400
    options.workloadDescription (1,1) string = "caller-supplied benchmark subset"
end
arguments (Output)
    report (1,1) struct
end
if isfile(fullfile(outputDirectory,'resource-contract.json'))
    error('WV:ReadinessResourceEvidence','Use a new resource-report directory; prior scenarios are immutable.');
end
samples=table();components=table();provenance=table();seenDirectories=strings(0,1);
for j=1:numel(benchmarks)
    b=benchmarks(j);
    if ~all(isfield(b,["directory","forcingMultiplier","stateRegime"])) || ~isnumeric(b.forcingMultiplier) || ~isscalar(b.forcingMultiplier) || ~ismember(b.forcingMultiplier,[10 100])
        error('WV:ReadinessResourceInput','Each benchmark needs directory, forcingMultiplier 10 or 100, and stateRegime.');
    end
    folder=string(b.directory);regime=string(b.stateRegime);
    if ~isscalar(folder) || ~isfolder(folder) || ~isscalar(regime) || ismissing(regime) || strlength(regime)==0
        error('WV:ReadinessResourceInput','Supply an existing benchmark directory and explicit scalar stateRegime.');
    end
    folder=string(java.io.File(char(folder)).getCanonicalPath());
    if ismember(folder,seenDirectories),error('WV:ReadinessResourceInput','A benchmark directory may contribute only once; do not relabel the same samples as another multiplier.');end
    seenDirectories(end+1,1)=folder; %#ok<AGROW>
    input=fullfile(folder,'integration.csv');
    if ~isfile(input),error('WV:ReadinessResourceInput','Missing benchmark integration ledger: %s.',input);end
    integration=readtable(input,TextType='string');
    required=["withOutput","simulatedSeconds","wallSeconds","status"];
    if ~all(ismember(required,string(integration.Properties.VariableNames)))
        error('WV:ReadinessResourceSchema','The integration ledger lacks measured seconds, output policy or status.');
    end
    caseId="unavailable";
    setupPath=fullfile(folder,'setup.csv');setup=table();
    if isfile(setupPath)
        setup=readtable(setupPath,TextType='string');
        if ismember('caseId',setup.Properties.VariableNames) && height(setup)==1,caseId=string(setup.caseId);end
    end
    originalRatio=nan(height(integration),1);
    if ismember('simulatedSecondsPerWallSecond',integration.Properties.VariableNames),originalRatio=integration.simulatedSecondsPerWallSecond;end
    for k=1:height(integration)
        s=integration(k,:);
        accepted=ismember(string(s.status),["complete","wall-budget"]) && isfinite(s.simulatedSeconds) && s.simulatedSeconds>0 && isfinite(s.wallSeconds) && s.wallSeconds>0;
        rate=NaN;if accepted,rate=s.simulatedSeconds/s.wallSeconds;end
        row=table(j,folder,caseId,b.forcingMultiplier,regime,k,logical(s.withOutput),s.simulatedSeconds,s.wallSeconds,rate,originalRatio(k), ...
            optionalNumber(s,"threads"),optionalNumber(s,"coefficientInterval"),optionalNumber(s,"scalarInterval"),string(s.status),accepted, ...
            VariableNames={'benchmarkIndex','directory','caseId','forcingMultiplier','stateRegime','sampleIndex','withOutput','simulatedSeconds','wallSeconds','simulatedSecondsPerWallSecond','recordedRatio','threads','sampleCoefficientInterval','sampleScalarInterval','sampleStatus','included'});
        samples=[samples;row]; %#ok<AGROW>
    end
    ioPath=fullfile(folder,'io.csv');io=table();
    if isfile(ioPath),io=readtable(ioPath,TextType='string');end
    names=["initialFileBytesIncludingFirstRecords","sampleFileBytes","additionalSampleBytes", ...
        "coefficientRecordPayloadBytes","scalarRecordPayloadBytes","staticFileBytes", ...
        "coefficientRecordAllocatedBytes","scalarRecordAllocatedBytes","checkpointFileBytes", ...
        "restorationSeconds","checkpointWriteSeconds","analysisSecondsPerCoefficientRecord", ...
        "constructionSeconds","canonicalRestorationSeconds","initialStateWriteSeconds", ...
        "integratorSetupSeconds","firstRhsSeconds","sampleOutputSetupSeconds"];
    for name=names
        values=[];source=io;column=name;
        if ismember(name,["constructionSeconds","initialStateWriteSeconds","integratorSetupSeconds","firstRhsSeconds"])
            source=setup;
        elseif name=="canonicalRestorationSeconds"
            source=setup;column="restorationSeconds";
        elseif name=="sampleOutputSetupSeconds"
            source=integration(logical(integration.withOutput),:);column="outputSetupSeconds";
        end
        if ismember(column,string(source.Properties.VariableNames)),values=source.(column);end
        values=values(isfinite(values) & values>=0);[low,high]=boundsOrNaN(values);
        evidence="unmeasured";
        if ~isempty(values),evidence="measured";end
        if ~isempty(values) && ismember(name,["coefficientRecordPayloadBytes","scalarRecordPayloadBytes"]),evidence="shape-derived logical payload";end
        units="bytes";
        if endsWith(name,"Seconds") || name=="analysisSecondsPerCoefficientRecord",units="s";end
        row=table(j,folder,caseId,b.forcingMultiplier,regime,name,low,high,numel(values),units,evidence, ...
            VariableNames={'benchmarkIndex','directory','caseId','forcingMultiplier','stateRegime','component','minimum','maximum','sampleCount','units','evidence'});
        components=[components;row]; %#ok<AGROW>
    end
    for file=[input,setupPath,ioPath]
        present=isfile(file);bytes=NaN;sha256="";
        if present,info=dir(file);bytes=info.bytes;sha256=hashFile(file);end
        row=table(j,file,present,bytes,sha256,VariableNames={'benchmarkIndex','path','present','bytes','sha256'});
        provenance=[provenance;row]; %#ok<AGROW>
    end
end
ranges=table();
for multiplier=[10 100]
    for withOutput=[false true]
        selected=false(height(samples),1);
        if ~isempty(samples),selected=samples.forcingMultiplier==multiplier & samples.withOutput==withOutput & samples.included;end
        values=[];regimes="unmeasured";
        if any(selected),values=samples.simulatedSecondsPerWallSecond(selected);regimes=join(unique(samples.stateRegime(selected)),"; ");end
        [low,high]=boundsOrNaN(values);
        row=table(multiplier,withOutput,numel(values),low,high,regimes,VariableNames={'forcingMultiplier','withOutput','sampleCount','minimumSimulatedSecondsPerWallSecond','maximumSimulatedSecondsPerWallSecond','stateRegimes'});
        ranges=[ranges;row]; %#ok<AGROW>
    end
end
scenarios=table();
for years=unique(options.years,'stable')
    for withOutput=[false true]
        rows=cell(1,2);
        for j=1:2
            multiplier=[10 100];multiplier=multiplier(j);
            r=ranges(ranges.forcingMultiplier==multiplier & ranges.withOutput==withOutput,:);
            simulated=years*options.seasonalPeriod;nc=48*years+1;ns=384*years+1;
            initial=componentBounds(components,multiplier,"initialFileBytesIncludingFirstRecords");
            coefficient=componentBounds(components,multiplier,"coefficientRecordPayloadBytes");
            scalar=componentBounds(components,multiplier,"scalarRecordPayloadBytes");
            payload=initial+(nc-1)*coefficient+(ns-1)*scalar;
            allocated=componentBounds(components,multiplier,"staticFileBytes")+nc*componentBounds(components,multiplier,"coefficientRecordAllocatedBytes")+ns*componentBounds(components,multiplier,"scalarRecordAllocatedBytes");
            analysis=nc*componentBounds(components,multiplier,"analysisSecondsPerCoefficientRecord")/3600;
            construction=componentBounds(components,multiplier,"constructionSeconds")/3600;
            restoration=componentBounds(components,multiplier,"canonicalRestorationSeconds")/3600;
            initialWrite=componentBounds(components,multiplier,"initialStateWriteSeconds")/3600;
            integratorSetup=componentBounds(components,multiplier,"integratorSetupSeconds")/3600;
            firstRhs=componentBounds(components,multiplier,"firstRhsSeconds")/3600;
            outputSetup=componentBounds(components,multiplier,"sampleOutputSetupSeconds")/3600;
            startupComponents=[restoration;integratorSetup;firstRhs;outputSetup];
            if ~withOutput,startupComponents(4,:)=[];end
            known=all(isfinite(startupComponents),2);startup=[NaN NaN];
            if any(known),startup=sum(startupComponents(known,:),1);end
            wall=[simulated/r.maximumSimulatedSecondsPerWallSecond,simulated/r.minimumSimulatedSecondsPerWallSecond]/3600;
            row=struct(caseLabel="M"+multiplier,years=years,withOutput=withOutput,caseCount=1,simulatedSeconds=simulated, ...
                measuredSampleCount=r.sampleCount,wallHoursMinimum=wall(1),wallHoursMaximum=wall(2), ...
                oneTimeConstructionHoursMinimum=construction(1),oneTimeConstructionHoursMaximum=construction(2), ...
                oneTimeCanonicalRestorationHoursMinimum=restoration(1),oneTimeCanonicalRestorationHoursMaximum=restoration(2), ...
                oneTimeIntegratorSetupHoursMinimum=integratorSetup(1),oneTimeIntegratorSetupHoursMaximum=integratorSetup(2), ...
                oneTimeFirstRhsHoursMinimum=firstRhs(1),oneTimeFirstRhsHoursMaximum=firstRhs(2), ...
                initialStateSnapshotWriteHoursMinimum=initialWrite(1),initialStateSnapshotWriteHoursMaximum=initialWrite(2), ...
                sampleOutputSetupHoursMinimum=outputSetup(1),sampleOutputSetupHoursMaximum=outputSetup(2), ...
                startupMeasuredComponentCount=sum(known),startupUnmeasuredComponentCount=sum(~known), ...
                measuredStartupSubsetHoursMinimum=startup(1),measuredStartupSubsetHoursMaximum=startup(2), ...
                integrationPlusMeasuredStartupHoursMinimum=wall(1)+startup(1),integrationPlusMeasuredStartupHoursMaximum=wall(2)+startup(2), ...
                coefficientRecords=nc,scalarRecords=ns,coefficientCadenceSeconds=options.seasonalPeriod/48,scalarCadenceSeconds=options.seasonalPeriod/384, ...
                oneFilePayloadScenarioBytesMinimum=payload(1),oneFilePayloadScenarioBytesMaximum=payload(2), ...
                allocatedByteScenarioMinimum=allocated(1),allocatedByteScenarioMaximum=allocated(2), ...
                coefficientAnalysisHoursMinimum=analysis(1),coefficientAnalysisHoursMaximum=analysis(2), ...
                additionalCheckpointCount=NaN,additionalCheckpointWallHours=NaN,additionalCheckpointBytes=NaN, ...
                totalWallHoursIncludingUnmeasuredCosts=NaN,productionWallLimitHours=NaN,productionDiskLimitBytes=NaN, ...
                measuredStateRegimes=r.stateRegimes,status="CONDITIONAL");
            rows{j}=row;
            scenarios=[scenarios;struct2table(row)]; %#ok<AGROW>
        end
        combined=rows{1};combined.caseLabel="M10+M100";
        for name=["caseCount","simulatedSeconds","measuredSampleCount","wallHoursMinimum","wallHoursMaximum","coefficientRecords","scalarRecords", ...
                "oneTimeConstructionHoursMinimum","oneTimeConstructionHoursMaximum","oneTimeCanonicalRestorationHoursMinimum","oneTimeCanonicalRestorationHoursMaximum", ...
                "oneTimeIntegratorSetupHoursMinimum","oneTimeIntegratorSetupHoursMaximum","oneTimeFirstRhsHoursMinimum","oneTimeFirstRhsHoursMaximum", ...
                "initialStateSnapshotWriteHoursMinimum","initialStateSnapshotWriteHoursMaximum","sampleOutputSetupHoursMinimum","sampleOutputSetupHoursMaximum", ...
                "startupMeasuredComponentCount","startupUnmeasuredComponentCount","measuredStartupSubsetHoursMinimum","measuredStartupSubsetHoursMaximum", ...
                "integrationPlusMeasuredStartupHoursMinimum","integrationPlusMeasuredStartupHoursMaximum", ...
                "oneFilePayloadScenarioBytesMinimum","oneFilePayloadScenarioBytesMaximum","allocatedByteScenarioMinimum","allocatedByteScenarioMaximum", ...
                "coefficientAnalysisHoursMinimum","coefficientAnalysisHoursMaximum"]
            combined.(name)=rows{1}.(name)+rows{2}.(name);
        end
        combined.measuredStateRegimes="M10: "+rows{1}.measuredStateRegimes+"; M100: "+rows{2}.measuredStateRegimes;
        scenarios=[scenarios;struct2table(combined)]; %#ok<AGROW>
    end
end
contract=struct(schema="thermal-campaign-resource-scenarios-v1",benchmarks=benchmarks,options=options, ...
    throughputScope="arithmetic scaling of observed workload samples; mature seasonal throughput is not established", ...
    setupScope="integration wall excludes setup; canonical restoration, integrator setup, first RHS and sample output setup are added once in a measured-only subtotal, with missing counts; scientific construction and initial snapshot writing remain separate alternative/optional costs", ...
    ioScope="withOutput identifies the timing samples; storage always uses planned T/48 and T/384 cadences, whose wall cost is not qualified by sample cadence", ...
    payloadScope="measured initial file including first records plus shape-derived payload for subsequent records; future format/chunk growth is excluded", ...
    checkpointScope="extra checkpoint count/cadence unspecified; component measurements are reported separately", ...
    combinedScope="serial execution of independent M10 and M100 campaigns; unknown inputs propagate as NaN", ...
    acceptance="CONDITIONAL: production wall/disk limits and unmeasured regime/analysis/checkpoint costs remain unresolved");
report=struct(contract=contract,samples=samples,ranges=ranges,components=components,scenarios=scenarios,provenance=provenance);
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
for name=["samples","ranges","components","scenarios","provenance"],writetable(report.(name),fullfile(outputDirectory,name+".csv"));end
file=fullfile(outputDirectory,'resource-contract.json');fid=fopen(file,'w');
if fid<0,error('WV:ReadinessResourceEvidence','Cannot create resource contract: %s.',file);end
cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(contract,PrettyPrint=true));
save(fullfile(outputDirectory,'resource-report.mat'),'report');
end

function value=optionalNumber(row,name)
value=NaN;if ismember(name,string(row.Properties.VariableNames)),value=row.(name);end
end

function value=componentBounds(components,multiplier,name)
value=[NaN NaN];if isempty(components),return;end
selected=components.forcingMultiplier==multiplier & components.component==name & components.sampleCount>0;
if any(selected),value=[min(components.minimum(selected)),max(components.maximum(selected))];end
end

function [low,high]=boundsOrNaN(values)
low=NaN;high=NaN;if ~isempty(values),low=min(values);high=max(values);end
end

function hash=hashFile(filePath)
fid=fopen(filePath,'rb');if fid<0,error('WV:ReadinessResourceEvidence','Cannot read benchmark ledger: %s.',filePath);end
cleanup=onCleanup(@()fclose(fid));digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid),digest.update(fread(fid,1024*1024,'*uint8'));end
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
