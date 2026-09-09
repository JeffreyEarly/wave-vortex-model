function report = collectPortableForwardIntegrationQualification(evidenceDirectory,provider,options)
% Assemble six retained case fragments without relabeling their execution.
arguments
    evidenceDirectory (1,1) string {mustBeFolder}
    provider (1,1) string {mustBeMember(provider,["reference","native-fftw"])}
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
root = options.repositoryRoot;
catalogPath = fullfile(root,"PortableRuntime","contracts","portable-forward-integration-v1.json");
catalog = jsondecode(fileread(catalogPath));
validatePortableForwardIntegrationCatalog(catalog,repositoryRoot=root);
fragments = cell(1,numel(catalog.cases));
paths = strings(1,numel(catalog.cases));
provenance = ["schema","schemaVersion","scope","status","sourceCommit","provider","matlabRelease", ...
    "platform","catalogSHA256","sourceSHA256","executionBinaries","buildSource"];
for k = 1:numel(catalog.cases)
    definition = catalog.cases(k);
    paths(k) = fullfile(evidenceDirectory,string(definition.id)+"-"+provider+".json");
    require(isfile(paths(k)),"Missing case fragment: "+paths(k));
    fragment = jsondecode(fileread(paths(k)));
    require(isstruct(fragment) && isscalar(fragment) && all(isfield(fragment,[provenance,"cases"])),"Incomplete fragment or execution provenance: "+paths(k));
    require(isscalar(fragment.cases) && string(fragment.cases.id)==string(definition.id) && string(fragment.provider)==provider,"Unexpected fragment case or provider: "+paths(k));
    require(isstruct(fragment.buildSource) && isscalar(fragment.buildSource) && all(isfield(fragment.buildSource,["root","commit"])),"Missing build source identity: "+paths(k));
    require(strlength(string(fragment.buildSource.root))>0 && ~isempty(regexp(string(fragment.buildSource.commit),'^[a-f0-9]{40}$','once')),"Invalid build source identity: "+paths(k));
    require(isstruct(fragment.executionBinaries) && all(isfield(fragment.executionBinaries,"sourceCommit")) && all(string({fragment.executionBinaries.sourceCommit})==string(fragment.buildSource.commit)),"Executable and build source identities disagree: "+paths(k));
    for field = provenance
        if k>1
            require(isequaln(fragment.(field),fragments{1}.(field)),"Mixed execution provenance ("+field+"): "+paths(k));
        end
    end
    fragments{k} = fragment;
end
report = fragments{1};
report.cases = cellfun(@(fragment)fragment.cases,fragments);
report.artifacts = struct(path={},sha256={});
% Content-addressed copies preserve any previously published receipt even if
% strict validation rejects this candidate after its fragments are retained.
for k = 1:numel(paths)
    digest = portableForwardIntegrationSHA256(paths(k));
    relative = "PortableRuntime/qualification/forward-integration-evidence-v1/"+string(catalog.cases(k).id)+"-"+provider+"-"+digest+".json";
    destination = fullfile(root,relative);
    if isfile(destination)
        require(portableForwardIntegrationSHA256(destination)==digest,"Retained evidence has changed: "+relative);
    else
        if ~isfolder(fileparts(destination)), mkdir(fileparts(destination)); end
        [copied,message] = copyfile(paths(k),destination);
        require(copied,"Cannot retain execution fragment: "+string(message));
    end
    report.artifacts(end+1) = struct(path=relative,sha256=digest);
end
validatePortableForwardIntegrationQualification(report,catalog,repositoryRoot=root);
outputPath = fullfile(root,"PortableRuntime","qualification","forward-integration-"+provider+"-v1.json");
encoded = jsonencode(report,PrettyPrint=true);
fid = fopen(outputPath,"w");
require(fid>=0,"Cannot write assembled qualification: "+outputPath);
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,"%s\n",encoded);
end

function require(condition,message)
if ~condition, error("WaveVortexModel:InvalidForwardIntegrationAssembly","%s",message); end
end
