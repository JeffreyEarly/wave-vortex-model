function validatePortableHydrostaticQualification(report,options)
% Reject incomplete, stale or contradictory Hydrostatic qualification evidence.
arguments (Input)
    report (1,1) struct
    options.repositoryRoot (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
contractsOnly=string(report.schemaIdentifier)=="wave-vortex-hydrostatic-contracts-v1";
require((string(report.schemaIdentifier)=="wave-vortex-hydrostatic-qualification-v1" || contractsOnly) && report.schemaVersion==1,"Unknown qualification schema.");
require(string(report.status)=="complete","Qualification is incomplete.");
providers = reshape(string(report.providers),1,[]);
require(isequal(providers,"reference") || isequal(providers,["reference","native-fftw"]),"Qualification requires the reference provider and optionally native FFTW.");
require(~contractsOnly || isequal(providers,"reference"),"Contract-only evidence requires the reference provider.");
require(~isempty(report.tests) && all([report.tests.passed]) && ~any([report.tests.failed]) && ~any([report.tests.incomplete]),"Failed or incomplete test evidence.");
testNames = string({report.tests.name});
require(numel(unique(testNames))==numel(testNames),"Duplicate test evidence.");
requiredClasses=["TestPortableHydrostatic","TestPortableHydrostaticQualification","TestPortableStableForcing","TestPortableForcingCompatibility","TestCompiledKernelIntegration","TestStratifiedModalRecord","TestHydrostaticCompiledKernel"];
expectedNames=strings(1,0);
if ismember("native-fftw",providers), expectedNames="TestPortableStratifiedQGQualification/lifecycleAndStorageRemainBounded"; end
for name=requiredClasses
    suite=testsuite(fullfile(options.repositoryRoot,"UnitTests",name+".m"));
    expectedNames=[expectedNames,string({suite.Name})]; %#ok<AGROW>
end
if contractsOnly, expectedNames=expectedNames(expectedNames~="TestPortableHydrostaticQualification/longerContinuationMatchesMatlab"); end
require(isequal(sort(testNames),sort(expectedNames)),"Missing or unexpected qualification tests.");
[catalog,compatibleCatalog] = portableQualificationCatalog(report,"hydrostatic",options.repositoryRoot);
require(compatibleCatalog,"Qualification catalog digest or transform slice is stale.");
expected=catalog.rows(startsWith(string({catalog.rows.configuration}),"hydrostatic"));
keys=strings(1,0);
for row=reshape(expected,1,[])
    rowProviders=providers;
    if string(row.acceptance)=="incompatible", rowProviders="reference"; end
    for provider=rowProviders
        keys(end+1)=string(row.id)+"/"+provider; %#ok<AGROW>
        candidates=report.rows(string({report.rows.id})==string(row.id) & string({report.rows.provider})==provider);
        require(isscalar(candidates) && candidates.passed,"Missing, duplicate or failed catalog row: "+keys(end));
        require(string(candidates.acceptance)==string(row.acceptance) && string(candidates.rejection)==string(row.matlab.rejection),"Catalog acceptance/rejection mismatch.");
        requiredTests="TestPortableHydrostatic/incompatibleModelGraphsAreTransactional";
        if string(row.acceptance)=="supported"
            requiredTests=["TestPortableHydrostatic/applicableForcingTendenciesMatchMatlab","TestPortableHydrostatic/orderedForcingTendenciesMatchMatlab","TestPortableHydrostatic/applicableForcingContinuationsMatchMatlab"];
        end
        require(isequal(sort(reshape(string(candidates.testNames),1,[])),sort(requiredTests)),"Catalog row points to the wrong tests.");
        require(~isempty(candidates.testNames) && all(ismember(string(candidates.testNames),testNames)),"Catalog row lacks executed evidence.");
    end
end
actualKeys=string({report.rows.id})+"/"+string({report.rows.provider});
require(isequal(sort(keys),sort(actualKeys)),"Unexpected or duplicate catalog rows.");
manifest=jsondecode(fileread(fullfile(options.repositoryRoot,"PortableRuntime","contracts","hydrostatic-qualification-cases-v1.json")));
continuations=report.continuations; if isstruct(continuations), continuations=num2cell(continuations); end
expectedContinuations=numel(manifest.cases)*numel(providers);
if contractsOnly, expectedContinuations=0; end
require(numel(continuations)==expectedContinuations,"Incomplete or unexpected continuation matrix for this report scope.");
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
    bound=2e-7; if string(row.definition.stepPolicy)=="default", bound=5e-4; end
    for result={row.whole,row.segmented}
        errors=result{1};
        families=[errors.coefficientFamilies.Ap errors.coefficientFamilies.Am errors.coefficientFamilies.A0];
        require(all(isfinite(families)) && all(families>=0) && errors.coefficients==max(families),"Coefficient-family evidence contradicts the summary.");
        values=[errors.coefficients errors.fields errors.energy errors.enstrophy errors.tracer errors.denseFields errors.mooring];
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
        require(string(measured.integrationRequest.activeMethod)==string(definition.method),"Integrator differs from the declared case.");
        if string(definition.stepPolicy)=="cfl", require(abs(measured.integrationRequest.selectedStep-5)<1e-10,"CFL did not select the declared five-second step."); end
        require(measured.integratorStorageLedger.byteLedgerAgreement && measured.storageBytes.persistentFullHermitian==0,"Runtime storage contract failed.");
    end
end
require(numel(unique(keys))==numel(keys),"Duplicate continuation cases.");
lifecycle=report.lifecycle; if isstruct(lifecycle), lifecycle=num2cell(lifecycle); end
expectedCount=sum(~[manifest.lifecycleCases.nativeOnly])*numel(providers)+sum([manifest.lifecycleCases.nativeOnly])*double(ismember("native-fftw",providers));
if isequal(providers,"reference"), expectedCount=size(manifest.referenceOnlyLifecycleGrids,1); end
require(numel(lifecycle)==expectedCount,"Incomplete lifecycle matrix.");
keys=strings(1,0);
for index=1:numel(lifecycle)
    row=lifecycle{index};
    require(ismember(string(row.provider),providers),"Unknown lifecycle provider.");
    grids=reshape([manifest.lifecycleCases.grid],3,[])';
    if isequal(providers,"reference"), grids=manifest.referenceOnlyLifecycleGrids; end
    require(ismember(reshape(row.grid,1,[]),grids,"rows"),"Unknown lifecycle grid.");
    definition=manifest.lifecycleCases(string({manifest.lifecycleCases.id})==string(row.definition.id));
    require(isscalar(definition),"Unknown lifecycle fixture.");
    require(row.Nj==definition.Nj && row.finalStateFinite,"Lifecycle modal size or final state failed.");
    require(isequal(row.grid(:),definition.grid(:)),"Lifecycle grid differs from its declaration.");
    for field=reshape(string(fieldnames(definition)),1,[])
        actualValue=row.definition.(field); expectedValue=definition.(field);
        require(isequal(actualValue(:),expectedValue(:)),"Lifecycle fixture differs from its declaration.");
    end
    if definition.nativeOnly, require(string(row.provider)=="native-fftw","Large lifecycle case requires native FFTW."); end
    require(string(row.schemaIdentifier)=="wave-vortex-hydrostatic-lifecycle-v1","Wrong lifecycle transform.");
    keys(end+1)=join(string(row.grid(:)),"x")+"/"+string(row.provider); %#ok<AGROW>
    require(row.completedLifecycles==6 && row.scientificOwnersReleased && row.retainedGrowthBytes==0,"Lifecycle ownership/storage qualification failed.");
    require(numel(row.measurements)==6,"Missing lifecycle measurements.");
    for measured=reshape(row.measurements,1,[])
        require(measured.retainedBytesAfter==measured.retainedBytesBefore && measured.retainedBytesAfter>0,"Measured retained storage grew or is absent.");
        require(isfinite(measured.setupSeconds) && measured.setupSeconds>0 && measured.scientificBytes>0,"Missing setup/scientific-storage measurement.");
        require(isfinite(measured.preparedStepAllocations) && measured.preparedStepAllocations>=0 && measured.preparedStepAllocations==fix(measured.preparedStepAllocations),"Invalid allocation measurement.");
        require(measured.fieldReconstructions>=measured.rhsEvaluations && measured.spatialProjections>=measured.rhsEvaluations,"Missing forcing work measurements.");
        require(measured.sampleSteps==16 && measured.rhsEvaluations==64 && isfinite(measured.sampleSeconds) && measured.sampleSeconds>0,"Invalid lifecycle work measurement.");
    end
    require(row.preparedStepAllocations==max([row.measurements.preparedStepAllocations]),"Allocation summary contradicts measurements.");
    if string(row.provider)=="native-fftw", require(row.preparedStepAllocations==0,"Native prepared integration allocates application memory."); end
end
require(numel(unique(keys))==numel(keys),"Duplicate lifecycle cases.");
end
function require(condition,message)
if ~condition, error("WaveVortexModel:InvalidHydrostaticQualification","%s",message); end
end
