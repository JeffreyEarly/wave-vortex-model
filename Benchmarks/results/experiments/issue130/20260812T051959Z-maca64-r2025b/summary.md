# Issue #130 Lyra scratch-screening handoff

- Status: `complete`
- Source: `db3fbe30600f653718294a35008511f01c7e5162`
- Provider: FFTW `3.3.11` NEON/`pthreads`, `16` threads
- Protocol: one process, one warmup, three medium-case samples; no large cases or fresh-process RSS

| Case | Variant | Correct | Median complete call (ms) | Regression | Scratch | Phase reservation | Plans | Executions | Advance |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | control-be0f789 | true | 66.474 | NaN% | 391.016 MiB | 0.000 MiB | 14 | 15 | true |
| constant-hydrostatic-256x256x65 | velocity-only | true | 61.513 | -7.46% | 391.016 MiB | 0.000 MiB | 14 | 15 | true |
| constant-hydrostatic-256x256x65 | streamed-target-three-channel | true | 60.352 | -9.21% | 326.016 MiB | 32.754 MiB | 17 | 18 | true |
| constant-nonhydrostatic-256x256x65 | control-be0f789 | true | 80.681 | NaN% | 423.516 MiB | 0.000 MiB | 14 | 18 | true |
| constant-nonhydrostatic-256x256x65 | velocity-only | true | 68.880 | -14.63% | 423.516 MiB | 0.000 MiB | 14 | 18 | true |
| constant-nonhydrostatic-256x256x65 | streamed-target-three-channel | true | 64.203 | -20.42% | 326.016 MiB | 32.754 MiB | 17 | 23 | true |
