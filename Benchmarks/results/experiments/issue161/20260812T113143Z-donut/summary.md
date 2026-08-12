# WaveVortexModel issue #161 canonical Donut confirmation

- Standalone disposition: **ADOPT**
- Independent MEX disposition: **MEX-QUALIFIED**
- Qualifying common size: `512x512x129`
- Candidate: `9ceb932a7f42e3a722f6cb406e7e06fe913aef86` (unchanged; parent `3af6b83e7ceac52a66536e8cdb8495e1c2df2016`)
- Control: `3af6b83e7ceac52a66536e8cdb8495e1c2df2016`; required ancestor: `be0f78995c49a2bfe4c43d75827856e3812ac278`

The compact descriptor is adopted because exact known max-live owned bytes fall by 7.36% in both 512 configurations while complete/native time and repeated-process RSS remain within the 3% ceiling. The 256 hydrostatic RSS run is conservatively marked nonqualifying because its process-relative RSS was noisy; the 512 common-size gate is independently sufficient.

## Environment and identity

| Item | Value |
|---|---|
| Host | Donut, Apple M5 Max, 18 cores, 48 GiB |
| OS | macOS 26.5.2 (25F84), Darwin 25.5.0 |
| MATLAB | 26.1.0.3312084 (R2026a) Update 4, maca64, 18 threads |
| FFTW | 3.3.11 native NEON/pthreads, 18 threads |
| Base dylib SHA-256 | `abc08b7b2c328d9659dd89a382494d7ca2e7aaec369c1f1025e255c6a2d99a0b` |
| Threads dylib SHA-256 | `6e5c9a14b2c3db5fc8ec5f9ba5bd08457677cc9b8c12baa6331379c6145ba0ca` |
| Loaded libomp | one image: `/Applications/MATLAB_R2026a.app/bin/maca64/libomp.dylib` |
| Plan accounting | 17 wrapper plans; FFTW-owned plan memory opaque |

The MEX `dladdr` identities resolved both control and candidate to the exact pinned base and pthreads dylibs. The pthreads dylib has no OpenMP dependency; MATLAB loaded only its bundled `libomp.dylib`.

## Performance

MEX complete and native/internal values are medians of the three fresh-process medians. Production MATLAB is measured in the same fresh processes.

| Case | Control MEX ms | Candidate MEX ms | MEX delta | Control native ms | Candidate native ms | Native delta | Production MATLAB ms | Candidate speedup |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| hydrostatic-256x256x65 | 55.033 | 53.638 | -2.54% | 54.795 | 53.397 | -2.55% | 95.299 | 1.777x |
| nonhydrostatic-256x256x65 | 70.512 | 64.380 | -8.70% | 70.268 | 64.141 | -8.72% | 113.513 | 1.763x |
| hydrostatic-512x512x129 | 426.129 | 432.130 | +1.41% | 425.215 | 429.504 | +1.01% | 754.311 | 1.746x |
| nonhydrostatic-512x512x129 | 535.822 | 525.933 | -1.85% | 534.906 | 524.982 | -1.86% | 939.151 | 1.786x |

## Memory

| Case | Descriptor control/candidate MiB | Descriptor reduction | Persistent control/candidate MiB | Max-live control/candidate MiB | Max-live reduction | Persistent RSS delta | Peak RSS delta |
|---|---:|---:|---:|---:|---:|---:|---:|
| hydrostatic-256x256x65 | 107.78 / 74.79 | 30.61% | 433.79 / 400.80 | 455.79 / 422.80 | 7.24% | +69.13% | +61.65% |
| nonhydrostatic-256x256x65 | 107.78 / 74.79 | 30.61% | 433.79 / 400.80 | 455.79 / 422.80 | 7.24% | -3.03% | -2.46% |
| hydrostatic-512x512x129 | 866.58 / 599.47 | 30.82% | 3450.61 / 3183.51 | 3628.68 / 3361.58 | 7.36% | -0.04% | -1.62% |
| nonhydrostatic-512x512x129 | 866.58 / 599.47 | 30.82% | 3450.61 / 3183.51 | 3628.68 / 3361.58 | 7.36% | -2.93% | -2.37% |

Scratch is unchanged (325.97 MiB at 256 and 2584.03 MiB at 512), plan count remains 17, and persistent full-Hermitian bytes remain zero.

## Correctness and lifecycle

| Case | Maximum relative error | Candidate lifecycle | Control lifecycle |
|---|---:|---|---|
| even-nonsquare-hydrostatic | 9.659e-16 | PASS | PASS |
| odd-nonsquare-hydrostatic | 1.725e-15 | PASS | PASS |
| even-nonsquare-nonhydrostatic | 1.420e-15 | PASS | PASS |
| odd-nonsquare-nonhydrostatic | 1.696e-15 | PASS | PASS |

Portable native contract tests passed for both exact commits. R2026a descriptor, forward/inverse, F/G derivative, ordinary coefficient production, post-#130 streamed three-channel and single-output projection, repeated-call/state ownership, odd/even/nonsquare hydrostatic/nonhydrostatic, alias/overlap rejection, and plan/allocation/execution injection cleanup all passed. Targeted maximum relative error was 1.725e-15; benchmark maximum was 2.170e-14.

## Complexity and scope

The candidate removes five redundant arrays—four complex arrays and one real array—totaling 72 bytes per `[Nj,Nkl]` coefficient (`UAm`, `VAm`, `WAm`, `NAm`, and `ApmW`) and adds one 8-byte `[Nj]` ApmW prefactor. Exact descriptor reduction is therefore `72*Nj*Nkl - 8*Nj` bytes. Removed fields are regenerated algebraically in ordinary transforms and streamed single-target projection while retaining #126 coefficient-production scaling.

Only five native source/test files changed (67 insertions, 35 deletions). There are no API, transform, plan, execution, provider, thread, dependency, binary, cache, full-Hermitian persistence, second-state, #158, or #160 changes.

## Gate details

| Size | Hydrostatic | Nonhydrostatic | Common-size result |
|---|---|---|---|
| 256x256x65 | FAIL | PASS | FAIL |
| 512x512x129 | PASS | PASS | PASS |

Final dispositions: **ADOPT** standalone and **MEX-QUALIFIED** independently. Candidate `9ceb932a7f42e3a722f6cb406e7e06fe913aef86` is unchanged; only this artifact is added after it.
