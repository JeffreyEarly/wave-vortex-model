function result = validatePortableCompatibilityMatrix(matrix,options)
% Validate source freshness, exact fixture scopes, and authoritative completeness.
arguments
    matrix (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
    options.expected = []
    options.requireComplete (1,1) logical = false
end
root=options.repositoryRoot;
require(string(matrix.schema)=="portable-compatibility-matrix-v1" && matrix.schemaVersion==1 && string(matrix.slice)=="standard","Unknown standard assembly.");
require(logical(matrix.readiness.standardParityReady) && string(matrix.readiness.decision)=="STANDARD-PORTABLE-PARITY","Final standard parity requires the explicit STANDARD-PORTABLE-PARITY decision.");
sourceIds=string({matrix.sources.id}); witnessIds=string({matrix.witnesses.id}); rowIds=string({matrix.rows.id});
require(numel(unique(sourceIds))==numel(sourceIds),"Duplicate source identity.");
require(numel(unique(witnessIds))==numel(witnessIds),"Duplicate fixture identity.");
require(numel(unique(rowIds))==numel(rowIds),"Duplicate row identity.");
for source=reshape(matrix.sources,1,[])
    path=string(source.path);
    require(~startsWith(path,"/") && ~contains(path,"..") && ~contains(path,"\"),"Invalid repository source path.");
    require(isfile(fullfile(root,path)),"Missing source: "+path);
    require(string(source.sha256)==portableCompatibilitySHA256(fullfile(root,path)),"Stale source: "+path);
end
for witness=reshape(matrix.witnesses,1,[])
    source=fileread(fullfile(root,string(witness.path)));
    symbol=regexptranslate('escape',char(witness.symbol));
    if endsWith(string(witness.path),".m")
        pattern=['(?m)^\s*function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?' symbol '\s*\('];
    else
        pattern=['\<' symbol '\s*\('];
    end
    require(~isempty(regexp(source,pattern,'once')),"Unresolved fixture symbol: "+string(witness.id));
    declared=reshape(string(witness.coverage.rowIds),1,[]);
    expected=strings(1,0);
    for row=reshape(matrix.rows,1,[])
        if ismember(string(witness.id),string(row.fixtures)), expected(end+1)=string(row.id); end %#ok<AGROW>
    end
    require(numel(unique(declared))==numel(declared) && isequal(sort(declared),sort(expected)),"Contradictory fixture row scope: "+string(witness.id));
end
for row=reshape(matrix.rows,1,[])
    require(ismember(string(row.sourceId),sourceIds),"Unresolved row source.");
    require(ismember(string(row.status),["supported","intentional-incompatibility","unqualified"]),"Unknown support decision.");
    require(all(ismember(string(row.fixtures),witnessIds)),"Unresolved row fixture.");
    if string(row.status)=="unqualified"
        require(isfield(row,"issue") && row.issue>=1 && strlength(string(row.reason))>0,"Untracked qualification gap.");
    else
        require(~isempty(row.fixtures),"Support or rejection lacks a fixture.");
    end
end
hasGaps=any(string({matrix.rows.status})=="unqualified");
require((string(matrix.completion)=="incomplete")==hasGaps,"Completion contradicts exact-pair coverage.");
if matrix.readiness.standardParityReady
    require(string(matrix.completion)=="complete" && ~hasGaps,"STANDARD-PORTABLE-PARITY requires complete coverage with zero unqualified rows.");
end
expected=options.expected;
if isempty(expected), expected=portableCompatibilityDefinition(root); end
require(isequaln(jsondecode(jsonencode(matrix)),jsondecode(jsonencode(expected))),"Assembly differs from current authoritative slices or fixture scopes.");
if options.requireComplete && hasGaps
    error("WaveVortexModel:CompatibilityIncomplete","Standard compatibility still contains tracked unqualified rows.");
end
result=struct(rowCount=numel(matrix.rows),witnessCount=numel(matrix.witnesses),unqualifiedCount=sum(string({matrix.rows.status})=="unqualified"));
end
function require(condition,message)
    if ~condition, error("WaveVortexModel:InvalidCompatibilityMatrix","%s",message); end
end
