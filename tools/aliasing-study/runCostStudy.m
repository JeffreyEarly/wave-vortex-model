function runCostStudy(caseId,policy,outputDirectory)
% Run a declared actual policy or independent sample for timing and validation.
arguments
    caseId (1,1) string
    policy (1,1) string {mustBeMember(policy,["linear","fixed","targeted","independent"])}
    outputDirectory (1,1) string
end
config=resolveStudyCase(caseId);
if policy=="linear"
    if isfolder(outputDirectory), error('WVStudy:ExistingOutput','Preserve the completed cost run.'); end
    mkdir(outputDirectory); data=prepareSourceStudy(config);
    timer=tic;
    gram=max(data.waveGram,[],2);
    count=leadingCount(gram<=config.gramTolerance);
    assessmentSeconds=toc(timer);
    meanPage=find(data.inventory.magnitudes==0); wavePage=find(data.inventory.magnitudes>0,1);
    familyModeLabels=struct(wave=data.wave{wavePage}.labels,apv=data.apv.labels,mda=data.mda.labels,inertial=data.wave{meanPage}.labels,boundary=["surface","bottom"]);
    summary=struct(familyModeLabels=familyModeLabels,caseId=caseId,policy=policy,scope="linear-only; no wave quadratic reference check",configuration=config,constructionSeconds=data.constructionSeconds,assessmentSeconds=assessmentSeconds,nonzeroProductEvaluations=0,largestLinearCount=count,eigenConvergence=max(data.requiredConvergence,[],'all'),fixedFamiliesGramAccepted=max([data.apv.assessment.prefixDiagnostics.gramError(end),data.mda.assessment.prefixDiagnostics.gramError(end),data.inertialGram])<=config.gramTolerance,matlabVersion=string(version),computer=string(computer));
    writeResult(fullfile(outputDirectory,'cost-summary.json'),summary); return
end
if policy=="independent"
    geometry=enumerateStudyInteractions(config.Lxy,config.Nxy);
    previous=rng; cleanup=onCleanup(@()rng(previous));
    rng(config.independentSampleSeed,'twister');
    indices=sort(randperm(height(geometry.interactions),config.independentSampleCount));
    clear cleanup
    runSourceSurvey(config,outputDirectory,interactionIndices=indices);
else
    runSourceSurvey(config,outputDirectory,policy=policy);
    indices=[];
end
loaded=load(fullfile(outputDirectory,'products.mat'),'raw','rows','summary','inventory');
summary=loaded.summary; errors=zeros(config.waveCount,1);
limitingRow=zeros(config.waveCount,1); limitingPair=zeros(config.waveCount,1);
if policy=="independent", maskPolicy="dense"; else, maskPolicy=policy; end
for r=1:height(loaded.rows)
    record=loaded.raw{r};
    for count=1:config.waveCount
        mask=studyModePairMask(record.positionA,record.positionB,loaded.rows.inputA(r),loaded.rows.inputB(r),count,maskPolicy);
        pairs=find(mask);
        if isempty(pairs), continue; end
        [value,j]=max(record.error(count,pairs));
        if value>errors(count)
            errors(count)=value; limitingRow(count)=r; limitingPair(count)=pairs(j);
        end
    end
end
prefix=table((1:config.waveCount).',summary.waveGram(:),errors,VariableNames=["waveCount","gramError","sampledQuadraticError"]);
writetable(prefix,fullfile(outputDirectory,'sampled-prefixes.csv'));
summary.caseId=caseId; summary.policy=policy;
summary.largestLinearCount=leadingCount(summary.waveGram(:)<=config.gramTolerance);
summary.largestSampledCounts=arrayfun(@(tolerance)leadingCount(errors<=tolerance & summary.waveGram(:)<=config.gramTolerance),[.1 .03 .01]);
summary.largestQuadraticOnlyCounts=arrayfun(@(tolerance)leadingCount(errors<=tolerance),[.1 .03 .01]);
summary.scope="maximum over the selected individual source products; no full-survey count is implied";
summary.independentInteractionIndices=indices;
summary.limiting=cell(config.waveCount,1);
for count=1:config.waveCount
    r=limitingRow(count); pair=limitingPair(count);
    if r==0, summary.limiting{count}=struct(); continue; end
    row=loaded.rows(r,:); record=loaded.raw{r};
    vectors=table2array(loaded.inventory.interactions(row.interaction,1:6));
    summary.limiting{count}=struct(interaction=row.interaction,inputA=row.inputA,inputB=row.inputB,output=row.output,channel=row.channel,modeA=record.labelA(pair),signA=record.signA(pair),modeB=record.labelB(pair),signB=record.signB(pair),integerWavevectors=reshape(vectors,2,3).',error=errors(count));
end
writeResult(fullfile(outputDirectory,'cost-summary.json'),summary);
end

function count=leadingCount(passes)
first=find(~passes,1); if isempty(first), count=length(passes); else, count=first-1; end
end

function writeResult(path,value)
fid=fopen(path,'w'); if fid<0, error('WVStudy:OutputFailure','Cannot write %s.',path); end
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
