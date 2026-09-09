function [expectedNames,validation] = portableQualificationTestInventory(report,family,root,evidenceScope)
% Bind historical workloads independently while keeping current inventories strict.
arguments
    report (1,1) struct
    family (1,1) string {mustBeMember(family,["stratified-qg","hydrostatic","boussinesq"])}
    root (1,1) string
    evidenceScope (1,1) string {mustBeMember(evidenceScope,["current","historical"])}
end
switch family
    case "stratified-qg", errorIdentifier = "WaveVortexModel:InvalidSQGQualification";
    case "hydrostatic", errorIdentifier = "WaveVortexModel:InvalidHydrostaticQualification";
    case "boussinesq", errorIdentifier = "WaveVortexModel:InvalidBoussinesqQualification";
end
inventoryPath = "PortableRuntime/qualification/historical-test-inventory-v1.json";
% Authority is committed here, not accepted from an incoming report or manifest.
inventorySHA256 = "da12f55d18401c52c0c5937d779e7e332fc2b6f13b44cb4cb693652697b068fc";
require(hashFile(fullfile(root,inventoryPath))==inventorySHA256,"Historical inventory authority has changed.");
inventory = jsondecode(fileread(fullfile(root,inventoryPath)));
entry = inventory.entries(string({inventory.entries.family})==family);
require(isscalar(entry),"Missing historical family inventory.");
providers = reshape(string(report.providers),1,[]);
contractsOnly = endsWith(string(report.schemaIdentifier),"-contracts-v1");
% Inventory/numerical validation alone does not establish source freshness.
validation = struct(scope="current-inventory-only",currentReadiness=false,sourceCommit=string(report.sourceCommit));
if evidenceScope=="historical"
    require(string(report.sourceCommit)==string(entry.sourceCommit) && isequal(report.workingTreeDirty,false),"Historical source identity differs from the recorded clean execution.");
    require(hashFile(fullfile(root,entry.reportPath))==string(entry.reportSHA256),"Historical qualification artifact digest changed.");
    recorded = jsondecode(fileread(fullfile(root,entry.reportPath)));
    require(isequal(recorded.workingTreeDirty,false) && string(recorded.sourceCommit)==string(entry.sourceCommit),"Historical artifact contradicts its independent source identity.");
    require(all([recorded.tests.passed]) && ~any([recorded.tests.failed]) && ~any([recorded.tests.incomplete]),"Historical authority contains failed original evidence.");
    expectedNames = reshape(string(entry.testNames),1,[]);
    require(isequal(sort(string({recorded.tests.name})),sort(expectedNames)),"Historical artifact lacks original source-derived tests.");
    if isequal(providers,"reference")
        % These are exact projections of the fully successful archived run.
        % Never derive a subset from caller-supplied results or test names.
        recorded.providers = 'reference';
        recorded.rows = recorded.rows(string({recorded.rows.provider})=="reference");
        recorded.continuations = recorded.continuations(string({recorded.continuations.provider})=="reference");
        selected = string({recorded.lifecycle.provider})=="reference";
        if family~="stratified-qg"
            grids = reshape([recorded.lifecycle.grid],3,[])';
            selected = selected & ismember(grids,[8 6 9;12 10 13],"rows")';
        end
        recorded.lifecycle = recorded.lifecycle(selected);
        if family=="hydrostatic"
            externalTest = "TestPortableStratifiedQGQualification/lifecycleAndStorageRemainBounded";
            recorded.tests = recorded.tests(string({recorded.tests.name})~=externalTest);
            expectedNames = expectedNames(expectedNames~=externalTest);
        end
    end
    if contractsOnly
        classNames = struct(hydrostatic="TestPortableHydrostaticQualification",boussinesq="TestPortableBoussinesqQualification");
        require(family~="stratified-qg" && isequal(providers,"reference"),"Unknown historical contract-only projection.");
        continuationTest = classNames.(family)+"/longerContinuationMatchesMatlab";
        recorded.schemaIdentifier = char("wave-vortex-"+family+"-contracts-v1");
        recorded.tests = recorded.tests(string({recorded.tests.name})~=continuationTest);
        recorded.continuations = [];
        expectedNames = expectedNames(expectedNames~=continuationTest);
    end
    % MATLAB callers may use strings for text fields decoded as char in JSON.
    candidate = jsondecode(jsonencode(report));
    recorded = jsondecode(jsonencode(recorded));
    require(isequaln(candidate,recorded),"Historical evidence differs from the original artifact or its declared projection.");
    validation.scope = "historical-workload";
    validation.currentReadiness = false;
    validation.inventoryPath = inventoryPath;
    validation.inventorySHA256 = inventorySHA256;
    validation.reportPath = string(entry.reportPath);
    validation.reportSHA256 = string(entry.reportSHA256);
    return
end
require(~ismember(string(report.sourceCommit),string({inventory.entries.sourceCommit})),"Historical execution cannot establish current readiness; request historical validation explicitly.");
switch family
    case "stratified-qg"
        classes = ["TestPortableStratifiedQG","TestPortableStratifiedQGQualification","TestPortableStableForcing","TestPortableForcingCompatibility","TestCompiledKernelIntegration","TestStratifiedModalRecord"];
    case "hydrostatic"
        classes = ["TestPortableHydrostatic","TestPortableHydrostaticQualification","TestPortableStableForcing","TestPortableForcingCompatibility","TestCompiledKernelIntegration","TestStratifiedModalRecord","TestHydrostaticCompiledKernel"];
    case "boussinesq"
        classes = ["TestPortableBoussinesq","TestPortableBoussinesqQualification","TestPortableStableForcing","TestPortableForcingCompatibility","TestCompiledKernelIntegration","TestStratifiedModalRecord","TestBoussinesqCompiledKernel"];
end
expectedNames = strings(1,0);
if family=="hydrostatic" && ismember("native-fftw",providers)
    expectedNames = "TestPortableStratifiedQGQualification/lifecycleAndStorageRemainBounded";
end
for name = classes
    suite = testsuite(fullfile(root,"UnitTests",name+".m"));
    expectedNames = [expectedNames,string({suite.Name})]; %#ok<AGROW>
end
if contractsOnly
    expectedNames = expectedNames(~endsWith(expectedNames,"/longerContinuationMatchesMatlab"));
end
    function value = hashFile(path)
        require(isfile(path),"Missing historical source or artifact: "+path);
        value = portableForwardIntegrationSHA256(path);
    end
    function require(condition,message)
        if ~condition, error(errorIdentifier,"%s",message); end
    end
end
