# T10 independent audit

This audit supports the [T10 validation report](README.md) and [accepted readiness plan](../../Architecture/Issue441ThermalReadinessPlan.md). It records source reviews and inspection of retained measurements on 14 September 2026. The independent review did not run MATLAB or alter scientific operators. The production correction has no identified correctness blocker; the final integration and readiness conclusions belong in the validation report.

Retained measurement paths below are relative to the workspace evidence directory `OceanKitRepositories/thermal-readiness-t10-evidence`, outside the exported package. They identify the evidence inspected for this audit, rather than results from other runs still in progress.

## Eigensolver correction and independent checks

Commit `615b89109da4c7518462e9ab17270df731d0a090` changes one solver option in [buildThermalPage](../../../+WVInternal/buildThermalPage.m): the eigendecomposition uses `nobalance` after the existing positive physical-energy QR scaling. The weak generator, complete trial space, source dual, eigenvector normalization, conjugacy checks, acceptance tolerances and persistence format remain unchanged. No direction or positive roundoff rate is removed. Restored scientific arrays remain authoritative.

At the affected radius, default balancing produces a numerically unusable eigenbasis. Exact similarity balancing does not mathematically change the stationary subspace; the failure concerns its computed representation. Disabling the additional balancing is supported by a comparison with a direct exponential of the same weak generator, rather than by eigenvalue residuals alone.

The [construction audit](../../../tools/auditThermalReadinessConstruction.m) separately assembles energy coordinates and an augmented generator containing both endpoint loads. Its `expm` reference does not use the runtime eigenvectors or diagonal evolution. It checks the full propagator, one homogeneous response and each endpoint source independently, then repeats assembly at 2057 and 4113 quadrature points. [TestThermalReadinessConstruction](../../../UnitTests/TestThermalReadinessConstruction.m) applies the declared inverse, eigenresidual, response and physical-refinement gates. The shared polynomial field evaluator means this is an independent test of the eigensolver and source-coordinate application, not a second derivation of the governing physics.

The regenerated `construction-audit/response.csv` records:

| Assembly points | Modal propagator | Relative Frobenius error against direct exponential |
| --- | --- | --- |
| 2057 | Diagnostic balanced solve | `4.27775e251` |
| 2057 | Runtime unbalanced solve | `7.03254e-14` |
| 4113 | Runtime unbalanced solve | `7.26887e-14` |

The largest corrected homogeneous and endpoint-source relative errors are `4.18e-15` and `5.79e-14`, respectively. The physical refinement table retains absolute errors and norms separately; near-zero opposite-endpoint responses are assessed with dimensional floors instead of requiring small raw relative errors.

The `construction-audit/radius-pages.csv` ledger contains 1094 passing pages: 48, 162 and 337 radii for each of the 32, 64 and 96 horizontal grids, at both 257 and 385 thermal directions. Maximum recorded condition number, inverse residual, eigenresidual and endpoint-source residual are `21.36397`, `1.455e-13`, `2.168e-16` and `1.504e-11`. The largest positive unit-diffusivity rate is `1.43154e-12`, corresponding to `1.43154e-17 s^-1` at the target diffusivity. These checks establish the bounded page construction; they do not substitute for native-grid, MDA, nonlinear-product or seasonal-trajectory qualification.

## Ownership and memory review

The [window qualifier](../../../tools/qualifyThermalReadiness.m), [restart qualifier](../../../tools/qualifyThermalReadinessRestart.m), [thermal benchmark](../../../tools/benchmarkThermalWorkload.m), [pinned APV benchmark](../../../tools/benchmarkPinnedThermalReadinessAPV.m) and [window comparison](../../../tools/compareThermalReadinessWindows.m) now explicitly release their owned model and transform handles. Cleanup covers completed repetitions, setup failures after construction, successful checkpoint restoration, output-close failures and temporary comparison snapshots. The case helper deletes a newly created target if initialization fails before returning it. The caller's authoritative initial or source transform is preserved.

Benchmark repetitions intentionally reuse one warm transform, while replacing and releasing their model objects. A restored benchmark model owns a separate transform, so both are deleted after its read measurement. Lifecycle control, interrupted and resumed models are released before the next lifecycle model is created. Temporary comparison transforms are released after each observation. These changes prevent completed objects' derived caches from being counted as a single simulation's ongoing requirement.

The source review found strong transform references in [WVForcing](../../../WVForcing.m) and [WVObservingSystem](../../../WVObservingSystem.m), as well as nested evolution callbacks. Closing a NetCDF file or clearing one local variable does not by itself prove that the transform is unreachable. Caller-retained forcing handles, transforms or returned diagnostic operators can still retain arrays. This is a plausible retention mechanism for the earlier multi-model workload, not forensic proof of the pre-reboot stall.

For [physicalMetricOperators](../../../@WVTransformFreeSurfaceThermalQG/physicalMetricOperators.m), the leading inventory is eight tall reconstruction/factor arrays per radius and six full Gram matrices. With quadrature count `Q=2057`, thermal count `N=257` and radius count `P=162`, the leading entry count is `8*Q*N*P + 6*N*N*P`. Treating every entry as complex double gives approximately **11.17 GiB**; the corresponding real-double estimate is approximately **5.585 GiB** using the rounded complex figure. This estimate excludes smaller arrays, scientific state, integrator/RHS caches, native output fields, temporary workspaces and MATLAB overhead. Sharing, real versus complex storage and operating-system accounting also affect the observed footprint. These arithmetic estimates are not measured allocations or process-memory bounds.

One failure-only ownership gap remains downstream in [WVModel.modelFromFile](../../../@WVModel/modelFromFile.m). If output-observer restoration fails after constructing the model, the factory closes its NetCDF file but does not explicitly delete the partial model and transform before rethrowing. A caller cannot reclaim an object that the factory never returns. This review left that shared runtime path unchanged; the successful restart qualification does not exercise that failure branch.

## Retained restart evidence

The inspected `restart64-horizontal/restart-contract.json` declares a 64×64×385 transform with 257 thermal and four MDA directions, the fixed 500 km by 500 km by 4 km geometry, a manufactured `0.01 m/s` developed state, M10 seasonal forcing and the frozen horizontal damping variant. The duration is 5400 seconds with a fixed maximum step of 900 seconds. Initial `t=123` and `t0=45` are distinct; the coefficient checkpoint, interruption and final times are 1923, 2823 and 5523 seconds.

The staged-prefix ledger contains 2 committed coefficient records followed by one staged record, 3 committed field records followed by one staged record, and 5 committed inventory records followed by one staged record. Field and inventory commits extend beyond the coefficient checkpoint, exercising independent observer schedules. Completed output has 4 coefficient, 6 field and 9 inventory records.

Both `continued-restart.csv` and `fresh-restart.csv` record zero checkpoint/final coefficient error, field error and energy error. Every row of both committed-stream tables has zero absolute discrepancy, including clocks, `Ath`, `Amda`, SSH, separately assessed surface and bottom anomalies, and all four inventories. The driver also checks exact scientific/forcing identities and clocks. This supports zero measured discrepancy for the declared bounded lifecycle; it does not claim byte-identical NetCDF files or unrestricted restart qualification.

The retained `recovery/restartFresh.m` starts a separate process, removes both InternalModes path families and asserts that `IMInternalModes` and `IMSolverSpectral` cannot resolve before invoking restoration. Continuation therefore exercises stored scientific arrays and numerical cache setup without the scientific provider.

| Measurement | Original lifecycle process | Fresh provider-unavailable process |
| --- | --- | --- |
| Final guard result | Completed, exit code 0 | Completed, exit code 0 |
| Sampled family physical-footprint peak | 15.36 GiB | 14.35 GiB |
| Sampled family resident-memory peak | 15.76 GiB | 14.73 GiB |
| Guard elapsed time, including process startup | 133.28 s | 47.80 s |
| Checkpoint read | 3.806 s | 4.821 s |
| Continuation integration | 5.834 s | 6.009 s |

These values come from `recovery/restart64/result.json`, `recovery/restart-fresh/result.json` and the restart CSVs. Both guard contracts use a 16 GiB cutoff and 0.25-second sampling; neither run received a cancellation signal. Read and continuation timings exclude integrator setup, whereas the guard elapsed time includes startup and other checks. The earlier in-progress observation near 4 GiB is not the final peak. The JSON's OS-accounted child maximum RSS is a separate metric, not a simultaneous process-family sum.

## Guard scope and tested limitations

The [external macOS guard](../../../tools/guardThermalReadiness.py) creates an owned process group, discovers descendants and checks process birth identities before signalling them. Memory-limit termination is immediate; wall-time and cancellation handling use a short TERM grace followed by KILL. A missing live-process measurement fails closed. The retained `recovery/guard-self-tests.log` records nine passing [guard tests](../../../tools/test_guardThermalReadiness.py), covering limits, normal and failed commands, immutable evidence, descendant memory, unrelated-process preservation, launcher exit, wall limits, cancellation and measurement failure.

The guard header states the limits of these tests and of userspace monitoring. Commands must not daemonize: a child that escapes and is reparented between samples may never be discovered. Host shutdown or SIGKILL of the guard bypasses its cleanup. Allocation can increase between samples. Summed physical footprint can count shared pages more than once, so it is a conservative process-family cutoff rather than unique host-memory usage or a reservation. The successful bounded checks do not establish an absolute instantaneous memory ceiling.

## Resolved source-review findings and remaining gates

Initial physical representation checks now precede trajectories in the [window qualifier](../../../tools/qualifyThermalReadiness.m). They compare initial states at both quadrature counts against one tenth of the spatial allowance and propagate failed or unresolved reference prerequisites to dependent cases. Time and product comparisons validate the authoritative scientific arrays held fixed outside the declared axis, including actual quadrature counts. Requested and effective refinements, source-normalization identity, separate endpoint norms and the tighter uncertainty allowances remain explicit. A cooperative wall budget is checked between short integration blocks; it does not rely on the diagnostics callback that is disabled when integration diagnostics are hidden.

The [resource estimator](../../../tools/estimateThermalCampaignResources.m) now separates construction, canonical restoration, initial-state writing, integrator setup, first RHS and sample-output setup. Its measured startup subtotal adds the relevant preparation costs once per campaign, reports missing component counts, and leaves unmeasured totals unknown. Construction and restoration are alternative preparation paths. M100 throughput is not inferred from M10 samples; serial combined scenarios sum independently measured cases. Shape-derived record payload is distinguished from allocated file growth and from unmeasured checkpoint/analysis costs. The [resource tests](../../../UnitTests/TestThermalCampaignResources.m) exercise these distinctions.

The pinned baseline's complete-control status now requires all four requested samples to complete their declared duration; partial timing remains explicitly partial. Its endpoint check uses the public `transformStateBack` API. Source inspection confirmed `matlabProcessID` is documented in the installed R2025b and R2026a reference catalogs as introduced in R2025a. The sampled current RSS field remains distinct from the external guard's process-family peak.

The retained `recovery/reviewed-tests.csv` records **15 passing tests**, with no failed or incomplete tests: nine readiness tests, three window-comparison tests and three resource tests. That invocation subsequently failed its Code Analyzer assertion on four array-growth notices, so its overall nonzero command result is not reported as a successful combined gate. The corresponding source concatenations have been revised; a fresh Analyzer result and final integration status are left to the validation report. This audit does not assign results to queued or ongoing runs.

The pre-reboot `/private/tmp/t10-readiness` directory is missing. Its earlier binary results, process samples and temporary logs cannot support retained-evidence claims. This audit relies on the surviving source and the explicitly identified regenerated workspace artifacts; no earlier temporary result is silently substituted for a missing check. Production wall-time/disk acceptance, mature seasonal throughput and any unrun scientific refinements remain separate readiness requirements.
