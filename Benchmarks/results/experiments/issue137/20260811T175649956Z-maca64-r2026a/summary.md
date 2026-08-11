# Native FFTW compiled-kernel baseline

- Status: `partial`
- Source: `2fd0412e1e911c55ec8ac56a9da661b27e69b516`
- Platform: `Apple M5 Max`, MATLAB `2026a`
- Planner: `FFTW_MEASURE | FFTW_UNALIGNED`

## Screening

| Provider | Threads | Geometric-mean internal nonlinearFlux (ms) | Status |
|---|---:|---:|---|
| native-plain-pthreads | 1 | 1227.406 | complete |
| native-plain-pthreads | 2 | 727.468 | complete |
| native-plain-pthreads | 4 | 451.121 | complete |
| native-plain-pthreads | 6 | 371.529 | complete |
| native-plain-pthreads | 8 | 346.410 | complete |
| native-plain-pthreads | 12 | 297.118 | complete |
| native-plain-pthreads | 18 | 270.942 | complete |
| native-neon-pthreads | 1 | 1003.532 | complete |
| native-neon-pthreads | 2 | 676.036 | complete |
| native-neon-pthreads | 4 | 413.125 | complete |
| native-neon-pthreads | 6 | 342.514 | complete |
| native-neon-pthreads | 8 | 310.534 | complete |
| native-neon-pthreads | 12 | 280.073 | complete |
| native-neon-pthreads | 18 | 249.677 | complete |
| native-simd128-pthreads | 1 | 1117.855 | complete |
| native-simd128-pthreads | 2 | 655.529 | complete |
| native-simd128-pthreads | 4 | 438.438 | complete |
| native-simd128-pthreads | 6 | 367.745 | complete |
| native-simd128-pthreads | 8 | 333.396 | complete |
| native-simd128-pthreads | 12 | 285.849 | complete |
| native-simd128-pthreads | 18 | 256.022 | complete |
| native-neon-openmp | 1 | 1045.709 | complete |
| native-neon-openmp | 2 | NaN | failed |
| native-neon-openmp | 4 | NaN | failed |
| native-neon-openmp | 6 | NaN | failed |
| native-neon-openmp | 8 | NaN | failed |
| native-neon-openmp | 12 | NaN | failed |
| native-neon-openmp | 18 | NaN | failed |

## Fully sampled configurations

| Provider | Threads | Internal nonlinearFlux geometric mean (ms) | Maximum error | Status |
|---|---:|---:|---:|---|
| matlab-bundled | 18 | 310.756 | 2.53e-14 | complete |
| native-neon-openmp | 1 | 1063.206 | 2.54e-14 | complete |
| native-neon-pthreads | 12 | 293.165 | 2.54e-14 | complete |
| native-neon-pthreads | 18 | 265.893 | 2.54e-14 | complete |
| native-plain-pthreads | 12 | 299.464 | 2.54e-14 | complete |
| native-plain-pthreads | 18 | 282.832 | 2.55e-14 | complete |
| native-simd128-pthreads | 12 | 303.630 | 2.54e-14 | complete |
| native-simd128-pthreads | 18 | 285.296 | 2.55e-14 | complete |

## Selected standalone baseline

- Provider: `native-neon-pthreads`
- Thread backend: `pthreads`
- Global thread count: `18`
- Reason: Selected the simplest valid global configuration within 3% of the per-workload speed ceilings and reference peak RSS.

| Workload | Native internal (ms) | Bundled internal (ms) | Native speedup |
|---|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 86.796 | 100.779 | 1.161x |
| constant-nonhydrostatic-256x256x65 | 108.752 | 127.028 | 1.168x |
| constant-hydrostatic-512x512x129 | 659.043 | 744.457 | 1.130x |
| constant-nonhydrostatic-512x512x129 | 803.483 | 978.514 | 1.218x |
