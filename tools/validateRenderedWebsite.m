function report = validateRenderedWebsite(renderedRoot,options)
arguments
    renderedRoot (1,1) string
    options.ShouldFail (1,1) logical = true
end

htmlFiles = renderedHTMLFiles(renderedRoot);
diagnostics = strings(0,1);
for relativePath = htmlFiles'
    pageText = string(fileread(fullfile(renderedRoot,relativePath)));
    mainMatch = regexp(pageText,'(?is)<main(?:\s[^>]*)?>(?<content>.*?)</main>','names','once');
    if isempty(mainMatch)
        diagnostics(end+1,1) = relativePath + ": missing main content element";
        continue
    end
    mainHTML = string(mainMatch.content);
    if isempty(regexp(mainHTML,'(?is)<h1(?:\s|>)','once'))
        diagnostics(end+1,1) = relativePath + ": missing level-one heading";
    end

    visibleHTML = mainHTML;
    excludedElements = ["script","style","pre","code"];
    for element = excludedElements
        expression = "(?is)<" + element + "(?:\\s[^>]*)?>.*?</" + element + ">";
        visibleHTML = regexprep(visibleHTML,expression,' ');
    end
    visibleText = regexprep(visibleHTML,'(?is)<[^>]+>',' ');
    if mod(numel(strfind(visibleText,"$$")),2) ~= 0
        diagnostics(end+1,1) = relativePath + ": unbalanced MathJax delimiters remain in rendered content";
    end
    tableMatches = regexp(visibleHTML,'(?is)<table(?:\s[^>]*)?>.*?</table>','match');
    for iTable = 1:numel(tableMatches)
        cells = regexp(tableMatches{iTable},'(?is)<t[dh](?:\s[^>]*)?>(?<content>.*?)</t[dh]>','names');
        for iCell = 1:numel(cells)
            if mod(numel(strfind(cells(iCell).content,"$$")),2) ~= 0
                diagnostics(end+1,1) = relativePath + ": MathJax expression is split across rendered table cells";
                break
            end
        end
    end
    if ~isempty(regexp(visibleText,'!?\[[^\]]*\]\([^)]*\)','once'))
        diagnostics(end+1,1) = relativePath + ": raw Markdown link or image remains in rendered content";
    end
    if contains(visibleText,"```")
        diagnostics(end+1,1) = relativePath + ": raw fenced-code marker remains in rendered content";
    elseif contains(visibleText,"`")
        diagnostics(end+1,1) = relativePath + ": raw Markdown backtick remains in rendered content";
    end
end

diagnostics = sort(unique(diagnostics));
report = struct("Files",htmlFiles,"Diagnostics",diagnostics,"IsValid",isempty(diagnostics));
fprintf("Rendered documentation validation: files=%d, failures=%d\n",numel(htmlFiles),numel(diagnostics));
if ~isempty(diagnostics)
    fprintf("  %s\n",strjoin(diagnostics,newline + "  "));
end
if options.ShouldFail && ~report.IsValid
    error("WaveVortexModel:InvalidRenderedDocumentation","Rendered documentation contains %d validation failure(s).",numel(diagnostics));
end
end

function files = renderedHTMLFiles(rootFolder)
entries = dir(fullfile(rootFolder,"**","*.html"));
entries = entries(~[entries.isdir]);
rootPrefix = char(rootFolder + filesep);
files = strings(numel(entries),1);
for iEntry = 1:numel(entries)
    fullPath = fullfile(entries(iEntry).folder,entries(iEntry).name);
    files(iEntry) = replace(string(fullPath(numel(rootPrefix)+1:end)),filesep,"/");
end
files = sort(unique(files));
end
