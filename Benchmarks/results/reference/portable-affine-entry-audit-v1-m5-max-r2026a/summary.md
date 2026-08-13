# Portable affine-state entry audit

Decision: **NOT-WARRANTED**

The existing three materialized RK stage-state construction passes consume only 0.59--0.81% of complete fixed-RK4 integration time. The largest individual fresh-process fraction was 0.87%, well below the 5% entry gate. Eliminating the 3M stage-state buffer could reduce known maximum-live storage by only 4.50--4.57%, also below the entry criterion.

| Case | Control (s/step) | Stage construction (ms/step) | Stage fraction | Theoretical storage saving | Maximum-live reduction | Error |
|---|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 0.226681 | 1.670 | 0.720% | 21.99 MiB | 4.500% | 4.962e-17 |
| constant-nonhydrostatic-256x256x65 | 0.290202 | 1.669 | 0.592% | 21.99 MiB | 4.500% | 4.576e-17 |
| constant-hydrostatic-512x512x129 | 1.701873 | 13.777 | 0.809% | 178.07 MiB | 4.571% | 4.101e-17 |
| constant-nonhydrostatic-512x512x129 | 2.223631 | 14.472 | 0.664% | 178.07 MiB | 4.571% | 6.996e-17 |

The timed and untimed builds used identical source and native FFTW configuration. Their aggregate complete-integration ratio was 0.9974, satisfying the 1% instrumentation-overhead check; individual process timing remained noisy in both directions. Because neither entry route passed, no affine-state prototype was implemented.
