# Issue #129 dense 2-D FFT-engine screen

Decision: **CORE-REJECT**

| Size | Channels | Engine | Forward (ms) | Inverse (ms) | Combined speedup | Workspace (MiB) | Max error |
|---|---:|---|---:|---:|---:|---:|---:|
| 256 x 256 x 65 | 3 | native-fftw | 2.033 | 2.212 | 1.000x | 0.000 | 4.25e-16 |
| 256 x 256 x 65 | 3 | pffft | 2.427 | 2.606 | 0.843x | 9.387 | 5.13e-16 |
| 256 x 256 x 65 | 3 | accelerate-vdsp | 16.941 | 17.349 | 0.124x | 9.000 | 7.22e-16 |
| 256 x 256 x 65 | 4 | native-fftw | 2.527 | 2.966 | 1.000x | 0.000 | 4.04e-16 |
| 256 x 256 x 65 | 4 | pffft | 2.952 | 3.449 | 0.858x | 9.387 | 5.92e-16 |
| 256 x 256 x 65 | 4 | accelerate-vdsp | 22.409 | 23.176 | 0.120x | 9.000 | 7.22e-16 |
| 512 x 512 x 129 | 3 | native-fftw | 18.210 | 18.728 | 1.000x | 0.000 | 4.44e-16 |
| 512 x 512 x 129 | 3 | pffft | 20.106 | 22.989 | 0.859x | 36.773 | 6.6e-16 |
| 512 x 512 x 129 | 3 | accelerate-vdsp | 155.709 | 157.581 | 0.118x | 36.000 | 7.4e-16 |
| 512 x 512 x 129 | 4 | native-fftw | 21.633 | 26.099 | 1.000x | 0.000 | 4.55e-16 |
| 512 x 512 x 129 | 4 | pffft | 25.570 | 28.817 | 0.875x | 36.773 | 5.56e-16 |
| 512 x 512 x 129 | 4 | accelerate-vdsp | 205.719 | 202.551 | 0.116x | 36.000 | 6.83e-16 |

## Assessment

| Engine | Advanced | Best common size | Minimum common speedup | Max error | Reason |
|---|:---:|---|---:|---:|---|
| pffft | no | 512 x 512 x 129 | 0.859x | 6.6e-16 | Complete transform pipeline did not clear the 1.10x screen for both channel counts at a common size. |
| accelerate-vdsp | no | 256 x 256 x 65 | 0.120x | 7.4e-16 | Complete transform pipeline did not clear the 1.10x screen for both channel counts at a common size. |

Neither PFFFT nor Accelerate/vDSP was at least 10% faster than selected native FFTW in the complete batched horizontal transform pipeline; no nonlinearFlux integration was warranted.

The native control is FFTW 3.3.11 NEON/pthreads with 18 workers. PFFFT is the pinned maintained double-precision fork; vDSP uses the double split-complex radix-2 2-D pipeline. All conversion and worker costs are included.
