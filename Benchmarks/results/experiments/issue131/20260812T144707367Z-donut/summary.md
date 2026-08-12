# Compiled-kernel assembly decision

- Status: `complete`
- Core: `CORE-COMPLETE`
- Integration: `INTEGRATION-NOT-READY`
- Provider: native FFTW 3.3.11 NEON/pthreads, 18 threads

## Final MATLAB comparison

| Case | MATLAB (ms) | C++ MEX (ms) | C++ internal (ms) | Speedup | Exact ratio | RSS ratio | Error |
|---|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 91.831 | 55.020 | 54.758 | 1.669x | 2.777 | 1.682 | 9.362e-15 |
| constant-nonhydrostatic-256x256x65 | 109.242 | 68.900 | 68.638 | 1.586x | 2.777 | 1.637 | 7.878e-15 |
| constant-hydrostatic-512x512x129 | 700.028 | 414.625 | 413.488 | 1.688x | 2.776 | 1.573 | 2.550e-14 |
| constant-nonhydrostatic-512x512x129 | 863.775 | 511.235 | 510.775 | 1.690x | 2.776 | 1.573 | 1.621e-14 |

## Historical compiled progression

| Implementation | Commit | Geometric-mean complete MEX (ms) |
|---|---|---:|
| matlab | `528e0708` | 279.077 |
| original-compiled | `52de1619` | 245.747 |
| native-foundation | `be0f7899` | 173.471 |
| preceding-adopted | `3af6b83e` | 167.942 |
| final-assembled | `528e0708` | 168.365 |

## Stage correspondence

| C++ stage | MATLAB operation |
|---|---|
| phase | evolve Ap and Am to time t |
| WV-to-field spectral assembly | transformWaveVortexToUVWEta coefficient assembly |
| fields and derivatives | F/G spatial reconstruction and derivatives |
| nonlinear products | ordinary nonlinear advection products |
| field-to-WV projection | transformUVEtaToWaveVortex or transformUVWEtaToWaveVortex |
