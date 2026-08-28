---
layout: default
title: Benchmarks
parent: Compiled execution
nav_order: 3
has_toc: true
description: Runtime and memory scaling for WaveVortexModel
permalink: /benchmarks
---

# Benchmarks

These frozen, machine-dependent measurements compare WaveVortexModel execution paths and show how ordinary MATLAB execution scales with resolution. MATLAB remains the default implementation; the compiled paths are optional source builds for supported configurations.

## MATLAB vs C++

The compact comparison uses `ode78 / RK8(7)`, the fastest integrator for every interface and workload in the accepted study. Runtime covers integration and required output delivery; peak memory is the largest sampled total process-tree RSS during that boundary. Startup, model construction, FFT planning, parsing, and cleanup are excluded.

<!-- BENCHMARKS:INTERFACE_SUMMARY:START -->
Published matched interface results will appear here.
<!-- BENCHMARKS:INTERFACE_SUMMARY:END -->

## MATLAB speed scaling

These plots show median `nonlinearFlux` evaluation time for MATLAB's builtin transforms. The representative plots use the nonhydrostatic constant-stratification transform; expandable tables retain every published transform family and environment.

<!-- BENCHMARKS:SPEED_SCALING:START -->
Published runtime scaling results will appear here.
<!-- BENCHMARKS:SPEED_SCALING:END -->

## MATLAB memory scaling

These plots show peak MATLAB process memory, including the language runtime and numerical libraries, for the same scaling cases.

<!-- BENCHMARKS:MEMORY_SCALING:START -->
Published memory scaling results will appear here.
<!-- BENCHMARKS:MEMORY_SCALING:END -->

## Integrator comparison

The detailed comparison holds the nonhydrostatic `[256 256 129]` model, numerical controls, hardware, thread policy, and three fresh-process repeats fixed. Runtime and memory winners are identified separately because the fastest interface need not use the least memory.

<!-- BENCHMARKS:INTEGRATOR_COMPARISON:START -->
Published integrator results will appear here.
<!-- BENCHMARKS:INTEGRATOR_COMPARISON:END -->

<details markdown="1">
<summary>Benchmark conditions, environments, and downloads</summary>

The v4.3 presentation is frozen to the accepted issue #312 Donut record `three-interface--m5-max--20260827T151230Z`; it is release evidence, not a benchmark to refresh during qualification. Comparisons require matching suite contracts, operations, domains, resolutions, numerical options, random seeds, warmup counts, and sample counts. Results from different environments reflect both hardware and toolchain differences.

Benchmark tools are authoring utilities and are not installed on the runtime package path. The [benchmark authoring guide](https://github.com/JeffreyEarly/wave-vortex-model/tree/main/Benchmarks) documents suite definitions, measurement boundaries, correctness gates, provenance, and publication. Missing coverage is reported as unavailable, never as zero or extrapolated performance.

**Test environments**

<!-- BENCHMARKS:COMPUTERS:START -->
Published computer details will appear here.
<!-- BENCHMARKS:COMPUTERS:END -->

<!-- BENCHMARKS:HISTORY:START -->
<!-- BENCHMARKS:HISTORY:END -->

**Downloadable results**

The compact published JSON records contain the measurements and correctness evidence used by this page. Raw worker outputs and RSS samples remain outside the source tree.

<!-- BENCHMARKS:DOWNLOADS:START -->
Published result downloads will appear here.
<!-- BENCHMARKS:DOWNLOADS:END -->

</details>
