# Compiled constant-stratification transform benchmark

- Status: `complete`
- Source: `01168b4dbd4d5cf66612b55d5ce1398902e1ec0a`
- MATLAB: `2026a` on `maca64`
- FFTW: `/Applications/MATLAB_R2026a.app/bin/maca64/libmwfftw3.3.dylib`

| Case | Forward speedup | Inverse speedup | F-all speedup | G-all speedup | Max error | Scratch MiB |
|---|---:|---:|---:|---:|---:|---:|
| 256x256x65-hydrostatic | 1.143x | 1.018x | 0.962x | 0.925x | 6.17e-15 | 131.02 |
| 256x256x65-nonhydrostatic | 1.283x | 1.027x | 0.963x | 0.968x | 6.74e-15 | 131.02 |
| 512x512x129-hydrostatic | 1.451x | 1.240x | 1.036x | 1.000x | 1.17e-14 | 1036.03 |
| 512x512x129-nonhydrostatic | 1.594x | 1.195x | 1.110x | 1.132x | 1.29e-14 | 1036.03 |
