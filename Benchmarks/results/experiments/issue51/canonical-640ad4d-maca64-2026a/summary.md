# Compiled nonlinear-flux schedule benchmark

- Status: `complete`
- Source: `640ad4da8e0381dfe0991e8e7bbd3f66d5639cf4`
- Selected schedule: `sequential`
- Reason: Paired batching did not satisfy the fixed speed, memory, correctness, and regression rule.

| Case | MATLAB (ms) | Sequential (ms) | Paired (ms) | Paired speedup | Scratch increase | Max error |
|---|---:|---:|---:|---:|---:|---:|
| 256x256x65-hydrostatic | 64.817 | 96.931 | 92.851 | 1.044x | 25.1% | 8.69e-15 |
| 256x256x65-nonhydrostatic | 92.218 | 116.188 | 110.815 | 1.048x | 30.8% | 8.35e-15 |
| 512x512x129-hydrostatic | 553.854 | 734.086 | 709.324 | 1.035x | 25.0% | 2.3e-14 |
| 512x512x129-nonhydrostatic | 736.873 | 932.723 | 873.156 | 1.068x | 30.8% | 1.64e-14 |
