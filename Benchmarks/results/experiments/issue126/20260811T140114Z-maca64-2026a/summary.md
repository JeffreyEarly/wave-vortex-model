# Compiled-kernel modal/vectorization benchmark

- Status: `complete`
- Decision: **QUALIFIED**
- Selected candidate: `threaded-8` (`prescaled`, `scalar`, 8 modal workers)
- Reason: The cumulative candidate passed the 10% speed/speed gate at 256x256x65, 512x512x129 without a correctness or greater-than-3% regression failure.
- Baseline commit: `52de16195c6817c6f107b6147c1f7e46922e8983`
- Candidate commit: `839eb6723455212af4c2ee5d039f69eee88dc774`

## Component screen

| Variant | Versus pinned baseline | Versus component control | Target-stage speedup | Descriptor reduction | All-process direction | Included |
|---|---:|---:|---:|---:|---:|---:|
| compact-modal | 1.041x | 1.041x | 1.000x | 11.7% | false | false |
| prescaled-modal | 1.031x | 0.990x | 1.189x | 0.0% | false | false |
| accelerate-phase | 1.087x | 1.055x | 1.365x | 0.0% | false | false |
| native-vectorized | 0.994x | 0.964x | 0.907x | 0.0% | false | false |
| native-vforce | 1.014x | 0.984x | 1.313x | 0.0% | false | false |
| threaded-2 | 1.121x | 1.088x | 1.682x | 0.0% | false | false |
| threaded-4 | 1.185x | 1.150x | 2.341x | 0.0% | true | true |
| threaded-8 | 1.201x | 1.166x | 3.049x | 0.0% | true | true |

## Qualification gate

| Case | Baseline (ms) | Candidate (ms) | Speedup | Live ratio | Peak RSS ratio | Error |
|---|---:|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 122.829 | 94.391 | 1.301x | 0.975 | 0.992 | 7.82e-15 |
| constant-hydrostatic-256x256x65 | 97.524 | 78.274 | 1.246x | 0.973 | 0.990 | 9.35e-15 |
| constant-nonhydrostatic-512x512x129 | 834.433 | 752.104 | 1.109x | 0.974 | 0.991 | 1.61e-14 |
| constant-hydrostatic-512x512x129 | 686.705 | 593.017 | 1.158x | 0.972 | 0.990 | 2.55e-14 |

## Candidate stage budget

| Case | Phase (ms) | Reconstruction (ms) | Derivatives (ms) | Products (ms) | Projection (ms) |
|---|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 1.948 | 15.787 | 52.777 | 11.238 | 14.866 |
| constant-hydrostatic-256x256x65 | 1.476 | 17.272 | 43.489 | 7.561 | 14.666 |
| constant-nonhydrostatic-512x512x129 | 12.510 | 123.469 | 423.172 | 81.393 | 118.892 |
| constant-hydrostatic-512x512x129 | 12.453 | 117.823 | 303.572 | 61.168 | 96.029 |

## Modal-table storage

| Case | Baseline tables (MiB) | Candidate tables (MiB) | Ratio | Reported descriptor (MiB) |
|---|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 120.961 | 106.565 | 0.881 | 107.779 |
| constant-hydrostatic-256x256x65 | 120.961 | 106.565 | 0.881 | 107.779 |
| constant-nonhydrostatic-512x512x129 | 979.394 | 861.734 | 0.880 | 866.585 |
| constant-hydrostatic-512x512x129 | 979.394 | 861.734 | 0.880 | 866.585 |

## Compiler evidence

- Status: `complete`
- Flags: `-O3 -mcpu=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize -Rpass-analysis=loop-vectorize`
- Vectorized remarks: 41
- Missed-vectorization remarks: 193
