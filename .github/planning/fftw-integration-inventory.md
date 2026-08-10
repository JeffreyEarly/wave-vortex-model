# FFTW Integration Inventory

Issue: [#95](https://github.com/JeffreyEarly/wave-vortex-model/issues/95)

Authoritative data: [`fftw-integration-inventory.json`](fftw-integration-inventory.json)

Baseline: WaveVortexModel v4.2.1 at `9652b116b3ffd4ee3372cc5cdeea9700cd6cbc32`

This inventory separates released infrastructure, unreleased integration work, and disposable experiments before any further FFTW implementation. Final production or cleanup work starts from `main`; neither `feature/layout-neutral-fftw-backend` nor `experiment/fftw-adapter-overhead` is a merge candidate.

## Branch record

| Ref | Commit | Tree | Merge base | Unique commits | Disposition |
|---|---|---|---|---:|---|
| `v4.2.1` / `main` | `9652b116b3ffd4ee3372cc5cdeea9700cd6cbc32` | `a74e72a9b2c1886468edf877c133fa6edc9cf416` | — | — | Immutable builtin baseline |
| `feature/layout-neutral-fftw-backend` | `453e79c9190623c2cee8308e9bb9fe92c0647c63` | `90a7d4b831af5313ec70831243724f3517991a50` | v4.2.1 | 25 | Reconstruct selected components only |
| `experiment/fftw-adapter-overhead` | `18a4de1c11250b2f2a9ce3e7530ff76a6827c23e` | `f84cbccc2688e236786d2d3bbfcf9b32f81f9938` | Integration head | 6 | Never merge; preserve conclusions only |

All three heads matched their corresponding remote refs and their worktrees were clean when this inventory was recorded.

## Component decisions

| Component ID | Origin | Current location | Disposition | Reconstruct? | Reason |
|---|---|---|---|:---:|---|
| `benchmark-framework` | #59 | `main` | Retain independently | no | Shared performance and memory benchmark contract |
| `full-mapping-baseline` | #69 | `main` | Retain independently | no | Frozen evidence for the optimized builtin mapping |
| `compact-layout-abstraction` | #70 | `main` | Retain independently | no | Released, faster, and shared by future backends |
| `legacy-expanded-mapping-removal` | #71 | integration | Retain independently | yes | Compact cleanup is mixed with the half-x adapter |
| `fourier-position-compact-reconstruction` | #71 | integration | Retain independently | yes | Backend-neutral use of the full layout contract |
| `obsolete-main-fftw-route` | legacy/main | `main` | Remove from main | yes | Unsupported and obsolete in either final outcome |
| `half-x-adapter` | #71 | integration | Conditional | yes | Reference only until a candidate clears #94 |
| `backend-selection-and-package-contract` | #72 | integration | Conditional | yes | Public/dependency complexity requires a qualified backend |
| `vertical-r2r-dispatch` | #73 | integration | Conditional | yes | Retain only with model-level qualification |
| `fftw-derivative-dispatch` | #74 | integration | Conditional | yes | Exact regions depend on the selected backend |
| `modal-direct-derivative-formulas` | #74 | integration | Conditional | yes | Must independently clear the contained-change gate |
| `generic-storage-and-rss-tools` | #75 | integration | Retain independently | yes | Needed by later transform and kernel decisions |
| `fftw-storage-readiness-machinery` | #75/#47 | integration | Conditional | yes | Rebuild only what the final clean gate needs |
| `fine-grained-not-ready-record` | #47 | GitHub/integration | Historical only | no | Valid canonical decision, not reopened |
| `adapter-overhead-prototype-code` | #92 | investigation | Discard | no | Disposable experimental implementations |
| `adapter-overhead-evidence` | #92 | GitHub/investigation | Historical only | no | Stage, batching, ownership, and RSS evidence |
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

## Downstream contract

- #96 may test only the remaining bounded MATLAB half-spectrum mappings.
- #93 may retain cached dispatch only under its contained-change gate or as part of a qualified cumulative candidate.
- #94 may use the integration and investigation branches as references but must prototype on a nonmergeable branch.
- #97 must create its final PROMOTE or RETIRE branch from `main`, reconstruct retained pieces, and remove the obsolete main-branch FFTW route in either outcome.
