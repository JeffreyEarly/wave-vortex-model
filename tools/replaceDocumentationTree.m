function replaceDocumentationTree(stagingFolder,destinationFolder)
arguments
    stagingFolder (1,1) string
    destinationFolder (1,1) string
end

backupFolder = string(tempname(fileparts(destinationFolder)));
hadExistingDestination = isfolder(destinationFolder);
if hadExistingDestination
    moveFolder(destinationFolder,backupFolder);
end

try
    moveFolder(stagingFolder,destinationFolder);
catch exception
    removeFolderIfPresent(destinationFolder);
    if hadExistingDestination && isfolder(backupFolder)
        moveFolder(backupFolder,destinationFolder);
    end
    rethrow(exception)
end

removeFolderIfPresent(backupFolder);
end

function moveFolder(sourceFolder,destinationFolder)
source = java.io.File(char(sourceFolder));
destination = java.io.File(char(destinationFolder));
if ~source.renameTo(destination)
    error("WaveVortexModel:DocumentationMoveFailed","Unable to move %s to %s.",sourceFolder,destinationFolder);
end
end

function removeFolderIfPresent(folderPath)
if isfolder(folderPath)
    rmdir(folderPath,"s");
end
end
