function report = analyzeProductionCode(repositoryRoot,options)
% analyzeProductionCode Analyze the WaveVortexModel production runtime.
%
% report = analyzeProductionCode(repositoryRoot) runs MATLAB Code Analyzer
% with its factory configuration, reports every active and suppressed
% finding, and fails when a correctness or unclassified finding remains.
%
% This is an authoring tool rather than WaveVortexModel runtime API.

arguments
    repositoryRoot (1,1) string {mustBeFolder}
    options.Files string = strings(0,1)
    options.ShouldPrint (1,1) logical = true
    options.ShouldFail (1,1) logical = true
end

files = reshape(options.Files,[],1);
if isempty(files)
    files = productionCodeFiles(repositoryRoot);
else
    files = sort(unique(files));
end
if isempty(files)
    error("WaveVortexModel:EmptyCodeAnalyzerInventory","No MATLAB production files were selected for analysis.");
end

analysis = codeIssues(files,CodeAnalyzerConfiguration="factory");
activeFindings = normalizedFindings(analysis.Issues,false,repositoryRoot);
suppressedFindings = normalizedFindings(analysis.SuppressedIssues,true,repositoryRoot);
findings = [activeFindings; suppressedFindings];
if ~isempty(findings)
    findings = sortrows(findings,["RelativeFile" "Line" "Column" "CheckID" "Suppressed"]);
    [findings.Classification,findings.Rationale] = classifyFindings(findings);
end

blockingMask = startsWith(findings.Classification,"blocking");
relativeFiles = relativePaths(string(analysis.Files),repositoryRoot);
report = struct( ...
    Release=string(analysis.Release), ...
    Files=sort(relativeFiles), ...
    Findings=findings, ...
    BlockingFindings=findings(blockingMask,:), ...
    NonblockingFindings=findings(~blockingMask,:));

if options.ShouldPrint
    printReport(report);
end
if options.ShouldFail && ~isempty(report.BlockingFindings)
    error("WaveVortexModel:CodeAnalyzerFailed","MATLAB Code Analyzer found %d blocking production finding(s).",height(report.BlockingFindings));
end
end

function files = productionCodeFiles(repositoryRoot)
rootEntries = dir(fullfile(repositoryRoot,"*.m"));
rootFiles = string(fullfile({rootEntries.folder},{rootEntries.name}))';
rootFiles(endsWith(rootFiles,filesep+"buildfile.m")) = [];

classDirectories = dir(fullfile(repositoryRoot,"@*"));
classDirectories = classDirectories([classDirectories.isdir]);
classFilesByDirectory = cell(numel(classDirectories),1);
for iDirectory = 1:numel(classDirectories)
    classFilesByDirectory{iDirectory} = matlabFilesUnder(fullfile(classDirectories(iDirectory).folder,classDirectories(iDirectory).name));
end
classFiles = vertcat(classFilesByDirectory{:});

manifest = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
runtimeFolders = string({manifest.folders.path})';
runtimeFolders(runtimeFolders == "UnitTests") = [];
folderFilesByDirectory = cell(numel(runtimeFolders),1);
for iFolder = 1:numel(runtimeFolders)
    folderFilesByDirectory{iFolder} = matlabFilesUnder(fullfile(repositoryRoot,runtimeFolders(iFolder)));
end
folderFiles = vertcat(folderFilesByDirectory{:});

files = sort(unique([rootFiles; classFiles; folderFiles]));
end

function files = matlabFilesUnder(folder)
entries = dir(fullfile(folder,"**","*.m"));
files = string(fullfile({entries.folder},{entries.name}))';
end

function findings = normalizedFindings(issueTable,isSuppressed,repositoryRoot)
if isempty(issueTable)
    findings = table( ...
        strings(0,1),strings(0,1),zeros(0,1),zeros(0,1),strings(0,1),strings(0,1),false(0,1),strings(0,1),strings(0,1), ...
        VariableNames=["RelativeFile" "CheckID" "Line" "Column" "Severity" "Diagnostic" "Suppressed" "Classification" "Rationale"]);
    return
end

relativeFile = relativePaths(string(issueTable.FullFilename),repositoryRoot);
checkID = string(issueTable.CheckID);
line = double(issueTable.LineStart);
column = double(issueTable.ColumnStart);
severity = string(issueTable.Severity);
diagnostic = string(issueTable.Description);
suppressed = repmat(isSuppressed,height(issueTable),1);
classification = strings(height(issueTable),1);
rationale = strings(height(issueTable),1);
findings = table(relativeFile,checkID,line,column,severity,diagnostic,suppressed,classification,rationale, ...
    VariableNames=["RelativeFile" "CheckID" "Line" "Column" "Severity" "Diagnostic" "Suppressed" "Classification" "Rationale"]);
end

function relative = relativePaths(files,repositoryRoot)
files = reshape(files,[],1);
rootPrefix = repositoryRoot + filesep;
relative = files;
insideRoot = startsWith(files,rootPrefix);
relative(insideRoot) = extractAfter(files(insideRoot),strlength(rootPrefix));
relative = replace(relative,filesep,"/");
end

function [classification,rationale] = classifyFindings(findings)
classification = repmat("blocking-unclassified",height(findings),1);
rationale = repmat("Unclassified findings require review before they can become nonblocking.",height(findings),1);

performanceMask = findings.CheckID == "AGROW";
classification(performanceMask) = "performance";
rationale(performanceMask) = "Dynamic allocation is visible performance advice and is not a correctness failure.";

styleMask = ismember(findings.CheckID,["INUSA" "INUSD" "MANU" "PROP"]);
classification(styleMask) = "style";
rationale(styleMask) = "Unused callback or interface inputs and property-name clarity advice are nonblocking style findings.";

geostrophicConstructorMask = findings.CheckID == "CTOINW" & findings.RelativeFile == "FlowComponents/WVGeostrophicMethods.m";
classification(geostrophicConstructorMask) = "accepted-false-positive";
rationale(geostrophicConstructorMask) = "The mixin constructor intentionally receives the already constructed transform during multiple-inheritance initialization.";

inertialPropertyMask = findings.CheckID == "MCNPR" & findings.RelativeFile == "FlowComponents/WVInertialOscillationMethods.m" & ...
    (contains(findings.Diagnostic,"'Ap'") | contains(findings.Diagnostic,"'Am'") | contains(findings.Diagnostic,"'A0'"));
mdaPropertyMask = findings.CheckID == "MCNPR" & findings.RelativeFile == "FlowComponents/WVMeanDensityAnomalyMethods.m" & contains(findings.Diagnostic,"'A0'");
inheritedPropertyMask = inertialPropertyMask | mdaPropertyMask;
classification(inheritedPropertyMask) = "accepted-false-positive";
rationale(inheritedPropertyMask) = "Ap, Am, and A0 are supplied by the composed transform hierarchy and are not visible to analysis of the mixin alone.";

errorMask = findings.Severity == "error";
classification(errorMask) = "blocking-error";
rationale(errorMask) = "MATLAB Code Analyzer errors always block, even when their identifier is otherwise nonblocking.";
end

function printReport(report)
nSuppressed = nnz(report.Findings.Suppressed);
nActive = height(report.Findings) - nSuppressed;
fprintf("MATLAB Code Analyzer: release=%s, files=%d, active=%d, suppressed=%d, blocking=%d\n", ...
    report.Release,numel(report.Files),nActive,nSuppressed,height(report.BlockingFindings));

for iFinding = 1:height(report.Findings)
    finding = report.Findings(iFinding,:);
    suppressionText = "";
    if finding.Suppressed
        suppressionText = ", suppressed";
    end
    fprintf("%s:%d:%d [%s, %s%s] %s\n",finding.RelativeFile,finding.Line,finding.Column, ...
        finding.CheckID,finding.Classification,suppressionText,finding.Diagnostic);
end

classifications = unique(report.Findings.Classification,"stable");
for iClassification = 1:numel(classifications)
    classification = classifications(iClassification);
    fprintf("  %s: %d\n",classification,nnz(report.Findings.Classification == classification));
end
end
