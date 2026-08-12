# Issue #153 — decomposed FFTW++ convolution

## Decision

**CORE_REJECT.** The binary 2-to-1 and grouped per-velocity decompositions fail the first exact correctness gate. No production implementation is retained.

## Correctness and lifecycle

The one-thread hydrostatic 128x128x33 (`Nj=21`) #128 standalone explicit reference was used. Its unchanged FFTW++ hybrid control has relative-infinity error `3.91e-14`. Before the #152 repair, binary and grouped errors were `6.631488126e-1` and `6.630791593e-1`. After applying only #152 commit `175e3d649ad7feda9322efd3033cad9217141063`'s two-loop `A > B` scheduler correction to the issue-local pinned FFTW++ dependency, the errors were still `6.531557948e-1` (binary) and `6.528051038e-1` (grouped), versus the `1e-12` requirement.

Both candidates completed lifecycle checks: 14 FFTW plans were created and destroyed, no planning bytes remained outstanding, and one-thread worker regions were disjoint. Neither retained a persistent contribution array.

## Algebraic schedules

| Candidate | Convolutions | Transforms | Reuse |
| --- | ---: | ---: | --- |
| Binary 2-to-1 | 9 | 27 | no shared velocity reuse |
| Grouped per velocity | 3 | 21 logical / 24 physical | six hydrostatic shared-velocity transforms; zero residue reuse |

The grouped schedule's extra three physical transforms are sacrificial channels required by the symmetric FFTW++ layout.

## Blocker and skipped stages

The #152 scheduler repair did not cure the decomposition mapping: a distinct FFTW++ channel/residue mapping fault remains. Therefore nonhydrostatic correctness, timing, RSS, finalist sampling, and Donut confirmation were intentionally skipped. No benchmark-performance artifact or production PR was created.
