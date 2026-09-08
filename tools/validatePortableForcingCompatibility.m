function validatePortableForcingCompatibility(matrix,options)
% Validate the forcing slice, exact evidence and baseline completeness.
%
% CI executes the referenced catalog-driven parity and rejection tests.
% Structural validation alone is not a numerical qualification run.
arguments (Input)
    matrix (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
    options.requireComplete (1,1) logical = false
end
require(isequal(sort(string(fieldnames(matrix))),sort(["schema";"schemaVersion";"slice";"completion";"inventory";"configurations";"evidence";"rows"])),"Unexpected matrix fields.");
require(string(matrix.schema) == "portable-compatibility-matrix-v1" && matrix.schemaVersion == 1 && string(matrix.slice) == "forcing","Unknown matrix identity/version/slice.");
require(ismember(string(matrix.completion),["incomplete","complete"]),"Unknown completion status.");
names = string(matrix.inventory.stable(:));
require(~isempty(names) && numel(unique(names)) == numel(names) && isequal(names,sort(names)),"Stable identities must be unique and sorted.");
configs = string({matrix.configurations.id});
require(numel(unique(configs)) == numel(configs) && numel(configs) == 12,"The forcing slice requires twelve unique configurations.");
expectedConfigs = strings(1,0);
for family = ["constant-hydrostatic","constant-nonhydrostatic","barotropic","stratified-qg","hydrostatic","boussinesq"]
    for antialias = [false true]
        key = family+"-aa"+double(antialias);
        expectedConfigs(end+1) = key; %#ok<AGROW>
        config = matrix.configurations(configs == key);
        require(isscalar(config),"Missing baseline configuration.");
        transform = "WVTransformConstantStratification";
        if family == "barotropic", transform = "WVTransformBarotropicQG"; end
        if family == "stratified-qg", transform = "WVTransformStratifiedQG"; end
        if family == "hydrostatic", transform = "WVTransformHydrostatic"; end
        if family == "boussinesq", transform = "WVTransformBoussinesq"; end
        require(string(config.transform) == transform && config.shouldAntialias == antialias && ...
            config.isHydrostatic == (~ismember(family,["constant-nonhydrostatic","boussinesq"])),"Contradictory configuration identity.");
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
    require(ismember(string(row.acceptance),["pending","supported","incompatible"]),"Unknown acceptance status.");
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
    if string(row.acceptance) == "supported"
        require(applicable && row.implementation.factoryAvailable,"Support requires MATLAB applicability and an executable factory.");
        requiredEvidence = ["baseline-pairs","baseline-compositions"];
        if startsWith(string(row.configuration),"stratified-qg"), requiredEvidence = ["sqg-pairs","sqg-compositions"]; end
        if startsWith(string(row.configuration),"hydrostatic"), requiredEvidence = ["hydro-pairs","hydro-compositions","hydro-continuations"]; end
        if startsWith(string(row.configuration),"boussinesq"), requiredEvidence = ["bouss-pairs","bouss-compositions","bouss-continuations"]; end
        require(all(ismember(requiredEvidence,references)),"Support requires catalog-driven exact-pair parity, append and composition/restart evidence.");
    elseif string(row.acceptance) == "incompatible"
        requiredEvidence = ["baseline-rejections","matlab-attachment"];
        if startsWith(string(row.configuration),"stratified-qg"), requiredEvidence = ["sqg-rejections","matlab-attachment"]; end
        if startsWith(string(row.configuration),"hydrostatic"), requiredEvidence = replace(requiredEvidence,"baseline-","hydro-"); end
        if startsWith(string(row.configuration),"boussinesq"), requiredEvidence = replace(requiredEvidence,"baseline-","bouss-"); end
        require(~applicable && all(ismember(requiredEvidence,references)),"Intentional rejection requires MATLAB attachment and C++ preflight evidence.");
    end
end
complete = ~any(string({matrix.rows.acceptance}) == "pending");
require((string(matrix.completion) == "complete") == complete,"Completion contradicts the row acceptance states.");
if options.requireComplete && ~complete
    error("WaveVortexModel:CompatibilityIncomplete","Forcing acceptance remains pending.");
end
end

function require(condition,message)
if ~condition
    error("WaveVortexModel:InvalidForcingCompatibility","%s",message);
end
end
