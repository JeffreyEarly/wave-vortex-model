# WaveVortexModel issue #154 — exact phase-shift screening

Recommendation: **CORE-REJECT**. Exact four-grid phase shifting passes the mathematical and numerical correctness gate, but is not remotely plausible for the complete compiled `nonlinearFlux` performance/storage gate.

## Identity and controls

The candidate is commit `153b31d5acef994a36b79b84e7c9f8a5a1248d47` with telemetry commit `b457c9d4f24abc7d03e4b9f43c5888c56900ef9f`, built on the issue #128 scaffold `782e9b41b76628eb0f61b1bd87339dd69b884314` and pinned baseline ancestor `be0f78995c49a2bfe4c43d75827856e3812ac278`.

The exact #128 native-pthread explicit control and matched isolated LLVM-libomp explicit control were reused. `otool -L` and runtime `dladdr` identify `fftw-3.3.11-neon`, the pinned pthread or OpenMP FFTW library, and the isolated `libwvissue137omp.dylib`; no standalone executable links MATLAB. The candidate uses the same pinned pthread FFTW provider. The accepted 21:39 PDT load guard had no MATLAB workload, benchmark, compiler, RSS sampler, or competing issue process.

## Exactness and schedule

Exhaustive enumeration covered 192 odd/even, square/nonsquare-domain geometries and 384 hydrostatic/nonhydrostatic operator cases. The complete alias set is the eight nearest cyclic images. Four tensor half-cell shifts on the minimal ((2K+1)\times(2L+1)) grid are necessary and sufficient; two diagonal shifts leave diagonal aliases with residual one. Enumeration errors are `7.97e-16` for explicit padding and `8.38e-16` for four-shift averaging.

The small native FFTW rerun covered hydrostatic 8×7×7 and nonhydrostatic 9×8×7 at one and four threads. Maximum candidate error was `6.17e-15`; all fourteen core plans and two phase-shift plans were destroyed, outstanding planning bytes returned to zero, and worker regions were disjoint. Across all screens the maximum relative infinity error was `1.20e-13`, below `1e-12`.

The candidate keeps retained Hermitian half-spectrum channels and no persistent full Hermitian spectrum. The medium candidate grid is 85×85 versus 128×128 explicit; the large grid is 171×171 versus 256×256 explicit. Every shifted product is evaluated and combined within one convolution call.

## Medium screening

Each configuration used one fresh process, two warmups, three deterministic samples, rotated implementation order, and thread counts 1, 4, 8, and 16. The table shows each implementation's best median.

| Case | pthread explicit | isolated-libomp explicit | four-shift candidate | Candidate / pthread | Max-live change | Screening RSS change |
|---|---:|---:|---:|---:|---:|---:|
| Hydrostatic 128×128×33 | 0.006687 s (16t) | 0.006776 s (16t) | 0.101970 s (1t) | 15.25× slower | −6.57% | −23.68% |
| Nonhydrostatic 128×128×33 | 0.008492 s (16t) | 0.009065 s (8t) | 0.127757 s (1t) | 15.04× slower | −1.19% | −20.23% |

The apparent one-process RSS reductions at one candidate thread are non-qualifying context. The exact max-live reduction is already below 10% in both configurations, while complete-core time regresses by roughly 1400%.

## Large screening

The 256×256×65 screen used 16 threads, two warmups, and one deterministic sample per fresh process.

| Case | pthread explicit | isolated-libomp explicit | four-shift candidate | Candidate / pthread | Max-live change | Screening RSS change |
|---|---:|---:|---:|---:|---:|---:|
| Hydrostatic | 0.065127 s | 0.070350 s | 0.935114 s | 14.36× slower | −7.10% | −2.91% |
| Nonhydrostatic | 0.090146 s | 0.087671 s | 1.171302 s | 12.99× slower | −1.81% | −0.23% |

At large size the candidate spends 0.856 s hydrostatic and 1.072 s nonhydrostatic inside shifted convolution, plus 0.0666 s and 0.0798 s mapping retained channels. A hydrostatic call requires 396/1,584 forward/inverse scalar horizontal transforms at medium and 780/3,120 at large; nonhydrostatic requires 528/1,980 and 1,040/3,900. Native explicit instead uses five hydrostatic or six nonhydrostatic batched horizontal plan executions.

Candidate known maximum-live owned storage is 64.8/72.8 MB at medium and 507/570 MB at large. The raw `opaquePlanBytes` field is zero because FFTW exposes no opaque-plan allocation size; it is recorded as unavailable rather than counted as measured memory. Construction, cleanup, exact scratch, retained spectrum, convolution work, mapping, complete-core, library, lifecycle, and threading fields are in `results.json`.

## Decision and skipped stages

No size/configuration pair approaches either adoption route. Speed is 13.0×–15.2× worse, exact maximum-live improves only 1.19%–7.10%, and large peak RSS improves only 0.23%–2.91%. The candidate is therefore **CORE-REJECT**.

The three-fresh-process finalist protocol, seven medium samples, three large samples, repeated-process RSS, and Donut confirmation were not run because those are finalist-only stages and the required early screen made the candidate unequivocally implausible. No additional phase-shift variants were explored.
