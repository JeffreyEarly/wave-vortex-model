function generateWebsiteDocumentation(repositoryRoot,buildFolder)
arguments
    repositoryRoot (1,1) string
    buildFolder (1,1) string
end

sourceFolder = fullfile(repositoryRoot,"Documentation","WebsiteDocumentation");
rebuildWebsiteDocumentationFromSource(sourceFolder,buildFolder);
writeVersionHistory(repositoryRoot,buildFolder);

classFolderName = "Class documentation";
transformSidecars = fullfile(repositoryRoot,"@WVTransform","detailedDescriptions");
forcingSidecars = fullfile(repositoryRoot,"Forcing","detailedDescriptions");

parentName = "Transforms";
websiteFolder = "classes/transforms";
writeClassDocumentation("WVTransform",buildFolder,websiteFolder,parentName,classFolderName,parentName,1,{'handle','CAAnnotatedClass'},transformSidecars);
classes = ["WVTransformBoussinesq" "WVTransformHydrostatic" "WVTransformConstantStratification" "WVTransformBarotropicQG" "WVTransformStratifiedQG"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,classFolderName,parentName,2,{'handle','WVTransform','CAAnnotatedClass'},transformSidecars);

writeClassDocumentation("WVModel",buildFolder,"classes",classFolderName,"",classFolderName,2,{'handle'},string.empty(0,1));

parentName = "Forcing";
websiteFolder = "classes/forcing";
writeClassDocumentation("WVForcing",buildFolder,websiteFolder,parentName,"",parentName,1,{'handle','CAAnnotatedClass','matlab.mixin.Heterogeneous'},forcingSidecars);
classes = ["WVNonlinearAdvection" "WVBottomFrictionLinear" "WVBottomFrictionQuadratic" "WVFixedAmplitudeForcing" "WVBetaPlanePVAdvection" "WVPseudoTopographicWaveGeneration"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,classFolderName,parentName,2,{'handle','WVForcing','CAAnnotatedClass','matlab.mixin.Heterogeneous'},forcingSidecars);

parentName = "Closures";
websiteFolder = "classes/forcing/closures";
classes = ["WVAdaptiveDamping" "WVVerticalDiffusivity" "WVHorizontalDamping" "WVVerticalDamping" "WVThermalDamping" "WVAntialiasing"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,"Forcing",parentName,1,{'handle','WVForcing','CAAnnotatedClass','matlab.mixin.Heterogeneous'},forcingSidecars);

parentName = "Model output";
websiteFolder = "classes/model-output";
classes = ["WVModelOutputFile" "WVModelOutputGroup"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,classFolderName,parentName,1,{'handle','CAAnnotatedClass','matlab.mixin.Heterogeneous'},string.empty(0,1));
writeClassDocumentation("WVModelOutputGroupEvenlySpaced",buildFolder,websiteFolder,parentName,classFolderName,parentName,3,{'handle','WVModelOutputGroup','CAAnnotatedClass','matlab.mixin.Heterogeneous'},string.empty(0,1));

parentName = "Observing systems";
websiteFolder = "classes/observing-systems";
writeClassDocumentation("WVObservingSystem",buildFolder,websiteFolder,parentName,classFolderName,parentName,1,{'handle','CAAnnotatedClass','matlab.mixin.Heterogeneous'},string.empty(0,1));
classes = ["WVEulerianFields" "WVLagrangianParticles" "WVTracer" "WVMooring" "WVCoefficients"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,classFolderName,parentName,2,{'handle','WVObservingSystem','CAAnnotatedClass','matlab.mixin.Heterogeneous'},string.empty(0,1));

parentName = "Operations & annotations";
websiteFolder = "classes/operations-and-annotations";
classes = ["WVOperation" "WVVariableAnnotation"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,classFolderName,parentName,1,{'handle'},string.empty(0,1));

parentName = "Flow components";
websiteFolder = "classes/flow-components";
writeClassDocumentation("WVFlowComponent",buildFolder,websiteFolder,parentName,classFolderName,parentName,1,{'handle'},string.empty(0,1));
classes = ["WVPrimaryFlowComponent" "WVTotalFlowComponent" "WVGeostrophicComponent" "WVInternalGravityWaveComponent" "WVInertialOscillationComponent" "WVMeanDensityAnomalyComponent"];
writeClassGroup(classes,buildFolder,websiteFolder,parentName,classFolderName,parentName,2,{'handle','WVFlowComponent'},string.empty(0,1));
end

function writeVersionHistory(repositoryRoot,buildFolder)
changelogPath = fullfile(repositoryRoot,"CHANGELOG.md");
if ~isfile(changelogPath)
    return
end

header = "---" + newline + ...
    "layout: default" + newline + ...
    "title: Version History" + newline + ...
    "nav_order: 100" + newline + ...
    "---" + newline + newline;
versionHistoryPath = fullfile(buildFolder,"version-history.md");
fileID = fopen(versionHistoryPath,"w");
if fileID < 0
    error("WaveVortexModel:DocumentationWriteFailed","Unable to write %s.",versionHistoryPath);
end
fileCleanup = onCleanup(@()fclose(fileID));
fwrite(fileID,header + fileread(changelogPath));
clear fileCleanup
end

function writeClassGroup(classes,buildFolder,websiteFolder,parent,grandparent,methodGrandparent,firstNavOrder,excludedSuperclasses,sidecarFolders)
for iClass = 1:numel(classes)
    writeClassDocumentation(classes(iClass),buildFolder,websiteFolder,parent,grandparent,methodGrandparent,firstNavOrder+iClass-1,excludedSuperclasses,sidecarFolders);
end
end

function writeClassDocumentation(className,buildFolder,websiteFolder,parent,grandparent,methodGrandparent,navOrder,excludedSuperclasses,sidecarFolders)
options = { ...
    "buildFolder",buildFolder, ...
    "websiteFolder",websiteFolder, ...
    "parent",parent, ...
    "methodGrandparent",methodGrandparent, ...
    "nav_order",navOrder, ...
    "excludedSuperclasses",excludedSuperclasses, ...
    "shouldLoadDetailedDescriptionSidecars",false ...
    };
if grandparent ~= ""
    options = [options {"grandparent",grandparent}];
end
documentation = ClassDocumentation(className,options{:});
normalizeReflectedDocumentation(documentation);
mergeCanonicalSidecars(documentation,sidecarFolders);
applyDocumentationTaxonomy(documentation);
documentation.writeToFile();
normalizeGeneratedMarkdown(documentation.pathOfClassFolderOnHardDrive);
end

function normalizeReflectedDocumentation(documentation)
% MATLAB releases expose help-text indentation differently through the
% metaclass API. Normalize it before ClassDocumentation writes Markdown so
% one source tree produces the same documentation on every supported release.
classMetadata = meta.class.fromName(documentation.name);
classDescription = ClassDocumentation.trimDeclarationFromString(classMetadata.DetailedDescription);
classDescription = Topic.trimTopicsFromString(classDescription);
documentation.detailedDescription = regexprep(removeCommonIndent(classDescription),'(?:\r?\n){3,}','\n\n');

for iMethod = 1:numel(documentation.allMethodDocumentation)
    methodDocumentation = documentation.allMethodDocumentation(iMethod);
    methodDocumentation.detailedDescription = normalizedReflectedDescription(classMetadata,methodDocumentation);
    if string(methodDocumentation.name) == documentation.name && ...
            ~isempty(methodDocumentation.detailedDescription) && ...
            (constructorUsesClassHelp(classMetadata) || ...
            isequal(strtrim(string(methodDocumentation.detailedDescription)),strtrim(string(documentation.detailedDescription))))
        % R2024b exposes the class help as constructor help when the
        % constructor has no help block. Newer releases leave it empty.
        methodDocumentation.shortDescription = [];
        methodDocumentation.detailedDescription = [];
        methodDocumentation.declaration = [];
    end
end
end

function tf = constructorUsesClassHelp(classMetadata)
tf = false;
methodMetadata = classMetadata.MethodList;
for iMetadata = 1:numel(methodMetadata)
    item = methodMetadata(iMetadata);
    if string(item.Name) ~= string(classMetadata.Name) || isempty(item.DetailedDescription)
        continue
    end
    constructorHelp = regexprep(strtrim(char(item.DetailedDescription)),'\s+',' ');
    classHelp = regexprep(strtrim(char(classMetadata.DetailedDescription)),'\s+',' ');
    tf = strcmp(constructorHelp,classHelp);
    return
end
end

function description = normalizedReflectedDescription(classMetadata,methodDocumentation)
description = methodDocumentation.detailedDescription;
if isempty(description)
    return
end
methodMetadata = classMetadata.MethodList;
for iMetadata = 1:numel(methodMetadata)
    item = methodMetadata(iMetadata);
    if string(item.Name) == string(methodDocumentation.name) && ...
            string(item.DefiningClass.Name) == string(methodDocumentation.definingClassName)
        normalizedMetadata = MethodDocumentation(methodDocumentation.name);
        normalizedMetadata.addMetadataFromDetailedDescription(char(removeCommonIndent(item.DetailedDescription)));
        if descriptionsDifferOnlyByIndent(description,normalizedMetadata.detailedDescription)
            description = normalizedMetadata.detailedDescription;
        else
            description = removeCommonIndent(description);
        end
        return
    end
end
propertyMetadata = classMetadata.PropertyList;
for iMetadata = 1:numel(propertyMetadata)
    item = propertyMetadata(iMetadata);
    if string(item.Name) == string(methodDocumentation.name) && ...
            string(item.DefiningClass.Name) == string(methodDocumentation.definingClassName)
        normalizedMetadata = MethodDocumentation(methodDocumentation.name);
        normalizedMetadata.addMetadataFromDetailedDescription(char(removeCommonIndent(item.DetailedDescription)));
        if descriptionsDifferOnlyByIndent(description,normalizedMetadata.detailedDescription)
            description = normalizedMetadata.detailedDescription;
        else
            description = removeCommonIndent(description);
        end
        return
    end
end
description = removeCommonIndent(methodDocumentation.detailedDescription);
end

function tf = descriptionsDifferOnlyByIndent(first,second)
if isempty(first) || isempty(second)
    tf = false;
    return
end
first = regexprep(char(first),'\r\n?','\n');
second = regexprep(char(second),'\r\n?','\n');
first = regexprep(first,'^[ \t]+','','lineanchors');
second = regexprep(second,'^[ \t]+','','lineanchors');
tf = strcmp(strtrim(first),strtrim(second));
end

function text = removeCommonIndent(text)
lines = splitlines(string(text));
nonblankLines = strlength(strtrim(lines)) > 0;
if ~any(nonblankLines)
    text = join(lines,newline);
    return
end

leadingWhitespace = zeros(sum(nonblankLines),1);
nonblankIndices = find(nonblankLines);
for iLine = 1:numel(nonblankIndices)
    line = char(lines(nonblankIndices(iLine)));
    match = regexp(line,'^[ \t]*','match','once');
    leadingWhitespace(iLine) = strlength(string(match));
end
commonIndent = min(leadingWhitespace);
if commonIndent > 0
    for iLine = 1:numel(lines)
        line = char(lines(iLine));
        if length(line) >= commonIndent
            lines(iLine) = string(line(commonIndent+1:end));
        end
    end
end
text = join(lines,newline);
end

function mergeCanonicalSidecars(documentation,sidecarFolders)
methodNames = string({documentation.allMethodDocumentation.name});
for sidecarFolder = sidecarFolders'
    sidecars = dir(fullfile(sidecarFolder,"*.md"));
    for iSidecar = 1:numel(sidecars)
        sidecarName = erase(string(sidecars(iSidecar).name),".md");
        if sidecarName == "README"
            continue
        end
        matchingIndices = find(methodNames == sidecarName);
        if isempty(matchingIndices)
            continue
        end
        sidecarMetadata = MethodDocumentation(sidecarName);
        sidecarMetadata.addMetadataFromDetailedDescription(fileread(fullfile(sidecars(iSidecar).folder,sidecars(iSidecar).name)));
        for iMethod = matchingIndices
            methodDocumentation = documentation.allMethodDocumentation(iMethod);
            methodDocumentation.mergeAnnotatedPropertyDocumentation(sidecarMetadata);
            if strlength(strtrim(string(sidecarMetadata.detailedDescription))) > 0
                methodDocumentation.detailedDescription = sidecarMetadata.detailedDescription;
            end
        end
    end
end
end

function normalizeGeneratedMarkdown(classFolder)
pages = dir(fullfile(classFolder,"*.md"));
for iPage = 1:numel(pages)
    pagePath = fullfile(pages(iPage).folder,pages(iPage).name);
    pageText = fileread(pagePath);
    pageText = regexprep(pageText,'[ \t]+(?=\r?\n|$)','');
    pageText = regexprep(pageText,'(## Discussion)(?:\r?\n){3,}','$1\n\n');
    pageText = regexprep(pageText,'(?:\r?\n){5,}(?=## Topics)','\n\n\n\n\n');
    pageText = regexprep(pageText,'(?:\r?\n)*$','\n');
    writeTextFile(pagePath,pageText);
end
end

function writeTextFile(path,text)
fileID = fopen(path,"w");
if fileID < 0
    error("WaveVortexModel:DocumentationWriteFailed","Unable to write %s.",path);
end
fileCleanup = onCleanup(@()fclose(fileID));
fwrite(fileID,text);
clear fileCleanup
end
