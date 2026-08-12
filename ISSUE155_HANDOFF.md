# Issue #155 feasibility handoff

## Decision

**FEASIBILITY_REJECT.** Do not build a production-facing pruned/generated engine or begin a benchmark run. The exact radial mask is large, but no evaluated candidate has a qualified path to the required `>=15%` complete horizontal-block improvement on Lyra.

## Reused controls

- Baseline ancestor: `be0f78995c49a2bfe4c43d75827856e3812ac278`.
- Assigned scaffold: `782e9b41b76628eb0f61b1bd87339dd69b884314`.
- Reused #128 standalone artifact: `Benchmarks/results/experiments/issue128/20260812T030810Z/summary.md` and `results.json`.
- Reused source identity: FFTW++ `1a185f41800cd0e9d4df4ddf93e16e362d4e2c45`, with `LICENSE.LESSER` (LGPL-3.0-or-later) in `/private/tmp/issue128-fftwpp-source`. No dependency source, library, executable, generated code, or cache is tracked in this branch.

## Exact radial retention

`tools/compiled-kernel/tests/Issue155RadialRetention.cpp` constructs the production descriptors without MATLAB or an FFT provider and asserts that each retained WV mode owns a distinct Hermitian half-spectrum row. It repeated descriptor construction/destruction 16 times for each physical configuration.

| Production shape | `Nj` | Dense half rows | Retained rows | Known-zero/discarded rows | Known-zero fraction | Retained coefficients | Discarded c2r inputs/r2c outputs |
|---|---:|---:|---:|---:|---:|---:|---:|
| 128 x 128 x 33 | 21 | 8,320 | 2,861 | 5,459 | 65.613% | 60,081 | 114,639 |
| 256 x 256 x 65 | 42 | 33,024 | 11,439 | 21,585 | 65.362% | 480,438 | 906,570 |

Thus the canonical `[Nj,Nkl]` state omits 1.83 MiB and 14.51 MiB, respectively, of double-complex dense-half-spectrum values per coefficient field. The retained disk still spans 43 of 65 medium and 86 of 129 large nonnegative-`k` columns; it is not a sparse set of isolated bins.

## Bounded hand-pruned model

For a square `N x N` real/Hermitian transform, a conventional two-pass split has the proxy cost

`2.5 N^2 log2(N) + 5 N (N/2 + 1) log2(N)` real flops,

where the first term is the real transform and the second is the complex pass over the nonnegative-`k` columns. A bounded manual implementation can only omit the columns that are identically zero before or irretrievably discarded after that complex pass. It cannot omit the real pass: physical fields and nonlinear products are dense.

| `N` | Dense proxy flops/plane | All-zero `k` columns skipped | Transform-only ceiling |
|---:|---:|---:|---:|
| 128 | 577,920 | 22 of 65 | 17.054% |
| 256 | 2,631,680 | 43 of 129 | 16.732% |

This is an optimistic ceiling, not a predicted speedup: it charges no packing, zero-fill, strided gather/scatter, normalization, plan storage, or generated-code instruction-cache cost. The native horizontal schedule has 13 c2r plus 3 r2c batches in hydrostatic mode and 16 c2r plus 4 r2c batches in nonhydrostatic mode; every batch still writes a dense real plane, and all target products remain dense. Even if the entire recorded reconstruction, derivative-reconstruction, and projection time in the matched #128 pthread control were reducible at that ceiling (it includes ineligible vertical and mapping work), the complete `nonlinearFlux` upper bound is only 14.53%, 14.71%, 14.56%, and 14.75% for medium hydrostatic, medium nonhydrostatic, large hydrostatic, and large nonhydrostatic cases. The actual horizontal-block improvement is necessarily lower. Therefore the required 15% feasibility gate fails before a production-shape prototype or reportable timing is justified.

The mask has additional radial variation within each live column. Exploiting it requires a true two-dimensional partial transform rather than bounded Cooley--Tukey pruning. That would add irregular gather/scatter, one generated/specialized kernel per shape and direction, separate c2r/r2c Hermitian normalization, and a new standalone OpenMP orchestration; no credible operation or traffic model from the available implementations pays for those costs at a 1.7-point transform-only margin.

## Candidate assessment

| Candidate | Real/Hermitian batched 2-D path | arm64 NEON + standalone OpenMP evidence | Reproducibility / code size / license | Outcome |
|---|---|---|---|---|
| SPIRAL / FFTX | Not qualified. FFTX documents fixed-size 1-D and 3-D libraries; its batched 1-D real transforms are explicitly “in development.” It does not document a masked radial 2-D c2r/r2c primitive. | No generated arm64/NEON artifact or verified standalone-OpenMP path was available locally. | BSD-style license is acceptable, but generation requires SPIRAL plus `fftx`, `simt`, `mpi`, and `jit` packages; library generation and runtime code generation create source/library caches. Generated size cannot be bounded before a qualified generator run. | Reject at interface/reproducibility gate. |
| Partial FFT formulation | The cited result is a 1-D space-varying cutoff formulation, not an available real/Hermitian 2-D radial batched implementation. | No arm64/NEON/OpenMP implementation or source identity is available in the #128 environment. | Paper-only route; source, license, generated-code provenance, and maintenance surface are unverified. | Reject at implementation gate. |
| Bounded hand-pruned Cooley--Tukey | Exact for the rectangular all-zero `k`-column subset, but leaves the dense real pass and all radial interior pruning unexploited. | Could use the existing pinned native FFTW providers, but has no 15% complete-block headroom after required traffic and mapping. | Small generic control code but would require new plan, scratch, mapping, Hermitian, normalization, correctness, and lifecycle machinery for each direction; no dependency-license issue. | Reject at operation/traffic gate. |

Primary-source notes: [FFTX README](https://raw.githubusercontent.com/spiral-software/fftx/main/README.md) requires the SPIRAL package set, generates library source before build, caches runtime-generated code, lists fixed 1-D/3-D libraries, and marks batched 1-D real transforms as in development. [SPIRAL’s FFTX overview](https://www.spiral.net/software/fftx.html) describes a build-time code generator and BSD-style licensing. [Bowman and Ghoggali](https://www.math.ualberta.ca/~bowman/publications/partialfft.pdf) describes a one-dimensional partial transform with a space-dependent cutoff; applying it to this radial 2-D Hermitian mask is a new algorithmic integration, not a drop-in provider.

## Verification and next step

Correctness/lifecycle command (already run; 64 successful records):

```sh
/private/tmp/issue155-overnight-cache/bin/issue155-radial-retention > /private/tmp/issue155-overnight-cache/results/radial-retention.jsonl
```

No FFTW/SPIRAL/FFTX build, no MATLAB, no medium/large benchmark, no RSS/timing artifact, and no tracked dependency/cache was created. Reconsider only if a maintained generator provides reproducible double-precision, masked 2-D real/Hermitian arm64 NEON code with a standalone OpenMP contract and a model that exceeds 15% after packing/memory traffic.
