# Dense half-spectrum write benchmark

- Status: `complete`
- Source: `b37497ddea3616af9d7c5cf357f1d68b940b92ee`
- Provider: `native-neon-pthreads`, 18 threads
- Screen winner: `fused-normalization`
- Decision: `CORE-ADOPT`

| Variant | Case | Inverse speedup | nonlinearFlux speedup | Dense-write reduction | Advanced |
|---|---|---:|---:|---:|---|
| row-classified | constant-nonhydrostatic-256x256x65 | 0.913x | 0.940x | 10.2% | no |
| row-classified | constant-hydrostatic-256x256x65 | 0.865x | 0.953x | 10.2% | no |
| segmented | constant-nonhydrostatic-256x256x65 | 0.934x | 0.954x | 10.2% | no |
| segmented | constant-hydrostatic-256x256x65 | 0.907x | 0.949x | 10.2% | no |
| fused-normalization | constant-nonhydrostatic-256x256x65 | 1.213x | 1.301x | 44.9% | yes |
| fused-normalization | constant-hydrostatic-256x256x65 | 1.098x | 1.307x | 44.9% | yes |
| row-classified-fused | constant-nonhydrostatic-256x256x65 | 1.200x | 1.172x | 55.1% | yes |
| row-classified-fused | constant-hydrostatic-256x256x65 | 1.129x | 1.189x | 55.1% | yes |
| segmented-fused | constant-nonhydrostatic-256x256x65 | 1.273x | 1.243x | 55.1% | yes |
| segmented-fused | constant-hydrostatic-256x256x65 | 1.179x | 1.216x | 55.1% | yes |

| Final case | Baseline (ms) | Candidate (ms) | Speedup | Dense-write reduction | Error |
|---|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 92.909 | 72.636 | 1.279x | 44.9% | 7.83e-15 |
| constant-hydrostatic-256x256x65 | 78.609 | 61.653 | 1.275x | 44.9% | 9.31e-15 |
| constant-nonhydrostatic-512x512x129 | 711.979 | 562.418 | 1.266x | 44.8% | 1.62e-14 |
| constant-hydrostatic-512x512x129 | 579.121 | 466.126 | 1.242x | 44.8% | 2.55e-14 |

## Disposition

Both physical configurations passed the 5% complete-call speed-or-memory gate at 256x256x65.
