# Portable integration decision

- Status: `complete`
- Runtime preview: `RUNTIME-PREVIEW-READY`
- Orchestration: `ORCHESTRATION-NOT-EFFICIENT`
- Adaptive RK3(2): `ADAPTIVE-RK23-AVAILABLE`

| Case | MATLAB builtin (s) | MATLAB compiled (s) | Standalone (s) | Builtin speedup | Standalone / MATLAB compiled | Error |
|---|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 2.956212 | 1.797175 | 1.913525 | 1.545x | 1.065 | 5.587e-17 |
| constant-nonhydrostatic-256x256x65 | 3.721070 | 2.231324 | 2.396608 | 1.553x | 1.074 | 5.684e-17 |
| constant-hydrostatic-512x512x129 | 25.002103 | 13.748297 | 14.251392 | 1.754x | 1.037 | 1.688e-16 |
| constant-nonhydrostatic-512x512x129 | 31.555345 | 17.768991 | 18.676505 | 1.690x | 1.051 | 7.821e-17 |

## Adaptive work versus error

| Fixture | RelTol | Error | Accepted | Rejected | RHS | Time (s) |
|---|---:|---:|---:|---:|---:|---:|
| forcing-mixed-hydrostatic.nc | 0.01 | 1.285e-03 | 3 | 0 | 12 | 0.027957 |
| forcing-mixed-hydrostatic.nc | 0.01 | 1.285e-03 | 3 | 0 | 12 | 0.028067 |
| forcing-mixed-hydrostatic.nc | 0.01 | 1.285e-03 | 3 | 0 | 12 | 0.027943 |
| forcing-mixed-hydrostatic.nc | 0.003 | 2.417e-04 | 4 | 2 | 22 | 0.049706 |
| forcing-mixed-hydrostatic.nc | 0.003 | 2.417e-04 | 4 | 2 | 22 | 0.050033 |
| forcing-mixed-hydrostatic.nc | 0.003 | 2.417e-04 | 4 | 2 | 22 | 0.050303 |
| forcing-mixed-hydrostatic.nc | 0.001 | 8.691e-05 | 5 | 2 | 26 | 0.059046 |
| forcing-mixed-hydrostatic.nc | 0.001 | 8.691e-05 | 5 | 2 | 26 | 0.059070 |
| forcing-mixed-hydrostatic.nc | 0.001 | 8.691e-05 | 5 | 2 | 26 | 0.060092 |
| forcing-mixed-hydrostatic.nc | 0.0003 | 2.554e-05 | 8 | 3 | 41 | 0.095052 |
| forcing-mixed-hydrostatic.nc | 0.0003 | 2.554e-05 | 8 | 3 | 41 | 0.094287 |
| forcing-mixed-hydrostatic.nc | 0.0003 | 2.554e-05 | 8 | 3 | 41 | 0.093417 |
| forcing-mixed-nonhydrostatic.nc | 0.01 | 1.429e-03 | 2 | 0 | 8 | 0.023865 |
| forcing-mixed-nonhydrostatic.nc | 0.01 | 1.429e-03 | 2 | 0 | 8 | 0.023591 |
| forcing-mixed-nonhydrostatic.nc | 0.01 | 1.429e-03 | 2 | 0 | 8 | 0.024141 |
| forcing-mixed-nonhydrostatic.nc | 0.003 | 3.799e-04 | 4 | 2 | 22 | 0.066870 |
| forcing-mixed-nonhydrostatic.nc | 0.003 | 3.799e-04 | 4 | 2 | 22 | 0.065523 |
| forcing-mixed-nonhydrostatic.nc | 0.003 | 3.799e-04 | 4 | 2 | 22 | 0.067131 |
| forcing-mixed-nonhydrostatic.nc | 0.001 | 9.377e-05 | 5 | 2 | 26 | 0.084267 |
| forcing-mixed-nonhydrostatic.nc | 0.001 | 9.377e-05 | 5 | 2 | 26 | 0.076364 |
| forcing-mixed-nonhydrostatic.nc | 0.001 | 9.377e-05 | 5 | 2 | 26 | 0.078869 |
| forcing-mixed-nonhydrostatic.nc | 0.0003 | 3.547e-05 | 8 | 3 | 41 | 0.124720 |
| forcing-mixed-nonhydrostatic.nc | 0.0003 | 3.547e-05 | 8 | 3 | 41 | 0.121250 |
| forcing-mixed-nonhydrostatic.nc | 0.0003 | 3.547e-05 | 8 | 3 | 41 | 0.120386 |
