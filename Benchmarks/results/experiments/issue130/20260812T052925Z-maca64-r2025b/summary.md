# Issue #130 Lyra scratch-screening handoff

- Status: `complete`
- Source: `7fd33f74aaccfa6e2ac80ad2ede12f19e8740d05`
- Provider: FFTW `3.3.11` NEON/`pthreads`, `16` threads
- Protocol: one process, one warmup, three medium-case samples; no large cases or fresh-process RSS

| Case | Variant | Correct | Median complete call (ms) | Regression | Scratch | Phase reservation | Plans | Executions | Advance |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | control-be0f789 | true | 63.401 | -- | 391.016 MiB | 0.000 MiB | 14 | 15 | true |
| constant-hydrostatic-256x256x65 | velocity-only | true | 60.300 | -4.89% | 358.262 MiB | 0.000 MiB | 14 | 15 | true |
| constant-hydrostatic-256x256x65 | streamed-target-three-channel | true | 59.472 | -6.20% | 326.016 MiB | 32.754 MiB | 17 | 18 | true |
| constant-hydrostatic-256x256x65 | streamed-target-single-output | true | 62.913 | -0.77% | 293.516 MiB | 32.754 MiB | 18 | 27 | true |
| constant-nonhydrostatic-256x256x65 | control-be0f789 | true | 80.407 | -- | 423.516 MiB | 0.000 MiB | 14 | 18 | true |
| constant-nonhydrostatic-256x256x65 | velocity-only | true | 78.285 | -2.64% | 423.516 MiB | 0.000 MiB | 14 | 18 | true |
| constant-nonhydrostatic-256x256x65 | streamed-target-three-channel | true | 73.050 | -9.15% | 326.016 MiB | 32.754 MiB | 17 | 23 | true |
| constant-nonhydrostatic-256x256x65 | streamed-target-single-output | true | 74.307 | -7.59% | 293.516 MiB | 32.754 MiB | 18 | 35 | true |
