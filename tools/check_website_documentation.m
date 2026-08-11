function comparison = check_website_documentation(options)
arguments
    options.rootDir = ""
end

repositoryRoot = documentationRepositoryRoot(options.rootDir);
validateClassDocumentationDependency();

stagingRoot = string(tempname(fileparts(repositoryRoot)));
mkdir(stagingRoot);
stagingCleanup = onCleanup(@()rmdir(stagingRoot,"s"));
stagingFolder = fullfile(stagingRoot,"docs");
generateWebsiteDocumentation(repositoryRoot,stagingFolder);
validateWebsiteDocumentation(stagingFolder);

comparison = compareDocumentationTrees(fullfile(repositoryRoot,"docs"),stagingFolder);
printComparison(comparison);
if ~comparison.IsEqual
    preserveDiagnostics(stagingFolder);
    error("WaveVortexModel:DocumentationOutOfDate","Committed documentation does not match a clean ClassDocumentation 1.3.2 build.");
end
clear stagingCleanup
end

function preserveDiagnostics(stagingFolder)
diagnosticFolder = string(getenv("WVM_DOCUMENTATION_DIAGNOSTIC_FOLDER"));
if diagnosticFolder == ""
    return
end
if isfolder(diagnosticFolder)
    error("WaveVortexModel:DocumentationDiagnosticExists","The documentation diagnostic folder already exists: %s",diagnosticFolder);
end
copyfile(stagingFolder,diagnosticFolder);
fprintf("Generated documentation diagnostics preserved at %s\n",diagnosticFolder);
end

function printComparison(comparison)
fprintf("Documentation comparison: added=%d, removed=%d, modified=%d, whitespace-only=%d, substantive=%d\n", ...
    numel(comparison.Added),numel(comparison.Removed),numel(comparison.Modified),numel(comparison.WhitespaceOnly),numel(comparison.Substantive));
printPaths("Added",comparison.Added);
printPaths("Removed",comparison.Removed);
printPaths("Whitespace-only",comparison.WhitespaceOnly);
printPaths("Substantive",comparison.Substantive);
end

function printPaths(label,paths)
if isempty(paths)
    return
end
fprintf("%s:\n  %s\n",label,strjoin(paths,newline + "  "));
end
