function report = prepareWaveVortexModelReleaseCandidate(repositoryRoot,oceanKitRoot,outputRoot,options)
%PREPAREWAVEVORTEXMODELRELEASECANDIDATE Build an unpublished 4.2.1 export.
arguments
    repositoryRoot (1,1) string {mustBeFolder}
    oceanKitRoot (1,1) string {mustBeFolder}
    outputRoot (1,1) string
    options.releaseDate (1,1) string = string(datetime("today",TimeZone="UTC",Format="yyyy-MM-dd"))
end

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end
manifestPath = fullfile(repositoryRoot,"resources","mpackage.json");
manifestBefore = jsondecode(fileread(manifestPath));
require(string(manifestBefore.name) == "WaveVortexModel" && string(manifestBefore.version) == "4.2.0", ...
    "The export dry run requires the WaveVortexModel 4.2.0 authoring manifest.");
configureIsolatedMPMRepository(oceanKitRoot);
packageBefore = matlab.mpm.Package(repositoryRoot);
require(string(packageBefore.ReleaseCompatibility) == ">=R2025b", ...
    "The export dry run requires MATLAB R2025b as the package compatibility floor.");

oceanKitTools = fullfile(oceanKitRoot,"tools");
sourceTools = fullfile(repositoryRoot,"tools");
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(oceanKitTools,"-begin");
releaseFunction = @ci_release;
dependency = oceankitrelease.installDocumentationPackage("ClassDocumentation@1.3.0", ...
    repositoryRoot=oceanKitRoot);
require(dependency.Version == "1.3.0", ...
    "ClassDocumentation 1.3.0 was not installed for the export dry run.");
addpath(sourceTools,"-begin");

oceankitrelease.runDocumentationCheck(repositoryRoot,"docs:check");
expectedBody = oceankitrelease.unreleasedBody(fullfile(repositoryRoot,"CHANGELOG.md"));
releaseBodyPath = fullfile(outputRoot,"release-body.md");
releaseFunction( ...
    rootDir=repositoryRoot, ...
    bumpType="patch", ...
    shouldBuildWebsiteDocumentation=true, ...
    shouldPackageForDistribution=true, ...
    shouldPromoteUnreleased=true, ...
    shouldRequireDocumentationBuilder=true, ...
    releaseDate=options.releaseDate, ...
    releaseBodyPath=releaseBodyPath, ...
    outputRoot=outputRoot);

changedPaths = oceankitrelease.changedAuthoringPaths(repositoryRoot,"pilot");
expectedPaths = ["CHANGELOG.md";"docs/version-history.md";"resources/mpackage.json"];
require(isequal(changedPaths,expectedPaths), ...
    "The export dry run changed files outside the permitted release-owned set.");
manifestAfter = jsondecode(fileread(manifestPath));
require(string(manifestAfter.version) == "4.2.1", ...
    "The export dry run did not create the expected 4.2.1 candidate.");
actualBody = string(fileread(releaseBodyPath));
require(strtrim(actualBody) == strtrim(expectedBody), ...
    "The release-body file does not match the promoted Unreleased body.");

changelog = string(fileread(fullfile(repositoryRoot,"CHANGELOG.md")));
unreleasedMatch = regexp(changelog,'(?s)^.*?## \[Unreleased\]\s*## \[4\.2\.1\] - [^\r\n]+','once','match');
require(~isempty(unreleasedMatch), ...
    "The promoted changelog does not begin with a fresh empty Unreleased section.");
changelogBody = versionBody(fullfile(repositoryRoot,"CHANGELOG.md"),"4.2.1");
require(contains(changelog,"## [4.2.1] - " + options.releaseDate) && changelogBody == expectedBody, ...
    "The promoted changelog does not contain the expected dated release body.");
versionHistory = string(fileread(fullfile(repositoryRoot,"docs","version-history.md")));
versionHistoryBody = versionBody(fullfile(repositoryRoot,"docs","version-history.md"),"4.2.1");
require(contains(versionHistory,"## [4.2.1] - " + options.releaseDate) && versionHistoryBody == expectedBody, ...
    "The generated version history does not agree with the promoted changelog.");

exportPath = fullfile(outputRoot,"WaveVortexModel-4.2.1");
require(isfolder(exportPath),"The expected WaveVortexModel-4.2.1 export was not created.");
exportManifest = jsondecode(fileread(fullfile(exportPath,"resources","mpackage.json")));
exportFolders = string({exportManifest.folders.path});
require(string(exportManifest.version) == "4.2.1" && ~any(exportFolders == "UnitTests"), ...
    "The exported manifest does not describe the expected runtime package.");
exportPackage = matlab.mpm.Package(exportPath);
require(string(exportPackage.ReleaseCompatibility) == ">=R2025b", ...
    "The exported package does not retain the MATLAB R2025b compatibility floor.");

report = struct( ...
    "version","4.2.1", ...
    "releaseCompatibility",string(exportPackage.ReleaseCompatibility), ...
    "exportPath",exportPath, ...
    "releaseBodyPath",releaseBodyPath, ...
    "releaseBody",expectedBody, ...
    "authoringPaths",changedPaths, ...
    "documentationPackageRoot",dependency.Root);
fprintf("Prepared unpublished WaveVortexModel 4.2.1 candidate at %s.\n",exportPath);
clear pathCleanup
end

function body = versionBody(path,version)
source = fileread(path);
escapedVersion = regexptranslate("escape",version);
[~,headingEnd] = regexp(source,'(?m)^## \[' + escapedVersion + '\][^\r\n]*\r?\n','once','start','end');
if isempty(headingEnd)
    error("WaveVortexModel:ReleaseCandidateVerificationFailed", ...
        "Version %s was not found in %s.",version,path);
end
followingText = source(headingEnd+1:end);
nextHeading = regexp(followingText,'(?m)^## \[','once','start');
if isempty(nextHeading)
    rawBody = followingText;
else
    rawBody = followingText(1:nextHeading-1);
end
body = string(regexprep(rawBody,'^\s*|\s*$',''));
end

function require(condition,message)
if ~condition
    error("WaveVortexModel:ReleaseCandidateVerificationFailed","%s",message);
end
end
