# T10: Bounded nonlinear readiness on the local Mac

Implementation evidence for [#441](https://github.com/JeffreyEarly/wave-vortex-model/issues/441), following the [accepted plan](../../Architecture/Issue441ThermalReadinessPlan.md). This report separates construction, short-window accuracy, diagnostics, lifecycle and resource measurements. A manufactured stress state is not a mature seasonal trajectory. No production campaign was launched.

## Decision: NOT READY for the seasonal campaign

T10 produces a useful conditional candidate and identifies its limits. The required full diagnostic record set fails its current cold-state coefficient reporting gate, and the finer thermal reference is missing. Under the accepted decision rules, this is **NOT READY for the long E2 campaign**; it is not evidence that every tested trajectory is inaccurate. Retain **64×64×385, 257 complete thermal directions, four mean modes, 2057 assembly points, 769 nonlinear product points, no optional damping and a 900-second maximum fixed step** as the candidate for the next bounded prerequisite checks. The 769-point rule has its own case identity. Most spatial/time comparisons use the original 1537-point rule; the fixed-space 769/1537/3074 comparison supplies the measured connection between them, not a claim that every spatial matrix was repeated at 769.

The principal numerical entry gap is thermal bandwidth. The complete 257/385 trajectories differ by at most **0.6484% in QGPV**, below the declared one-percent field allowance. The 513-direction trajectory stopped at the 32 GiB memory guard before producing a saved observation. Without that finer error estimate, all 81 lower-pair difference rows remain **INCONCLUSIVE REFERENCE**. A small quadrature uncertainty does not supply the missing bandwidth reference. The next useful runtime task is to reduce the physical-diagnostic cache cost enough to obtain that one reference while preserving physical cross terms and the existing tolerances.

The cold diagnostic failure is a reporting limitation that needs an explicit rule before a rerun. Its QGPV source RMS is only `1.840e-21 s^-1`, below the existing `1e-13 s^-1` diagnostic comparison floor. All 36 cold-initial physical observable rows pass, but the coefficient test has no absolute floor and reports relative changes of 0.5345 and 0.5654. The APV reference coefficient norms are only `1.08–1.13e-22 s^-1`, with absolute Frobenius changes of `5.80–6.38e-23 s^-1`; the nonzero boundary family changes by at most `2.59e-12` relatively. These raw coefficient norms are distinct from physical field RMS. The 129/257-depth basis capacity checks pass; the attempted fallback cannot run because the saved 513-depth basis is absent and scientific construction is disabled. The raw failed result remains authoritative. Do not increase depth counts just to chase this near-zero ratio.

The closure decision is clearer. Prefer **no optional damping** on the demonstrated windows, while retaining physical diffusion and bottom drag. The historical six-mode vertical APV taper supplies **positive physical energy work** and produces a **32.53% QGPV difference** and **11.68% upper-200-m buoyancy-gradient difference** after six hours, exceeding the five-percent bias screen. Horizontal-only damping passes that screen but barely acts on this low-support fixture; it is a fallback whose efficacy on a developed cascade is still unmeasured. These results do not justify a stronger vertical taper or a new closure within T10.

| Gate | Retained outcome and scope |
| --- | --- |
| Construction and existing interfaces | Corrected eigensolver passes direct-exponential checks and 1094 radius pages. All 62 focused methods pass on R2026a and the minimum R2025b. |
| Time, product, native, horizontal and mean comparisons | Completed declared field comparisons pass. The horizontal comparison is a 32/64/96 sequence; the mean control starts with four supported mean modes. Neither establishes arbitrary future spectral support. |
| Constant-stratification control | Independent assembled tendency and the three time-step windows pass, including both endpoints and mean. |
| Thermal bandwidth | 257/385 difference measured; 513 reference missing after a memory cutoff. Numerical readiness remains conditional. |
| Process budgets | Both product rules pass all four dense manufactured-window budgets. The single denser cold M10 attempt stops at 16 GiB; cold M100 completes with enstrophy sampling still inconclusive. Sparse and refined results remain separate. |
| Lifecycle | Original and 769-point candidate continuations on the 64×64 grid succeed with scientific construction unavailable; independent stream clocks, staged tails and physical fields are checked. |
| Offline diagnosis | Eleven of 13 records at 1537 product points, plus the separate 769-point checkpoint pass their sampling checks. The two exact cold starts fail the relative coefficient criterion; the required 13-record summary is **FAIL**. |
| Nonlinear activity | The six-hour comparison misses the declared trigger. The single three-day extension reaches it for QGPV and velocity at the first qualifying observation, 18 hours; this does not extend the six-hour accuracy qualification. |
| Regime and resource coverage | Manufactured controls and short cold starts do not cover a true forcing cycle or mature seasonal flow. Production wall-time/disk limits remain unaccepted. |

See [accuracy and budget evidence](Accuracy.md), [workload measurements](Measurements.md), [verification](Verification.md), the [independent audit](Audit.md), [closure/product audit](ClosureAudit.md), [reproduction instructions](Reproduction.md) and the [bounded follow-up](Handoff.md). Detailed ledgers preserve failed processes and unresolved scientific gates; a completed process is not automatically a passing scientific comparison.

The concrete follow-ups are [#530: diagnostic memory and the missing reference](https://github.com/JeffreyEarly/wave-vortex-model/issues/530), [#531: near-zero diagnostic comparison policy](https://github.com/JeffreyEarly/wave-vortex-model/issues/531), and [#532: failure cleanup during restart](https://github.com/JeffreyEarly/wave-vortex-model/issues/532). The first two address qualification gaps; the third is a shared lifecycle correction and is not a measured explanation of the Mac stall.

Both three-day activity trajectories complete 288 steps without rejection. The QGPV difference reaches 38.29% against the advection-disabled companion, or 7.66 times the declared activity threshold. This is a process contrast, not discretization error. Their sparsely sampled energy/bottom budgets pass while enstrophy/surface budgets remain inconclusive; no further extension or cadence refinement is inferred. The manufactured stress state remains outside a credible small-displacement seasonal interpretation.

## Measured local cost

Each sample below integrates six model hours at a 900-second maximum fixed step on four threads, with output enabled. All completed samples use 24 accepted steps, no rejections and 96 integration RHS evaluations; no extra RHS evaluations are needed at these aligned sample output times. Restart's independent output schedules do incur separately recorded interpolation work.

| Workload | Integration wall-time range |
| --- | ---: |
| Candidate thermal, cold M10 | 7.919–8.351 s |
| Candidate thermal, manufactured 0.01 m/s M10 at source peak | 7.883–8.317 s |
| Candidate thermal, manufactured 0.1 m/s M100 at source peak | 7.886–8.326 s |
| Historical pinned APV, cold M10 | 5.333–5.502 s |

Reducing thermal product sampling from 1537 to 769 cuts the median matched cold integration time by **34.75% with output** and **36.85% without output**. The selected thermal cold sample still takes about **1.50 times the APV wall time with output**. The historical APV representation uses 217 APV/321 MDA modes on 513 native depths and its own pinned dependency graph. Matching the cold physical recipe and optional-damping choice does not establish equal physical accuracy. No mature historical outputs were available at `free-surface-qg-experiments/output/64-10x` or `output/64-100x`, so that comparison remains unmeasured.

The candidate timing processes peak near **14.6 GiB** of sampled family physical footprint; the historical APV cold process peaks near **5.29 GiB**. The 96-grid reference reaches **30.06 GiB**. The failed 513-direction reference reaches a sampled **32.19 GiB** before the 32 GiB guard terminates it; sampling permits a small overshoot. Recorded host snapshots show zero swap use, with nonzero compressed memory. These are process/host observations, not a guarantee against future memory pressure or proof that the 48 GiB machine cannot fit a differently implemented reference.

Scaling only these measured integration rates, with sample output enabled, gives:

| Case | One model year | Five model years | Twenty model years |
| --- | ---: | ---: | ---: |
| M10 | 3.20–3.39 h | 16.00–16.95 h | 63.99–67.79 h |
| M100 | 3.20–3.38 h | 16.00–16.89 h | 64.01–67.58 h |
| Both, serial | 6.40–6.77 h | 32.00–33.84 h | 127.99–135.36 h |

The combined 20-year logical payload scenario is **7.034 GB (6.551 GiB)**, including the measured initial files and 1922 coefficient/15362 scalar records across both cases. This is a storage floor, not allocated campaign storage. Checkpoint copies, full-field snapshots, analysis products and filesystem overhead remain additional. See the [resource ledger](Measurements.md) for the complete scenarios and unknown components.

Scientific construction, numerical-cache setup, file restoration and analysis are separate from these warm integration times. The campaign-resource ledger scales the measured workloads into 1/5/20-year scenarios and retains unknown analysis, checkpoint and allocated-storage costs. A true annual pilot does not fit the remaining bounded qualification budget at the measured step policy; no year was compressed or source rescaled to create one.

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

[w,manifest] = thermalReadinessCase(struct(), ...
    cacheFile=fullfile(outputRoot,'scientific64.mat'));
delete(w);
clear w manifest
report = runThermalReadinessStudy(outputRoot,"time", ...
    scientificCache=fullfile(outputRoot,'scientific64.mat'));
```

Use a fresh guarded process for each block, as specified in [Reproduction.md](Reproduction.md). Run the named `product`, `native`, `horizontal`, `thermal` and `mean` blocks separately to release memory between comparisons. Mechanism blocks are `closures`, `activity`, `cold10`, `cold100`, `peak10`, `zero10` and `zero100`; the closure block requires the separately frozen canonical closure MAT file. Every block saves its exact case parameters, scientific/coefficient hashes, forcing choice, observation semantics, allowances and actual quadrature counts. Comparison references are genuinely finer; absent or uncertain refinements remain inconclusive.

The pre-reboot `/private/tmp/t10-readiness` directory was lost. Regenerated binary evidence is retained under `OceanKitRepositories/thermal-readiness-t10-evidence`; the artifact ledger records exact paths and hashes. Evidence paths are not runtime dependencies. Regenerate from the authoring drivers if those files are removed. Small CSV/JSON measurements and the verification/failure ledgers are retained here. Pre-reboot numerical observations must not be confused with retained regenerated evidence.
