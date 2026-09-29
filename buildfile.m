function plan = buildfile
import matlab.buildtool.Task
import matlab.buildtool.TaskGroup

tasks = [
    Task(Actions=@testSmokeTask,Description="Run the fast smoke test category.",DisableIncremental=true)
    Task(Actions=@testFullTask,Description="Run all non-optional, non-exhaustive tests.",DisableIncremental=true)
    Task(Actions=@testExhaustiveTask,Description="Run exhaustive numerical test matrices.",DisableIncremental=true)
    Task(Actions=@testOptionalTask,Description="Run tests that require optional dependencies.",DisableIncremental=true)
    ];

plan = buildplan;
plan("test") = TaskGroup(tasks,TaskNames=["smoke"; "full"; "exhaustive"; "optional"],Description="Run WaveVortexModel test categories.");
documentationTasks = [
    Task(Actions=@documentationBuildTask,Description="Build and transactionally replace committed documentation.",DisableIncremental=true)
    Task(Actions=@documentationCheckTask,Description="Verify committed documentation against a clean generated site.",DisableIncremental=true)
    ];
plan("docs") = TaskGroup(documentationTasks,TaskNames=["build"; "check"],Description="Build or verify website documentation.");
plan("analyze") = Task(Actions=@analyzeTask,Description="Analyze production MATLAB source for correctness findings.",DisableIncremental=true);
plan("kernel:contract") = Task(Actions=@kernelContractTask,Description="Build and run the portable C++ kernel contract tests.",DisableIncremental=true);
plan.DefaultTasks = "test:smoke";
end

function kernelContractTask(~)
repositoryRoot = fileparts(mfilename("fullpath"));
scriptPath = fullfile(repositoryRoot,"tools","compiled-kernel","run_contract_tests.sh");
[status,output] = system(sprintf('"%s"',scriptPath));
fprintf("%s",output);
if status ~= 0
    error("WaveVortexModel:KernelContractTestsFailed","Portable C++ kernel contract tests failed.");
end
end

function documentationBuildTask(~)
withToolsPath(@()build_website_documentation(rootDir=fileparts(mfilename("fullpath"))));
end

function documentationCheckTask(~)
withToolsPath(@()check_website_documentation(rootDir=fileparts(mfilename("fullpath"))));
end

function withToolsPath(action)
repositoryRoot = fileparts(mfilename("fullpath"));
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(fullfile(repositoryRoot,"tools"));
action();
clear pathCleanup
end

function analyzeTask(~)
repositoryRoot = fileparts(mfilename("fullpath"));
toolsFolder = fullfile(repositoryRoot,"tools");
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(toolsFolder);
analyzeProductionCode(repositoryRoot);
clear pathCleanup
end

function testSmokeTask(~)
runTestCategory("smoke","smoke");
end

function testFullTask(~)
runTestCategory("full",["smoke" "full"]);
end

function testExhaustiveTask(~)
runTestCategory("exhaustive","exhaustive");
end

function testOptionalTask(~)
runTestCategory("optional","optional");
end

function runTestCategory(categoryName,selectedTags)
repositoryRoot = fileparts(mfilename("fullpath"));
testFolder = fullfile(repositoryRoot,"UnitTests");
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
pathEntries = string(strsplit(path,pathsep));
if ~any(pathEntries == string(testFolder))
    addpath(testFolder);
end

addpath(fullfile(repositoryRoot,"tools"));
selectedSuite = discoverTestCategory(testFolder,selectedTags);

runner = testrunner("textoutput");
results = runner.run(selectedSuite);
passedCount = nnz([results.Passed]);
failedCount = nnz([results.Failed]);
incompleteCount = nnz([results.Incomplete]);
duration = sum([results.Duration]);
fprintf("\n%s test summary: total=%d, passed=%d, failed=%d, incomplete=%d, duration=%.3f s\n",categoryName,numel(results),passedCount,failedCount,incompleteCount,duration);

if failedCount > 0 || incompleteCount > 0
    error("WaveVortexModel:UnsuccessfulTestRun","The %s test category was unsuccessful: %d failed and %d incomplete.",categoryName,failedCount,incompleteCount);
end
clear pathCleanup
end
