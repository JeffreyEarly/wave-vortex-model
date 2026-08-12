# Issue #158 Lyra in-place arena screening

- Status: `CORE_REJECT`
- Source: `1f3b6de907d8d6fe6e56ba25ece1518d86133170` from validated schedule `7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05`
- Selection evidence: `90d8ef1befa2f074474e787ef756f77918621e12` (recorded, not merged)
- Provider: FFTW `3.3.11` NEON/`pthreads`, `16` threads
- Protocol: one process, one warmup, three samples, rotated order, deterministic advancement

| Case | Complete control (ms) | Complete arena (ms) | Time regression | Exact max-live control | Exact max-live arena | Reduction | Max error |
|---|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 56.863 | 76.235 | +34.07% | 477.778 MiB | 355.617 MiB | 25.57% | 9.59e-15 |
| constant-nonhydrostatic-256x256x65 | 75.893 | 87.069 | +14.73% | 477.778 MiB | 355.617 MiB | 25.57% | 7.73e-15 |

## Liveness result

The exact FFTW-compatible lower bound is six padded physical/Hermitian arenas plus one compact `[Nj,Nkl]` phase spill. Spectra alias only their future physical fields; their meaningful lifetimes do not overlap. The complete lower bound includes the descriptor, plan wrappers, scratch, and caller-owned canonical state and flux arrays. FFTW-owned plan memory remains opaque.

## Complexity ledger

- Added execution paths: 0
- Added FFT plans/transforms/executions: 0/0/0
- Added persistent scientific objects/fallbacks/recomputation: 0/0/0
- Public scientific-interface changes: 0; diagnostic metric fields added: 7
- Persistent dense Hermitian spectra: 0
- Localized source footprint: 8 files, +734/-112 lines

## Decision

`CORE_REJECT`. Single-output and bounded-FFT schedules remained rejected controls and were not expanded.
