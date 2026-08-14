# Portable observing-system readiness

Decision: **PARTIAL**

MATLAB: `2026a` on `maca64`.
Candidate: `a8a0f091481555c94db97e203f68b0dfe5479469`; baseline: `0becaa37f768106d3f9b2b469f346a41c3dd6505`.

| Observer | Runtime to MATLAB | MATLAB to runtime |
|---|---:|---:|
| WVCoefficients | yes | yes |
| WVEulerianFields | yes | yes |
| WVMooring | yes | yes |
| WVLagrangianParticles | yes | yes |
| WVTracer | yes | yes |

| Case | Candidate / pre-milestone no-output time | Passed |
|---|---:|---:|
| constant-hydrostatic-256x256x65 | 1.0238 | yes |
| constant-nonhydrostatic-256x256x65 | 1.0403 | no |
| constant-hydrostatic-512x512x129 | 0.9494 | yes |
| constant-nonhydrostatic-512x512x129 | 0.9949 | yes |

| Compatibility case | Integrator | Payload (ms) | Sync (ms) | Written (KiB) | Retained (KiB) | Peak RSS (MiB) | Provider | Fallback |
|---|---|---:|---:|---:|---:|---:|---|---:|
| runtime-fixed-hydrostatic | fixed-rk4 | 0.720 | 0.212 | 35.7 | 86.9 | 23.5 | reference-dft | no |
| runtime-adaptive-nonhydrostatic | adaptive-rk23 | 0.657 | 0.186 | 38.5 | 94.4 | 23.6 | reference-dft | no |
| matlab-fixed-nonhydrostatic | fixed-rk4 | 0.671 | 0.198 | 30.6 | 76.5 | 23.4 | reference-dft | no |
| matlab-adaptive-hydrostatic | adaptive-rk23 | 0.634 | 0.187 | 42.4 | 102.0 | 23.5 | reference-dft | no |
