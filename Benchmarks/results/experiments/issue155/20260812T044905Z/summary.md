# WaveVortexModel issue #155 — pruned/generated FFT feasibility

Recommendation: **FEASIBILITY_REJECT**. Do not build a production-facing pruned/generated engine or begin a benchmark run.

## Reused controls

- Baseline ancestor: `be0f78995c49a2bfe4c43d75827856e3812ac278`.
- Assigned #128 scaffold: `782e9b41b76628eb0f61b1bd87339dd69b884314`.
- Reused #128 standalone artifact: `Benchmarks/results/experiments/issue128/20260812T030810Z/summary.md` and `results.json`.
- Reused FFTW++ source identity: `1a185f41800cd0e9d4df4ddf93e16e362d4e2c45`. Its local `LICENSE.LESSER` is LGPL-3.0-or-later. No dependency source, library, executable, generated code, or cache is tracked here.

## Exact radial retention

The committed descriptor-only check constructs each production descriptor without MATLAB or an FFT provider, confirms each retained WV mode maps to a distinct Hermitian half-spectrum row, and repeats construction/destruction 16 times per shape and physical configuration.

| Production shape | `Nj` | Dense half rows | Retained rows | Known-zero/discarded rows | Known-zero fraction | Retained coefficients | Discarded c2r inputs/r2c outputs |
|---|---:|---:|---:|---:|---:|---:|---:|
| 128 x 128 x 33 | 21 | 8,320 | 2,861 | 5,459 | 65.613% | 60,081 | 114,639 |
| 256 x 256 x 65 | 42 | 33,024 | 11,439 | 21,585 | 65.362% | 480,438 | 906,570 |

The retained disk still spans 43 of 65 medium and 86 of 129 large nonnegative-`k` columns, so it is not a sparse collection of isolated bins.

## Feasibility gate

A bounded manual Cooley--Tukey implementation can omit only all-zero `k` columns. Its optimistic transform-only saving is 17.054% at `N = 128` and 16.732% at `N = 256`; it cannot omit the dense real pass, physical-space nonlinear products, or required mapping, zero-fill, normalization, and vertical work. Applying that ceiling generously to the matched #128 control's whole-call stage budget yields only 14.53%, 14.71%, 14.56%, and 14.75% for medium hydrostatic, medium nonhydrostatic, large hydrostatic, and large nonhydrostatic cases. The required 15% complete-horizontal-block gate therefore fails before a prototype can qualify.

The radial variation remaining inside live columns requires a new two-dimensional partial transform, with irregular packing, gather/scatter, Hermitian normalization, specializations by production size and direction, and standalone OpenMP orchestration. No available operation or memory-traffic model compensates for that 1.7-point transform-only margin.

## Candidate review

| Candidate | Decision |
|---|---|
| SPIRAL / FFTX | Reject. FFTX documents fixed-size 1-D and 3-D libraries; batched 1-D real transforms are documented as in development, not a masked radial 2-D c2r/r2c primitive. No verified local arm64/NEON generated artifact or standalone-OpenMP path is available. BSD-style licensing is acceptable, but reproducible generation requires SPIRAL plus `fftx`, `simt`, `mpi`, and `jit`; generation also creates source/library caches. |
| Partial FFT formulation | Reject. The cited method is a 1-D space-varying-cutoff formulation, not an available real/Hermitian 2-D radial batched implementation. No arm64/NEON/OpenMP implementation, source identity, or license qualification is available in the #128 environment. |
| Bounded hand-pruned Cooley--Tukey | Reject. Exact for rectangular all-zero columns only, but lacks 15% complete-block headroom after mandatory traffic and mapping. It would also require new direction-specific plan, scratch, mapping, normalization, correctness, and lifecycle machinery. |

Sources: [FFTX README](https://raw.githubusercontent.com/spiral-software/fftx/main/README.md), [SPIRAL FFTX overview](https://www.spiral.net/software/fftx.html), and [Bowman and Ghoggali](https://www.math.ualberta.ca/~bowman/publications/partialfft.pdf).

## Verification and disposition

`tools/compiled-kernel/tests/Issue155RadialRetention.cpp` compiled with Apple clang 21 and completed 64 successful descriptor construction/destruction records. It invokes neither MATLAB nor an FFT provider. No prototype, reportable timing, RSS measurement, generated engine, production integration, benchmark artifact, PR, or issue closure was performed.
