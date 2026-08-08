function report = validateWebsiteDocumentation(documentationRoot,options)
arguments
    documentationRoot (1,1) string
    options.ShouldFail (1,1) logical = true
    options.ShouldCheckHierarchy (1,1) logical = true
    options.ShouldCheckGeneratedContent (1,1) logical = true
end

files = documentationFiles(documentationRoot);
routeMap = documentationRouteMap(documentationRoot,files);
diagnostics = strings(0,1);

markdownFiles = files(endsWith(files,".md"));
for relativePath = markdownFiles'
    pagePath = fullfile(documentationRoot,relativePath);
    pageText = string(fileread(pagePath));
    malformedDiagnostics = malformedLinkDiagnostics(pageText);
    for diagnostic = malformedDiagnostics'
        diagnostics(end+1,1) = relativePath + ": " + diagnostic;
    end
    targets = markdownTargets(pageText);
    for target = targets'
        diagnostic = validateTarget(target,relativePath,documentationRoot,routeMap);
        if diagnostic ~= ""
            diagnostics(end+1,1) = relativePath + ": " + diagnostic;
        end
    end
end

function diagnostics = malformedLinkDiagnostics(pageText)
diagnostics = strings(0,1);
markdownStarts = regexp(pageText,'!?\[[^\]]*\]\(','start');
markdownLinks = regexp(pageText,'!?\[[^\]]*\]\([^)]*\)','start');
if numel(markdownStarts) ~= numel(markdownLinks)
    diagnostics(end+1,1) = "malformed Markdown link or image";
end
htmlStarts = regexp(pageText,'(?i:href|src)\s*=\s*["'']','start');
htmlLinks = regexp(pageText,'(?i:href|src)\s*=\s*(?:"[^"]*"|''[^'']*'')','start');
if numel(htmlStarts) ~= numel(htmlLinks)
    diagnostics(end+1,1) = "malformed HTML href or src attribute";
end
end

if options.ShouldCheckHierarchy
    diagnostics = [diagnostics; hierarchyDiagnostics(documentationRoot,markdownFiles)];
end
if options.ShouldCheckGeneratedContent
    diagnostics = [diagnostics; generatedContentDiagnostics(documentationRoot)];
end
diagnostics = sort(unique(diagnostics));

report = struct("Files",files,"Routes",string(keys(routeMap)).',"Diagnostics",diagnostics,"IsValid",isempty(diagnostics));
fprintf("Documentation validation: files=%d, routes=%d, failures=%d\n",numel(files),routeMap.Count,numel(diagnostics));
if ~isempty(diagnostics)
    fprintf("  %s\n",strjoin(diagnostics,newline + "  "));
end
if options.ShouldFail && ~report.IsValid
    error("WaveVortexModel:InvalidDocumentation","Generated documentation contains %d validation failure(s).",numel(diagnostics));
end
end

function files = documentationFiles(rootFolder)
entries = dir(fullfile(rootFolder,"**","*"));
entries = entries(~[entries.isdir]);
entries = entries(string({entries.name}) ~= ".DS_Store");
rootPrefix = char(rootFolder + filesep);
files = strings(numel(entries),1);
for iEntry = 1:numel(entries)
    fullPath = fullfile(entries(iEntry).folder,entries(iEntry).name);
    files(iEntry) = replace(string(fullPath(numel(rootPrefix)+1:end)),filesep,"/");
end
files = sort(unique(files));
end

function routeMap = documentationRouteMap(rootFolder,files)
routeMap = containers.Map("KeyType","char","ValueType","char");
for relativePath = files'
    routeMap = addRoute(routeMap,relativePath,relativePath);
    if ~endsWith(relativePath,".md")
        continue
    end

    htmlRoute = extractBefore(relativePath,strlength(relativePath)-2) + ".html";
    routeMap = addRoute(routeMap,htmlRoute,relativePath);
    if endsWith(relativePath,"/index.md") || relativePath == "index.md"
        directoryRoute = erase(relativePath,"index.md");
        directoryRoute = strip(directoryRoute,"right","/");
        routeMap = addRoute(routeMap,directoryRoute,relativePath);
        routeMap = addRoute(routeMap,directoryRoute + "/",relativePath);
    end

    pageText = string(fileread(fullfile(rootFolder,relativePath)));
    permalink = frontMatterValue(pageText,"permalink");
    if permalink ~= ""
        permalink = strip(permalink,"left","/");
        routeMap = addRoute(routeMap,permalink,relativePath);
        routeMap = addRoute(routeMap,strip(permalink,"right","/") + "/",relativePath);
    end
end
end

function routeMap = addRoute(routeMap,route,relativePath)
route = char(route);
if ~isKey(routeMap,route)
    routeMap(route) = char(relativePath);
end
end

function targets = markdownTargets(pageText)
markdownMatches = regexp(pageText,'!?\[[^\]]*\]\((?<target>[^)\s]+)(?:\s+[^)]*)?\)','names');
htmlDoubleMatches = regexp(pageText,'(?i:href|src)\s*=\s*"(?<target>[^"]+)"','names');
htmlSingleMatches = regexp(pageText,'(?i:href|src)\s*=\s*''(?<target>[^'']+)''','names');
targets = strings(0,1);
if ~isempty(markdownMatches)
    targets = [targets; string({markdownMatches.target}).'];
end
if ~isempty(htmlDoubleMatches)
    targets = [targets; string({htmlDoubleMatches.target}).'];
end
if ~isempty(htmlSingleMatches)
    targets = [targets; string({htmlSingleMatches.target}).'];
end
end

function diagnostic = validateTarget(rawTarget,sourceRelativePath,documentationRoot,routeMap)
diagnostic = "";
if startsWith(rawTarget,"//") || ~isempty(regexp(rawTarget,'^[A-Za-z][A-Za-z0-9+.-]*:','once'))
    return
end

[targetWithoutFragment,fragment] = splitFragment(rawTarget);
targetWithoutFragment = extractBefore(targetWithoutFragment + "?","?");
if targetWithoutFragment == ""
    resolvedRelativePath = sourceRelativePath;
else
    if startsWith(targetWithoutFragment,"/")
        route = extractAfter(targetWithoutFragment,1);
    else
        sourceFolder = replace(string(fileparts(sourceRelativePath)),filesep,"/");
        route = normalizeRelativeRoute(sourceFolder + "/" + targetWithoutFragment);
    end
    route = char(route);
    if ~isKey(routeMap,route)
        diagnostic = "unresolved internal target " + rawTarget;
        return
    end
    resolvedRelativePath = string(routeMap(route));
end

if fragment ~= "" && ~fragmentExists(fullfile(documentationRoot,resolvedRelativePath),fragment)
    diagnostic = "unresolved fragment #" + fragment + " in " + rawTarget;
end
end

function [target,fragment] = splitFragment(rawTarget)
hashIndex = strfind(rawTarget,"#");
if isempty(hashIndex)
    target = rawTarget;
    fragment = "";
else
    target = extractBefore(rawTarget,hashIndex(1));
    fragment = extractAfter(rawTarget,hashIndex(1));
end
end

function route = normalizeRelativeRoute(route)
segments = split(replace(route,"\","/"),"/");
normalized = strings(0,1);
for segment = segments'
    if segment == "" || segment == "."
        continue
    elseif segment == ".."
        if isempty(normalized)
            route = "";
            return
        end
        normalized(end) = [];
    else
        normalized(end+1,1) = segment;
    end
end
route = strjoin(normalized,"/");
end

function tf = fragmentExists(path,fragment)
if ~endsWith(path,".md")
    tf = false;
    return
end
pageText = string(fileread(path));
explicitIDs = regexp(pageText,'(?:id="|\{#)(?<id>[A-Za-z0-9_-]+)','names');
explicitIDs = string({explicitIDs.id});
headingMatches = regexp(pageText,'(?m)^#{1,6}\s+(?<heading>.+?)\s*#*\s*$','names');
headingSlugs = strings(numel(headingMatches),1);
for iHeading = 1:numel(headingMatches)
    heading = lower(string(headingMatches(iHeading).heading));
    heading = regexprep(heading,'<[^>]+>','');
    heading = erase(heading,["`" "*" "_"]);
    heading = regexprep(heading,'[^a-z0-9 -]','');
    heading = regexprep(strtrim(heading),'\s+','-');
    headingSlugs(iHeading) = regexprep(heading,'-+','-');
end
tf = any(fragment == [explicitIDs(:); headingSlugs(:)]);
end

function diagnostics = hierarchyDiagnostics(rootFolder,markdownFiles)
diagnostics = strings(0,1);
indexFiles = markdownFiles(endsWith(markdownFiles,"/index.md"));
for indexRelativePath = indexFiles'
    indexText = string(fileread(fullfile(rootFolder,indexRelativePath)));
    if ~contains(indexText,"## Declaration")
        continue
    end
    classTitle = frontMatterValue(indexText,"title");
    classParent = frontMatterValue(indexText,"parent");
    classFolder = string(fileparts(indexRelativePath));
    siblingPages = markdownFiles(startsWith(markdownFiles,classFolder + "/"));
    siblingPages = siblingPages(~contains(extractAfter(siblingPages,strlength(classFolder)+1),"/"));
    siblingPages = siblingPages(~endsWith(siblingPages,"/index.md"));
    for page = siblingPages'
        pageText = string(fileread(fullfile(rootFolder,page)));
        if frontMatterValue(pageText,"parent") ~= classTitle
            diagnostics(end+1,1) = page + ": parent does not match class title " + classTitle;
        end
        if frontMatterValue(pageText,"grand_parent") ~= classParent
            diagnostics(end+1,1) = page + ": grand_parent does not match class parent " + classParent;
        end
    end
end
end

function diagnostics = generatedContentDiagnostics(rootFolder)
diagnostics = strings(0,1);
transformIndex = fullfile(rootFolder,"classes","transforms","wvtransform","index.md");
if ~isfile(transformIndex)
    diagnostics(end+1,1) = "classes/transforms/wvtransform/index.md: required regression page is missing";
    return
end
pageText = string(fileread(transformIndex));
if ~contains(pageText,'$$\rho$$')
    diagnostics(end+1,1) = "classes/transforms/wvtransform/index.md: expected LaTeX command \\rho is missing";
end
if contains(pageText,'$$ho$$')
    diagnostics(end+1,1) = "classes/transforms/wvtransform/index.md: found the historical truncated LaTeX form $$ho$$";
end
end

function value = frontMatterValue(pageText,name)
expression = '(?m)^' + regexptranslate("escape",name) + ':\s*(?<value>[^\r\n]+)\s*$';
match = regexp(pageText,expression,'names','once');
if isempty(match)
    value = "";
else
    value = strtrim(string(match.value));
end
end
