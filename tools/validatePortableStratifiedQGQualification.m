function validation = validatePortableStratifiedQGQualification(report,options)
% Reject incomplete, stale or contradictory SQG qualification evidence.
arguments (Input)
    report (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
    options.evidenceScope (1,1) string {mustBeMember(options.evidenceScope,["current","historical"])} = "current"
end
require(string(report.schemaIdentifier)=="wave-vortex-sqg-qualification-v1" && report.schemaVersion==1,"Unknown qualification schema.");
require(string(report.status)=="complete","Qualification is incomplete.");
providers = reshape(string(report.providers),1,[]);
require(isequal(providers,"reference") || isequal(providers,["reference","native-fftw"]),"Qualification requires the reference provider and optionally native FFTW.");
require(~isempty(report.tests) && all([report.tests.passed]) && ~any([report.tests.failed]) && ~any([report.tests.incomplete]),"Failed or incomplete test evidence.");
testNames = string({report.tests.name});
require(numel(unique(testNames))==numel(testNames),"Duplicate test evidence.");
[expectedNames,validation] = portableQualificationTestInventory(report,"stratified-qg",options.repositoryRoot,options.evidenceScope);
require(isequal(sort(testNames),sort(expectedNames)),"Missing or unexpected qualification tests.");
[catalog,compatibleCatalog] = portableQualificationCatalog(report,"stratified-qg",options.repositoryRoot);
require(compatibleCatalog,"Qualification catalog digest or transform slice is stale.");
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
        if isnumeric(actual)
            matches=isequal(actual(:),expectedValue(:));
        elseif ischar(expectedValue) || isstring(expectedValue)
            matches=isequal(string(actual),string(expectedValue));
        else
            matches=isequal(actual,expectedValue);
        end
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
    require(isfinite(row.coefficientChange),"Nonfinite trajectory change.");
    if ~row.definition.linear, require(row.coefficientChange>1e-4,"Qualification trajectory is numerically trivial."); end
    for result={row.whole,row.segmented}
        graph=result{1}.graph;
        require(isequal(graph.wave_vortex.times(:),(17:100:617)') && graph.wave_vortex.ordinal==7,"Primary schedule/ordinal differs.");
        require(isequal(graph.dense.times(:),(17:25:617)') && graph.dense.ordinal==25,"Dense schedule/ordinal differs.");
    end
    require(isequal(row.whole.graph,row.segmented.graph),"Segmented graph identity differs.");
    runs=row.runtime; if isstruct(runs), runs=num2cell(runs); end
    require(numel(runs)==3,"Missing uninterrupted or segmented runtime reports.");
    for run=reshape(runs,1,[])
        measured=run{1};
        require(string(measured.status)=="complete" && measured.execution.noFallback && string(measured.provider.id)==string(row.provider),"Runtime completion/provider mismatch.");
        require(measured.integratorStorageLedger.byteLedgerAgreement && measured.storageBytes.persistentFullHermitian==0,"Runtime storage contract failed.");
    end
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
    require(numel(row.measurements)==6,"Missing lifecycle measurements.");
    for measured=reshape(row.measurements,1,[])
        require(measured.retainedBytesAfter==measured.retainedBytesBefore && measured.retainedBytesAfter>0,"Measured retained storage grew or is absent.");
        require(measured.sampleSteps==16 && measured.rhsEvaluations==64 && isfinite(measured.sampleSeconds) && measured.sampleSeconds>0,"Invalid lifecycle work measurement.");
    end
    require(row.preparedStepAllocations==max([row.measurements.preparedStepAllocations]),"Allocation summary contradicts measurements.");
    if string(row.provider)=="native-fftw", require(row.preparedStepAllocations==0,"Native prepared integration allocates application memory."); end
end
require(numel(unique(keys))==numel(keys),"Duplicate lifecycle cases.");
end
function require(condition,message)
if ~condition, error("WaveVortexModel:InvalidSQGQualification","%s",message); end
end
