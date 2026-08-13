# Portable runtime readiness

- Status: `complete`
- Runtime decision: `RUNTIME-PREVIEW-NOT-READY`
- Memory decision: `RUNTIME-MEMORY-OPTIMIZED`
- Speed gate: integration-only eight-step RK4 timing; construction and checkpoint I/O are descriptive.

| Case | MATLAB preview integration (s) | Standalone integration (s) | Speedup | Error | Peak RSS ratio |
|---|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 1.8960 | 1.8534 | 1.023x | 4.962e-17 | 0.006 |
| constant-nonhydrostatic-256x256x65 | 2.2172 | 2.4014 | 0.923x | 4.576e-17 | 0.005 |
| constant-hydrostatic-512x512x129 | 14.5315 | 14.1949 | 1.024x | 8.187e-17 | 0.004 |
| constant-nonhydrostatic-512x512x129 | 17.3236 | 18.5749 | 0.933x | 6.996e-17 | 0.001 |
