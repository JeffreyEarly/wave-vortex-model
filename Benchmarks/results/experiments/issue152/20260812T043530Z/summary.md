# Issue 152 corrected asymmetric FFTW++ MIMO — Lyra screening

## Decision

**CORE-REJECT.** The corrected named-channel 15→3 and 19→4 adapters are correct and materially faster than issue 128's `A=B` workaround, but the best corrected candidate remains far outside the shared adoption gate. FFTW++ hybrid is 2.76×/2.83× slower than the fastest pthread explicit control at medium size and 3.43×/3.58× slower at large size (hydrostatic/nonhydrostatic). Exact maximum-live bytes improve by only 6.57%/1.03% at medium and 7.12%/1.83% at large; single-process screening RSS increases in every decisive comparison.

No candidate was plausible after large screening. The three-fresh-process finalist protocol, seven-medium/three-large sampling, repeated-process RSS, and Donut confirmation were therefore skipped.

## Provenance and guard

- exact control baseline: `be0f78995c49a2bfe4c43d75827856e3812ac278`
- issue 128 scaffold: `782e9b41b76628eb0f61b1bd87339dd69b884314`
- implementation: `175e3d649ad7feda9322efd3033cad9217141063`
- pinned FFTW++: `1a185f41800cd0e9d4df4ddf93e16e362d4e2c45`, tree `77be88f8f58cd4a7d0b91f5323dcebd667e5b840`, LGPL-3.0-or-later
- runtime: FFTW 3.3.11 NEON pthread/OpenMP providers and isolated LLVM 22.1.8 `libwvissue137omp`
- load guard immediately before large screening: 91.56% CPU idle, 66 GiB unused, no MATLAB compute process, benchmark/compiler, RSS sampler, or competing issue workload
- standalone executables link no MATLAB libraries; `dladdr` resolves the exact issue-152 provider paths recorded in `results.json`

## Correctness and lifecycle

The direct-convolution reproducer passes all ten centered/Hermitian implicit and hybrid cases after the contained FFTW++ repair, with maximum relative error `9.995248e-16`. The fresh 16-thread small core probe passes both physical configurations and both candidates with maximum relative error `1.593954e-14`. The maximum error across all medium and large screening processes is `1.821084e-13`, below the `1e-12` gate.

Every process reports 14 FFT plans created and 14 destroyed, zero active plans and zero outstanding planning bytes after cleanup. FFT and multiplier worker counts never exceed 16, maximum OpenMP active level is 1, and worker regions are disjoint. No candidate retains a persistent full padded Hermitian spectrum.

## Complete-core timing

Fastest medium medians across 1/4/8/16 threads:

| Case | pthread explicit | OpenMP explicit | FFTW++ implicit | FFTW++ hybrid |
|---|---:|---:|---:|---:|
| Hydro 128×128×33 | 0.007032 s (8t) | 0.006846 s (16t) | 0.035355 s (16t) | 0.019438 s (8t) |
| Nonhydro 128×128×33 | 0.008518 s (16t) | 0.008563 s (16t) | 0.043945 s (8t) | 0.024137 s (16t) |

Large 16-thread screening:

| Case | pthread explicit | OpenMP explicit | FFTW++ implicit | FFTW++ hybrid |
|---|---:|---:|---:|---:|
| Hydro 256×256×65 | 0.066450 s | 0.071970 s | 0.245591 s | 0.227744 s |
| Nonhydro 256×256×65 | 0.081446 s | 0.091030 s | 0.307810 s | 0.291557 s |

Against issue 128's square-output workaround, corrected hybrid improves the best medium values by about 24.6%/26.2% and the large values by 32.6%/31.1%. Removing dummy output transforms is material, but not enough to challenge explicit padding.

## Storage and stage accounting

| Point | Exact max-live | pthread max-live | Change | Screening RSS change |
|---|---:|---:|---:|---:|
| Medium hydro hybrid | 64,826,845 B | 69,387,557 B | −6.57% | +16.11% |
| Medium nonhydro hybrid | 72,952,957 B | 73,712,933 B | −1.03% | +42.46% |
| Large hydro hybrid | 507,196,223 B | 546,083,271 B | −7.12% | +2.94% |
| Large nonhydro hybrid | 569,536,575 B | 580,161,991 B | −1.83% | +5.50% |

Hydrostatic execution uses 12 physical-input, 3 sacrificial-input, and 3 output transforms: 18 library transforms instead of the workaround's 30. Nonhydrostatic execution uses 15 + 4 + 4 = 23 instead of 38. Both dimensions use a `p=2`, `q=3` schedule; hybrid uses two logical padding slots per dimension, while implicit uses none. The centered application processes three residues with `D=1`; the Hermitian application uses the repaired two-loop `D=2` schedule.

For the fastest medium hybrid points, mapping/convolution wall times are 0.006464/0.011907 s hydrostatically and 0.007915/0.014651 s nonhydrostatically. Exact scratch capacities are 47,612,480 B and 55,738,592 B, with FFTW++ convolution work of 752,480 B and 1,068,416 B. Large hybrid mapping/convolution times are 0.059906/0.153743 s and 0.075469/0.195945 s; scratch capacities are 371,120,896 B and 433,461,248 B. The JSON records explicit reconstruction, derivative, product and projection stages, multiplier instrumentation, complete core, construction, cleanup, exact retained/work/max-live storage, and process RSS for every run.

Whole-kernel construction reaches 11.91 s at large size; cleanup remains below 0.000102 s. The provider exposes no opaque-plan allocation API, so `opaquePlanBytes=0` is explicitly recorded as a lower bound rather than proof of zero allocation.

## Funnel disposition

- **Skipped:** three fresh processes, two warmups, seven medium and three large samples. Reason: no candidate remained plausible after medium and large screening.
- **Skipped:** repeated-process peak RSS. Reason: exact max-live already misses the required 10% improvement in both configurations, and screening RSS increases.
- **Skipped:** Donut R2026a confirmation. Reason: only a gate-passing finalist advances.

The repaired FFTW++ adapter and upstream-quality defect reproducer remain useful research artifacts, but native FFTW explicit padding remains the selected production architecture.
