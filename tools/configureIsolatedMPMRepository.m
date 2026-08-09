function repository = configureIsolatedMPMRepository(oceanKitRoot)
%CONFIGUREISOLATEDMPMREPOSITORY Use one local OceanKit repository for MPM.
arguments
    oceanKitRoot (1,1) string {mustBeFolder}
end

repositories = mpmListRepositories;
if ~isempty(repositories)
    mpmRemoveRepository(repositories);
end
repository = mpmAddRepository("OceanKit",oceanKitRoot,Position="beginning");

repositories = mpmListRepositories;
if numel(repositories) ~= 1 || string(repositories.Name) ~= "OceanKit" || ...
        canonicalPath(string(repositories.Location)) ~= canonicalPath(oceanKitRoot)
    error("WaveVortexModel:PackageVerificationFailed", ...
        "Package verification requires the pinned OceanKit checkout to be the only MPM repository.");
end
end

function path = canonicalPath(path)
path = string(java.io.File(char(path)).getCanonicalPath());
end
