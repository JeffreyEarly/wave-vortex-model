# Nonlinear WVModel RK4 and native restart qualification

`TestFreeSurfaceNonlinearRestart` qualifies a bounded integration and persistence path for the full C1 mapped equations. It uses the production `WVModel` fixed RK4 integrator, explicit `WVNonlinearAdvection`, and a small `WVPrescribedBoussinesqSource` declared in physical coordinates. The source includes momentum and total-displacement rates with a nonzero absolute-time frequency and phase.

## Configuration and independent integration control

The retained grid is 8 by 8 by 65 on a 100 km by 100 km by 1 km domain with constant N2 = 1e-4 s^-2. APV, MDA, and inertial counts are two; each wave sign retains three modes on every nonzero wavenumber page. Both `shouldCheckQuadraticAliasing` and `shouldAntialias` are true. The existing weak-study mixed seed supplies positive/negative mean endpoint margins, balanced anomalies, and inertial motion. The test adds independent x/y wave columns and both wave signs.

The reference clock is t0 = -17 s, initial time is 327 s, final time is 367 s, and the fixed step is 5 s. An explicit four-stage RK4 loop calls `WVInternal.freeSurfaceNonlinearStage.evaluate` with supplied coefficient states and `includeForcing=true`. It changes the evaluation clock at each stage while verifying that supplied-state evaluation does not mutate stored coefficients. This is an independent control of integration/state/clock plumbing; it shares the already-qualified spatial equations with the production tendency and is not a second derivation of those equations.

## Native checkpoint and continuation

A second model writes its native NetCDF checkpoint at 347 s. The test removes all InternalModes paths before calling `WVModel.modelFromFile` and verifies that both `IMInternalModes` and `IMSolverSpectral` are unavailable. The new transform restores with `verticalModes` empty, every persisted non-function scientific property exactly equal, unchanged clocks, six coefficient families, wave counts, active prefixes, and construction-policy flags. Both forcing objects restore together, including the prescribed source's physical coordinate convention, patterns, frequency, reference time, and phase.

After configuring the restored runtime integrator, continuation to 367 s is compared with uninterrupted evolution. The test checks physical u/v/w, total and interior displacement, SSH, linear and full diagnostic pressure, material-coordinate w_i, the moving z mesh, and full nonlinear energy. The final committed NetCDF field record is checked independently against the uninterrupted fields.

This is a fresh restored object with provider paths removed in the same MATLAB process. It is not a separate-process cold-start test. No mode provider was discoverable on the restore/continuation path, and no stored mode inventory changed.

## Observed result

The focused test passed on MATLAB R2026a with the pinned beta dependency exports. Maximum relative errors across the six coefficient families were zero for both production-versus-explicit RK4 and restart-versus-uninterrupted comparisons. Physical-field and final saved-output comparisons also had zero error in this run. Full nonlinear energy agreed within the asserted 2e-11 relative tolerance.

Across all independently evaluated RK stages, the sampled parcel-label range was [-998.096356, -1.80072884] m, strictly inside [-1000, 0] m. The maximum reported weak-solver relative stationarity residual was 8.86551e-13. Native forcing restoration succeeded without an intermediate invalid inventory. Code Analyzer reported no findings in the new test.

The control covers 40 seconds and one qualified truncation. It does not establish a timestep convergence rate, long-time stability, general stratification, conservation of material/APV moments, or convergence of pressure along the reduced trajectory. It preserves and compares the existing instantaneous pressure diagnostic. Particles and tracers are omitted here because their coordinate equations have a separate focused observer qualification. Optional user-directory, undamped-model, and intermediate package-path-removal warnings did not prevent the test from completing.

## Separate-process restart with variable wave counts

`tools/nonlinear-study/runFreeSurfaceNativeRestartCheck.m` supplies an additional cold-start gate. Its write process constructs a separately qualified inventory with per-wavenumber wave counts [3, 2, 0, 3], including one zero-wave page and eight inactive entries in each rectangular wave array. Both horizontal directions and wave signs participate in the seed. The physical source convention, absolute source clock, retained families, integration times, and 5 s RK4 step follow the preceding control.

The write process stores an uninterrupted 367 s reference state, physical fields, full nonlinear energy, scientific operators, and forcing configuration in a MAT file, and a native 347 s checkpoint in NetCDF. The read process starts independently, configures WVM and only its non-provider dependencies, removes any installed InternalModes paths that survive `restoredefaultpath`, and asserts both mode-provider entry points are unavailable before loading checkpoint objects. It restores and continues the native file for 20 s, checks all stored operators/counts, and confirms inactive wave padding remains zero and MDA remains real.

The two separate MATLAB invocations, run from the worktree root outside the macOS sandbox, are:

```sh
matlab -batch "restoredefaultpath; maxNumCompThreads(2); addpath('tools/nonlinear-study'); runFreeSurfaceNativeRestartCheck('write','/private/tmp/wvm-nonlinear-fresh-restart-20260909','../oceankit-beta-publish');"
matlab -batch "restoredefaultpath; maxNumCompThreads(2); addpath('tools/nonlinear-study'); runFreeSurfaceNativeRestartCheck('read','/private/tmp/wvm-nonlinear-fresh-restart-20260909','../oceankit-beta-publish');"
```

The fresh read passed with zero relative coefficient, physical-field, and full-energy errors against the first process's uninterrupted reference. Its final sampled label range was [-998.096315151906, -1.8007518982660529] m, and the weak-solver relative residual was 4.6790371297744243e-13. The mode provider remained unavailable after continuation, `verticalModes` remained empty, and the saved scientific arrays and variable counts were unchanged. Code Analyzer reported no findings in the new verification script.

The durable local evidence is `variable-count-checkpoint.nc`, `variable-count-reference.mat`, `write-result.json`, and `read-result.json` in `/private/tmp/wvm-nonlinear-fresh-restart-20260909`. The read stage appends the 367 s record, so repeat the write stage before rerunning a read. An initial attempted read stopped before restoration when it detected provider paths inherited from installed-package setup; the explicit removal in the final helper addresses that verification-environment issue. This separate-process result establishes the bounded cold-start and variable-prefix continuation gate, with the same physical and trajectory limitations stated above.
