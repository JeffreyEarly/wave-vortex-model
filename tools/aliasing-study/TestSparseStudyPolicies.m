classdef TestSparseStudyPolicies < matlab.unittest.TestCase
    methods (Test)
        function anUnseenFailureIsNotReportedAsSafe(testCase)
            [root,cleanup]=syntheticSurvey([.0001;.05;.2],[0;0;0],true); %#ok<ASGLU>
            scores=scoreSourcePolicies(root,fullfile(root,'scores'));
            selected=scores(scores.tolerance==.1,:);
            testCase.verifyTrue(all(selected.falseAcceptance==1))
            testCase.verifyEqual(selected.largestDenseCount,2*ones(3,1))
            testCase.verifyEqual(selected.largestSampledCount,3*ones(3,1))
            testCase.verifyEqual(double(selected.worstMissedError),.2*ones(3,1),AbsTol=1e-7)
            testCase.verifyTrue(all(strlength(selected.limitingInteraction)>0))
        end

        function linearCountLossIsSeparatedFromQuadraticLoss(testCase)
            [root,cleanup]=syntheticSurvey([.0001;.0002;.0003],[0;2e-7;5e-7],true); %#ok<ASGLU>
            scores=scoreSourcePolicies(root,fullfile(root,'scores'));
            testCase.verifyEqual(scores.largestDenseCount,3*ones(9,1))
            testCase.verifyEqual(scores.largestJointCount,ones(9,1))
            testCase.verifyEqual(scores.retainedCountLoss,2*ones(9,1))
            testCase.verifyEqual(scores.additionalQuadraticLoss,zeros(9,1))
        end

        function unstableReferencesRemainInconclusive(testCase)
            [root,cleanup]=syntheticSurvey([.0001;.05;.2],[0;0;0],false); %#ok<ASGLU>
            scores=scoreSourcePolicies(root,fullfile(root,'scores'));
            testCase.verifyTrue(all(scores.status=="inconclusive-reference"))
            testCase.verifyTrue(all(isnan(scores.falseAcceptance)))
            testCase.verifyTrue(all(isnan(scores.retainedCountLoss)))
        end

        function plannedStressesKeepExternalAndCutoffModes(testCase)
            [i,j]=ndgrid(1:16); i=i(:).'; j=j(:).';
            previous=false(size(i));
            for count=1:16
                mask=studyModePairMask(i,j,"wave","wave",count,"fixed");
                testCase.verifyTrue(all(mask(previous)))
                testCase.verifyTrue(mask(i==1 & j==count))
                testCase.verifyTrue(mask(i==count & j==count))
                testCase.verifyFalse(any(mask(i>count | j>count)))
                previous=mask;
            end
        end
    end
end

function [root,cleanup]=syntheticSurvey(errors,gram,stable)
root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
inventory=enumerateStudyInteractions([1e5 1e5],[8 8]);
pageDifficulty=zeros(length(inventory.magnitudes),1);
selection=selectStudyInteractions(inventory,pageDifficulty);
unseen=setdiff(1:height(inventory.interactions),selection.targeted);
interaction=unseen(1);
rows=table(interaction,"wave","wave","wave","u*dx(u)",VariableNames=["interaction","inputA","inputB","output","channel"]);
raw={struct(positionA=1,positionB=1,labelA=1,labelB=1,signA=1,signB=-1,error=single(errors),isZero=false)};
summary=struct(configuration=struct(waveCount=3,gramTolerance=1e-7),waveGram=gram,pageDifficulty=pageDifficulty,referencesStable=stable,fixedFamiliesGramAccepted=true);
save(fullfile(root,'products.mat'),'raw','rows','summary','inventory');
end
