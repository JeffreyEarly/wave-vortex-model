# WaveVortexModel issue #153 — decomposed/grouped convolution screen

Recommendation: **CORE-REJECT**. Neither decomposition passed the first hydrostatic correctness gate, including after the issue #152 asymmetric FFTW++ scheduler correction.

## Identity and test

The experiment uses baseline `be0f78995c49a2bfe4c43d75827856e3812ac278`, scaffold `782e9b41b76628eb0f61b1bd87339dd69b884314`, and the standalone issue #128 pthread control as the deterministic reference. The bounded follow-up applied only issue #152 correction `175e3d649ad7feda9322efd3033cad9217141063` to an issue-local cached copy of the pinned FFTW++ source. No dependency source, library, binary, or build cache is tracked.

The test case was hydrostatic 128×128×33 with `Nj=21` and one thread. The existing FFTW++ hybrid control matched the native explicit reference at `3.91e-14` relative-infinity error.

| Schedule | Error before #152 repair | Error after #152 repair | Gate | Result |
|---|---:|---:|---:|---|
| Nine independent binary 2→1 convolutions | 0.663149 | 0.653156 | ≤1e-12 | Fail |
| Three grouped per-velocity convolutions | 0.663079 | 0.652805 | ≤1e-12 | Fail |

Both schedules passed lifecycle checks before and after the repair: 14 FFTW plans were created and destroyed, outstanding planning bytes returned to zero, one-thread worker regions were disjoint, and no contribution arrays persisted.

## Transform accounting

The binary schedule reports nine convolutions and 27 transforms with no shared-velocity reuse. The grouped schedule reports three convolutions, 21 logical transforms, and 24 physical transforms because its symmetric layout requires one sacrificial channel per velocity group. It reuses six hydrostatic velocity transforms but no residues.

## Decision and skipped stages

The issue #152 scheduler repair does not cure the decomposition mapping. A distinct channel/residue mapping defect remains, so the experiment stops at the required correctness gate. Nonhydrostatic correctness, medium and large timing, memory/RSS screening, finalist repetitions, and Donut confirmation were not run. The failed prototype was removed rather than retained as experimental implementation.

The exact values, lifecycle fields, transform counts, blocker, and reproduction command are in `results.json`.
