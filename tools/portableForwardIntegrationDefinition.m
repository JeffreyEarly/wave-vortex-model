function catalog = portableForwardIntegrationDefinition()
% Define the versioned integration slice consumed by compatibility assembly.
configurations = ["constant-hydrostatic","constant-nonhydrostatic","barotropic-qg","stratified-qg","hydrostatic","boussinesq"];
transforms = ["WVTransformConstantStratification","WVTransformConstantStratification","WVTransformBarotropicQG","WVTransformStratifiedQG","WVTransformHydrostatic","WVTransformBoussinesq"];
profiles = ["rk4-explicit","rk4-cfl","adaptive-rk23","adaptive-rk45","adaptive-rk78"];
catalog = struct(schema="wave-vortex-forward-integration-v1",schemaVersion=1,slice="forward-integration",assemblyTarget=306, ...
    scope="Supported forward integration only; an assembly input, not a complete feature matrix or a parity decision.");
catalog.configurations = struct(id=cellstr(configurations),transform=cellstr(transforms));
catalog.profiles = struct(id=cellstr(profiles),method=cellstr(["fixed-rk4","fixed-rk4",profiles(3:5)]), ...
    stepPolicy=cellstr(["explicit","cfl","adaptive","adaptive","adaptive"]));
catalog.exclusions = [ ...
    struct(id="backward-integration",reason="unsupported",detail="Backward execution is rejected before destination mutation."), ...
    struct(id="matlab-function-handle-execution",reason="unsupported",detail="C++ does not execute arbitrary MATLAB function handles. Persisted opaque N2Function bytes remain supported scientific provenance and are preserved for MATLAB restoration."), ...
    struct(id="experimental-adaptive-cell",reason="under-development",detail="Experimental adaptive-cell algorithms are outside this stable integration slice.")];
% These references describe test coverage, not a claim that a test was run.
witnesses = struct(id={},path={},symbol={},configurations={},profiles={},coverage={});
witnesses(end+1) = witness("constant-linear","TestPortableRuntimeCompatibility","linearBottomFrictionMatchesMatlabFixedAndAdaptive",configurations(1:2),profiles([1 3 4]),"MATLAB coefficient and physical-state parity for both constant-stratification configurations.");
witnesses(end+1) = witness("constant-cfl","TestPortableRuntimeCompatibility","runRequestV2MatchesCFLAndExactMatlabSolvers",configurations(2),profiles(2),"Nonhydrostatic CFL-selected execution and MATLAB solver comparison.");
witnesses(end+1) = witness("constant-hydrostatic-cfl-request","TestPortableRuntimeCompatibility","matlabWriterRequestsDecodeAndRunEveryIntegrationForm",configurations(1),profiles(2),"Hydrostatic CFL request acceptance at the saved time; advancing lifecycle is covered by the representative case.");
witnesses(end+1) = witness("forcing-continuation","TestPortableStableForcing","forcingOutputContinuationMatchesMatlab",configurations,profiles([1 4 5]),"Parameterized transform and dynamics cases exercise explicit RK4, RK45 and RK78 with composed forcing and output.");
witnesses(end+1) = witness("barotropic-methods","TestPortableRuntimeCompatibility","matlabWriterBarotropicQGRequestsDecodeAndRun",configurations(3),profiles,"All five profiles advance Barotropic QG output and compare MATLAB fields and amplitudes.");
for k = 4:6
    classes = ["TestPortableStratifiedQG","TestPortableHydrostatic","TestPortableBoussinesq"];
    witnesses(end+1) = witness(configurations(k)+"-methods",classes(k-3),"modelIntegrationRoundTripsThroughMatlab",configurations(k),profiles([1 3 5])); %#ok<AGROW>
    witnesses(end+1) = witness(configurations(k)+"-cfl",classes(k-3),"cflAndDefaultSteppingMatchMatlab",configurations(k),profiles(2)); %#ok<AGROW>
end
catalog.witnesses = witnesses;
caseIds = ["forward-constant-hydrostatic-cfl-rk4","forward-constant-nonhydrostatic-rk23","forward-barotropic-qg-rk45","forward-stratified-qg-rk45","forward-hydrostatic-rk45","forward-boussinesq-rk45"];
caseProfiles = [profiles(2),profiles(3),repmat(profiles(4),1,4)];
parameterNames = ["constantHydrostatic","constantNonhydrostatic","barotropic","stratifiedQG","hydrostatic","boussinesq"];
catalog.cases = struct(id=cellstr(caseIds),configuration=cellstr(configurations),profile=cellstr(caseProfiles), ...
    path="UnitTests/TestPortableForwardIntegration.m",symbol="representativeLifecycleMatchesMatlab",parameter=cellstr(parameterNames));
catalog.rows = struct(id={},configuration={},profile={},support={},witnesses={},representativeCases={});
for configuration = configurations
    for profile = profiles
        ids = strings(1,0);
        for item = witnesses
            if ismember(configuration,string(item.configurations)) && ismember(profile,string(item.profiles))
                ids(end+1) = item.id; %#ok<AGROW>
            end
        end
        selected = string({catalog.cases.configuration})==configuration & string({catalog.cases.profile})==profile;
        catalog.rows(end+1) = struct(id=configuration+"/"+profile,configuration=configuration,profile=profile,support="supported", ...
            witnesses={cellstr(ids)},representativeCases={cellstr(string({catalog.cases(selected).id}))});
    end
end
catalog.relatedCatalogs = ["PortableRuntime/contracts/portable-forcing-compatibility-v1.json","PortableRuntime/contracts/portable-variable-catalog-v1.json"];
catalog.historicalEvidence = struct(path=cellstr(["PortableRuntime/qualification/stratified-qg-apple-silicon-v1.json", ...
    "PortableRuntime/qualification/hydrostatic-apple-silicon-v1.json","PortableRuntime/qualification/boussinesq-apple-silicon-v1.json"]), ...
    classification="historical-workload-coverage");
catalog.acceptance = struct(relativeErrorMaximum=2e-7,particlePositionErrorMaximum=.02,heldAmplitudeErrorMaximum=1e-18, ...
    coefficientEvolutionMinimum=1e-6,particleEvolutionMinimum=1e-4,tracerEvolutionMinimum=1e-8);
catalog.evidencePolicy = "Source witnesses identify existing tests; they do not assert execution. Separate qualification receipts bind six representative cases per provider to source and artifact hashes. Historical reports retain their original workloads, methods, providers and source provenance. No exhaustive method-by-feature cross-product or final #307 parity decision is implied.";
end

function value = witness(id,className,symbol,configurations,profiles,coverage)
if nargin < 6, coverage = "MATLAB-authored model continuation compared with the matching MATLAB integration policy."; end
value = struct(id=id,path="UnitTests/"+className+".m",symbol=symbol,configurations={cellstr(configurations)},profiles={cellstr(profiles)},coverage=coverage);
end
