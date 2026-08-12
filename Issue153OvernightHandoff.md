# Issue #153 overnight handoff

Status: **CORE_REJECT**. No implementation is retained or committed.

The #128 standalone control at 128x128x33, hydrostatic, one thread, matched the native explicit reference with relative-infinity error `3.91e-14`. The two exact decomposition prototypes failed the first correctness gate at the same state: binary 2-to-1 reported `6.63e-1`, and the grouped per-velocity schedule reported `6.63e-1`. Both cleaned up all 14 FFTW plans, used one thread with disjoint worker regions, and retained no persistent contribution arrays. No medium/large, RSS, or timing screen was run.

Reported algebraic schedules were: binary 9 convolutions and 27 transforms (no shared-velocity reuse); grouped 3 convolutions, 21 logical transforms, and 24 physical transforms because the proven symmetric FFTW++ layout needs one sacrificial channel per velocity group. The grouped form would reuse six hydrostatic velocity transforms, but neither mapping is numerically valid with the current FFTW++ adapter.

Reproduction cache/build root: `/private/tmp/issue153-overnight-cache`. The failed implementation was removed from the worktree. A future retry needs a direct FFTW++ channel/residue mapping test before reintroducing either schedule.
