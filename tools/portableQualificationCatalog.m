function [catalog,compatible] = portableQualificationCatalog(report,family,root)
% Check recorded catalog bytes and exact current transform/evidence semantics.
% Historical measurements retain their original catalog digest. Adding an
% unrelated transform does not invalidate them; changing their own rows does.
arguments
    report (1,1) struct
    family (1,1) string {mustBeMember(family,["hydrostatic","stratified-qg"])}
    root (1,1) string
end
currentPath = "PortableRuntime/contracts/portable-forcing-compatibility-v1.json";
archivedPath = "PortableRuntime/qualification/forcing-catalog-through-hydrostatic-v1.json";
catalog = jsondecode(fileread(fullfile(root,currentPath)));
compatible = false;
if ~isfield(report,"catalogPath") || ~ismember(string(report.catalogPath),[currentPath,archivedPath]), return; end
recordedPath = fullfile(root,string(report.catalogPath));
file = fopen(recordedPath,"rb");
if file < 0, return; end
cleanup = onCleanup(@()fclose(file)); bytes = fread(file,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
hash = string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[])));
if string(report.catalogSHA256) ~= hash, return; end
recorded = jsondecode(native2unicode(bytes',"UTF-8"));
oldRows = recorded.rows(startsWith(string({recorded.rows.configuration}),family));
newRows = catalog.rows(startsWith(string({catalog.rows.configuration}),family));
oldConfigs = recorded.configurations(startsWith(string({recorded.configurations.id}),family));
newConfigs = catalog.configurations(startsWith(string({catalog.configurations.id}),family));
if isempty(oldRows) || ~isequal(oldRows,newRows) || ~isequal(oldConfigs,newConfigs) || ~isequal(recorded.inventory,catalog.inventory), return; end
references = strings(0,1);
for row = reshape(oldRows,1,[]), references = [references;string(row.evidence(:))]; end %#ok<AGROW>
for identity = reshape(unique(references),1,[])
    old = recorded.evidence(string({recorded.evidence.id})==identity);
    current = catalog.evidence(string({catalog.evidence.id})==identity);
    if ~isscalar(old) || ~isequal(old,current), return; end
end
compatible = true;
end
