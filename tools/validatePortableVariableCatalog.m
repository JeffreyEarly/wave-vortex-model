function validatePortableVariableCatalog(catalog)
% Validate the generated metadata graph before publishing either artifact.
names = string({catalog.variables.name});
ids = double([catalog.variables.ordinal]);
if ~isequal(ids,0:numel(names)-1) || numel(unique(names))~=numel(names) || numel(names)>=255
    invalid("Variable names and byte ordinals must be unique, contiguous and below 255.");
end
configurations = reshape(string(catalog.configurations),1,[]);
if ~isequal(reshape(string({catalog.configurationMetadata.id}),1,[]),configurations)
    invalid("Missing or contradictory transform configuration metadata.");
end
rows = catalog.contracts;
rowKeys = string({rows.configuration}) + "/" + string([rows.ordinal]);
if numel(unique(rowKeys))~=numel(rowKeys) || numel(unique(configurations))~=numel(configurations)
    invalid("Duplicate configuration or diagnostic row.");
end
intermediateIds = double([catalog.intermediates.ordinal]);
if ~isequal(intermediateIds,0:numel(intermediateIds)-1) || numel(intermediateIds)>63 || ...
        numel(unique(string({catalog.intermediates.name})))~=numel(intermediateIds)
    invalid("Intermediate names and ordinals must be unique and contiguous.");
end
for row = reshape(rows,1,[])
    m = row.metadata;
    if string(row.catalogStatus)~="supported" || ~isequal(string(row.netCDF.dimensionNames),string(m.dimensions)) || ...
            ~isequal(string(row.netCDF.coordinateRoles),string(m.dimensions))
        invalid("NetCDF dimension roles or catalog status contradict metadata.");
    end
    if row.ordinal<0 || row.ordinal>=numel(names) || m.ordinal~=row.ordinal || ...
            string(m.name)~=names(row.ordinal+1) || ~ismember(string(row.configuration),configurations)
        invalid("A configuration row contradicts its catalog identity.");
    end
    if isempty(m.units) || isempty(m.description) || numel(m.dimensions)>3 || ...
            ~ismember(string(row.runtimeStatus),["implemented","pending-305","pending-315"])
        invalid("Incomplete diagnostic metadata or runtime status.");
    end
    modes = string(m.samplingModes);
    if isempty(modes) || any(~ismember(modes,["coefficients","fullGrid","fixedVerticalProfiles","positions"])) || ...
            numel(unique(modes))~=numel(modes)
        invalid("Invalid sampling contract.");
    end
    if (string(m.naturalRank)=="coefficient" && any(modes~="coefficients")) || ...
            (string(m.naturalRank)~="coefficient" && any(modes=="coefficients"))
        invalid("Sampling mode contradicts the natural rank.");
    end
    if uint64(row.intermediateMask)>=bitshift(uint64(1),numel(intermediateIds))
        invalid("Unknown reusable intermediate bit.");
    end
    if isstruct(m.netCDFAttributes) && numel(unique(string({m.netCDFAttributes.name})))~=numel(m.netCDFAttributes)
        invalid("Duplicate NetCDF attributes.");
    end
end
for configuration = configurations
    selected = rows(string({rows.configuration})==configuration);
    available = arrayfun(@(r)string(r.metadata.name),selected);
    edges = zeros(0,2);
    for iRow = 1:numel(selected)
        deps = [reshape(string(selected(iRow).dependencies),1,[]), ...
            reshape(string(selected(iRow).trueProfileDependencies),1,[])];
        [present,indices] = ismember(deps,available);
        if any(~present) || numel(unique(deps))~=numel(deps)
            error("WaveVortexModel:InvalidPortableVariableDependency", ...
                "Missing or duplicate dependency of %s in %s.",available(iRow),configuration);
        end
        edges = [edges;[repmat(iRow,numel(indices),1),indices(:)]]; %#ok<AGROW>
    end
    if ~isdag(digraph(edges(:,1),edges(:,2),[],numel(selected)))
        error("WaveVortexModel:InvalidPortableVariableDependency","Dependency cycle in %s.",configuration);
    end
end
end

function invalid(message)
error("WaveVortexModel:InvalidPortableVariableCatalog","%s",message);
end
