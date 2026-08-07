# Benchmarks

This folder contains manual profiling and timing scripts for package authors. It is not an automated-test root and is not included on the WaveVortexModel runtime package path.

Benchmark results depend on the MATLAB release, available toolboxes and backends, hardware, grid configuration, and runtime state. Treat the scripts as performance investigations rather than correctness or release gates, and inspect their computational cost before running them.

Deterministic correctness checks belong in `UnitTests`; mixed scientific investigations and historical scripts belong in `DeveloperExperiments`.
