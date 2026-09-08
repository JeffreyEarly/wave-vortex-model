function scores = scoreSourcePolicies(surveyDirectory,outputDirectory)
% Replay all policies against the identical saved bounded-survey errors.
arguments
    surveyDirectory (1,1) string
    outputDirectory (1,1) string
end
if isfolder(outputDirectory), error('WVStudy:ExistingOutput','Choose a fresh scoring output directory.'); end
mkdir(outputDirectory);
loaded=load(fullfile(surveyDirectory,'products.mat'),'raw','rows','summary','inventory');
raw=loaded.raw; rows=loaded.rows; summary=loaded.summary; inventory=loaded.inventory;
config=summary.configuration; n=config.waveCount;
selection=selectStudyInteractions(inventory,summary.pageDifficulty(:));
policies=["linear","fixed","targeted"]; errors=zeros(n,4); evaluations=zeros(n,4);
limitingRow=zeros(n,4); limitingPair=zeros(n,4);
for r=1:height(rows)
    record=raw{r};
    for count=1:n
        denseMask=studyModePairMask(record.positionA,record.positionB,rows.inputA(r),rows.inputB(r),count,"dense");
        for policyIndex=1:4
            if policyIndex==1
                mask=denseMask;
            elseif policyIndex==2
                continue
            else
                policy=policies(policyIndex-1);
                if ~ismember(rows.interaction(r),selection.(policy)), continue; end
                mask=studyModePairMask(record.positionA,record.positionB,rows.inputA(r),rows.inputB(r),count,policy);
            end
            evaluations(count,policyIndex)=evaluations(count,policyIndex)+nnz(mask & ~record.isZero);
            candidates=find(mask);
            if isempty(candidates), continue; end
            [value,index]=max(record.error(count,candidates));
            if value>errors(count,policyIndex)
                errors(count,policyIndex)=value; limitingRow(count,policyIndex)=r; limitingPair(count,policyIndex)=candidates(index);
            end
        end
    end
end
linear=summary.waveGram(:)<=config.gramTolerance;
scoreRows=cell(9,1); r=0;
for tolerance=[.1 .03 .01]
    denseCount=acceptedCount(errors(:,1)<=tolerance);
    jointCount=acceptedCount(linear & errors(:,1)<=tolerance);
    for p=1:3
        r=r+1;
        count=acceptedCount(linear & errors(:,p+1)<=tolerance);
        status="scored";
        if ~summary.referencesStable, status="inconclusive-reference";
        elseif ~summary.fixedFamiliesGramAccepted, status="explicit-fixed-family-rejected"; end
        worstMissed=0; missedRow=0; missedPair=0;
        if count>0
            for j=1:height(rows)
                record=raw{j}; allowed=studyModePairMask(record.positionA,record.positionB,rows.inputA(j),rows.inputB(j),count,"dense");
                tested=false(size(allowed));
                if p>1 && ismember(rows.interaction(j),selection.(policies(p)))
                    tested=studyModePairMask(record.positionA,record.positionB,rows.inputA(j),rows.inputB(j),count,policies(p));
                end
                candidates=find(allowed & ~tested);
                if isempty(candidates), continue; end
                [value,index]=max(record.error(count,candidates));
                if value>worstMissed, worstMissed=value; missedRow=j; missedPair=candidates(index); end
            end
        end
        limiting=describeInteraction(missedRow,missedPair,raw,rows,inventory);
        scoreRows{r}=struct(policy=policies(p),tolerance=tolerance,status=status,largestDenseCount=denseCount,largestJointCount=jointCount,largestSampledCount=count,falseAcceptance=count>0 && errors(count,1)>tolerance,retainedCountLoss=max(0,denseCount-count),additionalQuadraticLoss=max(0,jointCount-count),worstMissedError=worstMissed,productEvaluations=evaluations(min(count+1,n),p+1),candidatePlanEvaluations=evaluations(n,p+1),densePlanEvaluations=evaluations(n,1),limitingInteraction=limiting);
        if status~="scored"
            scoreRows{r}.falseAcceptance=NaN;
            scoreRows{r}.retainedCountLoss=NaN;
            scoreRows{r}.additionalQuadraticLoss=NaN;
        end
    end
end
scores=struct2table(vertcat(scoreRows{:})); writetable(scores,fullfile(outputDirectory,'scores.csv'));
prefix=table((1:n).',summary.waveGram(:),errors(:,1),errors(:,3),errors(:,4),VariableNames=["waveCount","gramError","denseError","fixedError","targetedError"]);
writetable(prefix,fullfile(outputDirectory,'prefix-errors.csv'));
save(fullfile(outputDirectory,'scores.mat'),'scores','selection','prefix','errors','evaluations','limitingRow','limitingPair');
fid=fopen(fullfile(outputDirectory,'selection.json'),'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(selection,PrettyPrint=true));
disp(scores(:,1:8))
end

function count=acceptedCount(passes)
firstFailure=find(~passes,1);
if isempty(firstFailure), count=length(passes); else, count=firstFailure-1; end
end

function description=describeInteraction(r,p,raw,rows,inventory)
if r==0, description=""; return; end
vectors=table2array(inventory.interactions(rows.interaction(r),1:6));
record=raw{r};
description=sprintf('%s mode %g sign %g [%d,%d] x %s mode %g sign %g [%d,%d] -> %s [%d,%d], %s',rows.inputA(r),record.labelA(p),record.signA(p),vectors(1),vectors(2),rows.inputB(r),record.labelB(p),record.signB(p),vectors(3),vectors(4),rows.output(r),vectors(5),vectors(6),rows.channel(r));
end
