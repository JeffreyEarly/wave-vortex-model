# Native-FFTW coefficient assembly and projection

- Status: `complete`
- Baseline: #137 native FFTW 3.3.11 NEON/pthreads, 18 FFT threads
- Candidate source: `d571e075deac4ebfcb16893b807fb7a37147bf44`

## Component decisions

| Component | Decision | Reason |
|---|---|---|
| compact-coefficient-storage | **CORE-REJECT** | The compact representation missed its storage, correctness, or regression gate. |
| prescaled-arithmetic | **CORE-ADOPT** | The local change improved its coefficient stage by at least 5% and complete nonlinearFlux by at least 1% for both physical configurations at 512x512x129. |
| specialized-straight-line | **CORE-ADOPT** | The local change improved its coefficient stage by at least 5% and complete nonlinearFlux by at least 1% for both physical configurations at 256x256x65. |
| compiler-vectorized | **CORE-ADOPT** | The local change improved its coefficient stage by at least 5% and complete nonlinearFlux by at least 1% for both physical configurations at 256x256x65. |
| bounded-workers-2 | **CORE-ADOPT** | Transient bounded execution improved complete nonlinearFlux by at least 5% for both physical configurations at 256x256x65. |
| bounded-workers-4 | **CORE-ADOPT** | Transient bounded execution improved complete nonlinearFlux by at least 5% for both physical configurations at 256x256x65. Rejected in favor of the simpler within-3% worker count. |
| bounded-workers-8 | **CORE-ADOPT** | Transient bounded execution improved complete nonlinearFlux by at least 5% for both physical configurations at 256x256x65. Rejected in favor of the simpler within-3% worker count. |

## Component timing

| Variant | Case | Complete (ms) | Internal (ms) | Descriptor (MiB) | Peak RSS (MiB) | Error |
|---|---|---:|---:|---:|---:|---:|
| native-baseline | constant-hydrostatic-256x256x65 | 87.578 | 87.328 | 122.062 | 1014.688 | 9.36e-15 |
| native-baseline | constant-hydrostatic-512x512x129 | 635.672 | 634.763 | 983.792 | 8192.062 | 2.54e-14 |
| native-baseline | constant-nonhydrostatic-256x256x65 | 108.716 | 108.472 | 122.062 | 2211.344 | 7.88e-15 |
| native-baseline | constant-nonhydrostatic-512x512x129 | 790.839 | 789.892 | 983.792 | 13782.156 | 1.61e-14 |
| compact-storage | constant-hydrostatic-256x256x65 | 98.341 | 97.993 | 107.779 | 983.984 | 9.33e-15 |
| compact-storage | constant-hydrostatic-512x512x129 | 705.414 | 704.359 | 866.585 | 8004.469 | 2.55e-14 |
| compact-storage | constant-nonhydrostatic-256x256x65 | 119.482 | 119.135 | 107.779 | 2175.812 | 7.82e-15 |
| compact-storage | constant-nonhydrostatic-512x512x129 | 879.222 | 878.232 | 866.585 | 14195.938 | 1.61e-14 |
| prescaled-arithmetic | constant-hydrostatic-256x256x65 | 86.288 | 86.041 | 107.779 | 1000.781 | 9.35e-15 |
| prescaled-arithmetic | constant-hydrostatic-512x512x129 | 614.483 | 613.427 | 866.585 | 7873.625 | 2.55e-14 |
| prescaled-arithmetic | constant-nonhydrostatic-256x256x65 | 103.975 | 103.765 | 107.779 | 2197.922 | 7.84e-15 |
| prescaled-arithmetic | constant-nonhydrostatic-512x512x129 | 752.310 | 751.392 | 866.585 | 13574.547 | 1.62e-14 |
| specialized-straight-line | constant-hydrostatic-256x256x65 | 85.777 | 85.519 | 107.779 | 950.672 | 9.31e-15 |
| specialized-straight-line | constant-hydrostatic-512x512x129 | 603.878 | 602.944 | 866.585 | 7878.047 | 2.55e-14 |
| specialized-straight-line | constant-nonhydrostatic-256x256x65 | 102.093 | 101.881 | 107.779 | 2176.875 | 7.79e-15 |
| specialized-straight-line | constant-nonhydrostatic-512x512x129 | 725.070 | 724.024 | 866.585 | 13879.141 | 1.61e-14 |
| compiler-vectorized | constant-hydrostatic-256x256x65 | 86.749 | 86.480 | 107.779 | 949.594 | 9.4e-15 |
| compiler-vectorized | constant-hydrostatic-512x512x129 | 629.833 | 628.877 | 866.585 | 7937.328 | 2.55e-14 |
| compiler-vectorized | constant-nonhydrostatic-256x256x65 | 105.380 | 105.175 | 107.779 | 2130.250 | 7.83e-15 |
| compiler-vectorized | constant-nonhydrostatic-512x512x129 | 795.387 | 794.359 | 866.585 | 13931.188 | 1.61e-14 |
| bounded-workers-2 | constant-hydrostatic-256x256x65 | 77.562 | 77.297 | 107.779 | 949.078 | 9.36e-15 |
| bounded-workers-2 | constant-hydrostatic-512x512x129 | 575.075 | 574.079 | 866.585 | 7876.547 | 2.55e-14 |
| bounded-workers-2 | constant-nonhydrostatic-256x256x65 | 95.865 | 95.656 | 107.779 | 2177.594 | 7.86e-15 |
| bounded-workers-2 | constant-nonhydrostatic-512x512x129 | 705.609 | 704.630 | 866.585 | 13141.812 | 1.61e-14 |
| bounded-workers-4 | constant-hydrostatic-256x256x65 | 76.845 | 76.601 | 107.779 | 919.234 | 9.36e-15 |
| bounded-workers-4 | constant-hydrostatic-512x512x129 | 556.768 | 555.833 | 866.585 | 7865.594 | 2.55e-14 |
| bounded-workers-4 | constant-nonhydrostatic-256x256x65 | 95.403 | 95.187 | 107.779 | 2130.500 | 7.86e-15 |
| bounded-workers-4 | constant-nonhydrostatic-512x512x129 | 676.555 | 675.595 | 866.585 | 13606.344 | 1.61e-14 |
| bounded-workers-8 | constant-hydrostatic-256x256x65 | 78.922 | 78.628 | 107.779 | 946.734 | 9.36e-15 |
| bounded-workers-8 | constant-hydrostatic-512x512x129 | 543.262 | 542.290 | 866.585 | 7874.609 | 2.55e-14 |
| bounded-workers-8 | constant-nonhydrostatic-256x256x65 | 95.987 | 95.764 | 107.779 | 2133.000 | 7.85e-15 |
| bounded-workers-8 | constant-nonhydrostatic-512x512x129 | 654.702 | 653.733 | 866.585 | 12908.703 | 1.61e-14 |
| cumulative | constant-hydrostatic-256x256x65 | 79.026 | 78.745 | 107.779 | 947.969 | 9.41e-15 |
| cumulative | constant-hydrostatic-512x512x129 | 557.626 | 556.684 | 866.585 | 7937.641 | 2.55e-14 |
| cumulative | constant-nonhydrostatic-256x256x65 | 96.592 | 96.349 | 107.779 | 2163.797 | 7.86e-15 |
| cumulative | constant-nonhydrostatic-512x512x129 | 697.908 | 696.938 | 866.585 | 13125.328 | 1.62e-14 |

## Other findings

- Accelerate pointwise path: **CORE-REJECT** — No Accelerate primitive matches the fused interleaved complex coefficient assembly/projection without split-complex conversion, extra full-array passes, or an array-sized temporary. BLAS zaxpy supplies only scalar-vector multiplication; vDSP complex vector products require split-complex views. The no-pack eligibility condition is therefore false.
- Persistent executor: `not-required` — Transient worker lifecycle is not material, or bounded workers were not selected.
- Compiler vectorized-loop remarks: 43; missed-loop remarks: 221
