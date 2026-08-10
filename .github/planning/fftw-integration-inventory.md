# FFTW Integration Inventory

Issue: [#95](https://github.com/JeffreyEarly/wave-vortex-model/issues/95)

Authoritative data: [`fftw-integration-inventory.json`](fftw-integration-inventory.json)

Baseline: WaveVortexModel v4.2.1 at `9652b116b3ffd4ee3372cc5cdeea9700cd6cbc32`

This inventory separates released infrastructure, unreleased integration work, and disposable experiments. Issue #97 recorded `RETIRE`: no WaveVortex FFTW candidate cleared its complexity-adjusted model-level gate. The final cleanup was reconstructed from `main`; neither the integration branch nor an experimental branch was merged.

## Branch record

| Ref | Commit | Tree | Merge base | Unique commits | Disposition |
|---|---|---|---|---:|---|
| `v4.2.1` / `main` | `9652b116b3ffd4ee3372cc5cdeea9700cd6cbc32` | `a74e72a9b2c1886468edf877c133fa6edc9cf416` | — | — | Immutable builtin baseline |
| `feature/layout-neutral-fftw-backend` | `453e79c9190623c2cee8308e9bb9fe92c0647c63` | `90a7d4b831af5313ec70831243724f3517991a50` | v4.2.1 | 25 | Historical; selected cleanup reconstructed manually |
| `experiment/fftw-adapter-overhead` | `18a4de1c11250b2f2a9ce3e7530ff76a6827c23e` | `f84cbccc2688e236786d2d3bbfcf9b32f81f9938` | Integration head | 6 | Historical evidence only |

All three heads matched their corresponding remote refs and their worktrees were clean when this inventory was recorded.

## Component decisions

| Component ID | Origin | Current location | Disposition | Reconstruct? | Reason |
|---|---|---|---|:---:|---|
| `benchmark-framework` | #59 | `main` | Retain independently | no | Shared performance and memory benchmark contract |
| `full-mapping-baseline` | #69 | `main` | Retain independently | no | Frozen evidence for the optimized builtin mapping |
| `compact-layout-abstraction` | #70 | `main` | Retain independently | no | Released, faster, and shared by future backends |
| `legacy-expanded-mapping-removal` | #71 | `main` | Retained | no | Compact mappings replace vertically replicated compatibility state |
| `fourier-position-compact-reconstruction` | #71 | `main` | Retained | no | Backend-neutral use of the full layout contract |
| `obsolete-main-fftw-route` | legacy/main | removed | Removed | no | Unsupported three-plan adapter and probe retired |
| `half-x-adapter` | #71 | integration | Discarded | no | No production candidate qualified |
| `backend-selection-and-package-contract` | #72 | integration | Discarded | no | No public backend remains to justify the dependency or factory |
| `vertical-r2r-dispatch` | #73 | integration | Discarded | no | Did not qualify as a complete model-level contribution |
| `fftw-derivative-dispatch` | #74 | integration | Discarded | no | Conditional on the retired backend |
| `modal-direct-derivative-formulas` | #74 | integration | Discarded | no | Did not clear the contained complete-`nonlinearFlux` gate |
| `generic-storage-and-rss-tools` | #75 | `main` | Retained | no | Builtin-neutral storage and process-memory diagnostics support future kernels |
| `fftw-storage-readiness-machinery` | #75/#47 | integration | Discarded | no | Historical results remain in issues; unused harness code is not retained |
| `fine-grained-not-ready-record` | #47 | GitHub/integration | Historical only | no | Valid canonical decision, not reopened |
| `adapter-overhead-prototype-code` | #92 | investigation | Discard | no | Disposable experimental implementations |
| `adapter-overhead-evidence` | #92 | GitHub/investigation | Historical only | no | Stage, batching, ownership, and RSS evidence |
| `dispatch-cache-experiment` | #93 | GitHub/experiment | Discarded | no | Missed the contained-change gate and did not improve RSS |
| `matlab-half-mapping-experiment` | #96 | GitHub/experiment | Discarded | no | No new MATLAB mapping cleared the local-change gate |
| `coarse-gateway-experiment` | #94 | GitHub/experiment | Discarded | no | Missed the 20% architectural gate and increased RSS |
| `fftw-transforms-package` | external repository | released | Retain independently | no | Reusable outside WaveVortexModel |
| `integration-main-sync-merges` | branch history | integration | Historical only | no | Coverage records, not transferable changes |

## Commits requiring reconstruction

| Commit | Mixed concerns |
|---|---|
| `927c602c92b675414017970bee240e457a9518b0` | Independent legacy/Fourier-at-position cleanup plus conditional half-x adapter |
| `c2fcd0d9a00457daaea01bf6d3b8dfccf72360ce` | Obsolete-route removal plus conditional backend selection, persistence, and package dependency |
| `7781c86f7cd1e54c211384cb123496b9ea59cc50` | FFTW derivative dispatch plus independently judged modal-direct formulas |
| `c9b3be4b6c1f40d9fe815b2a27439d95565f9c7f` | Generic storage/RSS tooling plus FFTW-specific storage measurement |

These commits must not be cherry-picked into the final branch.

## Frozen builtin contract

The v4.2.1 builtin path:

- Stores canonical model coefficients as `[Nz,Nkl]`.
- Uses `WVFourierStorageLayout` with `mappingMethod="two-dimensional-rows"`.
- Uses full-complex Fourier storage for the builtin backend.
- Retains one reused full-complex row buffer for inverse transforms.
- Uses no vertically replicated mapping arrays in production transform calls.

The JSON inventory records Git blob and SHA-256 hashes for the builtin buffer owner, forward transform, inverse transform, geometry ordering, and layout class. It also records fixed hashes for the existing `core-v1`, layout-v1, layout-integration, and v4.2.1 release artifacts. No benchmark was rerun for this inventory.

## Final contract

- The supported lightweight implementation is the optimized MATLAB builtin path.
- WaveVortexModel has no FFTWTransforms dependency or public FFTW selector.
- `WVFourierStorageLayout` retains full and half-storage contracts for future compiled backends.
- Further FFTW work belongs to the compiled constant-stratification kernel milestone and compares against the optimized builtin baseline.
