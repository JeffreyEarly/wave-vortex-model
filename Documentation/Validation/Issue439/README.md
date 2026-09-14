# T8: thermal output, restart and physical transfer

The thermal peer now uses the existing annotated scientific-state writer, named coefficient discovery, committed coefficient stream, forcing factory, `WVModel.modelFromFile` and output graph. It does not introduce a file format or integrator hierarchy. This evidence concerns short restart and transfer behavior; it does not replace the historical seasonal linear qualification or qualify a long campaign.

## Supported lifecycle

The root group stores immutable scientific arrays once, with `t0`, forcing configuration and horizontal coordinates. A complete observer stream stores `Ath`, `Amda` and committed `t`; static eigenvectors/generators do not acquire a time dimension. Ordinary `WVEulerianFields` groups can record physical fields and diagnostics on independent schedules. `WVCoefficients` remains the model's integrated observer. Integrated particles/tracers are outside the exponential integrator's supported observer surface.

```matlab
model = WVModel(thermal);
model.setupIntegrator(integratorType="exponential");
file = model.createNetCDFFileForModelOutput('thermal.nc',outputInterval=3600);
fields = file.addNewEvenlySpacedOutputGroup('fields',initialTime=1800,outputInterval=7200);
fields.addObservingSystem(WVEulerianFields(model,fieldNames={'qgpv','u','v','ssh','endpointAnomalies'}));
model.integrateToTime(86400,shouldShowIntegrationDiagnostics=false);
model.closeNetCDFFile();

restored = WVModel.modelFromFile('thermal.nc');
restored.setupIntegrator(integratorType="exponential");
restored.integrateToTime(172800,shouldShowIntegrationDiagnostics=false);
restored.closeNetCDFFile();
```

The model reader restores the last committed coefficient record (`iTime=Inf`), absolute clock, forcing objects and the file's own output graph. Integrator selection/settings must be explicitly reattached. Scientific construction and construction qualification are never rerun. The exponential adapter may diagonalize the **stored** MDA generator and rebuild numeric metric/closure caches; this is distinct from a scientific InternalModes solve. No stage or departure buffers are serialized.

The concrete thermal reader also supports direct snapshots and specific committed indices. A scalar snapshot accepts `iTime=1` or `Inf`; fractional indices reject. Requesting the second reader output returns an open caller-owned NetCDF handle; one-output reads close it. Failure paths close their handles. Complete-state ambiguity, missing families, finite times beyond an uncommitted hole and a stream with no committed records reject through the shared contracts. Uncommitted payloads are ignored and overwritten on resumed output.

Scientific-only root construction is supported when coefficients live in a stream. Schema-1 snapshots migrate to the schema-2 linear-only nonlinear policy without construction. Historical thermal snapshots lacking `t0` restore it as zero: thermal coefficients have physical amplitude conventions and carry no analytical reference-time phase. Their stored physical `t` remains authoritative. A missing historical forcing inventory restores empty; current writers include the complete inventory.

## Physical resolution transfer

```matlab
[fine,loss] = thermal.waveVortexTransformWithResolution([24 24 385],thermalModeCount=385,mdaModeCount=thermal.mdaModeCount);
[state,loss] = thermal.coefficientStateForTransform(restoredTarget);
restoredTarget.Ath = state.Ath;
restoredTarget.Amda = state.Amda;
restoredTarget.t = thermal.t;
restoredTarget.t0 = thermal.t0;
```

The first call constructs and qualifies a fresh target, then transfers state/clocks/forcing. The second uses an existing target's authoritative arrays and leaves both objects unchanged; it does not convert forcing. Domain, stratification, gravity, latitude, reference density, endpoint convention and diffusivity must agree. Change diffusivity explicitly through the existing immutable-basis API rather than hiding a physical change inside transfer.

Fourier integer pairs identify horizontal content. A common refined physical-depth Gauss rule evaluates the source polynomial state and fits target QGPV with exact retained endpoint anomalies. The result is expressed through the target's authoritative polynomial-to-thermal map. No eigenvalue sorting, eigenvector matching or coefficient-row copy identifies thermal directions. Reordered and sign-changed canonical target directions are tested.

Mean displacement is fitted independently, preserving its two endpoint anomalies and depth-integrated buoyancy. An insufficient mean space rejects inconsistent constraints. A small shared `thermalConstrainedFit` worker also serves native `projectState`; the two callers supply their own scientific reconstruction maps and quadrature. Coarsening may change the interior mean profile substantially despite preserving endpoint/inventory constraints. The returned mean-displacement residual makes that loss explicit.

The assessment contracts the **reconstructed difference** in a positive physical energy metric, including cross terms, and reports QGPV, buoyancy, velocity, SSH, separate endpoint and mean-profile residuals. It does not estimate loss by subtracting source/target energies. Fourier content removed by the target contributes to those errors. State coarsening reports loss; it does not silently enforce a campaign-specific acceptance threshold.

Seasonal forcing conversion uses the same retained Fourier identities, preserves amplitude/period/phase and returns sampled relative RMS round-trip pattern loss. Loss above `1e-8` rejects conversion, including content that the original compact representation cannot retain. Same-grid conversion preserves the original pattern exactly after validation. The shared forcing converter constructs a target-owned inventory atomically and rejects unsupported conversion. No source object is changed.

## Evidence and limits

[Restart results](restart.csv) use a short deterministic exponential-profile case: 500 km square, 1000 m depth, `N20=1e-4 s^-2`, scale 1300 m, grid 8 by 8 by 65, 17 thermal directions and four MDA directions. Nonparallel polynomial seed, signed mean, scalar diffusion `1e-5 m2/s`, strict seasonal forcing, quadratic drag `Cd=1e-3` and `WVThermalAPVDamping` with a frozen four-mode APV band and cutoff fraction `0.5` are active. The forcing period of 1000 s exercises a changing source phase during this small lifecycle fixture; it is not the campaign's annual forcing.

The run starts at physical time 127 s with `t0=31 s`, saves the coefficient checkpoint at 207 s, advances diagnostics through 227 s, stages poisoned payloads without committing their times, then restores and continues to 367 s. Before running, the continuation allowance was fixed at `1e-11` relative coefficient/field/inventory error (with `1e-12` absolute field floor). Coefficient change is measured to ensure this is an evolving trajectory. The maximum restored coefficient error is `3.1443e-16`; compared output error is `2.3614e-16`. All forcing configuration, including frozen APV endpoint weights, must match exactly. Committed time vectors are compared after column normalization because the NetCDF wrapper can return equivalent row/column orientations after appending.

The scientific snapshot is 157812 bytes and the interrupted file with coefficient plus field streams is 728591 bytes in this fixture. Snapshot writing took about 0.200 s and model restoration 0.689 s. These are single local timings that include normal annotation/file overhead, not throughput benchmarks. The separate `writeAndIntegrateSeconds` measurement includes integration and is labeled accordingly. Static scientific arrays were inspected to confirm absence of `t` dimensions, and root `Ath` duplication is rejected by the fixture.

[Transfer results](transfer.csv) include constant and exponential stratification controls. Refining thermal dimension 17 to 25 and horizontal/native sampling 8 by 8 by 65 to 12 by 12 by 97 gives positive physical field residuals `1.91e-14` and `1.22e-13`. Coarsening to nine thermal directions, three MDA directions and 6 by 6 removes four source Fourier columns and reports field losses of 17.7% and 15.7%. Endpoint and mean buoyancy-inventory constraints remain at roundoff. These large coarsening losses are evidence to inspect, not an accepted production resolution choice. Doubled comparison quadrature changes normalized error energy by less than `3e-17` in these cases.

## Short restart at the actual seasonal target

The separate [campaign-geometry restart](campaign-restart.csv) uses the literal target: 500 km square, 4000 m depth, latitude 24 degrees, `N20=(5.2e-3)^2 s^-2`, scale 1300 m, both endpoints active, scalar diffusion `1e-5 m2/s`, annual meridional mode-5 forcing with `M=10`, and quadratic drag `Cd=1e-3`. The complete thermal dimension is 257 on an 18 by 18 by 385 grid. The frozen diagnostic APV band retains four modes sampled at **513** depths, with cutoff fraction `0.5`; the thermal and diagnostic sample counts are independent.

The initial state has zero mean anomaly and manufactured nonparallel surface displacement with exactly 1 cm RMS, zero bottom displacement and projected zero interior QGPV. Seed residuals are `6.04e-22 s^-1` for QGPV and `1.46e-16 m` for endpoints. Qualified nonlinear quadrature has stored moment residual `1.15e-11` against its `1e-8` tolerance. The source has its declared zero phase and annual absolute clock.

The uninterrupted run covers 0–7200 s with nominal 600 s exponential steps. The interrupted case retains its complete coefficient record at 2400 s, commits diagnostics through 3000 s, and stages poisoned later payloads before restoration and continuation. The predeclared relative restart allowance is `1e-10` for coefficients, physical fields and energy. Observed errors are `1.0811e-20`, `7.8242e-16` and zero, respectively. All six [process contributions](campaign-processes.csv)—diffusion, seasonal source, advection, drag and separate horizontal/vertical damping—are nonzero at the final state. Their CSV norms are coefficient-rate magnitudes, not process power or evidence of a developed turbulent state.

The interrupted checkpoint contains 77258236 bytes. In this single local run the two-hour control required 2.60 s of integration and restoration required 1.46 s. Setup took 105 s including projected seeding and a new diagnostic APV representation/closure; it reused the separately constructed thermal state. These measurements locate I/O and construction costs but do not constitute campaign performance qualification. An initial exploratory run sampled the diagnostic APV band at 385 depths; the retained result uses 513 as required by the audited sampling policy.

Run the same case with:

```matlab
qualifyThermalCampaignRestart('/tmp/thermal-campaign-restart');
```

A preconstructed canonical thermal state can be supplied with `scientificStateFile` to avoid duplicate scientific construction. In a fresh process with all InternalModes providers removed, run:

```matlab
qualifyThermalCampaignRestart('/tmp/thermal-campaign-restart',restoreOnly=true);
```

The [fresh-process result](campaign-fresh.csv) passed with **no InternalModes symbols available**: coefficient error `1.0811e-20`, field error `7.8242e-16` and energy error zero. The complete forcing configuration, including the frozen APV endpoint weights and annual clock, was compared exactly. Stored generators and closure arrays were sufficient for integrator attachment and continuation.

This remains a **two-hour restart qualification**. It does not qualify the annual nonlinear solution, choose a production damping band or establish spatial convergence for the campaign.

## Reproduction and verification ledger

Authoring baseline: `875ac2ec`, on the milestone implementation branch. Shared regressions, Code Analyzer and documentation gates are recorded in the [milestone verification ledger](../BalancedDiffusionMilestone2.md). Required provider remains InternalModes `v2.0.0-beta.4`, revision `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`. The clean path uses installed OceanKit snapshots: InternalModes 2.0.0-beta.4, SplineCore 2.2.0, Distributions 2.0.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1. MATLAB R2026a on local Apple Silicon was limited to two computational threads for parallel qualification. Older sibling InternalModes paths were removed and `IMInternalModes` resolution verified unique.

From the authoring repository, configure the path with `tools/configureCIEnvironment`, remove sibling InternalModes paths, and add `UnitTests`, `UnitTests/Fixtures` and `tools`. Then run outside the macOS sandbox:

```matlab
results = runtests('UnitTests/TestThermalOutputRestart.m');
assertSuccess(results);
qualifyThermalRestart('/tmp/thermal-restart',fullPhysics=true);
```

In a **fresh MATLAB process**, configure the same runtime dependencies but remove every InternalModes snapshot/provider path before executing:

```matlab
assert(isempty(which('IMInternalModes')) && isempty(which('IMSolverSpectral')));
TestThermalOutputRestart.verifyRestartWithoutProvider('/tmp/thermal-restart');
```

The fresh-process helper copies the checkpoint before appending, so the interrupted original remains reproducible. It also transfers between stored representations before attaching the integrator, then verifies unchanged scientific/configuration state and physical continuation.

Seven focused tests cover snapshots/migration, committed output/restart, corrupt streams/file cleanup, cadence and failed-stage recovery, refinement/coarsening, representation ordering and forcing transfer. Initial probes exposed missing thermal `t0`/forcing annotations and horizontal dimensions; those public contracts were corrected. A real failed-stage recovery probe exposed repeated modal conversion of MDA during rollback; the controller now restores its exact accepted physical state. Test-only corrections normalized Gauss weights, compared empty construction reports by field names, and compared equivalent time-vector orientation.

Independent audit corrections added strict scalar-snapshot index validation and shared exact thermal WKB interpolation for mean fields. The latter avoids polynomial coordinate-inversion error at coarse native sampling in the deep exponential profile. All seven focused tests passed across the recorded targeted reruns, and all eight existing thermal construction/interface tests passed after introducing the shared physical fitting worker. The smaller full-physics fresh-process continuation passed with relative coefficient error `3.1443e-16`, including exact frozen APV `g0/gd` configuration restoration. Code Analyzer, documentation and the shared APV/Boussinesq regressions are recorded in the [milestone verification ledger](../BalancedDiffusionMilestone2.md). No released snapshot, package manifest, historical experiment pin or campaign output is modified. NetCDF/MAT qualification artifacts are generated in the requested output folder and are not runtime dependencies.
