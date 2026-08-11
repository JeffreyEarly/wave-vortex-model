# Clean issue #126 coefficient-assembly confirmation

- Status: `complete`
- Candidate: `ad7e61fe664fa6c4cb57e1a33021de2800f32317`
- Baseline: `2fd0412e1e911c55ec8ac56a9da661b27e69b516`
- Provider: `native-neon-pthreads`, 18 FFTW threads
- Decision: `CORE-ADOPT-CONFIRMED`

| Case | Baseline total (ms) | Candidate total (ms) | Speedup | Descriptor reduction | Max-live reduction | Error |
|---|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 87.060 | 79.625 | 1.093x | 11.70% | 2.67% | 9.441e-15 |
| constant-nonhydrostatic-256x256x65 | 109.056 | 99.902 | 1.092x | 11.70% | 2.52% | 7.863e-15 |
| constant-hydrostatic-512x512x129 | 659.975 | 570.206 | 1.157x | 11.91% | 2.75% | 2.550e-14 |
| constant-nonhydrostatic-512x512x129 | 804.463 | 703.146 | 1.144x | 11.91% | 2.59% | 1.612e-14 |

The clean reconstruction uses contract v4 natural-dimensional, pre-scaled coefficient data, specialized straight-line assembly/projection, native compiler optimization, and two transient coefficient workers. The experimental branch remains the component-ablation record; this artifact verifies the reconstructed cumulative implementation.
