# T10: Bounded nonlinear readiness on the local Mac

Implementation evidence for [#441](https://github.com/JeffreyEarly/wave-vortex-model/issues/441), following the [accepted plan](../../Architecture/Issue441ThermalReadinessPlan.md). This report separates construction, short-window accuracy, diagnostics, lifecycle and resource measurements. A manufactured stress state is not a mature seasonal trajectory. No production campaign was launched.

## Scientific and execution contract

The fixed domain is 500 km square and 4 km deep at 24 degrees, with `N2(z)=(5.2e-3)^2*exp(2*z/1300)`, both endpoints active, insulating scalar diffusion `kappa_z=1e-5 m2/s`, strict annual mode-5 surface-displacement forcing, and quadratic bottom drag `Cd=1e-3`. The starting thermal configuration is 64×64×385, 257 complete directions, four MDA modes, 2057 assembly points and 1537 nonlinear product points. The reporting allowances were frozen before qualification in the accepted plan and each run contract. Temporal/initial-transfer comparisons use 0.1 of the full spatial allowance; reference and quadrature uncertainty each use at most 0.2 of that effective allowance.

The cold seed has zero interior QGPV, bottom anomaly and horizontal mean, with a deterministic 1 cm RMS surface anomaly. Developed controls use three nonparallel, low-degree pressure modes normalized once on a common 513-point quadrature, plus four supported mean coefficients. Target transforms receive the authoritative physical state through the existing transfer contract. The 0.1 m/s version is explicitly a numerical stress fixture: weak deep stratification produces bottom displacements that can violate small-amplitude QG assumptions. Its throughput cannot stand in for a physically credible mature seasonal regime.

The online closure comparison freezes one six-mode APV law on the candidate grid, with `apvCutoffFraction=.5`. Horizontal-only damping reuses `WVThermalAPVDamping` with exactly zero `apvVerticalRates`; it retains the same stored APV arrays and physical horizontal filter. Its unused APV setup and application work remain in timings. The 64-mode offline diagnostic is a separate basis and never redefines the damping law.

The host is an Apple M5 Max with 18 cores and 48 GiB RAM, running MATLAB R2026a Update 4 (`26.1.0.3312084`, `maca64`). Warm timing uses four MATLAB threads after a serial 1/2/4-thread screen. The qualification budget is four compute hours in cooperative blocks of at most 30 minutes; the proposed process-memory ceiling is 32 GiB. Production wall-time and disk acceptance limits have not been supplied, so production resource feasibility remains conditional.

## Required construction correction

The actual 64-grid factory initially failed at radius `13*2*pi/500000` with a nearly singular eigenbasis and a non-involutive conjugacy map. MATLAB's default balanced eigensolve produced a numerically unusable basis in coordinates already scaled by the positive physical-energy QR factorization. Exact similarity balancing does not mathematically change the stationary subspace; the observed defect concerns its computed representation. The correction is one solver option in `WVInternal.buildThermalPage`: `eig(generator,'nobalance','vector')`. It changes no weak operator, source, rate clipping, retained direction, tolerance or persistence format. Stored scientific arrays remain authoritative on restoration.

At the failing 2057-point assembly, the original balanced modal propagator has relative Frobenius error `4.28e251` against a direct matrix exponential; the regenerated corrected result agrees to `7.03e-14` (`7.27e-14` at 4113 assembly points). A separately assembled augmented exponential verifies the homogeneous response and both strict endpoint sources. The 2057/4113 refinement retains dimensional absolute floors for near-zero opposite-endpoint responses; raw relative errors remain in the ledger. All 1,094 requested radius pages across 32/64/96 grids and 257/385 directions pass unchanged construction guards. The largest eigenbasis condition is 21.364; the largest positive unit-diffusivity roundoff rate is `1.432e-12`, retained rather than clipped (`1.432e-17 s^-1` at the target diffusivity). These page checks do not replace full native-grid/MDA/product qualification.

## Reproduction and provenance

Start from the authoring checkout on the v5 line, based on `abe98510ba3ad24276c2af2bd89c80b24209b568`. Configure the path with `tools/configureCIEnvironment`, then remove sibling InternalModes authoring checkouts and assert unique resolution into `OceanKit/InternalModes-2.0.0-beta.5`. OceanKit revision is `1873071fe2dfc2678490df1b0252e5071e9d9715`; InternalModes beta.5 is `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`. Other installed snapshots are Distributions 2.0.0, SplineCore 2.2.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1; documentation uses ClassDocumentation 1.3.2. Released snapshots and historical experiment pins are unchanged.

Each invocation uses a new output directory. The authoring utilities are excluded from package exports and are invoked explicitly; public runtime behavior uses the ordinary transform, forcing, model and annotated persistence interfaces.

```matlab
restoredefaultpath;
addpath(fullfile(wvmRoot,'tools'));
configureCIEnvironment(wvmRoot,oceanKitRoot);
p = string(strsplit(path,pathsep));
bad = contains(p,'/internal-modes');
if any(bad), rmpath(char(join(p(bad),pathsep))); end
assert(contains(which('IMInternalModes'),'/InternalModes-2.0.0-beta.5/'));
assert(numel(string(which('IMInternalModes','-all'))) == 1);
maxNumCompThreads(4);

[w,manifest] = thermalReadinessCase();
scientificState = w.scientificState;
save(fullfile(outputRoot,'scientific64.mat'),'scientificState','-v7.3');
report = runThermalReadinessStudy(outputRoot,"time", ...
    scientificCache=fullfile(outputRoot,'scientific64.mat'));
```

Run the named `product`, `native`, `horizontal`, `thermal` and `mean` blocks separately to release memory between comparisons. Mechanism blocks are `closures`, `activity`, `cold10`, `cold100`, `peak10` and `zero100`; the closure block requires the separately frozen canonical closure MAT file. Every block saves its exact case parameters, scientific/coefficient hashes, forcing choice, observation semantics, allowances and actual quadrature counts. Comparison references are genuinely finer; absent or uncertain refinements remain inconclusive.

The pre-reboot `/private/tmp/t10-readiness` directory was lost. Regenerated binary evidence is retained under `OceanKitRepositories/thermal-readiness-t10-evidence`; the artifact ledger records exact paths and hashes. Evidence paths are not runtime dependencies. Regenerate from the authoring drivers if those files are removed. Small CSV/JSON measurements and the verification/failure ledgers are retained here. Pre-reboot numerical observations must not be confused with retained regenerated evidence.
