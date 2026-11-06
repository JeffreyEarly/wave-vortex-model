function verifyAPVProviderIntegration(sourceRoot,oceanKitRoot,providerRoot,mode)
% Use the same regression test file with beta.9 and with the proposed fix.
arguments
    sourceRoot (1,1) string {mustBeFolder}
    oceanKitRoot (1,1) string {mustBeFolder}
    providerRoot (1,1) string {mustBeFolder}
    mode (1,1) string {mustBeMember(mode,["baseline","provider"])}
end

addpath(fullfile(sourceRoot,"tools"));
configureCIEnvironment(sourceRoot,oceanKitRoot);
snapshotRoot = fullfile(oceanKitRoot,"InternalModes-2.0.0-beta.9");
expectedRoot = snapshotRoot;
if mode == "provider"
    paths = string(split(path,pathsep));
    snapshotPaths = paths(paths==snapshotRoot | startsWith(paths,snapshotRoot+filesep));
    rmpath(strjoin(snapshotPaths,pathsep));
    addpath(providerRoot,"-begin");
    expectedRoot = providerRoot;
end
solverPath = string(which("IMSolverSpectral"));
assert(startsWith(solverPath,expectedRoot+filesep),"Unexpected InternalModes solver at %s.",solverPath)
fprintf("MATLAB %s on %s\nSolver: %s\n",version,computer,solverPath)

providerTests = fullfile(providerRoot,"UnitTestsV2");
addpath(providerTests,"-begin");
result = runOne(fullfile(providerTests,"IMHighResolutionAPVTests.m"), ...
    "IMHighResolutionAPVTests/linuxRefinementRetainsFiniteSignedAPVModes");
if mode == "baseline"
    assert(result.Failed,"The Linux APV regression unexpectedly passed with beta.9.")
    fprintf("Observed the expected beta.9 regression failure.\n")
    return
end
assertSuccess(result);

confirmAPVFailure(requireSuccess=true)
result = runOne(fullfile(sourceRoot,"UnitTests","TestFreeSurfaceResolutionTransfer.m"), ...
    "TestFreeSurfaceResolutionTransfer/pureFamiliesAndStrictRequests");
assertSuccess(result);
end

function result = runOne(testFile,testName)
suite = matlab.unittest.TestSuite.fromFile(testFile);
suite = suite(string({suite.Name})==testName);
assert(isscalar(suite),"Expected exactly one test named %s.",testName)
result = run(suite);
end
