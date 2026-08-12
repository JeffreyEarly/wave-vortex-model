# Issue #130 bounded FFT screening handoff

- Status: `complete`
- Source: `83028bad57a8e50d35603a44bc122ea080f31a14`
- Schedule control: `streamed-target-three-channel` with all/all FFT batches
- Protocol: affected-FFT microbenchmark gate >=3%, then one process / one warmup / three complete-call samples for qualifiers
- Selection: `zall-rowsall` — No bounded configuration completed the gate and beat all/all by more than the 3% simplicity preference.

## constant-hydrostatic-256x256x65

| Setting | Correct | Horizontal FFT (ms) | Vertical FFT (ms) | Pipeline improvement | Qualified | Complete median (ms) | Complete improvement | Plans | Native executions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| zall-rowsall | true | 17.017 | 23.862 | 0.00% | true | 56.283 | 0.00% | 17 | 18 |
| zall-rows256 | true | 18.128 | 72.691 | -123.17% | false | NaN | NaN% | 17 | 1426 |
| zall-rows1024 | true | 17.380 | 33.835 | -25.51% | false | NaN | NaN% | 29 | 370 |
| zall-rows4096 | true | 17.392 | 25.491 | -5.12% | false | NaN | NaN% | 29 | 106 |
| z16-rowsall | true | 18.059 | 22.866 | 0.24% | false | NaN | NaN% | 22 | 46 |
| z16-rows256 | true | 18.540 | 72.963 | -124.64% | false | NaN | NaN% | 22 | 1454 |
| z16-rows1024 | true | 18.782 | 36.809 | -35.93% | false | NaN | NaN% | 34 | 398 |
| z16-rows4096 | true | 18.575 | 26.209 | -9.62% | false | NaN | NaN% | 34 | 134 |
| z32-rowsall | true | 19.730 | 25.670 | -11.26% | false | NaN | NaN% | 22 | 32 |
| z32-rows256 | true | 18.470 | 70.738 | -121.35% | false | NaN | NaN% | 22 | 1440 |
| z32-rows1024 | true | 18.404 | 34.905 | -30.64% | false | NaN | NaN% | 34 | 384 |
| z32-rows4096 | true | 18.768 | 27.173 | -11.89% | false | NaN | NaN% | 34 | 120 |
| z64-rowsall | true | 20.796 | 25.362 | -13.12% | false | NaN | NaN% | 22 | 25 |
| z64-rows256 | true | 20.835 | 73.193 | -129.86% | false | NaN | NaN% | 22 | 1433 |
| z64-rows1024 | true | 20.155 | 36.326 | -38.40% | false | NaN | NaN% | 34 | 377 |
| z64-rows4096 | true | 20.120 | 26.872 | -16.06% | false | NaN | NaN% | 34 | 113 |

## constant-nonhydrostatic-256x256x65

| Setting | Correct | Horizontal FFT (ms) | Vertical FFT (ms) | Pipeline improvement | Qualified | Complete median (ms) | Complete improvement | Plans | Native executions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| zall-rowsall | true | 22.016 | 28.834 | 0.00% | true | 72.076 | 0.00% | 17 | 23 |
| zall-rows256 | true | 22.418 | 88.901 | -119.33% | false | NaN | NaN% | 17 | 1815 |
| zall-rows1024 | true | 24.255 | 40.166 | -26.51% | false | NaN | NaN% | 29 | 471 |
| zall-rows4096 | true | 22.262 | 32.144 | -6.99% | false | NaN | NaN% | 29 | 135 |
| z16-rowsall | true | 23.253 | 29.113 | -3.05% | false | NaN | NaN% | 22 | 59 |
| z16-rows256 | true | 23.779 | 88.384 | -120.29% | false | NaN | NaN% | 22 | 1851 |
| z16-rows1024 | true | 23.824 | 41.243 | -27.96% | false | NaN | NaN% | 34 | 507 |
| z16-rows4096 | true | 23.453 | 31.715 | -8.13% | false | NaN | NaN% | 34 | 171 |
| z32-rowsall | true | 23.172 | 27.019 | 0.79% | false | NaN | NaN% | 22 | 41 |
| z32-rows256 | true | 22.914 | 89.129 | -120.34% | false | NaN | NaN% | 22 | 1833 |
| z32-rows1024 | true | 23.545 | 37.941 | -21.01% | false | NaN | NaN% | 34 | 489 |
| z32-rows4096 | true | 23.332 | 31.521 | -7.87% | false | NaN | NaN% | 34 | 153 |
| z64-rowsall | true | 24.235 | 27.764 | -2.26% | false | NaN | NaN% | 22 | 32 |
| z64-rows256 | true | 26.333 | 87.461 | -124.73% | false | NaN | NaN% | 22 | 1824 |
| z64-rows1024 | true | 25.688 | 39.378 | -27.96% | false | NaN | NaN% | 34 | 480 |
| z64-rows4096 | true | 25.494 | 31.843 | -11.91% | false | NaN | NaN% | 34 | 144 |
