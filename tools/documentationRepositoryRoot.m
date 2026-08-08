function repositoryRoot = documentationRepositoryRoot(requestedRoot)
arguments
    requestedRoot = ""
end

requestedRoot = string(requestedRoot);
if requestedRoot == ""
    repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
else
    repositoryRoot = requestedRoot;
end

if ~isscalar(repositoryRoot) || ~isfolder(repositoryRoot)
    error("WaveVortexModel:InvalidDocumentationRoot","The documentation repository root does not exist: %s",repositoryRoot);
end
repositoryRoot = string(java.io.File(repositoryRoot).getCanonicalPath());
end
