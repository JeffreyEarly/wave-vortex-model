classdef TestThermalCampaignResources < matlab.unittest.TestCase
    methods (TestClassSetup)
        function includeAuthoringTools(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
        end
    end
    methods (Test,TestTags="full")
        function missingMultiplierAndUnmeasuredOverheadsStayUnknown(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            source=fullfile(folder.Folder,'benchmark');mkdir(source);
            % The stored ratio is deliberately wrong: estimates must use the
            % measured numerator and denominator, and omit failed samples.
            integration=table([true;true;true],[1000;1000;1e9],[10;20;1],["complete";"wall-budget";"failed"],[999;999;999], ...
                VariableNames={'withOutput','simulatedSeconds','wallSeconds','status','simulatedSecondsPerWallSecond'});
            writetable(integration,fullfile(source,'integration.csv'));
            io=table(1100,100,10,VariableNames={'initialFileBytesIncludingFirstRecords','coefficientRecordPayloadBytes','scalarRecordPayloadBytes'});
            writetable(io,fullfile(source,'io.csv'));
            benchmark=struct(directory=string(source),forcingMultiplier=10,stateRegime="manufactured-control");
            report=estimateThermalCampaignResources(benchmark,fullfile(folder.Folder,'report'),years=1,seasonalPeriod=1000);
            rows=report.scenarios(report.scenarios.withOutput,:);
            measured=rows(rows.caseLabel=="M10",:);
            testCase.verifyEqual([measured.wallHoursMinimum measured.wallHoursMaximum],[10 20]/3600);
            testCase.verifyEqual([measured.coefficientRecords measured.scalarRecords],[49 385]);
            testCase.verifyEqual(measured.oneFilePayloadScenarioBytesMinimum,1100+48*100+384*10);
            testCase.verifyTrue(isnan(measured.allocatedByteScenarioMinimum));
            testCase.verifyTrue(isnan(measured.totalWallHoursIncludingUnmeasuredCosts));
            testCase.verifyTrue(isnan(measured.measuredStartupSubsetHoursMinimum));
            testCase.verifyTrue(isnan(measured.oneTimeConstructionHoursMinimum));
            testCase.verifyEqual(measured.startupMeasuredComponentCount,0);
            testCase.verifyEqual(measured.startupUnmeasuredComponentCount,4);
            testCase.verifyTrue(all(isnan(rows.wallHoursMinimum(rows.caseLabel~="M10"))));
            testCase.verifyTrue(all(rows.status=="CONDITIONAL"));
            testCase.verifyEqual(report.samples.included,[true;true;false]);
        end
        function serialCombinedCostsSumIndependentlyMeasuredCases(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            benchmarks=struct('directory',{},'forcingMultiplier',{},'stateRegime',{});
            for j=1:2
                source=fullfile(folder.Folder,"benchmark"+j);mkdir(source);
                integration=table(false,1000,10*j,"complete",VariableNames={'withOutput','simulatedSeconds','wallSeconds','status'});
                writetable(integration,fullfile(source,'integration.csv'));
                multiplier=[10 100];
                benchmarks(j)=struct(directory=string(source),forcingMultiplier=multiplier(j),stateRegime="manufactured-control");
            end
            report=estimateThermalCampaignResources(benchmarks,fullfile(folder.Folder,'report'),years=5,seasonalPeriod=1000);
            row=report.scenarios(report.scenarios.caseLabel=="M10+M100" & ~report.scenarios.withOutput,:);
            testCase.verifyEqual(row.wallHoursMinimum,(50+100)/3600,AbsTol=1e-15);
            testCase.verifyEqual(row.simulatedSeconds,10000);
            testCase.verifyEqual(row.caseCount,2);
            testCase.verifyEqual(row.coefficientRecords,2*(5*48+1));
        end
        function setupCostsAreSeparatedAndAddedOncePerCampaign(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            source=fullfile(folder.Folder,'benchmark');mkdir(source);
            integration=table([false;false;true;true],1000*ones(4,1),[10;10;12;12],repmat("complete",4,1),[0;0;7;9], ...
                VariableNames={'withOutput','simulatedSeconds','wallSeconds','status','outputSetupSeconds'});
            writetable(integration,fullfile(source,'integration.csv'));
            setup=table("known-setup",100,2,11,3,5,VariableNames={'caseId','constructionSeconds','restorationSeconds','initialStateWriteSeconds','integratorSetupSeconds','firstRhsSeconds'});
            writetable(setup,fullfile(source,'setup.csv'));
            % File restoration is distinct from the canonical constructor
            % timed before the repeated benchmark samples.
            io=table(13,VariableNames={'restorationSeconds'});
            writetable(io,fullfile(source,'io.csv'));
            benchmark=struct(directory=string(source),forcingMultiplier=10,stateRegime="manufactured-control");
            report=estimateThermalCampaignResources(benchmark,fullfile(folder.Folder,'report'),years=[1 5],seasonalPeriod=1000);
            rows=report.scenarios(report.scenarios.caseLabel=="M10",:);
            noOutput=rows(~rows.withOutput,:);
            testCase.verifyEqual(noOutput.measuredStartupSubsetHoursMinimum,[10;10]/3600,AbsTol=1e-15);
            testCase.verifyEqual(noOutput.integrationPlusMeasuredStartupHoursMinimum,[20;60]/3600,AbsTol=1e-15);
            withOutput=rows(rows.withOutput,:);
            testCase.verifyEqual(withOutput.measuredStartupSubsetHoursMinimum,[17;17]/3600,AbsTol=1e-15);
            testCase.verifyEqual(withOutput.measuredStartupSubsetHoursMaximum,[19;19]/3600,AbsTol=1e-15);
            testCase.verifyEqual(withOutput.integrationPlusMeasuredStartupHoursMinimum,[29;77]/3600,AbsTol=1e-15);
            testCase.verifyEqual(withOutput.startupMeasuredComponentCount,[4;4]);
            testCase.verifyEqual(withOutput.startupUnmeasuredComponentCount,[0;0]);
            testCase.verifyEqual(rows.oneTimeConstructionHoursMinimum,100*ones(4,1)/3600);
            testCase.verifyEqual(rows.initialStateSnapshotWriteHoursMinimum,11*ones(4,1)/3600);
            components=report.components;
            testCase.verifyEqual(components.minimum(components.component=="canonicalRestorationSeconds"),2);
            testCase.verifyEqual(components.minimum(components.component=="restorationSeconds"),13);
            testCase.verifyTrue(all(isnan(rows.totalWallHoursIncludingUnmeasuredCosts)));
        end
    end
end
