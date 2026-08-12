# WaveVortexModel issue #128 — Lyra FFTW++ prototype

Recommendation: **CORE-REJECT**. Neither the FFTW++ implicit nor hybrid candidate passed issue #128's complete-core time or storage gate, so no candidate advances to Donut and the three-process finalist protocol was not run.

## Scope and identity

- Baseline: `be0f78995c49a2bfe4c43d75827856e3812ac278`
- Experimental implementation: `1197f471280f63f312db4d490597f9f6cd865e73`
- Branch: `experiment/issue-128-fftwpp-implicit-dealiasing`
- Host: Lyra (`lyra.ad.nwra.com`), Mac Studio Mac16,9, Apple M4 Max, 16 cores (12P+4E), 128 GB
- OS/architecture: macOS 26.5.2 (25F84), arm64 / MATLAB maca64
- MATLAB: `25.2.0.3150157 (R2025b) Update 4`; default thread count 16
- FFTW++: `dealias/fftwpp` commit `1a185f41800cd0e9d4df4ddf93e16e362d4e2c45`, tree `77be88f8f58cd4a7d0b91f5323dcebd667e5b840`
- FFTW: 3.3.11; upstream `make check` and cycle-counter checks passed
- OpenMP: isolated #137 LLVM libomp 22.1.8 build; no system-wide installation

The load guard passed before fetching and before accepted timing. No Issue #140 benchmark, MATLAB benchmark, RSS sampler, screen session, or substantial competing workload was active.

## Prototype

The optional experimental engine preserves the canonical `[Nj,Nkl]` state and exact retained radial modes, maps retained modes into an even centered/Hermitian FFTW++ representation without constructing the omitted half, performs hydrostatic three-output or nonhydrostatic four-output nonlinear multiplication, and maps only retained modes back. Vertical transforms, field-to-WV projection, forcing composition, and integration remain outside FFTW++.

FFTW++ cyclically permutes channels in its optimized two-residue path when `A>B`. A named-channel WaveVortex MIMO multiplier is not invariant under that permutation. The valid prototype therefore uses `A=B` internally, retains only the first three/four outputs, and records the resulting conservative work and storage cost. Implicit schedules have zero logical padding; hybrid schedules have two logical cells of padding per horizontal dimension.

Small hydrostatic/nonhydrostatic correctness, zero-state, odd/even geometry, lifecycle, and pinned upstream direct-convolution tests passed. The maximum small-smoke relative infinity error was `1.4408912326264852e-15`; all screening errors were below `1.0e-14`, comfortably within the required `1e-12`.

## Same-host screening

Each configuration ran in a fresh MATLAB process with two warmups and deterministic state advancement. Medium cases used three samples; large cases used one screening sample. Values below are median internal complete `nonlinearFlux` seconds and exact maximum-live owned bytes.

| Case | pthread explicit | OpenMP explicit | FFTW++ implicit | FFTW++ hybrid | Hybrid speedup vs pthread | Hybrid max-live change |
|---|---:|---:|---:|---:|---:|---:|
| Hydro 128×128×33 | 0.029893 | 0.030278 | 0.138451 | 0.057946 | 0.516× | −5.65% |
| Nonhydro 128×128×33 | 0.038203 | 0.038038 | 0.172266 | 0.068912 | 0.554× | −0.10% |
| Hydro 256×256×65 | 0.284451 | 0.288886 | 0.805848 | 0.917847 | 0.310× | −6.66% |
| Nonhydro 256×256×65 | 0.367693 | 0.359337 | 1.029315 | 1.161215 | 0.317× | −1.29% |

Exact maximum-live bytes for pthread / implicit / hybrid were:

| Case | pthread | implicit | hybrid |
|---|---:|---:|---:|
| Hydro 128×128×33 | 69,387,557 | 65,456,789 | 65,467,861 |
| Nonhydro 128×128×33 | 73,712,933 | 73,627,541 | 73,641,365 |
| Hydro 256×256×65 | 546,083,271 | 509,696,967 | 509,718,983 |
| Nonhydro 256×256×65 | 580,161,991 | 572,662,855 | 572,690,375 |

The prototype keeps no persistent full padded Hermitian spectrum (`persistentFullHermitianBytes = 0`). FFTW/FFTW++ opaque plan allocation is not introspectable; the artifact separately records exact retained-spectrum/work bytes, wrapper lower bounds, and externally sampled RSS. Screening RSS did not establish a storage-gate candidate, and repeated-process finalist RSS was intentionally not collected because exact maximum-live reductions already missed 10% for both hydrostatic and nonhydrostatic cases.

For accepted one-thread measurements, instrumentation reports one outer OpenMP thread, one FFTW thread, one multiplier thread, active OpenMP level zero, disjoint worker regions, and no oversubscription.

## Threading constraint

A 16-thread lifecycle probe was rejected before timing. MATLAB R2025b had loaded its bundled `libomp.dylib`, while the pinned #137 provider loaded the isolated LLVM 22.1.8 runtime. Creating worker regions produced OpenMP error 179 (`pthread_mutex_init` invalid argument) followed by a segmentation violation across the two runtimes. No result from that process is included.

This prevents a valid R2025b multi-thread comparison using the required pinned OpenMP runtime. Thread-matched one-thread controls remain valid and are enough to reject both candidates: neither comes close to the time gate, and neither reaches the exact-storage gate.

## Decision

Issue #128 requires both hydrostatic and nonhydrostatic cases at one common size to achieve either at least 10% faster complete `nonlinearFlux`, or at least 10% lower exact maximum-live bytes and repeated-process peak RSS, with no more than 3% regression in the other metric. The best candidate is already 80%–223% slower and saves at most 6.66% exact maximum-live bytes. Therefore:

- no candidate qualifies as a finalist;
- the seven-medium/three-large, three-fresh-process finalist stage is skipped by the funnel;
- there is no candidate to hand to Donut for R2026a confirmation;
- the branch is experimental evidence only and must never be merged wholesale;
- issue #128 remains open.

## Reproduction and licensing

The branch contains the pinned-source build entry point, correctness smoke, fresh-process worker, and screening orchestrator. Dependencies, archives, libraries, MEX binaries, FFTW wisdom, and build caches remain outside the repository. `results.json` records source/archive/binary hashes and the `dladdr` identities of the loaded FFTW, FFTW thread, and OpenMP libraries.

FFTW++ is LGPL-3.0-or-later. If a combined/object work is conveyed, provide prominent notices and GPL/LGPL copies, allow replacement or relinking with a modified LGPL library, and provide corresponding application code or minimal corresponding source as required by LGPLv3 section 4. This experimental branch conveys none of the FFTW++ source or binaries.

Verification completed:

- pinned FFTW++ upstream direct errors: `1.01e-16`–`1.50e-16`;
- WaveVortex smoke correctness/lifecycle/zero-state: passed;
- fresh-process screening correctness and lifecycle: passed for all four configurations;
- standalone C++ contract tests: 1/1 passed;
- MATLAB `checkcode`: zero issues in the new build/smoke/worker/orchestrator scripts;
- `git diff --check`: clean.
