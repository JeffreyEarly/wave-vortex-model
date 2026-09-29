function report = runFocusedCI(selectionPath,binaryDirectory,outputPath,configuration,shard)
% Run the resolved CI suite using the exact-revision portable binary artifact.
% The caller configures pinned dependencies before entering this function.
arguments (Input)
    selectionPath (1,1) string
    binaryDirectory (1,1) string
    outputPath (1,1) string
    configuration (1,1) string {mustBeMember(configuration,["release","sanitized"])} = "release"
    shard (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end
arguments (Output)
    report (1,1) struct
end
root = string(fileparts(fileparts(mfilename("fullpath"))));
selection = jsondecode(fileread(selectionPath));
originalPath = path; pathCleanup = onCleanup(@()path(originalPath));
addpath(fullfile(root,"UnitTests"));
release = "R"+string(version("-release"));
assert(ismember(release,string(selection.releases)),"WaveVortexModel:CIRelease","Unselected MATLAB release.");
[status,commit] = system("git rev-parse HEAD");
assert(status==0 && strtrim(string(commit))==string(selection.sourceCommit),"WaveVortexModel:CISource","CI selection belongs to a different source revision.");
names = ["WVM_CI_BINARY_DIR","WV_STABLE_FORCING_RUNNER","WV_STABLE_FORCING_DUMP","WV_MODAL_DUMP_EXECUTABLE","WV_QG_KERNEL_DUMP","WV_HYDRO_KERNEL_DUMP","WV_BOUSS_KERNEL_DUMP","WV_DIAGNOSTIC_DUMP"];
executables = ["","wave-vortex-run","WVStableForcingDump","WVStratifiedModalDump","WVStratifiedQGKernelDump","WVHydrostaticKernelDump","WVBoussinesqKernelDump","WVDiagnosticFieldDump"];
previous = arrayfun(@(name)string(getenv(name)),names);
environmentCleanup = onCleanup(@()restoreEnvironment(names,previous));
if binaryDirectory ~= ""
    for index = 1:numel(names)
        value = fullfile(binaryDirectory,executables(index));
        if index>1, assert(isfile(value),"WaveVortexModel:CIArtifact","Missing CI probe: %s",value); end
        setenv(names(index),value);
    end
end
assert(string(selection.schema)=="wvm-ci-selection-v2","WaveVortexModel:CISelection","Unsupported CI selection format.");
report = struct(schema="wvm-ci-matlab-v2",sourceCommit=string(selection.sourceCommit), ...
    matlabRelease=release,configuration=configuration,shard=shard,passed=false, ...
    requestedClasses={cell(0,1)},expectedTests={cell(0,1)},smokeExpectedTests={cell(0,1)},deferredMethods={selection.deferredMethods}, ...
    excludedTags={selection.excludedTags},excludedTests={cell(0,1)},excludedClasses={cell(0,1)}, ...
    phases=struct(smoke=false,analyzer=false,documentation=false), ...
    phaseSeconds=struct,tests=struct(name={},passed={},incomplete={},seconds={}));
if configuration=="release"
    assert(selection.matlab,"WaveVortexModel:CISelection","MATLAB was not selected.");
    groups = selection.matlabShards;
else
    assert(selection.sanitized,"WaveVortexModel:CISelection","Sanitized MATLAB was not selected.");
    groups = selection.sanitizedShards;
end
assert(shard<numel(groups) && groups(shard+1).id==shard,"WaveVortexModel:CIShard","Unselected CI test batch.");
classes = reshape(string(groups(shard+1).classes),[],1);
report.requestedClasses = cellstr(classes);
report.phases.smoke = configuration=="release" && shard==0 && selection.smoke;
[suite,coverage] = selectFocusedCISuite(fullfile(root,"UnitTests"),classes,string(selection.matlabTests), ...
    string(selection.excludedTags),string(selection.deferredMethods),report.phases.smoke);
report.excludedTests = coverage.excludedTests;
report.excludedClasses = coverage.excludedClasses;
report.smokeExpectedTests = coverage.smokeExpectedTests;
if ~isempty(suite)
    report.expectedTests = cellstr(string({suite.Name}));
    results = run(suite);
    for result = reshape(results,1,[])
        report.tests(end+1) = struct(name=string(result.Name),passed=result.Passed,incomplete=result.Incomplete,seconds=result.Duration);
    end
    writeReport(outputPath,report);
    assertSuccess(results);
    assert(all([results.Passed]) && ~any([results.Incomplete]),"WaveVortexModel:CIIncomplete","Every selected CI test must pass without an assumption failure.");
end
if configuration=="release" && release=="R2025b" && shard==0
    if selection.analyzer
        started = tic; buildtool analyze; report.phaseSeconds.analyzer = toc(started); report.phases.analyzer = true;
    end
    if selection.documentation
        started = tic; buildtool docs:check; report.phaseSeconds.documentation = toc(started); report.phases.documentation = true;
    end
end
report.passed = true;
writeReport(outputPath,report);
end

function restoreEnvironment(names,values)
for index=1:numel(names), setenv(names(index),values(index)); end
end
function writeReport(path,value)
file = fopen(path,"w");
assert(file>=0,"WaveVortexModel:CIReport","Cannot write CI report: %s",path);
cleanup = onCleanup(@()fclose(file));
fprintf(file,"%s\n",jsonencode(value,PrettyPrint=true));
end
