function comparison = compareDocumentationTrees(referenceFolder,candidateFolder)
arguments
    referenceFolder (1,1) string
    candidateFolder (1,1) string
end

referenceFiles = documentationFileInventory(referenceFolder);
candidateFiles = documentationFileInventory(candidateFolder);
comparison.Added = setdiff(candidateFiles,referenceFiles);
comparison.Removed = setdiff(referenceFiles,candidateFiles);

commonFiles = intersect(referenceFiles,candidateFiles);
modified = strings(0,1);
whitespaceOnly = strings(0,1);
substantive = strings(0,1);
for relativePath = commonFiles'
    referencePath = fullfile(referenceFolder,relativePath);
    candidatePath = fullfile(candidateFolder,relativePath);
    referenceBytes = readFileBytes(referencePath);
    candidateBytes = readFileBytes(candidatePath);
    if isequal(referenceBytes,candidateBytes)
        continue
    end
    modified(end+1,1) = relativePath;
    if isTextFile(relativePath) && equalWithoutWhitespace(referenceBytes,candidateBytes)
        whitespaceOnly(end+1,1) = relativePath;
    else
        substantive(end+1,1) = relativePath;
    end
end

comparison.Modified = modified;
comparison.WhitespaceOnly = whitespaceOnly;
comparison.Substantive = substantive;
comparison.IsEqual = isempty(comparison.Added) && isempty(comparison.Removed) && isempty(comparison.Modified);
end

function files = documentationFileInventory(rootFolder)
entries = dir(fullfile(rootFolder,"**","*"));
entries = entries(~[entries.isdir]);
entries = entries(string({entries.name}) ~= ".DS_Store");
files = strings(numel(entries),1);
rootPrefix = char(rootFolder + filesep);
for iEntry = 1:numel(entries)
    fullPath = fullfile(entries(iEntry).folder,entries(iEntry).name);
    files(iEntry) = replace(string(fullPath(numel(rootPrefix)+1:end)),filesep,"/");
end
files = sort(unique(files));
end

function bytes = readFileBytes(path)
fileID = fopen(path,"r");
if fileID < 0
    error("WaveVortexModel:DocumentationReadFailed","Unable to read %s.",path);
end
fileCleanup = onCleanup(@()fclose(fileID));
bytes = fread(fileID,Inf,"*uint8");
end

function tf = isTextFile(relativePath)
[~,~,extension] = fileparts(relativePath);
tf = ismember(lower(string(extension)),[".md" ".txt" ".yml" ".yaml" ".html" ".css" ".js" ".xml" ".bib"]);
end

function tf = equalWithoutWhitespace(firstBytes,secondBytes)
firstText = regexprep(char(firstBytes.'),'\s','');
secondText = regexprep(char(secondBytes.'),'\s','');
tf = isequal(firstText,secondText);
end
