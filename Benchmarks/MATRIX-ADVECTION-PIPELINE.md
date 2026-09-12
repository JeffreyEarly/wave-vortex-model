# Matrix scheduling and immediate FFT advection consumption

This is a local optimization experiment following the shared-gradient pipeline in PR #476. The owner requested both directions. The implementation and focused verification are complete; a full idle-host performance campaign, source-linked consumer qualification and required hosted checks remain adoption gates. The experiment does not change MATLAB science, checkpoint formats, tracer algorithms or a running experiment.

## Changes

Hydrostatic and Boussinesq can consume each completed inverse FFT derivative plane immediately in the existing x/y/z advection accumulation order. The native retained FFT implementation invokes a synchronous consumer before releasing its plane task; fallback implementations deliver normalized physical output. Cached derivative hits use the existing pointwise path. Derivative storage remains available, capture still follows successful production, and callbacks touch only private flux scratch before publication. This removes a separate dispatch and improves locality without adding a physical-grid buffer. Compact runner execution selects it for Hydrostatic and Boussinesq only; direct callers can select `fusedDerivativeAdvection` explicitly.

Boussinesq now projects the wave-F inertial contribution only at its exact retained `(0,0)` column. Other projection outputs are unused by the coefficient assembly. The public complete projection remains available, and `inertialOnlyProjection=false` preserves the oracle. Exact retained identities and matrix membership remain authoritative; inconsistent identity falls back to the complete projection.

Prepared vertical operators can execute independent matrix groups through one persistent kernel-owned worker pool. Scalar and Accelerate backends declare support for concurrent calls. Packing buffers, when required, are separate for each worker; the measured model matrices already use direct views. Workspace and pool reentry are rejected. The compact Boussinesq runner selects up to eight workers, bounded by available performance cores. Direct construction defaults to one. Accelerate and its environment remain vendor controlled; no global thread settings are changed.

The spectral-kernel-benchmarks history had already accepted outer-group split-real Accelerate scheduling with a single-thread vendor cap. This experiment tests its transfer to the current complete model while leaving the vendor environment unchanged. Previously rejected packing bridges, zero-reset schemes and multi-pass vDSP coefficient assembly were not repeated.

## Isolated screens

Frozen baseline: `wave-vortex-model-benchmark-artifacts/shared-gradient-pipeline-20260911/qualified-candidate-wave-vortex-run`. Raw archive: `OceanKitRepositories/wave-vortex-model-benchmark-artifacts/matrix-advection-20260911`.

| Change | Workload | Measured reduction |
| --- | --- | ---: |
| Immediate FFT advection consumption | EddyTide integration | 8.35% |
| Immediate FFT advection consumption | Larger Hydrostatic integration | 3.71% |
| Immediate FFT advection consumption | Boussinesq integration | 5.51% |
| Exact inertial-column projections | Boussinesq integration | 10.34% |
| Eight matrix workers versus one, after inertial optimization | Complete Boussinesq nonlinear RHS | 26.14% |

Integration screens used two alternating baseline/candidate pairs per profile. Matrix workers were screened in order `1,2,4,8,8,4,2,1`, with two warmups and eight RHS samples per process. The median of process medians was 123.24 ms, 106.23 ms, 94.51 ms and 91.03 ms for one, two, four and eight workers. Kernel preparation stayed near 2.35 seconds. Matrix-group producer count was 23,635 per RHS, corresponding to 47,270 real Accelerate GEMM calls, down from the previous 60,762. The worker screen used twelve horizontal and twelve pointwise workers; the production runner uses twelve horizontal and eight pointwise workers on this host. The combined screen tests that actual runner policy.

These reductions are measured at different boundaries and must not be added. All output/flux comparisons passed. Flux differences in the worker sweep were at most approximately 5.1e-16 relative L2; repeated serial controls also showed final-bit variation.

## Verification ledger

- Combined native Release suite: 58/58 passed. Subsequent test-only lifetime correction reran only the two affected kernels successfully.
- ASan/UBSan: seven affected kernel, runtime, FFT and policy tests passed after a test-only correction. Initial H/B tests declared producer counters after the kernel owners, causing use-after-scope during instrumented plan destruction. Counters now outlive the plans; failed and corrected logs are retained. No runtime fix was needed.
- GCC 14: operator and both family kernel tests passed. The local runner target cannot compile the installed Apple SDK Mach header assertions with GCC; actual Linux runner CI remains required.
- MATLAB: all seven affected Hydrostatic/Boussinesq scientific parity methods passed, including compact consumers and concurrent Boussinesq matrix groups. Four integration/source checks passed initially; the stale native-engine identity check passed on focused rerun after updating source-selection metadata. No MATLAB source changed.
- Independent review covered consumer lifetime, derivative cache hits, normalization, density correction, partial inertial output, exact group mapping, worker scratch, failure publication, overflow, reentry and the combined conflict resolution.
- Prerequisite PR #476 cache-capacity probe corrections were verified under Release and sanitizers and pushed separately. Its runtime baseline is unchanged.

## Delivery boundary

Compiled runtime is frozen at `e8806710`; later source-selection and report edits do not alter compiled inputs. The local branches and raw archive retain separate experiments, failed checks, provider/binary/input hashes, requests and numerical comparisons. The combined screen is exploratory: Photos background services used about one core immediately before it, and a process-activity journal records the measurement period. It does not replace formal idle-host qualification.

Before merging, complete the idle-host paired campaign, refresh source-linked consumer receipts against the final source, and pass required hosted CI. Retain the exact independent reconstruction/projection controls for future qualification. Reprofile the accepted combination before selecting another larger refactor.
