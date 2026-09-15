# T10 verification ledger

This ledger accompanies the [readiness report](README.md) and [independent audit](Audit.md). It records retained post-reboot evidence inspected on 14 September 2026. All 62 focused methods passed on both R2026a and R2025b, and the bounded 64-grid restart checks below passed. The separately tested production correction passed all main, extended and package checks and merged. Final comprehensive Code Analyzer and documentation consistency checks remain pending at this draft; they are not implied by the completed checks.

## Evidence and environment

Original evidence is under `OceanKitRepositories/thermal-readiness-t10-evidence`. Paths in this ledger beginning with `recovery/` or `restart64-horizontal/` are relative to that directory. Small CSV/JSON artifacts are copied unchanged under [verification](verification/artifact-index.csv). The index records each inspected source's byte count and SHA-256; a blank `copy` column means the original log or launcher remains in the workspace evidence directory. The [per-class count](verification/focused-test-counts.csv) is derived from the two original test CSVs by taking the union of fully qualified method names.

The pre-reboot `/private/tmp/t10-readiness` directory is missing. Its binary results, process samples and temporary logs are unavailable and do not support this ledger. Large regenerated MAT/NetCDF files remain in the workspace evidence directory, outside the repository and exported package; reproduction requires those files or a new run of the explicitly invoked authoring drivers.

| Component | Retained qualification configuration |
| --- | --- |
| WVM v5 source baseline | `abe98510ba3ad24276c2af2bd89c80b24209b568` |
| Separate construction correction | `615b89109da4c7518462e9ab17270df731d0a090`, [PR #529](https://github.com/JeffreyEarly/wave-vortex-model/pull/529) |
| Production merge | `ee224bee309d802743ae365f4b22cc85ebbc563f`, 14 September 2026 at 23:55:31 UTC |
| Authoring code checkpoint | `85467674`, committed and pushed; one trailing end-of-file blank line was removed after the R2025b test run, with no semantic change |
| OceanKit | `1873071fe2dfc2678490df1b0252e5071e9d9715` |
| InternalModes | `2.0.0-beta.5`, `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37` |
| Other installed snapshots | Distributions 2.0.0; SplineCore 2.2.0; chebfun 5.7.0; NetCDF 1.0.2; ClassAnnotations 1.2.1 |
| Documentation dependency | ClassDocumentation 1.3.2 |
| Measured MATLAB | R2026a Update 4, `26.1.0.3312084`, `maca64` |
| Compatibility test MATLAB | R2025b, verified in the launcher with `version('-release')` |
| Declared package minimum | R2025b; manifest version 4.3.0 |
| Host | Apple M5 Max, 18 cores, 48 GiB RAM |

Launchers call `restoredefaultpath` and [configureCIEnvironment](../../../tools/configureCIEnvironment.m), remove sibling `/internal-modes` paths, and assert unique `IMInternalModes` resolution into `OceanKit/InternalModes-2.0.0-beta.5`. The initial focused test batch sets `maxNumCompThreads(2)`; subsequent recovery setup and restart runs use four threads. MATLAB launchers run outside the macOS sandbox. Released snapshots, package metadata and historical experiment pins remain unchanged. In particular, the historical APV comparison retains WVM `4ec07256476ee57ceee23d70422baec65d1f31a4` and InternalModes beta.4 `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`; these are separate from the current qualification dependencies.

## Focused tests and Analyzer

The retained invocation form is `matlab -batch "run('<workspace>/thermal-readiness-t10-evidence/recovery/<launcher>.m')"`, with `<workspace>` equal to the actual OceanKitRepositories path. Original launchers and logs are identified and hashed in the artifact index. An exit code applies to the entire launcher, including any Analyzer work after `assertSuccess(results)`.

| Launcher / evidence | Test result | Overall command and interpretation |
| --- | --- | --- |
| `verify_small.m`; [small-tests.csv](verification/recovery/small-tests.csv) | 59 passed, zero failed or incomplete | [Exit 1](verification/recovery/small-checks-v2/result.json) after the tests: Analyzer reported `DUPNAMEARG` in the construction audit. The older guard's `reason="completed"` does not override its nonzero return code. |
| `reviewedTests.m`; [reviewed-tests.csv](verification/recovery/reviewed-tests.csv) | 15 passed, zero failed or incomplete | [Exit 1](verification/recovery/reviewed-tests/result.json) after the tests: four [array-growth notices](verification/recovery/reviewed-analyzer.csv). |
| `diskWindowTests.m`; `recovery/disk-window-tests.mat` and `recovery/disk-window-tests/output.log` | The single `TestThermalReadiness/boundedLinearComparisonRequiresIndependentReference` method passed after the disk-window retention correction | [Exit 1](verification/recovery/disk-window-tests/result.json) in the subsequent Analyzer tail; the log reaches Analyzer only after `assertSuccess(results)`. |
| `verifyR2025b.m`; [r2025b-tests.csv](verification/recovery/r2025b-tests.csv) | All 62 unique methods passed, zero failed or incomplete | [Exit 0](verification/recovery/r2025b-tests/result.json); the launcher asserts both release `2025b` and exactly 62 results, then `assertSuccess(results)`. |

The 15-test batch overlaps the initial batch and adds exactly three methods: `TestThermalReadiness/initialRepresentationFailureStopsBeforeTrajectory`, `TestThermalReadiness/heldOperatorChangesAreRejectedBeforeTimeOrProductRuns`, and `TestThermalCampaignResources/setupCostsAreSeparatedAndAddedOncePerCampaign`. The union is **62 unique passing MATLAB methods**, not 74. The disk-window rerun is an additional execution of an existing method. Coverage includes construction, coefficient families, nonlinear tendencies, forcing, integration, committed output/restart, shared resolved interfaces, case admission, damping controls, field comparisons and resource accounting; these functional checks do not by themselves establish seasonal scientific readiness.

The R2025b CSV contains exactly the same 62 fully qualified method names as that R2026a union. Its [guard contract](verification/recovery/r2025b-tests/contract.json) uses an 8 GiB cutoff, 600-second wall limit and 0.25-second sampling. The invocation completed in 91.143 seconds with a sampled process-family physical-footprint peak of 2,247,937,840 bytes and no cancellation. This is the explicit authoring compatibility gate at the declared minimum MATLAB release; it is separate from hosted smoke selection and from Code Analyzer.

The broad `analyze.m` invocation inspected 24 files. Its [exit 0](verification/recovery/analyzer-v2/result.json) meant that the collection script completed; it did not assert an empty findings table. Its [five recorded findings](verification/recovery/analyzer.csv) therefore remain part of the verification history: unsupported `feature('getpid')`, one array-growth notice, two stale suppressions and one unused assignment. The subsequent strict [analyzer-final-v2 invocation](verification/recovery/analyzer-final-v2/result.json) also failed on array-growth notices. Those command results are not reported as clean Analyzer gates.

After the corresponding source fixes, `timeV2.m` first ran `analyzerFinal.m`. The retained `recovery/time-v2/output.log` lists `tools/qualifyThermalReadiness.m`, `tools/estimateThermalCampaignResources.m`, `tools/benchmarkPinnedThermalReadinessAPV.m` and `tools/runThermalReadinessStudy.m` without findings, then proceeds beyond the script's strict `assert(clean)` into the study. The enclosing invocation [exited 0](verification/recovery/time-v2/result.json). This establishes the final strict **four-file** check. A final strict inventory of all authored MATLAB files remains pending; the earlier collection-only scan is not a substitute.

The guard command `python3 tools/test_guardThermalReadiness.py` records **nine passing tests in 4.830 seconds** in `recovery/guard-self-tests.log`. Tests cover normal and failed commands, immutable output directories, cancellation, descendant memory, unrelated-process preservation, launcher exit, wall limits, failed measurements, invalid limits and PID reuse. See the [guard source](../../../tools/guardThermalReadiness.py) and [independent audit](Audit.md) for the boundaries of this evidence: userspace sampling cannot impose an instantaneous allocation ceiling, survive host shutdown or guarantee discovery of a child that daemonizes between samples.

## Actual 64-grid restart

The retained [restart contract](verification/restart64-horizontal/restart-contract.json) uses the target 500 km square, 4 km deep, 24-degree exponential-stratification case: 64×64×385 native grid, 257 thermal directions and four MDA modes. The fixed scalar diffusivity is `1e-5 m2/s`, both endpoints are active, and nonlinear advection, annual M10 strict mode-5 forcing, `Cd=1e-3` bottom drag and the frozen horizontal damping variant are attached. The authoritative manufactured developed state has `0.01 m/s` RMS velocity plus supported mean coefficients. The initial clock is `t=123`, with distinct `t0=45` and seasonal phase `pi/2`; the actual forcing argument includes the nonzero initial time.

The uninterrupted and interrupted paths use a 5400-second duration and a 900-second maximum fixed step. All paths explicitly visit the interruption boundary. The coefficient checkpoint is at 1923 seconds, interruption at 2823 seconds, and final time at 5523 seconds. Coefficients are observed every 1800 seconds, fields every 900 seconds starting at 348, and inventories every 600 seconds starting at 423. This exercises independent observer schedules and a checkpoint earlier than the latest committed observer records.

| Stream | Committed records before staged tail | Raw records before restoration | Completed records |
| --- | --- | --- | --- |
| Coefficients | 2 | 3 | 4 |
| Fields | 3 | 4 | 6 |
| Inventories | 5 | 6 | 9 |

The [staged-prefix table](verification/restart64-horizontal/staged-prefix.csv) records the deliberately incomplete tail. Both the [same-process continuation](verification/restart64-horizontal/continued-restart.csv) and [fresh-process continuation](verification/restart64-horizontal/fresh-restart.csv) have zero measured checkpoint/final coefficient error, field error and energy error. Every row of the two independent committed-stream comparisons ([continued](verification/restart64-horizontal/continued-streams.csv), [fresh](verification/restart64-horizontal/fresh-streams.csv)) has zero discrepancy: clocks, `Ath`, `Amda`, SSH, separate surface and bottom anomalies, energy, potential enstrophy and the two endpoint variances. Surface and bottom errors are checked independently against `1e-12 + 1e-10*referenceNorm`. The result concerns numerical values for this bounded case; the NetCDF files have different byte sizes and are not claimed to be byte-identical.

The [restart driver](../../../tools/qualifyThermalReadinessRestart.m) checks exact canonical scientific and forcing identities, coefficient restoration, `t` and `t0`. It requires an empty `constructionAssessment` after `WVModel.modelFromFile`. In the separately launched `recovery/restartFresh.m`, all InternalModes path families are removed and both `which('IMInternalModes')` and `which('IMSolverSpectral')` must be empty before `restoreOnly=true`. Successful replay therefore uses authoritative stored scientific arrays without the scientific provider. Numerical cache construction from those arrays remains allowed and is included in process time.

| Measurement | Original lifecycle process | Fresh provider-unavailable process |
| --- | --- | --- |
| Guard result | Completed, exit 0 | Completed, exit 0 |
| Sampled process-family physical-footprint peak | 16,489,383,744 bytes / 15.36 GiB | 15,404,205,072 bytes / 14.35 GiB |
| Sampled process-family resident-memory peak | 16,921,133,056 bytes / 15.76 GiB | 15,812,050,944 bytes / 14.73 GiB |
| Guard elapsed time, including startup | 133.278 s | 47.802 s |
| Checkpoint read | 3.806 s | 4.821 s |
| Continuation integration | 5.834 s | 6.009 s |
| Continuation accepted steps / RHS / output RHS | 4 / 16 / 24 | 4 / 16 / 24 |

The original and fresh [guard results](verification/recovery/restart64/result.json) / [fresh result](verification/recovery/restart-fresh/result.json) each record no cancellation signal. Their [contracts](verification/recovery/restart64/contract.json) / [fresh contract](verification/recovery/restart-fresh/contract.json) use a 16 GiB physical-footprint cutoff, 0.25-second sampling and respective 1800/900-second wall budgets. The OS-accounted child maximum RSS is a separate metric, not a simultaneous process-family sum. Read and continuation timings exclude integrator setup; process elapsed time includes startup, setup and comparisons. The [setup table](verification/restart64-horizontal/restart-setup.csv) separately records output preparation, integration, sync/close and file sizes, including a 696,602,778-byte checkpoint and 699,744,805-byte continued output.

These measured process values are distinct from the audit's analytical leading-cache estimate of approximately 11.17 GiB for complex storage or 5.585 GiB for real storage. The estimate is neither an observed allocation nor a process bound. The earlier approximately 4 GiB in-progress reading is not a final peak. A successful short manufactured restart does not qualify a mature seasonal trajectory, every damping variant or all restoration failures; the failure-only partial-model cleanup gap in `WVModel.modelFromFile` remains documented in [Audit.md](Audit.md).

## CI, package scope and remaining checks

The one-line production eigensolver correction was handled separately in [PR #529](https://github.com/JeffreyEarly/wave-vortex-model/pull/529). The coordinator's final hosted-status inspection records every main, extended and package check passing at tested head `615b89109da4c7518462e9ab17270df731d0a090`: [main CI run 34906625608](https://github.com/JeffreyEarly/wave-vortex-model/actions/runs/34906625608), [extended CI run 34906625535](https://github.com/JeffreyEarly/wave-vortex-model/actions/runs/34906625535), and [package CI run 34906625543](https://github.com/JeffreyEarly/wave-vortex-model/actions/runs/34906625543). The full MATLAB R2025b job passed in 55 minutes 52 seconds. The PR merged at `2026-09-14T23:55:31Z`, producing commit `ee224bee309d802743ae365f4b22cc85ebbc563f`. These are the production correction's checks; they do not imply hosted execution of the later authoring-only test suite.

For the authoring-only T10 change into `feature/v5.0-free-surface-qg` without `final-integration`, the [CI workflow](../../../.github/workflows/ci.yml) selects portable C++ contract/sanitizer checks, focused MATLAB R2025b and the required aggregator. The focused MATLAB command is `buildtool test:smoke analyze docs:check`. [buildfile.m](../../../buildfile.m) discovers and validates test classifications, but the new T10 classes retain their `full` tags and are not executed by that smoke selection. Default [production analysis](../../../tools/analyzeProductionCode.m) also excludes authoring tools and tests. The explicit local **62-method R2025b** compatibility run passed as recorded above; the final comprehensive authored-file Analyzer check remains pending. Hosted focused CI must not be described as having run these authoring tests.

The authoring change adds tools, tests and validation documentation. It changes no manifest, dependency snapshot, historical experiment pin, runtime integration law, release or website. Normal exported/installed runtime symbols remain the root class/package namespaces and manifest-listed runtime folders. The pinned OceanKit export excludes `tools` and `Documentation` physically, so `ThermalReadinessInventoryObserver` and the qualification drivers are not runtime dependencies. `UnitTests` files may remain in the exported payload, but are absent from the manifest-installed MATLAB path; export checks must not claim that all test files are physically removed. No new package export rule is required.

Remaining handoff checks are a strict full authored-file Analyzer inventory, one documentation consistency check, final whitespace/scope/generated-artifact review and the authoring change's own required hosted checks. No full seasonal campaign is rerun solely to validate this authoring report. Unrun scientific axes, mature-regime throughput and user-supplied production wall-time/disk limits remain readiness conditions in the main report, rather than missing functional-test passes.
