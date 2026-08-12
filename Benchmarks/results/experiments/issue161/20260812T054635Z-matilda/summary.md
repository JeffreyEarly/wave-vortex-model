# Issue #161 descriptor feasibility — Matilda

Status: `CORE_REJECT` pending a batch-capable MATLAB runtime. The storage gate passes; MATLAB/MEX core correctness, lifecycle, and directional native timing could not run because MATLAB aborts before executing project code with `Incompatible processor. This Qt build requires the following features: neon`.

The experiment begins at `be0f78995c49a2bfe4c43d75827856e3812ac278`; the independent audit checkout is the clean detached `7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05` and remains unmodified.

The current descriptor owns 232 bytes per `[j,kl]` coefficient: 56 bytes are exact conjugate/sign duplicates (`U-`, `V-`, `W-`, and `N-`), while `ApmW` is a further 16-byte separable direct scale. The candidate stores a pre-scaled 8-byte `[j]` factor for `ApmW`, preserves #126 normalization at coefficient production, and reconstructs only the duplicate values inside the existing straight-line assembly. Its exact descriptor saving is `72 * (Nj * Nkl) - 8 * Nj + 96` bytes.

| Grid | Dynamics | Nj × Nkl | Direct / conjugated rows | Descriptor reduction | Complete known-owned live reduction |
|---|---|---:|---:|---:|---:|
| 256 × 256 × 65 | Hydrostatic | 42 × 11,439 | 5,805 / 5,634 | 34,591,296 B (30.61%) | 6.33% |
| 256 × 256 × 65 | Nonhydrostatic | 42 × 11,439 | 5,805 / 5,634 | 34,591,296 B (30.61%) | 5.96% |
| 512 × 512 × 129 | Hydrostatic | 85 × 45,765 | 23,053 / 22,712 | 280,081,216 B (30.82%) | 6.44% |
| 512 × 512 × 129 | Nonhydrostatic | 85 × 45,765 | 23,053 / 22,712 | 280,081,216 B (30.82%) | 6.07% |

The complete known-owned figure includes the immutable descriptor, bounded half-spectrum and real scratch arenas, and the three MATLAB flux outputs. FFTW-owned plan memory remains opaque, matching the existing metric contract.

Stored form retains all 232 bytes per coefficient. The adopted generated-at-construction form retains direct pre-scaled fields but replaces exact conjugate/sign arrays and the `[j,kl]` `ApmW` scale. A fully runtime-reconstructed descriptor was rejected: it would save more storage but would add divisions, square roots, and mode classification to every reconstruction/projection pass, creating an unfavorable arithmetic, cache-traffic, and code-complexity tradeoff.

Both the candidate and read-only audit C++ contract suites passed. These cover odd/even descriptor mappings, hydrostatic and nonhydrostatic kernel paths, alias/ownership rejection, repeat-call phase accounting, bounded scratch assertions, and injected planning/execution cleanup. They do not substitute for the blocked MEX comparisons: odd/even/nonsquare MATLAB comparisons, three-channel/single-output streamed variants, pointer stability, native lifecycle, and Matilda timing remain unexecuted.
