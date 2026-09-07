function validatePortableStratifiedQGQualification(report,options)
% Reject incomplete, stale or contradictory SQG qualification evidence.
arguments (Input)
    report (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
require(string(report.schemaIdentifier)=="wave-vortex-sqg-qualification-v1" && report.schemaVersion==1,"Unknown qualification schema.");
require(string(report.status)=="complete","Qualification is incomplete.");
providers = reshape(string(report.providers),1,[]);
require(isequal(providers,"reference") || isequal(providers,["reference","native-fftw"]),"Qualification requires the reference provider and optionally native FFTW.");
require(~isempty(report.tests) && all([report.tests.passed]) && ~any([report.tests.failed]) && ~any([report.tests.incomplete]),"Failed or incomplete test evidence.");
testNames = string({report.tests.name});
require(numel(unique(testNames))==numel(testNames),"Duplicate test evidence.");
requiredClasses=["TestPortableStratifiedQG","TestPortableStratifiedQGQualification","TestPortableStableForcing","TestPortableForcingCompatibility","TestCompiledKernelIntegration","TestStratifiedModalRecord"];
expectedNames=strings(1,0);
for name=requiredClasses
    suite=testsuite(fullfile(options.repositoryRoot,"UnitTests",name+".m"));
    expectedNames=[expectedNames,string({suite.Name})]; %#ok<AGROW>
end
require(isequal(sort(testNames),sort(expectedNames)),"Missing or unexpected qualification tests.");
catalogPath = fullfile(options.repositoryRoot,"PortableRuntime","contracts","portable-forcing-compatibility-v1.json");
file=fopen(catalogPath,"rb"); cleanup=onCleanup(@()fclose(file)); bytes=fread(file,Inf,"*uint8");
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes); hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[])));
require(string(report.catalogSHA256)==hash,"Qualification catalog digest is stale.");
catalog=jsondecode(fileread(catalogPath));
expected=catalog.rows(startsWith(string({catalog.rows.configuration}),"stratified-qg"));
keys=strings(1,0);
for row=reshape(expected,1,[])
    rowProviders=providers;
    if string(row.acceptance)=="incompatible", rowProviders="reference"; end
    for provider=rowProviders
        keys(end+1)=string(row.id)+"/"+provider; %#ok<AGROW>
        candidates=report.rows(string({report.rows.id})==string(row.id) & string({report.rows.provider})==provider);
        require(isscalar(candidates) && candidates.passed,"Missing, duplicate or failed catalog row: "+keys(end));
        require(string(candidates.acceptance)==string(row.acceptance) && string(candidates.rejection)==string(row.matlab.rejection),"Catalog acceptance/rejection mismatch.");
        requiredTests="TestPortableStratifiedQG/incompatibleModelGraphsAreTransactional";
        if string(row.acceptance)=="supported"
            requiredTests=["TestPortableStratifiedQG/applicableForcingTendenciesMatchMatlab","TestPortableStratifiedQG/orderedForcingTendenciesMatchMatlab"];
        end
        require(isequal(sort(reshape(string(candidates.testNames),1,[])),sort(requiredTests)),"Catalog row points to the wrong tests.");
        require(~isempty(candidates.testNames) && all(ismember(string(candidates.testNames),testNames)),"Catalog row lacks executed evidence.");
    end
end
actualKeys=string({report.rows.id})+"/"+string({report.rows.provider});
require(isequal(sort(keys),sort(actualKeys)),"Unexpected or duplicate catalog rows.");
manifest=jsondecode(fileread(fullfile(options.repositoryRoot,"PortableRuntime","contracts","stratified-qg-qualification-cases-v1.json")));
continuations=report.continuations; if isstruct(continuations), continuations=num2cell(continuations); end
require(numel(continuations)==6*numel(providers),"Incomplete continuation matrix.");
keys=strings(1,0);
for index=1:numel(continuations)
    row=continuations{index}; keys(end+1)=string(row.definition.id)+"/"+string(row.provider); %#ok<AGROW>
    require(ismember(string(row.provider),providers),"Unexpected continuation provider.");
    definition=manifest.cases(string({manifest.cases.id})==string(row.definition.id));
    require(isscalar(definition),"Unknown continuation fixture.");
    for field=reshape(string(fieldnames(definition)),1,[])
        actual=row.definition.(field); expectedValue=definition.(field);
        if isnumeric(actual), matches=isequal(actual(:),expectedValue(:));
        elseif ischar(expectedValue) || isstring(expectedValue), matches=isequal(string(actual),string(expectedValue));
        else, matches=isequal(actual,expectedValue); end
        require(matches,"Continuation fixture differs from its declared configuration.");
    end
    if string(row.definition.stepPolicy)=="cfl"
        require(row.convergence.fineCoefficientError<row.convergence.coarseCoefficientError/100,"RK4 endpoint comparison failed convergence.");
    end
    bound=2e-7; if string(row.definition.stepPolicy)=="default", bound=5e-4; end
    for result={row.whole,row.segmented}
        errors=result{1}; values=[errors.coefficients errors.fields errors.energy errors.enstrophy errors.tracer errors.denseFields errors.mooring];
        require(isfinite(errors.particlePosition) && errors.particlePosition>=0 && errors.particlePosition<=.02,"Particle-position qualification exceeds tolerance.");
        require(all(isfinite(values)) && all(values>=0) && all(values<=bound),"Continuation parity exceeds the declared tolerance.");
    end
    if ~row.definition.linear, require(row.coefficientChange>1e-4,"Qualification trajectory is numerically trivial."); end
end
require(numel(unique(keys))==numel(keys),"Duplicate continuation cases.");
lifecycle=report.lifecycle; if isstruct(lifecycle), lifecycle=num2cell(lifecycle); end
require(numel(lifecycle)==3*numel(providers),"Incomplete lifecycle matrix.");
keys=strings(1,0);
for index=1:numel(lifecycle)
    row=lifecycle{index};
    require(ismember(string(row.provider),providers),"Unknown lifecycle provider.");
    require(ismember(reshape(row.grid,1,[]),manifest.lifecycleGrids,"rows"),"Unknown lifecycle grid.");
    keys(end+1)=join(string(row.grid(:)),"x")+"/"+string(row.provider); %#ok<AGROW>
    require(row.completedLifecycles==6 && row.scientificOwnersReleased && row.retainedGrowthBytes==0,"Lifecycle ownership/storage qualification failed.");
    if string(row.provider)=="native-fftw", require(row.preparedStepAllocations==0,"Native prepared integration allocates application memory."); end
end
require(numel(unique(keys))==numel(keys),"Duplicate lifecycle cases.");
end
function require(condition,message)
if ~condition, error("WaveVortexModel:InvalidSQGQualification","%s",message); end
end
