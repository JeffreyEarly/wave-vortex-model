function build_website_documentation(options)
arguments
    options.rootDir = ""
end

repositoryRoot = documentationRepositoryRoot(options.rootDir);
validateClassDocumentationDependency();

destinationFolder = fullfile(repositoryRoot,"docs");
stagingRoot = string(tempname(fileparts(repositoryRoot)));
mkdir(stagingRoot);
stagingCleanup = onCleanup(@()removeFolderIfPresent(stagingRoot));
stagingFolder = fullfile(stagingRoot,"docs");

generateWebsiteDocumentation(repositoryRoot,stagingFolder);
validateWebsiteDocumentation(stagingFolder);

replaceDocumentationTree(stagingFolder,destinationFolder);
clear stagingCleanup
fprintf("Website documentation rebuilt at %s\n",destinationFolder);
end

function removeFolderIfPresent(folderPath)
if isfolder(folderPath)
    rmdir(folderPath,"s");
end
end
