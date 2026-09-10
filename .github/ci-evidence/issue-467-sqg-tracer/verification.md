# Issue 467 verification ledger

Qualified source commit: `9641226c206342712b5df871ee3bfb37a44469fa`.

- The pre-fix clean-path reproduction fails at the first tracer RHS with `WVTransform:UnknownVariable` for `w`.
- The dedicated regression class passed 3/3 checks for capability selection, first RHS and integration against an explicit horizontal SQG tracer, and save/restart with the full XYZ tracer layout.
- Existing focused tracer facade and barotropic restart checks passed 2/2. The frozen-source qualification therefore passed 5/5 tests.
- Code Analyzer ran once after the source was frozen. `TestSQGTracerConvenience.m` has zero findings. `WVModel.m` reports three findings.
- Receipt serialization failed after the tests and Analyzer completed because the temporary driver retained MATLAB `duration` objects. The original diary and driver are retained, and `reporting-correction.json` records that no scientific test or Analyzer rerun followed.
- Qualification used a clean MATLAB R2025b path with the v4 authoring checkout and pinned OceanKit package snapshots. `WVModel` and `WVNonlinearAdvection` were asserted to resolve inside this checkout.
