function environment = setupDealiasingStudy(wvmRoot,internalModesRoot,dependencyRoot,chebfunRoot)
% Configure explicit authoring or released roots for the dealiasing study.
arguments (Input)
    wvmRoot (1,1) string
    internalModesRoot (1,1) string
    dependencyRoot (1,1) string
    chebfunRoot (1,1) string
end
arguments (Output)
    environment (1,1) struct
end
studyRoot = string(fileparts(mfilename('fullpath')));
restoredefaultpath;
roots = [fullfile(dependencyRoot,["ClassAnnotations-1.2.1","Distributions-2.0.0","SplineCore-2.2.0","NetCDF-1.0.2"]),chebfunRoot,internalModesRoot,wvmRoot];
for root = roots
    manifest = jsondecode(fileread(fullfile(root,"resources","mpackage.json")));
    folders = strings(1,numel(manifest.folders));
    for index = 1:numel(folders)
        folders(index) = fullfile(root,manifest.folders(index).path);
    end
    paths = cellstr([folders(isfolder(folders)),root]);
    addpath(paths{:});
end
addpath(studyRoot,fullfile(dependencyRoot,"tools","profiling"));
assert(startsWith(string(which('WVTransformFreeSurfaceBoussinesq')),wvmRoot+filesep),'The study resolved a different WVM root.');
assert(startsWith(string(which('IMSolverSpectral')),internalModesRoot+filesep),'The study resolved a different InternalModes root.');
environment = struct(matlabVersion=string(version),wvmRoot=wvmRoot,internalModesRoot=internalModesRoot,dependencyRoot=dependencyRoot,chebfunRoot=chebfunRoot);
end
