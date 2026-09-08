function provenance = configureStudyPath(oceanKitRoot)
% Configure only the pinned exported dependencies and this WVM authoring tree.
arguments (Input)
    oceanKitRoot (1,1) string
end
packages = ["ClassAnnotations-1.2.1","SplineCore-2.2.0","Distributions-2.0.0","chebfun-5.7.0","NetCDF-1.0.2","InternalModes-2.0.0-beta.1"];
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
provenance = struct(wvmRevision="9fefcc9a528de65e2f348706c45b13f741754a78",oceanKitRevision="80006f5040da787465860249f975def9831624c8",internalModesRevision="4086f978b36a4100e7419688ab355591c8253ef1",packages=packages,matlabVersion=string(version),computer=string(computer),internalModesPath=string(which('IMInternalModes')));
end
