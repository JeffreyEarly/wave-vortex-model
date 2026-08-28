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

The usual starting point is MATLAB at low resolution: it keeps the model easy to inspect while you build physical understanding and establish that the configuration behaves as intended. Once the science is clear, higher resolutions, different integrators, or compiled execution may be useful. This page summarizes measured runtime and memory tradeoffs to help decide when that added complexity is worthwhile.

## MATLAB vs C++

**Setup.** The benchmark evolves a nonhydrostatic, constant-stratification flow in a 150 km × 150 km × 1.3 km domain, initialized with GM(1) waves and a first-baroclinic red geostrophic spectrum, for 0.12 inertial periods. The numerics use a `256 × 256 × 129` grid and the adaptive `ode78 / RK8(7)` integrator. The model and integrator are fixed while the execution path and output workload vary.

**Conclusion.** Standalone C++ is fastest and uses the least memory for both workloads. MATLAB with the compiled core nearly matches its coefficients-only runtime, but the dense-output speedup is smaller and peak memory remains close to MATLAB builtin.

<!-- BENCHMARKS:INTERFACE_SUMMARY:START -->
Published matched interface results will appear here.
<!-- BENCHMARKS:INTERFACE_SUMMARY:END -->

## MATLAB speed scaling

**Setup.** These tests evaluate one state-advanced `nonlinearFlux` call using MATLAB's builtin transforms with anti-aliasing enabled. The representative plots use a constant-stratification, nonhydrostatic model in a 15 km × 15 km × 1.3 km domain. Horizontal sweeps vary `Nx = Ny`, holding `Nz = 65` in the standard suite and `Nz = 129` in the large suite; vertical sweeps vary `Nz`, holding `Nx = Ny` at 128 or 512. The model, transform, and operation are otherwise fixed.

**Conclusion.** Horizontal refinement is the stronger runtime constraint: at large resolutions, doubling both horizontal dimensions increases runtime by roughly fourfold, while doubling the vertical resolution increases it by about two to two-and-a-half times.

<!-- BENCHMARKS:SPEED_SCALING:START -->
Published runtime scaling results will appear here.
<!-- BENCHMARKS:SPEED_SCALING:END -->

## MATLAB memory scaling

**Setup.** These tests repeat the same model, operation, and horizontal and vertical resolution sweeps used above; only the reported metric changes to peak MATLAB process memory, including the language runtime and numerical libraries.

**Conclusion.** Horizontal refinement is also the stronger memory constraint: at large resolutions, doubling both horizontal dimensions increases peak memory by roughly three- to fourfold, while doubling the vertical resolution approximately doubles it.

<!-- BENCHMARKS:MEMORY_SCALING:START -->
Published memory scaling results will appear here.
<!-- BENCHMARKS:MEMORY_SCALING:END -->

## Integrator comparison

**Setup.** This comparison reuses the MATLAB-vs-C++ model, initial condition, 0.12 inertial-period duration, and `256 × 256 × 129` grid. Each table fixes the output workload, varies the integrator down the rows, and varies the execution path across the columns; the forcing and anti-aliasing remain fixed. Runtime and memory winners are identified independently within each execution-path column.

**Conclusion.** `ode78 / RK8(7)` is fastest for every execution path in both workloads, while fixed RK4 uses the least peak memory. In this experiment, `ode23 / RK3(2)` is substantially slower without using less memory than fixed RK4.

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
