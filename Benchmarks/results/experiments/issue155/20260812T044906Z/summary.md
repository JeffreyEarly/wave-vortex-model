# WaveVortexModel issue #155 — pruned/generated FFT feasibility

Recommendation: **FEASIBILITY-REJECT**. Exact radial retention creates many known zeros, but none of the bounded candidates has a qualified path to the issue's 15% complete-horizontal-block gate on Lyra.

## Exact radial pattern

The descriptor-only test uses baseline `be0f78995c49a2bfe4c43d75827856e3812ac278` and scaffold `782e9b41b76628eb0f61b1bd87339dd69b884314`. It ran without MATLAB or an FFT provider and completed 64 construction/destruction cycles. Every retained WaveVortex mode mapped to a unique Hermitian half-spectrum row.

| Production shape | Dense half rows | Retained rows | Known zero/discarded | Live k columns | Transform-only ceiling |
|---|---:|---:|---:|---:|---:|
| 128×128×33, `Nj=21` | 8,320 | 2,861 | 65.613% | 43/65 | 17.054% |
| 256×256×65, `Nj=42` | 33,024 | 11,439 | 65.362% | 86/129 | 16.732% |

The radial disk still spans most nonnegative-k columns. A bounded hand-pruned Cooley–Tukey implementation can omit those all-zero columns but cannot omit the dense real pass or the dense nonlinear products. Before packing, mapping, normalization, instruction-cache cost, or extra memory traffic, the generous complete-call ceilings are only 14.53%–14.75%, below the required 15% spike gate.

## Candidate assessment

- SPIRAL/FFTX has no qualified masked batched 2-D real/Hermitian primitive, generated arm64 NEON artifact, or verified standalone OpenMP path in the pinned environment. Its 1-D real batching is documented as in development.
- The cited partial FFT is a one-dimensional space-varying-cutoff formulation, not an available 2-D radial real/Hermitian implementation. Source identity, licensing, and arm64 integration remain unverified.
- Bounded hand pruning lacks enough complete-block headroom after mandatory dense work and traffic.

The pinned FFTW++ source identity remains LGPL-3.0-or-later. FFTX project materials describe BSD-style licensing, but any future generated path must capture generator/dependency identities, generated-code provenance, reproducibility, code size, and cache behavior.

## Decision and skipped stages

The descriptor correctness and lifecycle spike passes, but the operation/traffic gate fails. No production-shape horizontal prototype, reportable timing, medium/large benchmark, RSS sampling, generated dependency, or Donut handoff was created. Reconsider only if a maintained generator supplies reproducible double-precision masked 2-D real/Hermitian arm64 NEON code with a standalone OpenMP contract and a model exceeding 15% after packing and memory traffic.

Exact counts, ceilings, lifecycle fields, licensing notes, and the reproduction command are in `results.json`.
