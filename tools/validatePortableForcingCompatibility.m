function validatePortableForcingCompatibility(matrix,options)
% Validate the forcing catalog foundation and its exact evidence references.
%
% requireComplete is a readiness gate, not a structural check. The foundation
% deliberately contains pending acceptance rows and cannot pass this gate.
arguments (Input)
    matrix (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
    options.requireComplete (1,1) logical = false
end
require(isequal(sort(string(fieldnames(matrix))),sort(["schema";"schemaVersion";"slice";"completion";"inventory";"configurations";"evidence";"rows"])),"Unexpected matrix fields.");
require(string(matrix.schema) == "portable-compatibility-matrix-v1" && matrix.schemaVersion == 1 && string(matrix.slice) == "forcing","Unknown matrix identity/version/slice.");
require(string(matrix.completion) == "incomplete","The foundation cannot claim qualification completeness.");
names = string(matrix.inventory.stable(:));
require(~isempty(names) && numel(unique(names)) == numel(names) && isequal(names,sort(names)),"Stable identities must be unique and sorted.");
configs = string({matrix.configurations.id});
require(numel(unique(configs)) == numel(configs) && numel(configs) == 6,"The baseline requires six unique configurations.");
expectedConfigs = strings(1,0);
for family = ["constant-hydrostatic","constant-nonhydrostatic","barotropic"]
    for antialias = [false true]
        key = family+"-aa"+double(antialias);
        expectedConfigs(end+1) = key; %#ok<AGROW>
        config = matrix.configurations(configs == key);
        require(isscalar(config),"Missing baseline configuration.");
        transform = "WVTransformConstantStratification";
        if family == "barotropic", transform = "WVTransformBarotropicQG"; end
        require(string(config.transform) == transform && config.shouldAntialias == antialias && ...
            config.isHydrostatic == (family ~= "constant-nonhydrostatic"),"Contradictory configuration identity.");
    end
end
require(isequal(sort(configs),sort(expectedConfigs)),"Unknown baseline configuration.");
evidenceIds = string({matrix.evidence.id});
require(numel(unique(evidenceIds)) == numel(evidenceIds),"Duplicate evidence identities.");
for evidence = reshape(matrix.evidence,1,[])
    require(ismember(string(evidence.kind),["cpp-unit","matlab-runtime-parity","matlab-contract"]),"Unknown evidence kind.");
    relativePath = string(evidence.path);
    require(~startsWith(relativePath,"/") && ~contains(relativePath,"..") && ~contains(relativePath,"\"),"Evidence paths must be repository-relative.");
    path = fullfile(options.repositoryRoot,relativePath);
    require(isfile(path),"Missing evidence file: "+relativePath);
    source = fileread(path);
    symbol = regexptranslate('escape',char(evidence.symbol));
    if endsWith(relativePath,".m")
        pattern = ['(?m)^\s*function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?' symbol '\s*\('];
    else
        pattern = ['(?m)^void\s+' symbol '\s*\('];
    end
    require(~isempty(regexp(source,pattern,'once')),"Missing evidence function: "+string(evidence.symbol));
end
require(numel(matrix.rows) == numel(names)*numel(configs),"Incomplete forcing/configuration Cartesian inventory.");
keys = string({matrix.rows.id});
require(numel(unique(keys)) == numel(keys),"Duplicate compatibility rows.");
for row = reshape(matrix.rows,1,[])
    require(ismember(string(row.forcing),names) && ismember(string(row.configuration),configs),"Unknown forcing or configuration.");
    require(string(row.id) == string(row.configuration)+"/"+string(row.forcing),"Contradictory row identity.");
    require(row.contractVersion == 1,"Stale portable pair version.");
    require(string(row.acceptance) == "pending","This evidence-mapping foundation cannot advertise qualified support or rejection.");
    applicable = string(row.matlab.applicability) == "applicable";
    require(ismember(string(row.matlab.applicability),["applicable","incompatible"]),"Unknown MATLAB applicability.");
    active = string(row.matlab.activeTypes);
    declared = string(row.matlab.forcingTypes);
    require(all(ismember(active,declared)),"Active stages must be declared by MATLAB.");
    require(isscalar(row.matlab.priority) && row.matlab.priority >= 0 && row.matlab.priority <= 255 && fix(row.matlab.priority) == row.matlab.priority,"Invalid forcing priority.");
    if applicable
        require(isscalar(active) && string(row.matlab.rejection) == "","Applicable rows need exactly one active stage and no rejection.");
    else
        require(isempty(active) && ismember(string(row.matlab.rejection),["double-antialias","forcing-stage-unavailable","wave-transform-required"]),"Incompatibilities need one structured reason and no active stage.");
    end
    require(islogical(row.implementation.factoryAvailable) && isscalar(row.implementation.factoryAvailable),"Factory availability must be Boolean.");
    require(isscalar(row.implementation.issue) && row.implementation.issue >= 0 && fix(row.implementation.issue) == row.implementation.issue,"Invalid implementation issue.");
    if applicable && ~row.implementation.factoryAvailable
        require(row.implementation.issue > 0,"An applicable missing implementation needs a tracked issue.");
    end
    references = string(row.evidence);
    require(numel(unique(references)) == numel(references) && all(ismember(references,evidenceIds)),"Duplicate or unresolved evidence reference.");
    if row.implementation.factoryAvailable && applicable
        require(~isempty(references),"Implemented applicable rows require mapped evidence.");
    end
end
if options.requireComplete
    error("WaveVortexModel:CompatibilityIncomplete","Forcing acceptance is pending; the foundation is not a support qualification.");
end
end

function require(condition,message)
if ~condition
    error("WaveVortexModel:InvalidForcingCompatibility","%s",message);
end
end
