function diagnostics = scoreQuadraticDiagnostics(surveyDirectory,scoreDirectory,outputFile)
% Isolate sparse quadratic coverage from the more restrictive linear gate.
arguments
    surveyDirectory (1,1) string
    scoreDirectory (1,1) string
    outputFile (1,1) string
end
if isfile(outputFile), error('WVStudy:ExistingOutput','Preserve the existing diagnostic table.'); end
saved=load(fullfile(scoreDirectory,'scores.mat'),'errors','selection');
survey=load(fullfile(surveyDirectory,'products.mat'),'raw','rows','summary','inventory');
errors=saved.errors; selection=saved.selection; rows=survey.rows; raw=survey.raw;
policies=["linear","fixed","targeted"]; records=cell(9,1); index=0;
for tolerance=[.1 .03 .01]
    dense=countPassing(errors(:,1)<=tolerance);
    for p=1:3
        count=countPassing(errors(:,p+1)<=tolerance); worstMissed=0; limiting="";
        if count>0
            for r=1:height(rows)
                record=raw{r}; allowed=studyModePairMask(record.positionA,record.positionB,rows.inputA(r),rows.inputB(r),count,"dense");
                tested=false(size(allowed));
                if p>1 && ismember(rows.interaction(r),selection.(policies(p)))
                    tested=studyModePairMask(record.positionA,record.positionB,rows.inputA(r),rows.inputB(r),count,policies(p));
                end
                candidates=find(allowed & ~tested);
                if isempty(candidates), continue; end
                [value,j]=max(record.error(count,candidates));
                if value>worstMissed
                    worstMissed=double(value); pair=candidates(j);
                    vectors=table2array(survey.inventory.interactions(rows.interaction(r),1:6));
                    limiting=string(sprintf('%s mode %g sign %g [%d,%d] x %s mode %g sign %g [%d,%d] -> %s [%d,%d], %s',rows.inputA(r),record.labelA(pair),record.signA(pair),vectors(1),vectors(2),rows.inputB(r),record.labelB(pair),record.signB(pair),vectors(3),vectors(4),rows.output(r),vectors(5),vectors(6),rows.channel(r)));
                end
            end
        end
        status="diagnostic-linear-gate-ignored";
        falseAcceptance=count>0 && errors(count,1)>tolerance; loss=max(0,dense-count);
        if ~survey.summary.referencesStable, status="inconclusive-reference"; falseAcceptance=NaN; loss=NaN; end
        index=index+1;
        records{index}=struct(policy=policies(p),tolerance=tolerance,status=status,largestDenseQuadraticCount=dense,largestSampledQuadraticCount=count,falseAcceptance=falseAcceptance,retainedCountLoss=loss,worstMissedError=worstMissed,limitingInteraction=limiting);
    end
end
diagnostics=struct2table(vertcat(records{:})); writetable(diagnostics,outputFile);
disp(diagnostics(:,1:7))
end

function count=countPassing(passes)
first=find(~passes,1); if isempty(first), count=length(passes); else, count=first-1; end
end
