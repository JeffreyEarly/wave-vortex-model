# RHS scheduling study

This authoring study isolates reconstruction, thermodynamic setup, source evaluation, projection, and complete-callback scheduling. `RHSSchedulingReference` preserves the pre-change behavior and `RHSSchedulingCandidate` selects study-only variants.

`prepareRHSSchedulingStudy` writes reusable scientific fixtures to the explicit folder supplied by the caller. `runRHSSchedulingBenchmarks`, `runFinalRHSScheduling`, and `runRHSSchedulingTrajectories` read those fixtures. Their result tables default to `fullfile(tempdir,"wave-vortex-model-studies","rhs-scheduling-study")`.

```matlab
fixtureDirectory = "/external/wvm-studies/rhs-scheduling/fixtures";
prepareRHSSchedulingStudy(fixtureDirectory)
runRHSSchedulingBenchmarks(fixtureDirectory)
runRHSSchedulingTrajectories(fixtureDirectory)
```

Regenerate fixtures after changing the scientific setup. Keep fixtures, profiles, tables, and logs outside the repository. The scheduling investigation is tracked on [issue #484](https://github.com/JeffreyEarly/wave-vortex-model/issues/484).
