# Issue #161 descriptor feasibility — Matilda

Status: `ADVANCE`. The storage gate passes, candidate MATLAB/MEX checks pass, and the independent audit passes. The initial MATLAB Qt/NEON failure was caused by the filesystem sandbox; the unrestricted isolated batch path runs on Matilda.

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

Candidate MATLAB/MEX checks cover `7 × 6 × 7` hydrostatic, `8 × 8 × 9` nonhydrostatic, and `9 × 7 × 9` hydrostatic cases. Their maximum relative-infinity error is `1.03e-22`; repeat outputs are exact, descriptor/scratch/persistent pointers are stable, lifecycle is balanced, fallback is false, and persistent full-Hermitian storage is zero.

Same-host Matilda screening at `256 × 256 × 65`, one FFTW thread, two warmups, and five alternating samples reports 0.593135 s versus 0.594966 s for hydrostatic (1.003×) and 0.746199 s versus 0.753564 s for nonhydrostatic (1.010×), candidate versus exact `be0f789` baseline. Both final-output relative errors are zero. This is directional screening evidence only.

The read-only audit at `7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05` builds both `streamed-target-three-channel` and `streamed-target-single-output` variants. Across odd `7 × 6 × 7`, even `8 × 8 × 9`, and nonsquare `9 × 7 × 9` hydrostatic/nonhydrostatic cases (12 total), the maximum relative-infinity error is `9.36e-23` and repeat outputs are exact. Every case has stable ownership, no fallback, balanced lifecycle, bounded scratch, and zero persistent full-Hermitian storage. Injected plan, allocation, and execution failures are rejected; each execution-failure kernel recovers on its next call and cleans up completely.
