# Issue #130 — Donut reduced dual-host validation

- Status: `complete`
- Source: `ad98592908b8073b63f0bca14b753f988a0236e5` (pinned parent `7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05`)
- Explicit control: `be0f78995c49a2bfe4c43d75827856e3812ac278`
- Provider: FFTW 3.3.11 NEON/pthreads build `99b0f0e9ae7e3864`, 18 threads
- MATLAB: `26.1.0.3312084 (R2026a) Update 4`
- Protocol: medium hydrostatic/nonhydrostatic only; one fresh process per path; two warmups and three samples; rotated order; no RSS/finalist protocol
- Derivation: completed timing samples were preserved; classification metadata was corrected to record two joined coefficient workers outside the 18-thread FFTW regions, with no timing rerun

| Case | Candidate | Native control (ms) | Native candidate (ms) | Native speedup | MEX baseline (ms) | Candidate MEX (ms) | MEX speedup | Production (ms) | Native/MEX error |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | streamed-target-three-channel | 60.325 | 55.136 | 1.094x | 52.941 | 52.416 | 1.010x | 90.676 | 7.47e-14 / 9.55e-15 |
| constant-hydrostatic-256x256x65 | streamed-target-single-output-4H+5R | 60.325 | 61.971 | 0.973x | 52.941 | 58.398 | 0.907x | 90.676 | 7.02e-14 / 9.57e-15 |
| constant-nonhydrostatic-256x256x65 | streamed-target-three-channel | 71.041 | 68.252 | 1.041x | 67.765 | 69.525 | 0.975x | 108.990 | 6.31e-14 / 8.46e-15 |
| constant-nonhydrostatic-256x256x65 | streamed-target-single-output-4H+5R | 71.041 | 76.524 | 0.928x | 67.765 | 71.751 | 0.944x | 108.990 | 8.79e-14 / 8.31e-15 |

## Classification

| Candidate | Overall | Native | MATLAB/MEX | Native geometric speedup | MEX geometric speedup |
|---|---|---|---|---:|---:|
| streamed-target-three-channel | `ADVANCE` | `ADVANCE` | `MEX_NOT_QUALIFIED` | 1.067x | 0.992x |
| streamed-target-single-output-4H+5R | `CORE_REJECT` | `CORE_REJECT` | `MEX_NOT_QUALIFIED` | 0.951x | 0.925x |

All reported native and MEX candidates require relative-infinity error <= 1e-12, balanced plan cleanup, zero fallback, zero persistent full-Hermitian storage, the pinned FFTW libraries by `dladdr`, exactly 18 requested/effective FFTW threads, two joined coefficient workers outside FFTW execution regions, and no nested or isolated LLVM OpenMP runtime. MATLAB's bundled `libomp` may already be resident but is not the FFTW backend. FFTW-owned plan memory is opaque; plan wrapper bytes are a lower bound, while descriptor/scratch/state/output array byte counts are exact.
