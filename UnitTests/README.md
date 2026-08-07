# WaveVortexModel automated tests

`UnitTests` is the root for intentional automated tests using the MATLAB unit testing framework. Recursive test discovery in this folder should find only formal tests.

## Contents

- `Test*.m` contains `matlab.unittest.TestCase` classes.
- `EtaTrueOperationToolboxUnavailable.m` is a test double used to exercise the no-Optimization-Toolbox path.
- `IsSameSolutionAs.m` provides a custom test constraint.
- `private/` contains functions shared by formal tests without placing them on the public test path.
- `RunAllUnitTests.m` is the existing compatibility runner. Canonical test categories and entry points will be added separately.

Interactive investigations, scratch scripts, plots, and historical comparisons belong in [DeveloperExperiments](../DeveloperExperiments/). Profiling and timing scripts belong in [Benchmarks](../Benchmarks/). Those authoring folders are not part of automated discovery or the runtime package path.

Do not place section-based scripts with test-like filenames in this folder because MATLAB may discover their sections as automated tests.
