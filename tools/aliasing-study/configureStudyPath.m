function provenance = configureStudyPath(oceanKitRoot)
% Configure only the pinned exported dependencies and this WVM authoring tree.
arguments (Input)
    oceanKitRoot (1,1) string
end
packages = ["ClassAnnotations-1.2.1","SplineCore-2.2.0","Distributions-2.0.0","chebfun-5.7.0","NetCDF-1.0.2","InternalModes-2.0.0-beta.2"];
studyRoot = string(fileparts(mfilename("fullpath")));
repositoryRoot = fileparts(fileparts(studyRoot));
for package = packages
    packageRoot = fullfile(oceanKitRoot,package);
    manifestPath = fullfile(packageRoot,"resources","mpackage.json");
    if ~isfile(manifestPath)
        error('WVStudy:MissingDependency','Missing pinned package manifest: %s',manifestPath)
    end
    manifest = jsondecode(fileread(manifestPath));
    addpath(packageRoot);
    for j = 1:numel(manifest.folders)
        addpath(fullfile(packageRoot,manifest.folders(j).path));
    end
end
addpath(repositoryRoot,studyRoot);
manifest = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for j = 1:numel(manifest.folders), addpath(fullfile(repositoryRoot,manifest.folders(j).path)); end
provenance = struct(wvmRevision=currentRevision(repositoryRoot),oceanKitRevision="5c2b41d2d4858f90756866f137002f18cb0ae1b6",internalModesRevision="c97f3ba50eb7ef67c8c3183cfcf6b7645783bbea",packages=packages,matlabVersion=string(version),computer=string(computer),internalModesPath=string(which('IMInternalModes')));
end

function revision = currentRevision(repositoryRoot)
originalDirectory = pwd;
directoryCleanup = onCleanup(@()cd(originalDirectory));
cd(repositoryRoot);
[status,value] = system('git rev-parse HEAD');
if status ~= 0
    error('WVStudy:MissingSourceRevision','Run the authoring study from a Git checkout so its source revision can be recorded.')
end
revision = strtrim(string(value));
end
