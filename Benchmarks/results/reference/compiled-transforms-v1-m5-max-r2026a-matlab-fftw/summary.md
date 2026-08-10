# Compiled constant-stratification transform benchmark

- Status: `complete`
- Source: `a73fc71cee26adef808e4a417bad7248e037aad4`
- MATLAB: `2026a` on `maca64`
- FFTW: `/Applications/MATLAB_R2026a.app/bin/maca64/libmwfftw3.3.dylib`

| Case | Forward speedup | Inverse speedup | F-all speedup | G-all speedup | Max error | Scratch MiB |
|---|---:|---:|---:|---:|---:|---:|
| 256x256x65-hydrostatic | 1.211x | 1.037x | 1.035x | 0.972x | 6.17e-15 | 131.02 |
| 256x256x65-nonhydrostatic | 1.330x | 1.033x | 0.972x | 0.972x | 6.74e-15 | 131.02 |
| 512x512x129-hydrostatic | 1.485x | 1.255x | 1.061x | 1.052x | 1.17e-14 | 1036.03 |
| 512x512x129-nonhydrostatic | 1.638x | 1.263x | 1.178x | 1.183x | 1.29e-14 | 1036.03 |
