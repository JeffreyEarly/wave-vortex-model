# Portable integration traffic

Decision: **CORE-ADOPT**

The candidate removes redundant classical-RK4 clearing/copying and lets the first whole-flux forcing producer write the caller's RHS output directly. The nonlinear-advection-only schedule retains no forcing-engine array workspace. Accepted state and time remain failure-atomic by constraining the endpoint in existing stage storage before committing it.

| Case | Baseline (s) | Candidate (s) | Time ratio | Known storage ratio | Traffic ratio |
|---|---:|---:|---:|---:|---:|
| Hydrostatic 256x256x65 | 2.117932 | 1.986713 | 0.9380 | 0.6429 | 0.3968 |
| Nonhydrostatic 256x256x65 | 2.708708 | 2.704840 | 0.9986 | 0.6165 | 0.3968 |
| Hydrostatic 512x512x129 | 10.250461 | 9.131544 | 0.8908 | 0.6431 | 0.3968 |
| Nonhydrostatic 512x512x129 | 12.070172 | 12.193869 | 1.0102 | 0.6168 | 0.3968 |

Exact known maximum-live storage fell 35.7--38.3%, and exact integration-boundary traffic fell 60.3%. Complete integration improved 6.2% and 10.9% in the hydrostatic cases, was unchanged at medium nonhydrostatic size, and regressed 1.0% at large nonhydrostatic size. All timing medians therefore remain inside the 3% nonqualifying-metric guard.

The large nonhydrostatic case uses six process pairs. Its first three-pair median crossed the guard amid high process variance; three supplemental pairs reused the exact binaries, provider, and input. No provider selection or completed case was rerun. The six-pair result is reported without discarding any sample.

The candidate and control use native FFTW 3.3.11 NEON/pthreads with 18 threads and 17 plans. Loaded-library identity was validated, no fallback executed, and no persistent full Hermitian spectrum is retained. Focused C++ and MATLAB suites enforce relative infinity error at most `1e-12`; the supplemental large nonhydrostatic checkpoint comparison measured `6.18e-17`.

RSS lower bounds are retained in the JSON as supporting diagnostics, but they are allocator-sensitive and are not the adoption metric. The decision rests on exact application-owned storage plus the complete-integration timing guard.
