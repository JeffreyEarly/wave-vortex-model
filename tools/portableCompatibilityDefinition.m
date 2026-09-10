function matrix = portableCompatibilityDefinition(root)
% Assemble source-owned compatibility slices and explicit fixture coverage.
arguments
    root (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
forcingPath="PortableRuntime/contracts/portable-forcing-compatibility-v1.json";
variablePath="PortableRuntime/contracts/portable-variable-catalog-v1.json";
integrationPath="PortableRuntime/contracts/portable-forward-integration-v1.json";
forcing=jsondecode(fileread(fullfile(root,forcingPath)));
variables=jsondecode(fileread(fullfile(root,variablePath)));
integration=jsondecode(fileread(fullfile(root,integrationPath)));
validatePortableForcingCompatibility(forcing,repositoryRoot=root);
validatePortableVariableCatalog(variables);
validatePortableForwardIntegrationCatalog(integration,repositoryRoot=root);
observerFiles=dir(fullfile(root,"ObservingSystems","*.m"));
observers=sort(erase(string({observerFiles.name}),".m"));
forceFiles=dir(fullfile(root,"Forcing","*.m"));
forceNames=sort(erase(string({forceFiles.name}),".m"));
expectedForces=sort([string(forcing.inventory.stable(:));string({forcing.inventory.excluded.identity})']);
require(isequal(forceNames(:),expectedForces(:)),"Supplied forcing inventory differs from its authoritative slice.");
sourceInventory=fileread(fullfile(root,forcing.inventory.source));
forcingSection=extractBetween(string(sourceInventory),"## Forcing and closures","## Observing systems");
stable=sort(string(regexp(forcingSection,'(?m)^- `(WV\w+)`','tokens')));
require(isequal(stable(:),sort(string(forcing.inventory.stable(:)))),"Documented stable forcing inventory differs from its slice.");
% Discover current MATLAB annotations independently of the committed catalog.
authority=portableVariableAnnotations();
actualKeys=sort(arrayfun(@(a)string(a.configuration)+"/"+string(a.annotation.name),authority));
catalogKeys=sort(arrayfun(@(a)string(a.configuration)+"/"+string(a.metadata.name),variables.contracts));
require(isequal(actualKeys(:),catalogKeys(:)),"Current MATLAB annotations differ from the variable slice.");
documentedTransforms=regexp(sourceInventory,'(?m)^\| `(WVTransform\w+)`','tokens');
documentedTransforms=sort(string([documentedTransforms{:}]));
actualTransforms=sort(unique(string({authority.transformClass})));
require(isequal(documentedTransforms(:),actualTransforms(:)),"Documented stable transforms differ from the portable inventory.");
for name=documentedTransforms
    require(isfile(fullfile(root,"@"+name,name+".m")),"Documented transform class is missing: "+name);
end
factoryPath="@WVTransform/classDefinedOperationForKnownVariable.m";
factorySource=fileread(fullfile(root,factoryPath));
factoryNames=regexp(factorySource,"(?m)^\s*case '([^']+)'",'tokens');
factoryNames=string([factoryNames{:}]);
require(all(ismember(factoryNames,string({variables.variables.name}))),"A known MATLAB operation is absent from the variable catalog.");
rows={}; witnesses={}; sources={};
addSource("assembly-definition","tools/portableCompatibilityDefinition.m","fixture-binding-authority");
addSource("known-variable-factory",factoryPath,"MATLAB known-operation authority");
addSource("schedule-type","PortableRuntime/include/WaveVortexRuntime/WVOutputSchedule.hpp","schedule-type-authority");
addSource("forcing",forcingPath,string(forcing.schema));
addSource("fields",variablePath,string(variables.schema));
addSource("integration",integrationPath,string(integration.schema));
addSource("matlab-inventory",string(forcing.inventory.source),"MATLAB documented stable inventory");
for name=observers, addSource("observer-"+name,"ObservingSystems/"+name+".m","MATLAB observer class"); end
addSource("matlab-variable-discovery","tools/portableVariableAnnotations.m","MATLAB registration inventory");
addSource("matlab-sampling","@WVTransform/variableAtPositionWithName.m","MATLAB generic gridded interpolation");
for item=reshape(forcing.evidence,1,[])
    kind=string(item.kind); if startsWith(string(item.path),"tools/"), kind="matlab-authority"; end
    addWitness("forcing-"+string(item.id),kind,string(item.path),string(item.symbol),"Assigned forcing-slice row references; fixture kinds distinguish numerical parity, mathematical controls, and MATLAB applicability.");
end
for item=reshape(integration.witnesses,1,[])
    addWitness("integration-"+string(item.id),"matlab-runtime-parity",string(item.path),string(item.symbol),string(item.coverage));
end
addWitness("declared-sampling","matlab-runtime-parity","UnitTests/TestPortableFieldSamplingMatrix.m","declaredPortableSamplingMatchesMatlab","All six transform configurations, both antialias modes, every declared position/profile field, linear/spline and reference/native providers when available.");
addWitness("ordinary-fields","matlab-runtime-parity","UnitTests/TestPortableDiagnostics.m","allTransformDiagnosticsMatchMatlab","Both antialias modes and both grid parities; registered non-forcing outputs except primary coefficients and separately qualified density fields.");
addWitness("density-fields","matlab-runtime-parity","UnitTests/TestPortableDensityEventEvaluation.m","coefficientDrivenDensityMatchesMatlab","Four wave families, both antialias modes, actual and initial references; full natural density grids.");
addWitness("forcing-wave-fields","matlab-runtime-parity","UnitTests/TestPortableStableForcing.m","fullGridWaveTendenciesMatchMatlab","Full-grid built-in forcing channels in four wave families, both antialias modes.");
addWitness("forcing-barotropic-fields","matlab-runtime-parity","UnitTests/TestPortableStableForcing.m","fullGridBarotropicTendenciesMatchMatlab","Barotropic forcing channels, both antialias modes.");
addWitness("forcing-stratified-fields","matlab-runtime-parity","UnitTests/TestPortableStableForcing.m","fullGridStratifiedTendenciesMatchMatlab","Stratified QG forcing channels, both antialias modes.");
addWitness("matlab-sampling-authority","matlab-authority","@WVTransform/variableAtPositionWithName.m","variableAtPositionWithName","MATLAB interpolates registered gridded variables independently of the portable sampling mask.");
addWitness("density-position-rejection","cpp-unit","PortableRuntime/tests/TestWVPortableVariableCatalog.cpp","main","Exact density position-sampling rejection in all four wave-bearing families and both antialias modes.");
addWitness("constant-moving-authority","cpp-authority","PortableRuntime/src/WVFieldEvaluationService.cpp","createMovingPlan","The constant adapter rejects fields without a movingPrimitiveChannel; this is source authority, not an executed rejection fixture.");

addWitness("observer-contracts","matlab-contract","UnitTests/TestPortableObserverContracts.m","supportedObserversReturnExactVersionedContracts","Five built-in observer identities and exact pair versions in a constant nonhydrostatic model.");
addWitness("constant-graph","matlab-runtime-parity","UnitTests/TestPortableRuntimeCompatibility.m","matlabModelGraphRoundTripsThroughStandalone","Both constant configurations at AA-off: nonlinear model graph, coefficients, field/mooring records, particles and tracer.");
addWitness("barotropic-graph","matlab-runtime-parity","UnitTests/TestPortableRuntimeCompatibility.m","barotropicQGModelOutputRoundTripsThroughStandalone","Both antialias modes: coefficients, Eulerian fields, particles and tracer model output/restart.");
addWitness("constant-hydrostatic-fields","matlab-runtime-parity","UnitTests/TestPortableRuntimeCompatibility.m","linearBottomFrictionMatchesMatlabFixedAndAdaptive","Constant hydrostatic AA-off coefficients and Eulerian model output with fixed and adaptive friction trajectories.");
addWitness("barotropic-mooring-authority","matlab-authority","ObservingSystems/WVMooring.m","WVMooring","MATLAB constructor explicitly rejects non-three-dimensional domains.");
addWitness("barotropic-mooring-rejection","matlab-runtime-parity","UnitTests/TestPortableRuntimeCompatibility.m","matlabWriterBarotropicQGRejectionsAreTransactional","Barotropic model preflight rejects an unsupported mooring graph transactionally.");
for family=["hydrostatic","boussinesq","stratified-qg"]
    className=transformTestClass(family);
    addWitness(family+"-sampling","matlab-runtime-parity","UnitTests/"+className+".m","fieldSamplingMatchesMatlab","AA-off odd nonuniform grid, explicit primitive-name list, linear/spline, fixed/moving/event positions.");
    addWitness(family+"-graph","matlab-runtime-parity","UnitTests/"+className+".m","modelIntegrationRoundTripsThroughMatlab","Transform-specific coefficient, field, mooring, particle and tracer continuation.");
    addWitness(family+"-files","matlab-runtime-parity","UnitTests/"+className+".m","multiFileOutputPoliciesAndRestart","Multiple destinations and create/replace/append restart policies.");
end
addWitness("forward-compositions","matlab-runtime-parity","UnitTests/TestPortableForwardIntegration.m","representativeLifecycleMatchesMatlab","Six parameterized rich trajectories with all continuation directions, two destinations, held coefficients, particles/tracers and controlled stops.");
addWitness("diagnostic-output","matlab-runtime-parity","UnitTests/TestPortableDiagnostics.m","outputContinuationMatchesMatlab","AA-on ordinary and dense multi-file diagnostic output across six families.");
addWitness("density-output","matlab-runtime-parity","UnitTests/TestPortableDensityOutput.m","twoDestinationsContinueInBothDirections","Constant hydrostatic actual reference and hydrostatic initial reference, AA-on, two destinations and MATLAB/C++ continuation.");
addWitness("base-observer-rejection","matlab-contract","UnitTests/TestPortableObserverContracts.m","baseClassIsUnavailable","Abstract extension base is not a supplied portable observer.");
% Existing typed forcing and integration rows remain the sole scientific facts.
for item=reshape(forcing.rows,1,[])
    axes=emptyAxes(); axes.configuration=string(item.configuration); axes.feature=string(item.forcing);
    axes.stage=strjoin(string(item.matlab.activeTypes),",");
    status="supported"; reason="";
    if string(item.acceptance)=="incompatible", status="intentional-incompatibility"; reason=string(item.matlab.rejection); end
    if string(item.acceptance)=="pending", status="unqualified"; reason="source-slice-pending"; end
    addRow("forcing/"+string(item.id),"forcing","forcing",string(item.id),axes,status,reason,"forcing-"+string(item.evidence));
end
for item=reshape(integration.rows,1,[])
    axes=emptyAxes(); axes.configuration=string(item.configuration); axes.profile=string(item.profile); axes.feature="forward-integration";
    addRow("integration/"+string(item.id),"integration","integration",string(item.id),axes,"supported","","integration-"+string(item.witnesses));
end
% Enumerate MATLAB gridded sampling beyond the narrower portable mask; these
% remain gaps, not invented MATLAB incompatibilities or accepted exclusions.
for item=reshape(variables.contracts,1,[])
    name=string(item.metadata.name); configuration=string(item.configuration);
    sourceRow=configuration+"/"+string(item.ordinal); declared=reshape(string(item.metadata.samplingModes),1,[]);
    modes=declared;
    if string(item.metadata.naturalRank)=="volume", modes=unique([modes,"positions","fixedVerticalProfiles"],"stable"); end
    if string(item.metadata.naturalRank)=="horizontal", modes=unique([modes,"positions"],"stable"); end
    for sampling=modes
        axes=emptyAxes(); axes.configuration=configuration; axes.feature=name; axes.sampling=sampling;
        missingMoving=false;
        if sampling=="positions"
            axes.stage="fixed-event-and-moving";
            % The qualified sampler explicitly omits moving calls for these
            % constant-adapter channel=-1 fields, while fixed/event work.
            missingMoving=ismember(sampling,declared) && startsWith(configuration,"constant-") && ...
                ismember(name,["p","pi","psi","qgpv","ssh","ssu","ssv","zeta_x","zeta_y","zeta_z"]);
            if missingMoving, axes.stage="fixed-and-event"; end
        end
        status="supported"; reason="";
        if ~ismember(sampling,declared)
            status="unqualified"; reason="matlab-supported-sampling-not-implemented"; refs="matlab-sampling-authority";
            if sampling=="positions" && ismember(name,["eta_true","ape","apv"])
                refs=["matlab-sampling-authority","density-position-rejection"];
            end
        elseif ismember(name,["rho_nm","eta_true","ape","apv"])
            refs="density-fields";
        elseif endsWith(name,"_portable_catalog_forcing")
            if startsWith(configuration,"barotropic")
                refs="forcing-barotropic-fields";
            elseif startsWith(configuration,"stratified-qg")
                refs="forcing-stratified-fields";
            else
                refs="forcing-wave-fields";
            end
        elseif ismember(name,["Ap","Am","A0"])
            refs=coefficientWitness(configuration);
        elseif ismember(sampling,["fullGrid","coefficients"])
            refs="ordinary-fields";
        else
            refs="declared-sampling";
        end
        if string(item.runtimeStatus)~="implemented", status="unqualified"; reason="source-evaluator-not-implemented"; end
        addRow("fields/"+sourceRow+"/"+sampling,"fields","fields",sourceRow,axes,status,reason,refs);
        if missingMoving
            axes.stage="moving";
            addRow("fields/"+sourceRow+"/"+sampling+"/moving","fields","fields",sourceRow,axes,"unqualified", ...
                "matlab-supported-moving-sampling-not-implemented",["matlab-sampling-authority","constant-moving-authority"]);
        end
    end
end
% Exact antialias settings belong to the fixture contract as well.
for configuration=reshape(string(variables.configurations),1,[])
    family=extractBefore(configuration,"-aa"); aa=endsWith(configuration,"aa1");
    for observer=observers
        axes=emptyAxes(); axes.configuration=configuration; axes.feature=observer;
        refs=strings(1,0); status="unqualified"; reason="observer-exact-pair-witness-not-mapped";
        if family=="barotropic" && observer~="WVMooring"
            refs="barotropic-graph";
        elseif family=="constant-hydrostatic" && ~aa
            refs="constant-graph";
        elseif aa && ~(family=="barotropic" && observer=="WVMooring")
            refs="forward-compositions";
        elseif ~aa && family=="constant-nonhydrostatic"
            refs=["observer-contracts","constant-graph"];
        elseif ~aa && ismember(family,["hydrostatic","boussinesq","stratified-qg"])
            refs=family+"-graph";
        end
        if ~ismember(observer,["WVCoefficients","WVEulerianFields","WVLagrangianParticles","WVMooring","WVTracer"])
            refs=strings(1,0); reason="new-matlab-observer-without-portable-witness";
        end
        if ~isempty(refs), status="supported"; reason=""; end
        if family=="barotropic" && observer=="WVMooring"
            status="intentional-incompatibility"; reason="MATLAB-mooring-requires-three-dimensional-domain";
            refs=["barotropic-mooring-authority","barotropic-mooring-rejection"];
        end
        addRow("observers/"+configuration+"/"+observer,"observers","observer-"+observer,observer,axes,status,reason,refs);
    end
    % Cross-feature lifecycle compositions are deliberately representative
    % AA-on scenarios, not a redundant Cartesian integration campaign.
    if ~aa, continue; end
    for feature=["ordinary-dense-output","multi-destination-output","segmented-restart","matlab-cpp-continuation","controlled-stop-resume"]
        axes=emptyAxes(); axes.configuration=configuration; axes.feature=feature;
        axes.outputLayout="MATLAB-column-major-real-or-split-complex";
        axes.restartState="coefficients-forcing-observers-schedules";
        refs="forward-compositions"; status="supported"; reason="";
        addRow("persistence/"+configuration+"/"+feature,"persistence","integration",replace(family,"barotropic","barotropic-qg"),axes,status,reason,refs);
    end
end
% Source-build coverage is structural; #307 owns fresh execution receipts.
addWitness("source-contract","cpp-unit","PortableRuntime/tests/TestWVPortableImplementationContract.cpp","verifyContractIdentity","Portable source API identity compiled by the supported macOS/Linux CI toolchains; not a fresh provider execution receipt.");
for platform=["macos-apple-silicon","linux-gcc","linux-clang"]
    providers=["reference","native-fftw"];
    if platform~="macos-apple-silicon", providers="reference"; end
    for provider=providers
        axes=emptyAxes(); axes.feature="source-build"; axes.platform=platform; axes.provider=provider;
        addRow("execution/"+platform+"/"+provider,"execution","witness-source-contract","verifyContractIdentity",axes,"supported","","source-contract");
    end
end
versions=contractVersions(root);
for item=reshape(versions,1,[]), addSource("version-"+item.id,item.source,"version-authority"); end
exclusions={};
for item=reshape(forcing.inventory.excluded,1,[])
    exclusions{end+1}=struct(id=string(item.identity),reason=string(item.reason),source=string(forcing.inventory.source),fixtures=strings(1,0)); %#ok<AGROW>
end
for item=reshape(variables.exclusions,1,[])
    exclusions{end+1}=struct(id=string(item.name),reason=string(item.reason),source=variablePath,fixtures="ordinary-fields"); %#ok<AGROW>
end
for item=reshape(integration.exclusions,1,[])
    exclusions{end+1}=struct(id=string(item.id),reason=string(item.reason)+": "+string(item.detail),source=integrationPath,fixtures=strings(1,0)); %#ok<AGROW>
end
exclusions{end+1}=struct(id="windows-msvc",reason="Windows/MSVC source-linked execution is outside the declared platform contract.",source=string(forcing.inventory.source),fixtures="source-contract");
exclusions{end+1}=struct(id="linux-native-fftw",reason="The optimized provider is restricted to Apple silicon; Linux uses the reference source build.",source=string(forcing.inventory.source),fixtures="source-contract");
completion="complete"; if any(cellfun(@(r)r.status=="unqualified",rows)), completion="incomplete"; end
matrix=struct(schema="portable-compatibility-matrix-v1",schemaVersion=1,slice="standard",completion=completion, ...
    readiness=struct(standardParityReady=false,decision="pending-307",meaning="Fixture coverage is not executed qualification; unqualified rows remain tracked gaps."), ...
    sources=[sources{:}],inventory=struct(forcing=reshape(string(forcing.inventory.stable),1,[]),observers=observers,variables=string({variables.variables.name}), ...
    configurations=string(variables.configurations),integrationProfiles=string({integration.profiles.id})), ...
    versions=versions,witnesses=[witnesses{:}],rows=[rows{:}],exclusions=[exclusions{:}]);

    function addSource(id,path,schema)
        if any(cellfun(@(v)v.path==path,sources)), return; end
        sources{end+1}=struct(id=id,path=path,schema=schema,sha256=portableCompatibilitySHA256(fullfile(root,path)));
    end
    function addWitness(id,kind,path,symbol,description)
        witnesses{end+1}=struct(id=id,kind=kind,path=path,symbol=symbol,coverage=struct(description=description,rowIds=strings(1,0)));
        addSource("witness-"+id,path,"qualification-source");
    end
    function addRow(id,slice,sourceId,sourceRow,axes,status,reason,refs)
        refs=reshape(string(refs),1,[]);
        row=struct(id=id,slice=slice,sourceId=sourceId,sourceRow=sourceRow,axes=axes,status=status,reason=reason,fixtures=refs,issue=0);
        if status=="unqualified", row.issue=307; end
        if ismember(reason,["matlab-supported-sampling-not-implemented","matlab-supported-moving-sampling-not-implemented"]), row.issue=454; end
        rows{end+1}=row;
        for ref=refs
            index=find(cellfun(@(w)w.id==ref,witnesses));
            require(isscalar(index),"Unresolved fixture: "+ref);
            witnesses{index}.coverage.rowIds(end+1)=id;
        end
    end
end
function axes=emptyAxes()
    axes=struct(configuration="",feature="",sampling="",profile="",provider="",platform="",outputLayout="",restartState="",stage="");
end
function refs=coefficientWitness(configuration)
    family=extractBefore(configuration,"-aa");
    if ismember(family,["constant-hydrostatic","constant-nonhydrostatic","barotropic"])
        refs="forcing-baseline-pairs";
    elseif family=="stratified-qg"
        refs="forcing-sqg-pairs";
    elseif family=="hydrostatic"
        refs="forcing-hydro-continuations";
    else
        refs="forcing-bouss-continuations";
    end
end
function value=transformTestClass(family)
    if family=="hydrostatic"
        value="TestPortableHydrostatic";
    elseif family=="boussinesq"
        value="TestPortableBoussinesq";
    else
        value="TestPortableStratifiedQG";
    end
end
function require(condition,message)
    if ~condition, error("WaveVortexModel:InvalidCompatibilityMatrix","%s",message); end
end

function versions=contractVersions(root)
    definitions={ ...
        "WVPortablePairContractVersion","PortableRuntime/include/WaveVortexRuntime/WVPortableImplementationContract.hpp"; ...
        "WVPortableRuntimeSourceAPIMajorVersion","PortableRuntime/include/WaveVortexRuntime/WVPortableImplementationContract.hpp"; ...
        "WVPortableRuntimeSourceAPIMinorVersion","PortableRuntime/include/WaveVortexRuntime/WVPortableImplementationContract.hpp"; ...
        "WVKernelContractVersion","CompiledKernel/include/WaveVortexKernel/WVKernelTypes.hpp"; ...
        "WVCheckpointProfileVersion","PortableRuntime/include/WaveVortexRuntime/WVCheckpointReader.hpp"; ...
        "WVPortableObserverContractVersion","PortableRuntime/include/WaveVortexRuntime/WVObserverContracts.hpp"; ...
        "WVObservationSchemaContractVersion","PortableRuntime/include/WaveVortexRuntime/WVObservation.hpp"};
    versions=struct(id={},version={},source={});
    for k=1:size(definitions,1)
        symbol=string(definitions{k,1}); path=string(definitions{k,2});
        token=regexp(fileread(fullfile(root,path)),symbol+"\s*=\s*(\d+)",'tokens','once');
        require(~isempty(token),"Missing version authority: "+symbol);
        versions(end+1)=struct(id=symbol,version=str2double(token{1}),source=path); %#ok<AGROW>
    end
    for n=1:2
        path="PortableRuntime/contracts/wave-vortex-run-request-v"+n+".schema.json";
        schema=jsondecode(fileread(fullfile(root,path)));
        versions(end+1)=struct(id=string(schema.properties.schemaIdentifier.const),version=schema.properties.schemaVersion.const,source=path); %#ok<AGROW>
    end
    path="PortableRuntime/src/WVOutputSchedule.cpp";
    token=regexp(fileread(fullfile(root,path)),'contractVersion\(\) const noexcept override \{ return (\d+);','tokens','once');
    require(~isempty(token),"Missing evenly spaced schedule version.");
    scheduleType=regexp(fileread(fullfile(root,"PortableRuntime/include/WaveVortexRuntime/WVOutputSchedule.hpp")),'WVEvenlySpacedOutputScheduleType\s*=\s*"([^"]+)"','tokens','once');
    require(~isempty(scheduleType),"Missing evenly spaced schedule identity.");
    versions(end+1)=struct(id=string(scheduleType{1}),version=str2double(token{1}),source=path);
    path="PortableRuntime/include/WaveVortexRuntime/WVDensityDiagnosticContract.hpp";
    token=regexp(fileread(fullfile(root,path)),'identifier = "([^"]+)"','tokens','once');
    require(~isempty(token),"Missing density contract identifier.");
    versions(end+1)=struct(id=string(token{1}),version=string(token{1}),source=path);
    path="PortableRuntime/contracts/portable-forward-integration-v1.json";
    contract=jsondecode(fileread(fullfile(root,path)));
    versions(end+1)=struct(id=string(contract.schema),version=contract.schemaVersion,source=path);
end
