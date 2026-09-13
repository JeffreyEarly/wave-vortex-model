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

**Setup.** The primary release campaign uses RK78 for a 150 km × 150 km × 1.3 km domain, initialized with GM(1) waves and a first-baroclinic red geostrophic spectrum, for 7168 s. It uses a `256 × 256 × 129` grid. Select constant nonhydrostatic, Hydrostatic exponential, or Boussinesq exponential to view the corresponding measured model configuration; an unavailable panel means that model has not been measured in the selected campaign.

**Conclusion.** Read the winner labels and ratios within the selected release campaign. They describe the recorded source and environment for that campaign.

<!-- BENCHMARKS:INTERFACE_SUMMARY:START -->
Published matched interface results will appear here.
<!-- BENCHMARKS:INTERFACE_SUMMARY:END -->

## MATLAB speed scaling

**Setup.** These historical tests evaluate one state-advanced `nonlinearFlux` call using MATLAB's builtin transforms with anti-aliasing enabled. The representative plots use a constant-stratification, nonhydrostatic model in a 15 km × 15 km × 1.3 km domain. Horizontal sweeps vary `Nx = Ny`, holding `Nz = 65` in the standard suite and `Nz = 129` in the large suite; vertical sweeps vary `Nz`, holding `Nx = Ny` at 128 or 512. The model, transform, and operation are otherwise fixed. Each expanded table identifies the recorded WaveVortexModel version, MATLAB release, platform, and suite.

**Conclusion.** Within these MATLAB builtin records, horizontal refinement is the stronger runtime constraint: at large resolutions, doubling both horizontal dimensions increases runtime by roughly fourfold, while doubling the vertical resolution increases it by about two to two-and-a-half times. The scaling plots do not measure the current compiled C++ runtime.

<!-- BENCHMARKS:SPEED_SCALING:START -->
Published runtime scaling results will appear here.
<!-- BENCHMARKS:SPEED_SCALING:END -->

## MATLAB memory scaling

**Setup.** These historical tests repeat the same model, operation, and horizontal and vertical resolution sweeps used above; only the reported metric changes to peak MATLAB process memory, including the language runtime and numerical libraries. The separate [MATLAB builtin transform storage benchmark](/developers-guide/transform-storage-benchmark.html) inventories known application-owned arrays without treating them as total process memory.

**Conclusion.** Within these MATLAB builtin records, horizontal refinement is also the stronger memory constraint: at large resolutions, doubling both horizontal dimensions increases peak memory by roughly three- to fourfold, while doubling the vertical resolution approximately doubles it. Exact storage ledgers and process RSS answer different questions and must not be combined into a synthetic memory estimate.

<!-- BENCHMARKS:MEMORY_SCALING:START -->
Published memory scaling results will appear here.
<!-- BENCHMARKS:MEMORY_SCALING:END -->

## Integrator comparison

**Setup.** This historical comparison reuses the nonhydrostatic MATLAB-vs-C++ model, initial condition, 0.12 inertial-period duration, and `256 × 256 × 129` grid. Each table fixes the output workload, varies the integrator down the rows, and varies the execution path across the columns; the forcing and anti-aliasing remain fixed. Runtime and memory winners are identified independently within each execution-path column.

**Conclusion.** The highlighted cells identify the fastest runtime and lowest peak memory within each execution-path column of each workload table. These record-specific rankings compare integrators under one matched contract and should not be extrapolated to later source revisions or different workloads.

<!-- BENCHMARKS:INTEGRATOR_COMPARISON:START -->
Published integrator results will appear here.
<!-- BENCHMARKS:INTEGRATOR_COMPARISON:END -->

<details markdown="1">
<summary>Benchmark conditions, environments, and downloads</summary>

The generated interface summary identifies the selected compatible record and its source, platform, provider, and sample count. Comparisons require matching suite contracts, operations, domains, resolutions, numerical options, random seeds, warmup counts, and sample counts. Results from different environments reflect both hardware and toolchain differences.

The normalized public downloads below remain available. The original M5 raw archives for August 27–28 were unavailable in the local artifact repository during the September 12 audit; their recorded hashes and expected paths are preserved in the [benchmark audit](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/.github/planning/benchmark-website-audit-20260912.md).

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
