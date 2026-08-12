# Issue 152 overnight handoff

Status: **ADVANCE_TO_BENCHMARK**

Implementation/tests commit: `175e3d649ad7feda9322efd3033cad9217141063`

## Finding

This is an FFTW++ library defect, not adapter misuse or an undocumented `A <= 2B` contract. In pinned FFTW++ commit `1a185f41800cd0e9d4df4ddf93e16e362d4e2c45`, `Convolution::convolveRaw` enters its Hermitian two-loop schedule whenever `A > B`, but reconstructs first-residue outputs only while `a + (A-B) <= B`. For 15→3 and 19→4 that loop is skipped, and the final second-residue forward transform overwrites the unreconstructed first-residue output buffers. The observed result is a mixture of residue/channel contributions, not one consistent pointer permutation.

The contained patch transforms each still-live input batch before reconstructing the corresponding first-residue output batch, including the final partial batch, then transforms the remaining inputs. It is suitable for an upstream report.

## Correctness and lifecycle

- Unpatched direct-oracle reproducer: 1-D centered passes, while 1-D Hermitian and 2-D centered/Hermitian fail. The exact 2-D implicit errors are `4.996869e-01` for 15→3 and `4.985616e-01` for 19→4; hybrid errors are `4.811887e-01` and `4.802951e-01`.
- Patched direct-oracle suite: all ten minimal implicit/hybrid cases pass, including 15→3 and 19→4; maximum relative error is `9.995248e-16`.
- Small compiled-core comparison against the pinned native explicit control, at four threads: hydrostatic implicit/hybrid errors are `9.519088e-15`/`1.052333e-14`; nonhydrostatic implicit/hybrid errors are `8.736335e-15`/`1.583649e-14`.
- Every compiled-core process reports 14 plans created and 14 destroyed, zero active plans, zero outstanding planning bytes, disjoint worker regions, maximum OpenMP active level 1, and no oversubscription.

The corrected hydrostatic adapter performs 12 physical-input, 3 sacrificial-input, and 3 output transforms (18 library transforms versus 30 for the issue-128 `A=B` workaround). The nonhydrostatic adapter performs 15 + 4 + 4 = 23 library transforms versus 38. No dependency source, library, executable, cache, benchmark result, or RSS artifact is tracked.

## Benchmark candidate

No medium/large/reportable timing was run. The prepared four-thread candidate command is:

```sh
cd /private/tmp/issue152-overnight-wave-vortex-model && OMP_NUM_THREADS=4 ISSUE152_CACHE_ROOT=/private/tmp/issue152-overnight-cache ISSUE152_THREADS=4 Benchmarks/runIssue152CandidateBenchmark.sh /private/tmp/issue152-overnight-cache/benchmark-medium-4t
```

Expected runtime: about 2 minutes. Compare against the existing issue-128 `A=B` artifact; the command also runs fresh pthread and OpenMP explicit controls.

FFTW++ remains LGPL-3.0-or-later. The tracked file is an upstreamable patch, not dependency source. Distributing a binary built with the modified library requires satisfying LGPL source/modification notice and relinking requirements; no such binary is committed here.
