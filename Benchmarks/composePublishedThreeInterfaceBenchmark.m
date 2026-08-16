function dataset = composePublishedThreeInterfaceBenchmark(frozenArtifactPath,adaptiveArtifactPath)
% Combine frozen valid cases with one corrected adaptive benchmark case.
arguments
    frozenArtifactPath (1,1) string {mustBeFile}
    adaptiveArtifactPath (1,1) string {mustBeFile}
end
frozen = jsondecode(fileread(frozenArtifactPath));
adaptive = jsondecode(fileread(adaptiveArtifactPath));
validateInput(frozen,"frozen");
validateInput(adaptive,"adaptive");
if string(jsonencode(orderfields(frozen.platform))) ~= string(jsonencode(orderfields(adaptive.platform))) || string(jsonencode(orderfields(frozen.provider))) ~= string(jsonencode(orderfields(adaptive.provider)))
    error("WaveVortexBenchmark:IncompatiblePublishedEvidence","Frozen and adaptive evidence must use the same platform and provider.");
end
frozenIds = arrayfun(@(index)string(itemAt(frozen.cases,index).id),1:numel(frozen.cases));
adaptiveIds = arrayfun(@(index)string(itemAt(adaptive.cases,index).id),1:numel(adaptive.cases));
if ~all(ismember(["nonlinear-flux" "fixed-rk4-continuation"],frozenIds)) || ~isequal(adaptiveIds,"adaptive-rk23-observer-output")
    error("WaveVortexBenchmark:IncompatiblePublishedEvidence","Composition requires frozen nonlinear-flux/fixed-RK4 cases and exactly one corrected adaptive case.");
end
cases = cell(1,3);
cases{1} = withEvidence(caseWithId(frozen,"nonlinear-flux"),frozen);
cases{2} = withEvidence(caseWithId(frozen,"fixed-rk4-continuation"),frozen);
cases{3} = withEvidence(caseWithId(adaptive,"adaptive-rk23-observer-output"),adaptive);
resolution = double(cases{1}.contract.Nxyz(:)');
if any(cellfun(@(value)~isequal(double(value.contract.Nxyz(:)'),resolution),cases))
    error("WaveVortexBenchmark:IncompatiblePublishedEvidence","Every composed case must use the same resolution.");
end
sources = [evidenceRecord(frozen) evidenceRecord(adaptive)];
dataset = struct("schemaVersion","published-three-interface-v2","datasetId",string(adaptive.datasetId),"collectedAt",string(adaptive.collectedAt),"source",adaptive.source,"platform",adaptive.platform,"provider",adaptive.provider,"provenance",struct("composition","frozen-valid-v1-plus-corrected-adaptive","sourceDatasets",sources),"cases",{cases});
end

function validateInput(dataset,role)
if string(dataset.schemaVersion) ~= "published-three-interface-v1" || logical(dataset.source.sourceDirty) || isempty(dataset.cases)
    error("WaveVortexBenchmark:IncompatiblePublishedEvidence","The %s input is not clean published-three-interface-v1 evidence.",role);
end
for index = 1:numel(dataset.cases)
    if ~logical(itemAt(dataset.cases,index).correctness.passed)
        error("WaveVortexBenchmark:IncompatiblePublishedEvidence","The %s input contains a failing case.",role);
    end
end
end

function value = caseWithId(dataset,identifier)
matches = arrayfun(@(index)string(itemAt(dataset.cases,index).id)==identifier,1:numel(dataset.cases));
if nnz(matches) ~= 1
    error("WaveVortexBenchmark:IncompatiblePublishedEvidence","Dataset %s does not contain exactly one %s case.",string(dataset.datasetId),identifier);
end
value = itemAt(dataset.cases,find(matches,1));
end

function value = withEvidence(value,dataset)
value.evidence = evidenceRecord(dataset);
end

function value = evidenceRecord(dataset)
value = struct("datasetId",string(dataset.datasetId),"collectedAt",string(dataset.collectedAt),"source",dataset.source,"externalArchive",dataset.provenance.externalArchive);
end

function item = itemAt(values,index)
if iscell(values)
    item = values{index};
else
    item = values(index);
end
end
