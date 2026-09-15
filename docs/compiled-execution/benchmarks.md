---
layout: default
title: Benchmarks
parent: Compiled execution
nav_order: 3
has_toc: true
description: Reproduce WaveVortexModel runtime and memory measurements
permalink: /benchmarks
---

# Benchmarks

The benchmark tools compare MATLAB and compiled execution using explicit, reproducible workloads. Start with a small configuration and establish its scientific behavior before measuring larger resolutions or another execution path.

## Run a comparison

The [benchmark authoring guide](https://github.com/JeffreyEarly/wave-vortex-model/tree/main/Benchmarks) defines the suites, measurement boundaries, correctness checks, and output formats. Authoring tools are not installed on the runtime package path.

`runWaveVortexBenchmark` measures state-advanced `nonlinearFlux` calls. Its smoke suite exercises the transform families; core and scaling suites compare horizontal and vertical resolution. Scored runs require an explicitly supplied external reference catalog.

`runThreeInterfaceBenchmarkComparison` compares MATLAB builtin, MATLAB with the compiled core, and standalone C++ execution. Its workloads separate coefficient-only integration from observer and dense-output costs. Compare runtime and peak memory separately, using matching model, integrator, tolerances, output schedules, and provider identities.

## Keep outputs separate from source

Run results, profiling tables, logs, generated figures, and archived measurements are written outside this repository. The website documents how to reproduce measurements and does not embed recorded benchmark datasets. Record the exact source revisions, toolchain, hardware, configuration, and measurement boundaries with each external run.

Timing differences across machines or toolchains are not implementation speedups. Use matched workloads, warmup and repeated unprofiled trials for performance comparisons, with a separate profiling pass when locating bottlenecks. Missing implementation coverage is unavailable, never zero cost or extrapolated performance.
