classdef TestFocusedCISelection < matlab.unittest.TestCase
    % Verify focused CI selection independently of numerical test execution.
    properties
        fixtureFolder
    end
    methods (TestMethodSetup)
        function createFixtures(testCase)
            testCase.fixtureFolder = string(tempname);
            mkdir(testCase.fixtureFolder);
            testCase.addTeardown(@()rmdir(testCase.fixtureFolder,"s"));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.fixtureFolder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename("fullpath"))),"tools")));
            testCase.writeFixture("TestCIParameterizedFixture",[
                "classdef TestCIParameterizedFixture < matlab.unittest.TestCase"
                "properties (TestParameter)"
                "value = {1,2};"
                "end"
                "methods (Test, TestTags={'smoke'})"
                "function baseline(testCase,value), testCase.verifyGreaterThan(value,0); end"
                "end"
                "methods (Test, TestTags={'full'})"
                "function focused(testCase), testCase.verifyTrue(true); end"
                "end"
                "end"]);
            testCase.writeFixture("TestCIExcludedFixture",[
                "classdef TestCIExcludedFixture < matlab.unittest.TestCase"
                "methods (Test, TestTags={'exhaustive'})"
                "function expensive(testCase), testCase.verifyTrue(true); end"
                "end"
                "end"]);
            testCase.writeFixture("TestCIResidualFixture",[
                "classdef TestCIResidualFixture < matlab.unittest.TestCase"
                "methods (Test, TestTags={'smoke'})"
                "function baseline(testCase), testCase.verifyTrue(true); end"
                "end"
                "end"]);
        end
    end
    methods (Test, TestTags={'full'})
        function smokeIsCompleteAndDeduplicated(testCase)
            selected = "TestCIParameterizedFixture";
            [suite,coverage] = selectFocusedCISuite(testCase.fixtureFolder,selected,selected,["optional","exhaustive"],strings(0,1),true);
            names = string({suite.Name});
            testCase.verifyEqual(numel(names),4);
            testCase.verifyEqual(numel(unique(names)),numel(names));
            testCase.verifyEqual(numel(coverage.smokeExpectedTests),3);
            testCase.verifyTrue(all(ismember(string(coverage.smokeExpectedTests),names)));
        end
        function otherBatchOwnsSelectedSmokeMethods(testCase)
            selected = "TestCIParameterizedFixture";
            [first,coverage] = selectFocusedCISuite(testCase.fixtureFolder,strings(0,1),selected,["optional","exhaustive"],strings(0,1),true);
            [second,other] = selectFocusedCISuite(testCase.fixtureFolder,selected,selected,["optional","exhaustive"],strings(0,1),false);
            names = [string({first.Name}),string({second.Name})];
            testCase.verifyEqual(numel(first),1);
            testCase.verifyEqual(numel(unique(names)),numel(names));
            testCase.verifyTrue(all(ismember(string(coverage.smokeExpectedTests),names)));
            testCase.verifyEmpty(other.smokeExpectedTests);
        end
        function exclusionsAndDeferredMethodsRemainExplicit(testCase)
            selected = ["TestCIParameterizedFixture","TestCIExcludedFixture"];
            [suite,coverage] = selectFocusedCISuite(testCase.fixtureFolder,selected,selected,["optional","exhaustive"],"TestCIParameterizedFixture/focused",false);
            testCase.verifyEqual(numel(suite),2);
            testCase.verifyEqual(string(coverage.excludedClasses),"TestCIExcludedFixture");
            testCase.verifyEqual(string(coverage.excludedTests),"TestCIExcludedFixture/expensive");
        end
        function smokeDiscoveryRejectsInvalidPrimaryTags(testCase)
            testCase.writeFixture("TestCIInvalidFixture",[
                "classdef TestCIInvalidFixture < matlab.unittest.TestCase"
                "methods (Test, TestTags={'smoke','full'})"
                "function invalid(testCase), testCase.verifyTrue(true); end"
                "end"
                "end"]);
            testCase.verifyError(@()discoverTestCategory(testCase.fixtureFolder,"smoke"),"WaveVortexModel:InvalidTestClassification");
        end
    end
    methods (Access=private)
        function writeFixture(testCase,name,lines)
            file = fopen(fullfile(testCase.fixtureFolder,name+".m"),"w");
            cleanup = onCleanup(@()fclose(file));
            fprintf(file,"%s\n",lines);
        end
    end
end
