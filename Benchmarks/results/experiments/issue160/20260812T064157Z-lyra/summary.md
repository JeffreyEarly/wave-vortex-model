# Issue #160 transient-layout feasibility on Lyra

- Status: `FEASIBILITY_REJECT`
- Core decision: `CORE-REJECT`
- MEX decision: `MEX-NOT-QUALIFIED`
- Exact base: `be0f78995c49a2bfe4c43d75827856e3812ac278`
- Harness commit: `637a2d48ede2a1c964d140eabe6d202051cea25c`
- Common size: `256x256x65`, `Nj=42`, `Nkl=11439`
- Result: no transient layout clears the strict `>=5%` model gate in both hydrostatic and nonhydrostatic cases, so no kernel prototype or medium native/MATLAB screen was run.

## Incremental baseline

This screen compares with the current Fourier-row implementation, not obsolete pre-row code. Current transient half-spectrum storage is complex `[z,channel,Fourier-row]`: vertical DCT/DST lines have unit complex stride, while the guru horizontal FFT writes Fourier rows with output strides `Nz*fields` and `Nz*fields*NxHalf`. The compact WV state remains canonical `[Nj,Nkl]`.

The prior bounded-FFT artifact at commit `48f6ee220362cf5e9d730ab5df12a09f3b45c27f` is negative evidence: all 16 z-batch/Fourier-row-batch combinations were correct (maximum errors `9.22e-15` hydrostatic and `8.23e-15` nonhydrostatic), none improved the complete pipeline by at least 3%, and `zall-rowsall` remained selected.

| Current stage | Hydrostatic | Nonhydrostatic | Source/model |
|---|---:|---:|---|
| Complete pipeline | 56.283 ms | 72.076 ms | prior all/all measurement |
| Horizontal FFT | 17.017 ms / 7 executions | 22.225 ms / 9 executions | prior all/all measurement |
| Vertical DCT/DST | 22.789 ms / 11 executions | 28.336 ms / 14 executions | prior all/all measurement |
| Scatter/gather + products + projection remainder | 16.478 ms | 21.515 ms | complete minus measured FFT stages; modeled unchanged |
| Transpose/pack | 0 | 0 | current baseline |

## Layout comparison

| Layout | Transform and boundary effect | Exact live-storage effect | Complexity | Decision |
|---|---|---:|---|---|
| Current vertical/Fourier-row | Vertical stride 1 complex; strided horizontal output | baseline | existing | retain |
| Horizontal/Fourier-row only | Horizontal planes contiguous; vertical z stride becomes 33,024 complex values (528,384 bytes); all scatter/gather, normalization, and Hermitian indexing changes | no inherent reduction | large | reject before prototype |
| Explicit pack | Current vertical layout plus a full horizontal buffer; every vertical/horizontal boundary copies | +137,379,840 bytes | moderate | reject before prototype |
| z blocks 1/4/8/16/full | Tiles the same explicit copy; bytes and FFT counts do not change | +137,379,840 bytes | moderate | all reject |
| Simplest hybrid | Horizontal-native buffer only around horizontal transforms; equivalent to explicit pack | +137,379,840 bytes | moderate | reject before prototype |

The horizontal-only layout has no consistent positive model prediction. Its absolute horizontal saving ceiling is 30.2% hydrostatic and 30.8% nonhydrostatic only if every horizontal FFT becomes free, but it makes all 11/14 vertical transforms and all coefficient access 528,384-byte-strided. It also requires the broader transform-boundary rewrite for which the funnel requires stronger evidence; none exists above 5%.

## Correctness and boundary-cost harness

`Benchmarks/issue160TransientLayoutFeasibility.cpp` performs exact `[z,channel,row] -> [row,z,channel] -> [z,channel,row]` round trips at the common size. It tests z blocks `1`, `4`, `8`, `16`, and full depth with one and two copy workers, one warmup and three samples. Every configuration was bit-exact (`0` relative error), preserving values at zero/Nyquist and the omitted half because the harness only permutes storage.

One four-channel pack reads and writes 137,379,840 bytes, moving 274,759,680 bytes. A complete nonlinear-flux call crosses vertical-to-horizontal storage for reconstruction and each three-channel derivative, then crosses back for projection. That is 16 channel-equivalents (1,099,038,720 moved bytes) hydrostatically and 20 channel-equivalents (1,373,798,400 moved bytes) nonhydrostatically.

| z block | Workers | Pack | Unpack | Hydro boundary | Nonhydro boundary | Optimistic hydro improvement | Optimistic nonhydro improvement |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 13.868 ms | 13.122 ms | 54.912 ms | 68.593 ms | -67.3% | -64.3% |
| 4 | 1 | 12.830 ms | 12.063 ms | 50.746 ms | 63.384 ms | -59.9% | -57.1% |
| 8 | 1 | 12.391 ms | 11.443 ms | 48.852 ms | 61.005 ms | -56.6% | -53.8% |
| 16 | 1 | 12.460 ms | 11.716 ms | 49.282 ms | 61.556 ms | -57.3% | -54.6% |
| full | 1 | 11.766 ms | 10.462 ms | 46.086 ms | 57.526 ms | -51.6% | -49.0% |
| 1 | 2 | 13.359 ms | 13.007 ms | 53.173 ms | 66.445 ms | -64.2% | -61.4% |
| 4 | 2 | 8.235 ms | 10.099 ms | 34.338 ms | 43.039 ms | -30.8% | -28.9% |
| 8 | 2 | 7.456 ms | 7.029 ms | 29.503 ms | 36.852 ms | -22.2% | -20.3% |
| 16 | 2 | 7.200 ms | 7.196 ms | 28.797 ms | 35.997 ms | -20.9% | -19.1% |
| full | 2 | 6.654 ms | 6.311 ms | 26.360 ms | 32.928 ms | **-16.6%** | **-14.8%** |

The optimistic improvement assigns the candidate horizontal FFT zero time, leaves DCT/DST, scatter/gather, nonlinear products, and projection unchanged, and charges only the measured pack boundaries. Even this physically impossible best case is slower in both modes. The actual candidate would still pay its FFT work.

Baseline scratch is exactly 410,009,600 bytes hydrostatic and 444,088,320 bytes nonhydrostatic at this base. With state/flux outputs, known maximum live ownership excluding descriptor and opaque FFTW plan memory is 433,070,624 and 467,149,344 bytes. Explicit pack/hybrid raises those figures to 570,450,464 and 604,529,184 bytes; it cannot satisfy the alternate exact-live-reduction gate.

## Decision

No layout predicts a common `>=5%` complete native improvement, and the only modest prototype adds 137.38 MB while remaining slower even under a zero-cost-FFT assumption. Therefore the strict funnel stops at `FEASIBILITY_REJECT`: no production implementation, build/dependency change, persistent state, public API, canonical-state change, full Hermitian ownership, medium screen, large run, or fresh-process RSS protocol was performed.

Reproduce the harness from the repository root with:

```sh
clang++ -std=c++17 -O3 -march=native -pthread -Wall -Wextra -Wpedantic Benchmarks/issue160TransientLayoutFeasibility.cpp -o /tmp/issue160-layout-feasibility
/tmp/issue160-layout-feasibility
```
