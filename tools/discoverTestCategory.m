function selectedSuite = discoverTestCategory(testFolder,selectedTags)
% Discover a category and validate every formal method's primary tag.
arguments (Input)
    testFolder (1,1) string {mustBeFolder}
    selectedTags (1,:) string
end
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(testFolder);
folderSuite = matlab.unittest.TestSuite.fromFolder(testFolder,IncludingSubfolders=true);
rejectAccidentalScriptTests(folderSuite);
suite = formalTestSuite(testFolder);
[expectedPairs,discoveredPairs,selectedSuite] = validateTestDiscovery(testFolder,suite,selectedTags);

missingPairs = setdiff(expectedPairs,discoveredPairs);
unexpectedPairs = setdiff(discoveredPairs,expectedPairs);
if ~isempty(missingPairs) || ~isempty(unexpectedPairs)
    details = discoveryDifferenceDetails(missingPairs,unexpectedPairs);
    error("WaveVortexModel:TestDiscoveryFailed","The %s test category did not match its declared test methods.%s",strjoin(selectedTags,","),details);
end
if isempty(selectedSuite)
    error("WaveVortexModel:EmptyTestCategory","No tests were discovered for the %s category.",strjoin(selectedTags,","));
end

end

function suite = formalTestSuite(testFolder)
testFiles = dir(fullfile(testFolder,"Test*.m"));
classSuites = cell(numel(testFiles),1);
for iFile = 1:numel(testFiles)
    className = erase(string(testFiles(iFile).name),".m");
    testClass = meta.class.fromName(className);
    if isempty(testClass) || ~isTestCaseClass(testClass)
        error("WaveVortexModel:InvalidFormalTest","%s must define a matlab.unittest.TestCase class named %s.",testFiles(iFile).name,className);
    end
    classSuites{iFile} = matlab.unittest.TestSuite.fromClass(testClass);
end
suite = [classSuites{:}];
end

function rejectAccidentalScriptTests(suite)
discoveredClassNames = string({suite.TestClass});
if any(discoveredClassNames == "")
    accidentalNames = unique(string({suite(discoveredClassNames == "").Name}));
    error("WaveVortexModel:AccidentalScriptTests","UnitTests discovery found script-based tests: %s",strjoin(accidentalNames,", "));
end
end

function [expectedPairs,discoveredPairs,selectedSuite] = validateTestDiscovery(testFolder,suite,selectedTags)
primaryTags = ["smoke" "full" "exhaustive" "optional"];
testFiles = dir(fullfile(testFolder,"Test*.m"));
expectedPairsByFile = cell(numel(testFiles),1);

for iFile = 1:numel(testFiles)
    className = erase(string(testFiles(iFile).name),".m");
    testClass = meta.class.fromName(className);
    if isempty(testClass) || ~isTestCaseClass(testClass)
        error("WaveVortexModel:InvalidFormalTest","%s must define a matlab.unittest.TestCase class named %s.",testFiles(iFile).name,className);
    end

    testMethods = testClass.MethodList.findobj("Test",true);
    if isempty(testMethods)
        error("WaveVortexModel:InvalidFormalTest","%s does not declare any test methods.",className);
    end
    selectedMethodPairs = strings(numel(testMethods),1);
    nSelectedMethods = 0;
    for iMethod = 1:numel(testMethods)
        methodTags = string(testMethods(iMethod).TestTags);
        validatePrimaryTags(className,testMethods(iMethod).Name,methodTags,primaryTags);
        if any(ismember(methodTags,selectedTags))
            nSelectedMethods = nSelectedMethods + 1;
            selectedMethodPairs(nSelectedMethods) = className + "/" + testMethods(iMethod).Name;
        end
    end
    expectedPairsByFile{iFile} = selectedMethodPairs(1:nSelectedMethods);
end
nonemptyExpectedPairs = expectedPairsByFile(~cellfun(@isempty,expectedPairsByFile));
if isempty(nonemptyExpectedPairs)
    expectedPairs = strings(0,1);
else
    expectedPairs = vertcat(nonemptyExpectedPairs{:});
end

discoveredClassNames = string({suite.TestClass});
discoveredMethodNames = string({suite.ProcedureName});

selectedMask = false(size(suite));
for iTest = 1:numel(suite)
    testTags = string(suite(iTest).Tags);
    validatePrimaryTags(discoveredClassNames(iTest),discoveredMethodNames(iTest),testTags,primaryTags);
    selectedMask(iTest) = any(ismember(testTags,selectedTags));
end

selectedSuite = suite(selectedMask);
discoveredPairs = unique(discoveredClassNames(selectedMask) + "/" + discoveredMethodNames(selectedMask));
expectedPairs = unique(expectedPairs);
end

function validatePrimaryTags(className,methodName,testTags,primaryTags)
matchingTags = intersect(testTags,primaryTags);
if numel(matchingTags) ~= 1
    error("WaveVortexModel:InvalidTestClassification","%s/%s must declare exactly one primary test tag from %s; found %s.",className,methodName,strjoin(primaryTags,", "),strjoin(matchingTags,", "));
end
end

function tf = isTestCaseClass(testClass)
tf = testClass.Name == "matlab.unittest.TestCase";
if tf
    return
end
for superclass = testClass.SuperclassList'
    if isTestCaseClass(superclass)
        tf = true;
        return
    end
end
end

function details = discoveryDifferenceDetails(missingPairs,unexpectedPairs)
details = "";
if ~isempty(missingPairs)
    details = details + newline + "Missing: " + strjoin(missingPairs,", ");
end
if ~isempty(unexpectedPairs)
    details = details + newline + "Unexpected: " + strjoin(unexpectedPairs,", ");
end
end
