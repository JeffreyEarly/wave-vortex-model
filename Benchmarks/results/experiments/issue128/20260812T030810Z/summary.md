# WaveVortexModel issue #128 — combined Lyra result

Recommendation: **CORE-REJECT**, now based on both required execution tracks.

The earlier Lyra update was incomplete: it correctly characterized the MATLAB-hosted R2025b track, but incorrectly treated MATLAB's dual-libomp crash as a limitation of the overall OpenMP experiment. A standalone executable linked only to the pinned FFTW and isolated LLVM 22.1.8 libomp works cleanly through 16 threads. This artifact adds that missing track and supersedes the earlier overall interpretation.

## Tracks explored

1. **MATLAB-hosted MEX:** R2025b Update 4, pthread explicit, isolated-OpenMP explicit, FFTW++ implicit, and FFTW++ hybrid. One-thread results are valid; multi-thread execution cannot safely load a second libomp beside MATLAB's bundled runtime.
2. **Standalone C++:** no MATLAB process or MATLAB library. A pthread executable links only `libfftw3_threads` and `libfftw3`; a separate OpenMP executable links `libfftw3_omp`, `libfftw3`, and `@loader_path/libwvissue137omp.dylib`. The OpenMP executable provides explicit, implicit, and hybrid modes.

`otool -L` confirms that neither standalone executable links a MATLAB library. Runtime `dladdr` confirms the exact pinned FFTW and OpenMP providers.

## Standalone correctness and threading

The standalone pthread control writes deterministic flux references. OpenMP explicit and both FFTW++ candidates read those references at the same state. All medium and large errors are below the required `1e-12`; the maximum observed large error is `1.23e-13`. All plans are destroyed, outstanding planning bytes return to zero, and no lifecycle failure occurs.

The 16-thread FFTW++ probe reports:

- outer OpenMP threads: up to 16;
- FFTW threads: up to 16;
- multiplier threads: up to 16;
- maximum active OpenMP level: 1;
- disjoint worker regions: true;
- oversubscription: false.

Thus our isolated OpenMP runtime is valid outside MATLAB, and FFTW and OpenMP worker regions do not overlap.

## Medium screening

Fresh standalone processes used two warmups, three samples, deterministic state advancement, rotated OpenMP variant order, and thread counts 1, 4, 8, and 16. These are each configuration's fastest median complete `nonlinearFlux` result:

| Case | pthread explicit | OpenMP explicit | FFTW++ implicit | FFTW++ hybrid |
|---|---:|---:|---:|---:|
| Hydro 128×128×33 | 0.006893 s (16t) | 0.006805 s (16t) | 0.051669 s (8t) | 0.025771 s (8t) |
| Nonhydro 128×128×33 | 0.008520 s (16t) | 0.008457 s (16t) | 0.065343 s (16t) | 0.032713 s (8t) |

At the hybrid candidate's best common thread count (8), it is 3.35× slower hydrostatic and 3.77× slower nonhydrostatic than the matched pthread explicit control. Exact maximum-live bytes change by −5.43% hydrostatic and +0.16% nonhydrostatic. Peak RSS increases by 15.1% and 18.8%, respectively.

## Large screening

The 256×256×65 screen used 16 threads, two warmups, and one large screening sample:

| Case | pthread explicit | OpenMP explicit | FFTW++ implicit | FFTW++ hybrid |
|---|---:|---:|---:|---:|
| Hydro | 0.066591 s | 0.070423 s | 0.350204 s | 0.337703 s |
| Nonhydro | 0.088990 s | 0.087531 s | 0.443607 s | 0.423302 s |

Hybrid is 5.07× slower hydrostatic and 4.76× slower nonhydrostatic than pthread explicit. Exact maximum-live bytes fall by only 6.54% and 1.15%, while peak RSS rises by 2.04% and 6.38%.

## Decision

The standalone track removes the MATLAB runtime confound but does not produce an advancing candidate. Neither FFTW++ schedule reaches a 10% complete-core speed improvement or a 10% exact maximum-live reduction for both hydrostatic and nonhydrostatic cases. Hybrid also raises peak RSS at both screened sizes.

No candidate remains plausible after the funnel, so the three-fresh-process finalist protocol (two warmups, seven medium samples, three large samples) is not run. There is no advancing candidate for Donut canonical confirmation.

Interim recommendation remains **CORE-REJECT**, now for algorithmic performance/storage reasons rather than the MATLAB OpenMP conflict. Issue #128 remains open, no production PR is created, and the experimental branch must not be merged wholesale.

## Reproduction

- `Benchmarks/buildIssue128Standalone.sh` builds both standalone executables from pinned external sources and libraries.
- `Benchmarks/runIssue128StandaloneScreening.sh` runs deterministic fresh-process controls/candidates and supports size, sample, and thread overrides through `ISSUE128_*` variables.
- `tools/compiled-kernel/WVIssue128StandaloneBenchmark.cpp` owns standalone configuration, state generation, reference exchange, timing, RSS, stage metrics, `dladdr` identity, cleanup, and JSON output.

The branch tracks no FFTW++, FFTW, LLVM, library, executable, reference output, wisdom, or build cache. FFTW++ remains LGPL-3.0-or-later with the obligations recorded in the prior artifact and combined JSON result.
