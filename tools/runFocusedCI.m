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
report = struct(schema="wvm-ci-matlab-v1",sourceCommit=string(selection.sourceCommit), ...
    matlabRelease=release,configuration=configuration,shard=shard,passed=false, ...
    requestedClasses={cell(0,1)},expectedTests={cell(0,1)},deferredMethods={selection.deferredMethods}, ...
    phases=struct(smoke=false,analyzer=false,documentation=false), ...
    phaseSeconds=struct,tests=struct(name={},passed={},incomplete={},seconds={}));
if configuration=="release"
    groups = selection.matlabShards;
    if shard==0
        started = tic; buildtool test:smoke; report.phaseSeconds.smoke = toc(started); report.phases.smoke = true;
    end
else
    groups = selection.sanitizedShards;
end
assert(shard<numel(groups) && groups(shard+1).id==shard,"WaveVortexModel:CIShard","Unselected CI test batch.");
classes = string(groups(shard+1).classes);
classes = reshape(classes,[],1);
report.requestedClasses = cellstr(classes);
suite = matlab.unittest.Test.empty;
for name = reshape(classes,1,[])
    testPath = fullfile(root,"UnitTests",name+".m");
    assert(isfile(testPath),"WaveVortexModel:CIMissingTest","Missing selected test class: %s",name);
    part = testsuite(testPath);
    deferred = ismember(string({part.Name}),string(selection.deferredMethods));
    part = part(~deferred);
    assert(~isempty(part),"WaveVortexModel:CIEmptyTest","No selected methods for %s",name);
    suite = [suite,part]; %#ok<AGROW>
end
if ~isempty(suite)
    [~,indices] = unique(string({suite.Name}),'stable'); suite = suite(indices);
    report.expectedTests = cellstr(string({suite.Name}));
    results = run(suite);
    for result = reshape(results,1,[])
        report.tests(end+1) = struct(name=string(result.Name),passed=result.Passed,incomplete=result.Incomplete,seconds=result.Duration);
    end
    writeReport(outputPath,report);
    assertSuccess(results);
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
