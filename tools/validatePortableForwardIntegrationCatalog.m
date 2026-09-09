function validatePortableForwardIntegrationCatalog(catalog,options)
% Reject contradictory support rows and unresolved integration witnesses.
arguments
    catalog (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
expected = portableForwardIntegrationDefinition();
require(isequaln(jsondecode(jsonencode(catalog)),jsondecode(jsonencode(expected))), ...
    "The integration slice must match its versioned configurations, profiles, rows, witnesses and exclusions.");
for item = reshape(catalog.witnesses,1,[])
    path = fullfile(options.repositoryRoot,string(item.path));
    require(isfile(path),"Missing integration witness: "+string(item.path));
    pattern = "(?m)^\s*function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?"+string(item.symbol)+"\s*\(";
    require(~isempty(regexp(fileread(path),pattern,'once')),"Unresolved witness: "+string(item.symbol));
end
for path = reshape(string(catalog.relatedCatalogs),1,[])
    require(isfile(fullfile(options.repositoryRoot,path)),"Missing related catalog: "+path);
end
for item = reshape(catalog.historicalEvidence,1,[])
    require(isfile(fullfile(options.repositoryRoot,string(item.path))),"Missing historical evidence: "+string(item.path));
end
end

function require(condition,message)
if ~condition, error("WaveVortexModel:InvalidForwardIntegrationCatalog","%s",message); end
end
