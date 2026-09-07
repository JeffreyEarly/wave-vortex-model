function result = generatePortableForcingCompatibility(options)
% Generate the forcing slice from MATLAB attachment and portable evidence.
%
% This developer tool probes the baseline constant-stratification and
% Barotropic QG configurations. It does not qualify numerical parity or
% change model behavior. The supplement owns implementation/evidence facts;
% MATLAB owns inventory membership, applicability, stages and priority.
arguments (Input)
    options.outputRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
root = string(fileparts(fileparts(mfilename("fullpath"))));
supplement = jsondecode(fileread(fullfile(root,"PortableRuntime","contracts","portable-forcing-evidence-v1.json")));
source = string(fileread(fullfile(root,supplement.inventorySource)));
section = extractBetween(source,"## Forcing and closures","## Observing systems");
names = sort(string(regexp(section,'(?m)^- `(WV\w+)`','tokens')));
expected = sort(string({supplement.forcings.identity}));
if ~isequal(names(:),expected(:))
    error("WaveVortexModel:CompatibilityInventoryMismatch","The evidence inventory differs from the documented stable MATLAB inventory.");
end
files = dir(fullfile(root,"Forcing","*.m"));
actual = sort(erase(string({files.name}),".m"));
if ~isequal(actual(:),sort([names(:); string({supplement.excluded.identity})'])) || ~contains(section,"`WVThermalDamping` is under development")
    error("WaveVortexModel:CompatibilityInventoryMismatch","Every supplied forcing requires a current stable or excluded inventory entry.");
end
configurations = struct('id',{},'transform',{},'isHydrostatic',{},'shouldAntialias',{});
rows = struct('id',{},'forcing',{},'contractVersion',{},'configuration',{},'matlab',{},'implementation',{},'acceptance',{},'evidence',{},'barotropicCase',{});
for family = ["constant-hydrostatic","constant-nonhydrostatic","barotropic","stratified-qg"]
    for shouldAntialias = [false true]
        isBarotropic = family == "barotropic";
        isStratifiedQG = family == "stratified-qg";
        isHydrostatic = family ~= "constant-nonhydrostatic";
        identity = "WVTransformConstantStratification";
        if isBarotropic
            identity = "WVTransformBarotropicQG";
        end
        if isStratifiedQG, identity = "WVTransformStratifiedQG"; end
        configuration = struct(id=family+"-aa"+double(shouldAntialias),transform=identity,isHydrostatic=isHydrostatic,shouldAntialias=shouldAntialias);
        configurations(end+1) = configuration; %#ok<AGROW>
        for iForce = 1:numel(supplement.forcings)
            definition = supplement.forcings(iForce);
            if isStratifiedQG
                wvt = WVTransformStratifiedQG([17000 11000 1000],[8 6 9],Nj=4,N2Function=@(z) 1e-4*exp(z/700),shouldAntialias=shouldAntialias);
                available = definition.stratifiedQGFactory;
                evidence = string(definition.stratifiedQGEvidence);
                caseName = "";
            elseif isBarotropic
                wvt = WVTransformBarotropicQG([17000 11000],[8 6],j=1,shouldAntialias=shouldAntialias);
                available = definition.barotropicFactory;
                evidence = string(definition.barotropicEvidence);
                caseName = string(definition.barotropicCase);
            else
                wvt = WVTransformConstantStratification([17000 11000 1000],[8 6 5],N0=5.2e-3,isHydrostatic=isHydrostatic,shouldAntialias=shouldAntialias);
                available = definition.constantFactory;
                evidence = string(definition.constantEvidence);
                caseName = "";
            end
            wvt.removeAllForcing();
            scientific = probeForcing(wvt,string(definition.identity));
            acceptance = "pending";
            if string(supplement.qualification) == "baseline-v1"
                if scientific.applicability == "incompatible"
                    acceptance = "incompatible";
                    evidence = ["baseline-rejections","matlab-attachment"];
                    if isStratifiedQG, evidence = ["sqg-rejections","matlab-attachment"]; end
                elseif available
                    acceptance = "supported";
                end
            end
            implementation = struct(factoryAvailable=available,issue=definition.implementationIssue);
            if available
                implementation.issue = 0;
            end
            rows(end+1) = struct(id=configuration.id+"/"+definition.identity,forcing=string(definition.identity), ...
                contractVersion=definition.contractVersion,configuration=configuration.id,matlab=scientific, ...
                implementation=implementation,acceptance=acceptance,evidence=reshape(evidence,1,[]),barotropicCase=caseName); %#ok<AGROW>
        end
    end
end
completion = "incomplete";
if ~any(string({rows.acceptance}) == "pending"), completion = "complete"; end
matrix = struct(schema="portable-compatibility-matrix-v1",schemaVersion=1,slice="forcing",completion=completion, ...
    inventory=struct(source=string(supplement.inventorySource),stable=reshape(names,1,[]),excluded=supplement.excluded), ...
    configurations=configurations,evidence=supplement.evidence,rows=rows);
validatePortableForcingCompatibility(matrix,repositoryRoot=root);
contractFolder = fullfile(options.outputRoot,"PortableRuntime","contracts");
headerFolder = fullfile(options.outputRoot,"PortableRuntime","tests","generated");
if ~isfolder(contractFolder), mkdir(contractFolder); end
if ~isfolder(headerFolder), mkdir(headerFolder); end
catalogPath = fullfile(contractFolder,"portable-forcing-compatibility-v1.json");
headerPath = fullfile(headerFolder,"WVForcingCompatibilityRows.hpp");
% JSON collections must stay arrays even when MATLAB holds one element.
serialized = matrix;
serialized.inventory.stable = cellstr(string(matrix.inventory.stable));
serialized.inventory.excluded = num2cell(matrix.inventory.excluded);
serialized.configurations = num2cell(matrix.configurations);
serialized.evidence = num2cell(matrix.evidence);
for iRow = 1:numel(serialized.rows)
    serialized.rows(iRow).matlab.forcingTypes = cellstr(string(matrix.rows(iRow).matlab.forcingTypes));
    serialized.rows(iRow).matlab.activeTypes = cellstr(string(matrix.rows(iRow).matlab.activeTypes));
    serialized.rows(iRow).evidence = cellstr(string(matrix.rows(iRow).evidence));
end
serialized.rows = num2cell(serialized.rows);
writeText(catalogPath,string(jsonencode(serialized,PrettyPrint=true))+newline);
writeText(headerPath,generatedHeader(matrix));
result = struct(matrix=matrix,catalogPath=catalogPath,headerPath=headerPath);
end

function record = probeForcing(wvt,identity)
record = struct(applicability="applicable",forcingTypes=strings(1,0),activeTypes=strings(1,0),priority=0,rejection="");
try
    switch identity
        case "WVPseudoTopographicWaveGeneration"
            force = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=zeros(wvt.Nx,wvt.Ny),barotropicVelocityAmplitude=[0.01;0],frequency=1e-4);
        case "WVNarrowBandGeostrophicForcing"
            force = WVNarrowBandGeostrophicForcing(wvt,initialPV="none",k_f=2*wvt.dk,j_f=1);
        case "WVFixedAmplitudeForcing"
            force = WVFixedAmplitudeForcing(wvt,name="catalog fixed amplitude");
        case "WVAntialiasing"
            force = WVAntialiasing(wvt,Nj=1);
        otherwise
            force = feval(identity,wvt);
    end
catch exception
    % Only this exact MATLAB constructor rejection is scientific evidence.
    % Unexpected errors must stop generation rather than invent incompatibility.
    if identity == "WVAntialiasing" && wvt.shouldAntialias && string(exception.identifier) == "WVAntialiasing:AntialiasingNotSupported"
        record.applicability = "incompatible";
        record.rejection = "double-antialias";
        return
    end
    if identity == "WVPseudoTopographicWaveGeneration" && (isa(wvt,"WVTransformBarotropicQG") || isa(wvt,"WVTransformStratifiedQG")) && string(exception.identifier) == "WVPseudoTopographicWaveGeneration:UnsupportedTransform"
        record.applicability = "incompatible";
        record.rejection = "wave-transform-required";
        return
    end
    rethrow(exception)
end
record.forcingTypes = reshape(sort(string(force.forcingType)),1,[]);
record.activeTypes = reshape(sort(string(intersect(force.forcingType,wvt.forcingType))),1,[]);
record.priority = double(force.priority);
if isempty(record.activeTypes)
    try
        wvt.addForcing(force);
    catch exception
        if string(exception.identifier) == "" && startsWith(string(exception.message),"The transform does not support exactly one forcing category")
            record.applicability = "incompatible";
            record.rejection = "forcing-stage-unavailable";
            return
        end
        rethrow(exception)
    end
    error("WaveVortexModel:CompatibilityAttachmentMismatch","MATLAB accepted a forcing without an applicable stage.");
end
wvt.addForcing(force);
end

function text = generatedHeader(matrix)
lines = ["// Generated by tools/generatePortableForcingCompatibility.m. Do not edit."; ...
    "#pragma once"; "#include <array>"; "#include <cstdint>"; ...
    "namespace wavevortex::runtime::test {"; ...
    "struct ForcingCompatibilityRow { const char *identity; bool barotropic; bool stratifiedQG; bool antialias; bool applicable; bool factoryAvailable; std::uint32_t version; std::uint8_t priority; const char *stage; };"; ...
    "inline constexpr std::array<ForcingCompatibilityRow, "+numel(matrix.rows)+"> forcingCompatibilityRows{{"];
for row = matrix.rows
    stages = row.matlab.activeTypes;
    stage = "";
    if ~isempty(stages), stage = stages(1); end
    lines(end+1) = "  {"""+row.forcing+""", "+cppBoolean(startsWith(row.configuration,"barotropic"))+", "+cppBoolean(startsWith(row.configuration,"stratified-qg"))+", "+cppBoolean(endsWith(row.configuration,"aa1"))+", "+ ...
        cppBoolean(row.matlab.applicability == "applicable")+", "+cppBoolean(row.implementation.factoryAvailable)+", "+ ...
        row.contractVersion+", "+row.matlab.priority+", """+stage+"""},"; %#ok<AGROW>
end
lines = [lines; "}};"; "} // namespace wavevortex::runtime::test"];
text = join(lines,newline)+newline;
end

function value = cppBoolean(value)
if value, value = "true"; else, value = "false"; end
end

function writeText(path,text)
[file,message] = fopen(path,"w");
if file < 0, error("WaveVortexModel:CompatibilityWriteFailed","%s",message); end
cleanup = onCleanup(@()fclose(file));
fprintf(file,"%s",text);
end
