function configureCIEnvironment(sourceRoot,oceanKitRoot,options)
arguments
    sourceRoot (1,1) string {mustBeFolder}
    oceanKitRoot (1,1) string {mustBeFolder}
    options.documentationPackageSpecifier (1,1) string {mustBeMember(options.documentationPackageSpecifier,["","ClassDocumentation@1.3.2"])} = ""
end

% Routine CI loads the pinned package snapshots directly to minimize setup
% time. The release-verification workflow separately exercises native MPM
% installation from a clean MATLAB path on the R2025b compatibility floor.
snapshotNames = [
    "Distributions-2.0.0"
    "SplineCore-2.2.0"
    "chebfun-5.7.0"
    "InternalModes-1.3.0"
    "NetCDF-1.0.2"
    "ClassAnnotations-1.2.1"
    ];

if options.documentationPackageSpecifier ~= ""
    snapshotNames(end+1) = replace(options.documentationPackageSpecifier,"@","-");
end

for snapshotName = snapshotNames'
    addPackageSnapshotToPath(fullfile(oceanKitRoot,snapshotName));
end
addPackageSnapshotToPath(sourceRoot);
end

function addPackageSnapshotToPath(packageRoot)
manifestPath = fullfile(packageRoot,"resources","mpackage.json");
if ~isfile(manifestPath)
    error("WaveVortexModel:MissingCIPackageManifest","The CI package manifest is missing: %s",manifestPath);
end

manifest = jsondecode(fileread(manifestPath));
packagePaths = strings(numel(manifest.folders)+1,1);
nPackagePaths = 0;
if isstruct(manifest.folders)
    for iFolder = 1:numel(manifest.folders)
        packageFolder = fullfile(packageRoot,string(manifest.folders(iFolder).path));
        if isfolder(packageFolder)
            nPackagePaths = nPackagePaths + 1;
            packagePaths(nPackagePaths) = packageFolder;
        end
    end
end
nPackagePaths = nPackagePaths + 1;
packagePaths(nPackagePaths) = packageRoot;
packagePaths = packagePaths(1:nPackagePaths);
warningState = warning("query","MATLAB:mpath:uninstalledPackagesOnPath");
warningCleanup = onCleanup(@()warning(warningState));
warning("off","MATLAB:mpath:uninstalledPackagesOnPath");
addpath(strjoin(packagePaths,pathsep));
clear warningCleanup
fprintf("CI package: %s %s (%s)\n",string(manifest.name),string(manifest.version),packageRoot);
end
