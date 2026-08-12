function generateBenchmarkWebsiteDocumentation(repositoryRoot,buildFolder)
% Generate the catalog-driven portions of the Benchmarks website page.
arguments
    repositoryRoot (1,1) string
    buildFolder (1,1) string
end

pagePath = fullfile(buildFolder,"benchmarks.md");
if ~isfile(pagePath)
    error("WaveVortexModel:MissingBenchmarkPage","The canonical Benchmarks page is missing from the staged documentation tree.");
end

catalogPath = fullfile(repositoryRoot,"Benchmarks","results","catalog.json");
catalog = jsondecode(fileread(catalogPath));
if ~isfield(catalog,"schemaVersion") || string(catalog.schemaVersion) ~= "benchmark-catalog-v1"
    error("WaveVortexModel:InvalidBenchmarkCatalog","The benchmark catalog must use schema benchmark-catalog-v1.");
end
allowedSuites = string({catalog.scoringReferences.suiteId});
records = loadPublishedRecords(repositoryRoot,catalog,allowedSuites);
validateComparableCases(records);
copyPublishedRecords(records,buildFolder);

latestRecords = latestPublishedRecords(records);
pageText = string(fileread(pagePath));
pageText = replaceGeneratedSection(pageText,"AT_GLANCE",atAGlanceMarkdown(latestRecords));
pageText = replaceGeneratedSection(pageText,"SCALING",scalingMarkdown(latestRecords,buildFolder));
pageText = replaceGeneratedSection(pageText,"COMPUTERS",computerMarkdown(latestRecords));
pageText = replaceGeneratedSection(pageText,"HISTORY",historyMarkdown(records));
pageText = replaceGeneratedSection(pageText,"DOWNLOADS",downloadsMarkdown(records));
writeText(pagePath,pageText);
end

function records = loadPublishedRecords(repositoryRoot,catalog,allowedSuites)
records = struct("dataset",{},"artifactPath",{},"rawPath",{});
if isempty(catalog.publishedDatasets)
    return
end

entries = catalog.publishedDatasets;
seenDatasetIds = strings(0,1);
for iEntry = 1:numel(entries)
    entry = itemAt(entries,iEntry);
    artifactPath = repositoryFile(repositoryRoot,string(entry.artifact),"published dataset");
    dataset = jsondecode(fileread(artifactPath));
    validatePublishedDataset(dataset,string(entry.datasetId));
    if any(seenDatasetIds == string(dataset.datasetId))
        error("WaveVortexModel:DuplicatePublishedBenchmark","The catalog contains duplicate dataset ID %s.",string(dataset.datasetId));
    end
    seenDatasetIds(end+1,1) = string(dataset.datasetId);
    if ~ismember(string(dataset.benchmark.suiteId),allowedSuites)
        continue
    end
    rawPath = repositoryFile(repositoryRoot,string(dataset.provenance.rawArtifact),"raw benchmark artifact");
    records(end+1) = struct("dataset",dataset,"artifactPath",artifactPath,"rawPath",rawPath);
end
end

function validatePublishedDataset(dataset,catalogDatasetId)
requiredFields = ["schemaVersion" "datasetId" "collectedAt" "benchmark" "implementation" "platform" "toolchain" "provenance" "cases"];
if ~all(isfield(dataset,requiredFields)) || string(dataset.schemaVersion) ~= "published-benchmark-v1"
    error("WaveVortexModel:InvalidPublishedBenchmark","Published dataset %s does not use the required contract.",catalogDatasetId);
end
datasetId = string(dataset.datasetId);
if datasetId ~= catalogDatasetId || isempty(regexp(datasetId,'^[a-z0-9][a-z0-9-]*--(?:matlab|cpp)-[a-z0-9][a-z0-9-]*--[a-z0-9][a-z0-9-]*--\d{8}T\d{6}Z$','once'))
    error("WaveVortexModel:PublishedBenchmarkIdentityMismatch","Catalog ID %s does not match a valid dataset ID.",catalogDatasetId);
end
if ~isfield(dataset.implementation,"sourceDirty") || logical(dataset.implementation.sourceDirty)
    error("WaveVortexModel:DirtyPublishedBenchmark","Published dataset %s must come from a clean source checkout.",datasetId);
end

caseIds = strings(numel(dataset.cases),1);
for iCase = 1:numel(dataset.cases)
    benchmarkCase = itemAt(dataset.cases,iCase);
    caseIds(iCase) = string(benchmarkCase.id);
    status = string(benchmarkCase.status);
    if status == "complete"
        if ~isfield(benchmarkCase,"correctness") || ~logical(benchmarkCase.correctness.passed) || ~isfield(benchmarkCase,"timing") || ~isfinite(benchmarkCase.timing.medianSeconds) || benchmarkCase.timing.medianSeconds <= 0
            error("WaveVortexModel:InvalidPublishedBenchmark","Completed case %s in %s lacks successful correctness and timing.",caseIds(iCase),datasetId);
        end
    elseif status ~= "unavailable"
        error("WaveVortexModel:InvalidPublishedBenchmark","Case %s in %s has unsupported status %s.",caseIds(iCase),datasetId,status);
    end
end
if numel(unique(caseIds)) ~= numel(caseIds)
    error("WaveVortexModel:DuplicatePublishedBenchmarkCase","Dataset %s contains duplicate case IDs.",datasetId);
end
end

function validateComparableCases(records)
signatures = containers.Map("KeyType","char","ValueType","any");
owners = containers.Map("KeyType","char","ValueType","char");
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    for iCase = 1:numel(dataset.cases)
        benchmarkCase = itemAt(dataset.cases,iCase);
        key = comparisonCaseKey(dataset,benchmarkCase);
        signature = comparableSignature(dataset,benchmarkCase);
        if isKey(signatures,key) && ~isequaln(signatures(key),signature)
            error("WaveVortexModel:ConflictingPublishedBenchmarkCase","Datasets %s and %s define incompatible configurations for %s.",string(owners(key)),string(dataset.datasetId),string(benchmarkCase.id));
        end
        signatures(key) = signature;
        owners(key) = char(string(dataset.datasetId));
    end
end
end

function signature = comparableSignature(dataset,benchmarkCase)
signature = struct( ...
    "operation",string(dataset.benchmark.operation), ...
    "correctnessTolerance",double(dataset.benchmark.correctnessTolerance), ...
    "transformId",string(benchmarkCase.transformId), ...
    "scoreFamily",string(benchmarkCase.scoreFamily), ...
    "Lxyz",double(benchmarkCase.configuration.Lxyz(:)'), ...
    "Nxyz",double(benchmarkCase.configuration.Nxyz(:)'), ...
    "isHydrostatic",logical(benchmarkCase.configuration.isHydrostatic), ...
    "shouldAntialias",logical(benchmarkCase.configuration.shouldAntialias), ...
    "seed",double(benchmarkCase.configuration.seed), ...
    "warmupCount",double(benchmarkCase.configuration.warmupCount), ...
    "sampleCount",double(benchmarkCase.configuration.sampleCount));
end

function key = comparisonCaseKey(dataset,benchmarkCase)
key = char(string(dataset.benchmark.suiteId) + "|" + string(dataset.benchmark.suiteVersion) + "|" + string(benchmarkCase.id));
end

function copyPublishedRecords(records,buildFolder)
if isempty(records)
    return
end
dataFolder = fullfile(buildFolder,"benchmarks","data");
rawFolder = fullfile(buildFolder,"benchmarks","raw");
mkdir(dataFolder);
mkdir(rawFolder);
for iRecord = 1:numel(records)
    datasetId = string(records(iRecord).dataset.datasetId);
    copyfile(records(iRecord).artifactPath,fullfile(dataFolder,datasetId + ".json"),"f");
    copyfile(records(iRecord).rawPath,fullfile(rawFolder,datasetId + ".json"),"f");
end
end

function records = latestPublishedRecords(records)
if isempty(records)
    return
end
latestByKey = containers.Map("KeyType","char","ValueType","double");
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    key = char(environmentKey(dataset) + "|" + string(dataset.benchmark.suiteId) + "|" + string(dataset.benchmark.suiteVersion));
    if ~isKey(latestByKey,key) || collectionTime(dataset) > collectionTime(records(latestByKey(key)).dataset)
        latestByKey(key) = iRecord;
    end
end
indices = sort(cell2mat(values(latestByKey)));
records = records(indices);
end

function markdown = atAGlanceMarkdown(records)
representativeId = "constant-nonhydrostatic-256x256x65";
rows = strings(0,5);
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    if string(dataset.benchmark.suiteId) ~= "scaling-standard-v1" || double(dataset.benchmark.suiteVersion) ~= 1
        continue
    end
    benchmarkCase = caseWithId(dataset,representativeId);
    [runtime,memory,increment] = representativeValues(benchmarkCase);
    rows(end+1,:) = [datasetLabel(dataset),runtime,memory,increment,string(dataset.platform.threadCount)];
end
if isempty(rows)
    markdown = "No approved benchmark datasets have been published yet. Approved results will appear here when they are added to the benchmark catalog.";
    return
end
rows = sortrows(rows,1);
markdown = markdownTable(["Implementation and platform" "Median runtime" "Peak process memory" "Memory above baseline" "Threads"],rows);
end

function [runtime,memory,increment] = representativeValues(benchmarkCase)
runtime = "Unavailable";
memory = "Unavailable";
increment = "Unavailable";
if isempty(benchmarkCase) || string(benchmarkCase.status) ~= "complete"
    return
end
runtime = formatSeconds(benchmarkCase.timing.medianSeconds);
if string(benchmarkCase.memory.status) == "complete"
    memory = formatBytes(benchmarkCase.memory.peakProcessBytes);
    increment = formatBytes(benchmarkCase.memory.peakIncrementBytes);
end
end

function markdown = scalingMarkdown(records,buildFolder)
records = records(arrayfun(@(record)startsWith(string(record.dataset.benchmark.suiteId),"scaling-"),records));
if isempty(records)
    markdown = "No approved scaling datasets have been published yet.";
    return
end

specifications = [ ...
    struct("id","runtime-horizontal","title","Runtime versus horizontal resolution","axis","horizontal","metric","runtime","xLabel","Horizontal grid points per dimension","yLabel","Median runtime (s)"), ...
    struct("id","runtime-vertical","title","Runtime versus vertical resolution","axis","vertical","metric","runtime","xLabel","Vertical grid points","yLabel","Median runtime (s)"), ...
    struct("id","memory-horizontal","title","Peak process memory versus horizontal resolution","axis","horizontal","metric","memory","xLabel","Horizontal grid points per dimension","yLabel","Peak process memory (GiB)"), ...
    struct("id","memory-vertical","title","Peak process memory versus vertical resolution","axis","vertical","metric","memory","xLabel","Vertical grid points","yLabel","Peak process memory (GiB)") ...
    ];
assetFolder = fullfile(buildFolder,"assets","benchmarks");
mkdir(assetFolder);
sections = strings(1,numel(specifications));
for iSpecification = 1:numel(specifications)
    specification = specifications(iSpecification);
    rows = scalingRows(records,specification.axis,specification.metric);
    if isempty(rows)
        sections(iSpecification) = "### " + specification.title + newline + newline + "No compatible complete cases are available.";
        continue
    end
    if ~any([rows.status] == "complete")
        sections(iSpecification) = "### " + specification.title + newline + newline + ...
            "No complete measurements are available." + newline + newline + ...
            "<details markdown=""1"">" + newline + "<summary>View unavailable cases</summary>" + newline + newline + ...
            scalingTable(rows,specification.metric) + newline + newline + "</details>";
        continue
    end
    assetRelativePath = "assets/benchmarks/" + specification.id + ".svg";
    writeScalingSVG(fullfile(buildFolder,assetRelativePath),specification.title,specification.xLabel,specification.yLabel,rows);
    sections(iSpecification) = "### " + specification.title + newline + newline + ...
        "![" + specification.title + "](/" + assetRelativePath + ")" + newline + newline + ...
        "<details markdown=""1"">" + newline + "<summary>View accessible data table</summary>" + newline + newline + ...
        scalingTable(rows,specification.metric) + newline + newline + "</details>";
end
markdown = strjoin(sections,newline + "" + newline);
end

function rows = scalingRows(records,axisName,metricName)
templates = caseTemplates(records);
eligible = false(1,numel(templates));
for iTemplate = 1:numel(templates)
    eligible(iTemplate) = isScalingTemplate(templates,iTemplate,axisName);
end
templates = templates(eligible);
environments = latestEnvironmentRecords(records);
rows = struct("datasetId",{},"datasetLabel",{},"chartLabel",{},"suiteId",{},"transformId",{},"caseId",{},"resolution",{},"status",{},"reason",{},"value",{});
for iEnvironment = 1:numel(environments)
    environmentDataset = environments(iEnvironment).dataset;
    environment = environmentKey(environmentDataset);
    for iTemplate = 1:numel(templates)
        template = templates(iTemplate);
        recordIndex = find(arrayfun(@(record)environmentKey(record.dataset) == environment && ...
            string(record.dataset.benchmark.suiteId) == template.suiteId && ...
            double(record.dataset.benchmark.suiteVersion) == template.suiteVersion,records),1);
        if isempty(recordIndex)
            dataset = environmentDataset;
            status = "unavailable";
            reason = "No " + template.suiteId + " dataset was collected for this environment.";
            value = NaN;
        else
            dataset = records(recordIndex).dataset;
            benchmarkCase = caseWithId(dataset,template.caseId);
            [status,reason,value] = scalingValue(benchmarkCase,metricName);
        end
        resolution = template.Nxyz(1);
        if axisName == "vertical"
            resolution = template.Nxyz(3);
        end
        rows(end+1) = struct( ...
            "datasetId",string(dataset.datasetId), ...
            "datasetLabel",datasetLabel(dataset) + " — " + template.suiteId, ...
            "chartLabel",chartLabel(dataset), ...
            "suiteId",template.suiteId, ...
            "transformId",template.transformId, ...
            "caseId",template.caseId, ...
            "resolution",resolution, ...
            "status",status, ...
            "reason",reason, ...
            "value",value);
    end
end
end

function templates = caseTemplates(records)
templates = struct("key",{},"suiteId",{},"suiteVersion",{},"transformId",{},"caseId",{},"Nxyz",{});
seen = strings(0,1);
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    for iCase = 1:numel(dataset.cases)
        benchmarkCase = itemAt(dataset.cases,iCase);
        key = string(comparisonCaseKey(dataset,benchmarkCase));
        if any(seen == key)
            continue
        end
        seen(end+1,1) = key;
        templates(end+1) = struct( ...
            "key",key, ...
            "suiteId",string(dataset.benchmark.suiteId), ...
            "suiteVersion",double(dataset.benchmark.suiteVersion), ...
            "transformId",string(benchmarkCase.transformId), ...
            "caseId",string(benchmarkCase.id), ...
            "Nxyz",double(benchmarkCase.configuration.Nxyz(:)'));
    end
end
end

function tf = isScalingTemplate(templates,index,axisName)
template = templates(index);
sameFamily = [templates.suiteId] == template.suiteId & [templates.suiteVersion] == template.suiteVersion & [templates.transformId] == template.transformId;
family = templates(sameFamily);
if axisName == "horizontal"
    if numel(template.Nxyz) == 2
        tf = template.Nxyz(1) == template.Nxyz(2) && nnz(arrayfun(@(item)numel(item.Nxyz) == 2 && item.Nxyz(1) == item.Nxyz(2) && item.Nxyz(1) ~= template.Nxyz(1),family)) > 0;
    else
        tf = template.Nxyz(1) == template.Nxyz(2) && nnz(arrayfun(@(item)numel(item.Nxyz) == 3 && item.Nxyz(1) == item.Nxyz(2) && item.Nxyz(3) == template.Nxyz(3) && item.Nxyz(1) ~= template.Nxyz(1),family)) > 0;
    end
else
    tf = numel(template.Nxyz) == 3 && nnz(arrayfun(@(item)numel(item.Nxyz) == 3 && all(item.Nxyz(1:2) == template.Nxyz(1:2)) && item.Nxyz(3) ~= template.Nxyz(3),family)) > 0;
end
end

function [status,reason,value] = scalingValue(benchmarkCase,metricName)
status = "unavailable";
reason = "Case was not recorded in this dataset.";
value = NaN;
if isempty(benchmarkCase)
    return
elseif string(benchmarkCase.status) == "unavailable"
    reason = string(benchmarkCase.unavailableReason);
    return
end
if metricName == "runtime"
    value = double(benchmarkCase.timing.medianSeconds);
elseif string(benchmarkCase.memory.status) == "complete"
    value = double(benchmarkCase.memory.peakProcessBytes)/2^30;
else
    reason = string(benchmarkCase.memory.reason);
    return
end
status = "complete";
reason = "";
end

function writeScalingSVG(path,titleText,xLabel,yLabel,rows)
completeRows = rows([rows.status] == "complete");
seriesKeys = sort(unique([completeRows.datasetId] + "|" + [completeRows.transformId]));
palette = ["#0072B2" "#D55E00" "#009E73" "#CC79A7" "#E69F00" "#56B4E9" "#000000"];
width = 960;
plotX = 85;
plotY = 55;
plotWidth = 830;
plotHeight = 360;
legendRows = ceil(numel(seriesKeys)/2);
height = 470 + 24*legendRows;
identifier = regexprep(lower(string(titleText)),'[^a-z0-9]+','-');
svg = strings(0,1);
svg(end+1) = sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" aria-labelledby="%s-title %s-desc">',width,height,identifier,identifier);
svg(end+1) = '<title id="' + identifier + '-title">' + xmlEscape(titleText) + '</title>';
svg(end+1) = '<desc id="' + identifier + '-desc">Logarithmic scaling series by dataset and transform family. Exact values and unavailable cases are listed in the following table.</desc>';
svg(end+1) = '<rect width="100%" height="100%" fill="white"/>';
svg(end+1) = '<text x="480" y="24" text-anchor="middle" font-family="Avenir Next, Avenir, Helvetica, Arial, sans-serif" font-size="18" font-weight="600">' + xmlEscape(titleText) + '</text>';
[xMinimum,xMaximum] = logarithmicLimits([completeRows.resolution]);
[yMinimum,yMaximum] = logarithmicLimits([completeRows.value]);
svg(end+1) = sprintf('<rect x="%g" y="%g" width="%g" height="%g" fill="none" stroke="#777"/>',plotX,plotY,plotWidth,plotHeight);
axisText = chartAxisLabels(plotX,plotY,plotWidth,plotHeight,xMinimum,xMaximum,yMinimum,yMaximum,xLabel,yLabel);
svg = [svg(:); axisText(:)];
for iSeries = 1:numel(seriesKeys)
    keyParts = split(seriesKeys(iSeries),"|");
    series = completeRows([completeRows.datasetId] == keyParts(1) & [completeRows.transformId] == keyParts(2));
    [~,order] = sort([series.resolution]);
    series = series(order);
    x = plotX + (log10([series.resolution])-log10(xMinimum))/(log10(xMaximum)-log10(xMinimum))*plotWidth;
    y = plotY + plotHeight - (log10([series.value])-log10(yMinimum))/(log10(yMaximum)-log10(yMinimum))*plotHeight;
    color = palette(mod(iSeries-1,numel(palette))+1);
    pointText = string(arrayfun(@(xValue,yValue)sprintf('%.3f,%.3f',xValue,yValue),x,y,"UniformOutput",false));
    points = join(pointText(:)'," ",2);
    polyline = '<polyline points="' + points + '" fill="none" stroke="' + color + '" stroke-width="2"/>';
    polyline = join(polyline(:),"");
    svg = [svg(:); polyline];
    for iPoint = 1:numel(series)
        tooltip = series(iPoint).datasetLabel + "; " + displayTransform(series(iPoint).transformId) + "; resolution " + string(series(iPoint).resolution) + "; value " + sprintf('%.6g',series(iPoint).value);
        svg(end+1) = sprintf('<circle cx="%.3f" cy="%.3f" r="4" fill="%s"><title>%s</title></circle>',x(iPoint),y(iPoint),color,xmlEscape(tooltip));
    end
    column = mod(iSeries-1,2);
    row = floor((iSeries-1)/2);
    x = 40 + column*450;
    y = 455 + row*24;
    label = series(1).chartLabel + " — " + displayTransform(series(1).transformId);
    svg(end+1) = sprintf('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="2"/><circle cx="%g" cy="%g" r="4" fill="%s"/>',x,y,x+24,y,color,x+12,y,color);
    svg(end+1) = sprintf('<text x="%g" y="%g" dominant-baseline="middle" font-family="Avenir Next, Avenir, Helvetica, Arial, sans-serif" font-size="10">%s</text>',x+32,y,xmlEscape(label));
end
svg(end+1) = '</svg>';
writeText(path,strjoin(svg,newline));
end

function labels = chartAxisLabels(x,y,width,height,xMinimum,xMaximum,yMinimum,yMaximum,xLabel,yLabel)
font = 'font-family="Avenir Next, Avenir, Helvetica, Arial, sans-serif" font-size="9" fill="#333"';
labels = strings(0,1);
labels(end+1) = sprintf('<text x="%g" y="%g" %s>%s</text>',x,y+height+13,font,formatNumber(xMinimum));
labels(end+1) = sprintf('<text x="%g" y="%g" text-anchor="end" %s>%s</text>',x+width,y+height+13,font,formatNumber(xMaximum));
labels(end+1) = sprintf('<text x="%g" y="%g" %s>%s</text>',x-5,y+height,font,formatNumber(yMinimum));
labels(end+1) = sprintf('<text x="%g" y="%g" %s>%s</text>',x-5,y+8,font,formatNumber(yMaximum));
labels(end+1) = sprintf('<text x="%g" y="%g" text-anchor="middle" %s>%s</text>',x+width/2,y+height+27,font,xmlEscape(xLabel));
labels(end+1) = sprintf('<text x="%g" y="%g" text-anchor="middle" transform="rotate(-90 %g %g)" %s>%s</text>',x-38,y+height/2,x-38,y+height/2,font,xmlEscape(yLabel));
end

function [minimum,maximum] = logarithmicLimits(values)
minimum = min(values);
maximum = max(values);
if minimum == maximum
    minimum = minimum/sqrt(2);
    maximum = maximum*sqrt(2);
else
    padding = 0.05*(log10(maximum)-log10(minimum));
    minimum = 10^(log10(minimum)-padding);
    maximum = 10^(log10(maximum)+padding);
end
end

function table = scalingTable(rows,metricName)
body = strings(numel(rows),7);
for iRow = 1:numel(rows)
    value = "Unavailable";
    if rows(iRow).status == "complete"
        if metricName == "runtime"
            value = formatSeconds(rows(iRow).value);
        else
            value = sprintf('%.3g GiB',rows(iRow).value);
        end
    end
    body(iRow,:) = [rows(iRow).suiteId,displayTransform(rows(iRow).transformId),rows(iRow).datasetLabel,string(rows(iRow).resolution),value,rows(iRow).status,rows(iRow).reason];
end
body = sortrows(body,[1 2 4 3]);
table = markdownTable(["Suite" "Transform" "Dataset" "Resolution" "Value" "Status" "Reason"],body);
end

function markdown = computerMarkdown(records)
records = latestEnvironmentRecords(records);
if isempty(records)
    markdown = "No approved computer results have been published yet.";
    return
end
rows = strings(numel(records),7);
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    rows(iRecord,:) = [ ...
        string(dataset.implementation.displayName) + " " + string(dataset.implementation.version) + " (" + string(dataset.implementation.backend) + ")", ...
        string(dataset.platform.displayName), ...
        string(dataset.platform.processor), ...
        formatBytes(dataset.platform.physicalMemoryBytes), ...
        string(dataset.platform.os) + " / " + string(dataset.platform.architecture), ...
        string(dataset.toolchain.name) + " " + string(dataset.toolchain.version), ...
        string(dataset.platform.threadCount)];
end
rows = sortrows(rows,[2 1]);
markdown = markdownTable(["Implementation" "Platform" "Processor" "Physical memory" "OS / architecture" "Toolchain" "Threads"],rows);
end

function records = latestEnvironmentRecords(records)
if isempty(records)
    return
end
indicesByKey = containers.Map("KeyType","char","ValueType","double");
platformsByKey = containers.Map("KeyType","char","ValueType","any");
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    key = char(environmentKey(dataset));
    if isKey(platformsByKey,key) && ~isequaln(platformsByKey(key),dataset.platform)
        error("WaveVortexModel:ConflictingPublishedPlatform","Published datasets disagree about platform %s.",string(dataset.platform.id));
    end
    platformsByKey(key) = dataset.platform;
    if ~isKey(indicesByKey,key) || collectionTime(dataset) > collectionTime(records(indicesByKey(key)).dataset)
        indicesByKey(key) = iRecord;
    end
end
records = records(sort(cell2mat(values(indicesByKey))));
end

function markdown = historyMarkdown(records)
groups = containers.Map("KeyType","char","ValueType","any");
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    for iCase = 1:numel(dataset.cases)
        benchmarkCase = itemAt(dataset.cases,iCase);
        key = char(environmentKey(dataset) + "|" + comparisonCaseKey(dataset,benchmarkCase));
        row = struct("dataset",dataset,"benchmarkCase",benchmarkCase);
        if isKey(groups,key)
            valuesForKey = groups(key);
            valuesForKey(end+1) = row;
            groups(key) = valuesForKey;
        else
            groups(key) = row;
        end
    end
end

rows = strings(0,7);
groupKeys = sort(string(keys(groups)));
for key = groupKeys
    valuesForKey = groups(char(key));
    versions = unique(arrayfun(@(value)string(value.dataset.implementation.version),valuesForKey));
    if numel(versions) < 2
        continue
    end
    for value = valuesForKey
        benchmarkCase = value.benchmarkCase;
        runtime = "Unavailable";
        memory = "Unavailable";
        if string(benchmarkCase.status) == "complete"
            runtime = formatSeconds(benchmarkCase.timing.medianSeconds);
            if string(benchmarkCase.memory.status) == "complete"
                memory = formatBytes(benchmarkCase.memory.peakProcessBytes);
            end
        end
        rows(end+1,:) = [ ...
            string(value.dataset.platform.displayName), ...
            string(value.dataset.implementation.displayName), ...
            string(value.dataset.implementation.version), ...
            string(value.dataset.benchmark.suiteId), ...
            string(benchmarkCase.id), ...
            runtime,memory];
    end
end
if isempty(rows)
    markdown = "";
    return
end
rows = unique(sortrows(rows,[1 2 4 5 3]),"rows","stable");
markdown = "## Performance across releases" + newline + newline + ...
    "This section appears only when matching platform, toolchain, suite, and case configurations exist for at least two WaveVortexModel versions." + newline + newline + ...
    "<details markdown=""1"">" + newline + "<summary>View comparable release history</summary>" + newline + newline + ...
    markdownTable(["Platform" "Implementation" "Version" "Suite" "Case" "Median runtime" "Peak process memory"],rows) + newline + newline + "</details>";
end

function markdown = downloadsMarkdown(records)
if isempty(records)
    markdown = "No approved result files have been published yet.";
    return
end
rows = strings(numel(records),7);
for iRecord = 1:numel(records)
    dataset = records(iRecord).dataset;
    datasetId = string(dataset.datasetId);
    rows(iRecord,:) = [ ...
        datasetId, ...
        string(dataset.implementation.displayName) + " " + string(dataset.implementation.version), ...
        string(dataset.platform.displayName), ...
        string(dataset.benchmark.suiteId), ...
        string(dataset.collectedAt), ...
        "[Published JSON](/benchmarks/data/" + datasetId + ".json)", ...
        "[Raw JSON](/benchmarks/raw/" + datasetId + ".json)"];
end
rows = sortrows(rows,1);
markdown = markdownTable(["Dataset" "Implementation" "Platform" "Suite" "Collected" "Normalized" "Raw artifact"],rows);
end

function markdown = markdownTable(headers,rows)
headers = escapeMarkdownCell(headers);
rows = escapeMarkdownCell(rows);
lines = ["| " + strjoin(headers," | ") + " |"; "| " + strjoin(repmat("---",size(headers))," | ") + " |"];
for iRow = 1:size(rows,1)
    lines(end+1,1) = "| " + strjoin(rows(iRow,:)," | ") + " |";
end
markdown = strjoin(lines,newline);
end

function values = escapeMarkdownCell(values)
values = string(values);
values = replace(values,"|","\|");
values = replace(values,newline," ");
values(values == "") = "—";
end

function benchmarkCase = caseWithId(dataset,caseId)
benchmarkCase = [];
for iCase = 1:numel(dataset.cases)
    candidate = itemAt(dataset.cases,iCase);
    if string(candidate.id) == caseId
        benchmarkCase = candidate;
        return
    end
end
end

function item = itemAt(items,index)
if iscell(items)
    item = items{index};
else
    item = items(index);
end
end

function key = environmentKey(dataset)
details = dataset.toolchain.details;
if isstruct(details)
    details = orderfields(details);
end
key = string(dataset.implementation.id) + "|" + string(dataset.implementation.backend) + "|" + string(dataset.platform.id) + "|" + string(dataset.toolchain.kind) + "|" + string(dataset.toolchain.name) + "|" + string(dataset.toolchain.version) + "|" + string(jsonencode(details));
end

function value = collectionTime(dataset)
value = datetime(string(dataset.collectedAt),"InputFormat","yyyy-MM-dd'T'HH:mm:ss'Z'","TimeZone","UTC");
end

function label = datasetLabel(dataset)
label = string(dataset.platform.displayName) + " — " + string(dataset.implementation.displayName) + " " + string(dataset.implementation.version) + " (" + string(dataset.implementation.backend) + "; " + string(dataset.toolchain.name) + " " + string(dataset.toolchain.version) + ")";
end

function label = chartLabel(dataset)
label = string(dataset.platform.displayName) + " — " + string(dataset.toolchain.name);
if string(dataset.toolchain.kind) == "matlab" && isfield(dataset.toolchain.details,"matlabRelease")
    label = label + " R" + string(dataset.toolchain.details.matlabRelease);
    update = string(regexp(string(dataset.toolchain.version),'Update \d+','match','once'));
    if update ~= ""
        label = label + " " + update;
    end
else
    label = label + " " + string(dataset.toolchain.version);
end
end

function displayName = displayTransform(transformId)
identifiers = ["constant-nonhydrostatic" "constant-hydrostatic" "hydrostatic" "boussinesq" "stratified-qg" "barotropic-qg"];
names = ["Constant nonhydrostatic" "Constant hydrostatic" "Variable hydrostatic" "Variable Boussinesq" "Stratified QG" "Barotropic QG"];
index = find(identifiers == transformId,1);
if isempty(index)
    displayName = transformId;
else
    displayName = names(index);
end
end

function value = formatSeconds(seconds)
value = sprintf('%.4g s',double(seconds));
end

function value = formatBytes(bytes)
value = sprintf('%.3g GiB',double(bytes)/2^30);
end

function value = formatNumber(number)
value = sprintf('%.3g',double(number));
end

function value = xmlEscape(value)
value = replace(string(value),"&","&amp;");
value = replace(value,"<","&lt;");
value = replace(value,">","&gt;");
value = replace(value,"""","&quot;");
value = replace(value,"'","&apos;");
end

function absolutePath = repositoryFile(repositoryRoot,relativePath,label)
parts = split(relativePath,"/");
if startsWith(relativePath,["/" "\"]) || ~isempty(regexp(relativePath,"^[A-Za-z]:","once")) || contains(relativePath,"\") || any(parts == "..") || any(parts == "")
    error("WaveVortexModel:UnsafeBenchmarkPath","The %s path must be repository-relative and cannot contain traversal: %s.",label,relativePath);
end
absolutePath = fullfile(repositoryRoot,relativePath);
if ~isfile(absolutePath)
    error("WaveVortexModel:MissingBenchmarkArtifact","The %s does not exist: %s.",label,relativePath);
end
end

function pageText = replaceGeneratedSection(pageText,sectionName,content)
startMarker = "<!-- BENCHMARKS:" + sectionName + ":START -->";
endMarker = "<!-- BENCHMARKS:" + sectionName + ":END -->";
expression = "(?s)" + regexptranslate("escape",startMarker) + ".*?" + regexptranslate("escape",endMarker);
matches = regexp(pageText,expression,"match");
if numel(matches) ~= 1
    error("WaveVortexModel:InvalidBenchmarkPageMarkers","The Benchmarks page must contain exactly one %s generated section.",sectionName);
end
replacement = startMarker + newline;
if content ~= ""
    replacement = replacement + content + newline;
end
replacement = replacement + endMarker;
pageText = regexprep(pageText,expression,replacement);
end

function writeText(path,text)
fileId = fopen(path,"w");
if fileId < 0
    error("WaveVortexModel:DocumentationWriteFailed","Unable to write %s.",path);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",text);
clear cleanup
end
