# WaveVortexModel automated tests

`UnitTests` is the root for intentional automated tests using the MATLAB unit testing framework. Recursive test discovery in this folder should find only formal tests.

## Contents

- `Test*.m` contains `matlab.unittest.TestCase` classes.
- `EtaTrueOperationToolboxUnavailable.m` is a test double used to exercise the no-Optimization-Toolbox path.
- `IsSameSolutionAs.m` provides a custom test constraint.
- `private/` contains functions shared by formal tests without placing them on the public test path.
- `RunAllUnitTests.m` is a compatibility wrapper for the canonical full test task.

Interactive investigations, scratch scripts, plots, and historical comparisons belong in [DeveloperExperiments](../DeveloperExperiments/). Profiling and timing scripts belong in [Benchmarks](../Benchmarks/). Those authoring folders are not part of automated discovery or the runtime package path.

Do not place section-based scripts with test-like filenames in this folder because MATLAB may discover their sections as automated tests.

## Running tests

Run test categories from the repository root with MATLAB's build tool:

```matlab
buildtool test:smoke
buildtool test:full
buildtool test:exhaustive
buildtool test:optional
```

Running `buildtool` without a task runs the smoke category. `RunAllUnitTests` delegates to `buildtool test:full` and may be invoked from any working directory.

Every formal test method declares exactly one primary tag:

- `smoke` provides fast, representative development feedback. Smoke tests are also included in full execution.
- `full` contains the remaining deterministic tests that do not require optional dependencies or exhaustive parameter sweeps.
- `exhaustive` contains large numerical parameter matrices, including spectral differentiation combinations.
- `optional` requires a declared optional dependency. The current optional category exercises the supported Optimization Toolbox path; unavailable dependencies produce an incomplete, unsuccessful run.

Any failed or incomplete test makes its build task unsuccessful. Full and exhaustive discovery also check declared test metadata so a class or method cannot be silently omitted.
