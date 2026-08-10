# Compiled constant-stratification transform benchmark

- Status: `complete`
- Source: `e84e0216f6381cb181d72e04dfbc0d4d47cb12e7`
- MATLAB: `2026a` on `maca64`
- FFTW: `/Applications/MATLAB_R2026a.app/bin/maca64/libmwfftw3.3.dylib`

| Case | Forward speedup | Inverse speedup | F-all speedup | G-all speedup | Max error | Scratch MiB |
|---|---:|---:|---:|---:|---:|---:|
| 256x256x65-hydrostatic | 1.256x | 1.127x | 1.102x | 1.006x | 6.17e-15 | 131.02 |
| 256x256x65-nonhydrostatic | 1.397x | 1.104x | 1.066x | 1.058x | 6.74e-15 | 131.02 |
| 512x512x129-hydrostatic | 1.505x | 1.243x | 1.054x | 1.086x | 1.17e-14 | 1036.03 |
| 512x512x129-nonhydrostatic | 1.640x | 1.249x | 1.146x | 1.143x | 1.29e-14 | 1036.03 |
