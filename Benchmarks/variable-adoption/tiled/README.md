# Tiled horizontal reconstruction/advection screen

Hypothesis: prepare a short vertical tile, reconstruct its four fields, evaluate x/y/z derivatives, accumulate advection and immediately perform forward horizontal projection in one persistent-worker dispatch. Retain inverse-y columns for only one active plane per worker. Preserve the accepted FFTW plans, full-zero/in-place behavior, normalization and per-cell x/y/z subtraction order. Full physical fields are still written for downstream damping/diagnostics.

This is a benchmark-only experiment based on accepted main 60287e19, not the rejected #481 implementation. It includes the accepted native adapter directly so baseline and candidate execute the same actual FFTW handles and persistent pool. No production API or default changes.

The first experiment starts from precomputed vertical matrix outputs for four fields and their vertical derivatives. Vertical MM and spectral assembly are deliberately outside both timed paths. This supplies a necessary horizontal-stage screen, not a model speedup or memory claim. A model integration would still need to qualify tiled/grouped MM throughput, scheduling of derivative producers, caching, capture, forcing and diagnostics.

Screen Hydrostatic (u/v/eta tendencies) and Boussinesq (u/v/w/eta), at 256 × 256 × 28 and 256 × 256 × 129. Probe tile depths 1, 4 and 16 using 12 persistent horizontal workers and the accepted eight-worker derivative materialization baseline. Use separate fresh process blocks, alternating execution order, two warmups, and repeated samples. Require at least approximately 10% credible horizontal-pipeline benefit at representative size before proposing the larger integration. Stop or narrow at the 30–45 minute checkpoint. Do not launch broad MATLAB/CI qualification for an inconclusive screen.

Check complete field and projected-tendency agreement with the accepted schedule, direct Fourier/flux values at small analytical cases, nonuniform vertical envelope/correction, worker partition tails and tile tails. Keep x/y/z accumulation order unchanged. Input spectra and selected modes remain immutable. Track explicit scratch/storage requirements and actual FFT counts outside timed calls.

The manufactured spectra use the production radial two-thirds mask and primary Hermitian representatives (including negative k). Both families apply the eta vertical density correction. A quadratic vertical envelope provides an independent Fourier/vertical-derivative oracle. Variant 0 performs the same FFT count as baseline; variant 1 shares inverse-y columns between a field and its x derivative inside one active plane. Actual FFT producer counts are checked outside timing. Fields must agree exactly; variant 0 flux/projection must agree exactly; variant 1 and the direct oracle use a separate 1e-12 scaled error gate.

The frozen pilot probes tile depths 1, 4 and 16, including the previously selected native tile depth as a control. It runs five alternating paired samples after two warmups for Hydrostatic 28 and Boussinesq 129. If promising, one selected schedule receives four fresh-process blocks of nine pairs across both families and both depths. Blocks alternate first role. Report block-level uncertainty; do not count correlated samples as independent processes. The paired process retains both paths' scratch, so reported role-specific buffer bytes are not RSS or full-model memory measurements.

## Result: proceed to a bounded runtime integration

The depth-4, shared-column schedule cleared the horizontal-stage screen in all four fresh-process blocks for every case. The table reports the median of four block median paired ratios. The range is the observed block range, not a formal confidence interval; nine within-process pairs are not treated as nine independent processes.

| Family and grid | Baseline stage, ms | Candidate stage, ms | Time reduction | Block reduction range |
| --- | ---: | ---: | ---: | ---: |
| Hydrostatic 256 × 256 × 28 | 8.36 | 5.92 | 29.7% | 25.4–31.4% |
| Boussinesq 256 × 256 × 28 | 10.46 | 7.13 | 31.2% | 28.1–31.3% |
| Hydrostatic 256 × 256 × 129 | 32.83 | 23.26 | 26.5% | 23.0–29.1% |
| Boussinesq 256 × 256 × 129 | 42.29 | 30.35 | 28.8% | 22.6–30.4% |

The time columns are medians of block medians, so their quotient need not equal the median paired ratio. The host passed a read-only idle preflight before each campaign; there was no continuous host monitor. Baseline timings varied across processes, making the repeated paired direction more useful than a single absolute timing. No experiment or unrelated process was altered.

The equal-FFT-count depth-4 pilot also improved, supporting locality/scheduling as a useful direction beyond saved transforms. That variant did not receive independent confirmation and cannot isolate a precise contribution. Depth 16 sometimes improved further but allocated 359 MiB Hydro /430 MiB Bouss scratch; depth 4 was selected before confirmation to limit the storage cost.

| Grid depth | Baseline extra scratch, MiB | Depth-4 Hydro, MiB | Depth-4 Bouss, MiB |
| --- | ---: | ---: | ---: |
| 28 | 32.9 | 107.9 | 128.7 |
| 129 | 151.5 | 107.9 | 128.7 |

These are explicit role-specific buffer capacities, excluding common prepared spectra, four cached full physical fields, projected outputs, native resources and untimed verification captures. The paired executable retains both roles simultaneously. This is not candidate RSS and not a promise of final model storage. Runtime integration may also change the lifetime/count of prepared vertical or projected spectra; account for that before adoption. At small Nz, production allocation should cap tile capacity at the actual largest worker partition.

The shared-column schedule performs 10 instead of 13 inverse-y transforms per plane for Hydrostatic and 12 instead of 16 for Boussinesq. Row inverse counts remain 13 and 16. The counters surround actual FFT execution in untimed verification; timing does not include atomic counter increments.

## Verification and provenance ledger

- Frozen benchmark source: `de3d6682f9499394d9386909c381028992370e00`; accepted production base: `60287e1993b1a5a91ee8249eca94ee8f45dda801`. Subsequent commits add only evidence/documentation.
- Frozen executable SHA-256: `6a908326d20b8b081e07be866500d38cae0ed500c7bc03b1d205ea7d0f0467b8`. Same native NEON/pthreads FFTW libraries for baseline/candidate, twelve outer workers, one internal FFT worker and eight materialization workers.
- Clang Release, GCC 14 Release and Clang ASan/UBSan Debug each passed eight direct-oracle, negative-k, odd/even grid, single-plane, worker-partition and tile-tail cases. SHARE=0 requires exact fields, flux and projection. SHARE=1 requires exact fields and a separate 1e-12 flux/projection gate. Direct Fourier oracle has its own 1e-12 gate.
- Independent review corrected a Boussinesq eta correction omission in the initial prototype/oracle, nonproduction representative layout, scaling generality, overly broad tolerance and unused Hydro scratch before source freeze or representative timing. Final review found no blocker. No preliminary timing with those errors is used here.
- All 28 representative processes passed full-array field/flux/projection checks and direct pointwise oracle before and after timing. Largest scaled field difference: zero; flux: `3.864e-17`; projection: `6.776e-20`; direct oracle: `2.090e-16`.
- No production source changes: broad runtime/MATLAB qualification and hosted CI were deliberately deferred to runtime integration. Focused checks were rerun after review corrections; none were repeated after the source freeze.
- Raw archive: `OceanKitRepositories/wave-vortex-model-benchmark-artifacts/tiled-advection-screen-20260912`; compact data and provider identities: [results.json](results.json). The archive's `evidence-hashes.json` SHA-256 is `fafa805feb0591d33f17df30f1ecb75703ff4b9df3ac99e74d7679a91a5abe96`.
- Pilot worker processes occupied 8.2 seconds total; confirmation worker processes 12.2 seconds, excluding two ten-second preflight waits. Most work in this increment was prototype construction and correctness review, not timing campaigns. Only two bounded agent assignments were active; neither launched competing compute.

## Reproduction

Configure this directory as a standalone CMake project with `-DFFTW_ROOT=<frozen-native-provider>` and `-DCMAKE_BUILD_TYPE=Release`, then build `wv-tiled-screen`. Run `python3 check-screen.py <binary> <new-check-directory>`. Run `python3 run-screen.py <frozen-binary> <archive-directory> pilot`, followed by `python3 run-screen.py <frozen-binary> <archive-directory> confirmation 4 1`. Campaign directories must not exist. The runner checks host idleness using `ps` and never changes another process. The standalone source includes the accepted native implementation once; its provider-internal access is strictly a benchmark device, not a production API.

For the first runtime increment, retain prepared base/z spectra and the qualified grouped MM schedule. Add the fused horizontal producer through an explicit provider/evaluator contract, preserve complete physical-field publication, component/view identity, derivative capture and reference fallback, then qualify whole-model time and memory. A later vertical-MM tiling experiment is justified only if the integrated profile still calls for it.
