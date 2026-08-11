# Compiled-kernel readiness

- Status: `complete`
- Decision: **NOT READY**
- Reason: The compiled kernel did not reach 1.25x on every case: constant-nonhydrostatic-256x256x65, constant-hydrostatic-256x256x65, constant-nonhydrostatic-512x512x129, constant-hydrostatic-512x512x129.

| Case | MATLAB (ms) | Compiled (ms) | Speedup | Max error | Compiled persistent (MiB) | Compiled peak RSS (MiB) | Pass |
|---|---:|---:|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 108.676 | 117.056 | 0.928x | 7.88e-15 | 545.578 | 1761.312 | false |
| constant-hydrostatic-256x256x65 | 91.810 | 93.376 | 0.983x | 9.38e-15 | 513.078 | 1679.516 | false |
| constant-nonhydrostatic-512x512x129 | 848.429 | 905.273 | 0.937x | 1.6e-14 | 4341.823 | 12648.500 | false |
| constant-hydrostatic-512x512x129 | 700.380 | 725.948 | 0.965x | 2.53e-14 | 4083.823 | 11990.078 | false |
