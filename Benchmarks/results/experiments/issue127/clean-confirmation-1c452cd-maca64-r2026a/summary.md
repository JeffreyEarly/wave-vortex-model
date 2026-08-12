# Clean issue #127 confirmation

- Candidate: `1c452cda3dbeb434c1d0cd4c4585b464dc18db03`
- Decision: `CORE-ADOPT`

| Case | Baseline (ms) | Candidate (ms) | Speedup | Error |
|---|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 99.725 | 80.937 | 1.232x | 7.9e-15 |
| constant-hydrostatic-256x256x65 | 81.927 | 66.074 | 1.240x | 9.41e-15 |
| constant-nonhydrostatic-512x512x129 | 689.937 | 557.053 | 1.239x | 1.61e-14 |
| constant-hydrostatic-512x512x129 | 572.495 | 454.324 | 1.260x | 2.55e-14 |
