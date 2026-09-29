function [suite,coverage] = selectFocusedCISuite(testFolder,classes,allSelectedClasses,excludedTags,deferredMethods,includeSmoke)
% Merge the focused class methods with a validated smoke baseline exactly once.
arguments (Input)
    testFolder (1,1) string {mustBeFolder}
    classes string
    allSelectedClasses string
    excludedTags string
    deferredMethods string
    includeSmoke (1,1) logical
end
coverage = struct(excludedTests={cell(0,1)},excludedClasses={cell(0,1)},smokeExpectedTests={cell(0,1)});
suite = matlab.unittest.Test.empty;
for name = reshape(classes,1,[])
    testPath = fullfile(testFolder,name+".m");
    assert(isfile(testPath),"WaveVortexModel:CIMissingTest","Missing selected test class: %s",name);
    part = testsuite(testPath);
    assert(~isempty(part),"WaveVortexModel:CIEmptyTest","No test methods discovered for %s",name);
    originalNames = string({part.Name});
    for tag = reshape(excludedTags,1,[])
        part = part.selectIf(~matlab.unittest.selectors.HasTag(tag));
    end
    excluded = originalNames(~ismember(originalNames,string({part.Name})));
    coverage.excludedTests = [coverage.excludedTests;reshape(cellstr(excluded),[],1)];
    if isempty(part)
        coverage.excludedClasses{end+1,1} = char(name);
        continue
    end
    deferred = ismember(string({part.Name}),deferredMethods);
    part = part(~deferred);
    assert(~isempty(part),"WaveVortexModel:CIEmptyTest","No selected methods for %s",name);
    suite = [suite,part]; %#ok<AGROW>
end

if includeSmoke
    smokeSuite = discoverTestCategory(testFolder,"smoke");
    coverage.smokeExpectedTests = cellstr(string({smokeSuite.Name}));
    % Classes selected in other batches own their smoke methods there.
    smokeSuite = smokeSuite(~ismember(string({smokeSuite.TestClass}),allSelectedClasses));
    suite = [suite,smokeSuite];
end
if ~isempty(suite)
    [~,indices] = unique(string({suite.Name}),'stable');
    suite = suite(indices);
end
end
