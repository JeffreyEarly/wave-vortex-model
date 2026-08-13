# Portable composite-state coefficient-path regression

Decision: **COEFFICIENT-PATH-QUALIFIED**

Baseline: `0becaa37f768106d3f9b2b469f346a41c3dd6505`. Candidate: `7102c234641e8a96de51203e2917c28827177b8c`.

| Case | Baseline (s/step) | Candidate (s/step) | Candidate / baseline | Workspace unchanged | Error |
|---|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 0.228670 | 0.231370 | 1.0118 | yes | 4.962e-17 |
| constant-nonhydrostatic-256x256x65 | 0.298831 | 0.295555 | 0.9890 | yes | 4.576e-17 |
| constant-hydrostatic-512x512x129 | 1.740900 | 1.777286 | 1.0209 | yes | 4.101e-17 |
| constant-nonhydrostatic-512x512x129 | 2.226871 | 2.210678 | 0.9927 | yes | 3.499e-17 |

All four cases remain within the 3% coefficient-only regression limit. The established coefficient-only integrator source files were unchanged; this paired run confirms the linked runtime behavior on Apple M5 Max/R2026a.
