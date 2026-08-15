---
layout: default
title: Benchmarks
nav_order: 8
description: Runtime and memory scaling for WaveVortexModel
permalink: /benchmarks
---

# Benchmarks

These benchmarks measure the cost of one state-advanced nonlinear-flux evaluation across WaveVortexModel transform families and grid sizes. They are intended to help you estimate runtime and memory requirements, compare computers, and reproduce the measurements on your own hardware.

## Performance at a glance

The representative comparison uses the nonhydrostatic constant-stratification case with resolution `[256 256 65]`. Absolute measurements are shown because benchmark scores can obscure the practical time and memory required by a model.

<!-- BENCHMARKS:AT_GLANCE:START -->
<table>
  <thead>
    <tr><th scope="col">Implementation and platform</th><th scope="col">Median runtime</th><th scope="col">Peak process memory</th><th scope="col">Memory above baseline</th><th scope="col">Threads</th></tr>
  </thead>
  <tbody>
    <tr><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4)</td><td>0.1167 s</td><td>1.86 GiB</td><td>1.25 GiB</td><td>18</td></tr>
    <tr><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4)</td><td>0.1082 s</td><td>1.82 GiB</td><td>1.24 GiB</td><td>16</td></tr>
    <tr><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4)</td><td>0.1926 s</td><td>1.85 GiB</td><td>1.25 GiB</td><td>10</td></tr>
  </tbody>
</table>
<!-- BENCHMARKS:AT_GLANCE:END -->

## Compiled constant-stratification preview

The source-only compiled preview is an explicit opt-in for ordinary constant-stratification nonlinear flux. MATLAB remains the default. Availability, speed, numerical error, exact retained application storage, and isolated operation memory are shown together because the preview intentionally prioritizes a substantial speed gain while its memory use remains a target for future refinement.

<!-- BENCHMARKS:COMPILED_PREVIEW:START -->
**PREVIEW-AVAILABLE.** Donut (Apple M5 Max); Apple Clang + FFTW 21.0.0; provider `native-fftw`. Memory ratios are descriptive and do not gate preview availability.

<table>
  <thead>
    <tr><th scope="col">Case</th><th scope="col">MATLAB (ms)</th><th scope="col">Compiled (ms)</th><th scope="col">Speedup</th><th scope="col">Exact retained ratio</th><th scope="col">Operation RSS ratio</th><th scope="col">Relative error</th></tr>
  </thead>
  <tbody>
    <tr><td>Constant hydrostatic 256×256×65</td><td>96.716</td><td>57.723</td><td>1.676x</td><td>1.922</td><td>0.160</td><td>8.855e-15</td></tr>
    <tr><td>Constant nonhydrostatic 256×256×65</td><td>113.332</td><td>66.681</td><td>1.700x</td><td>1.922</td><td>0.127</td><td>8.034e-15</td></tr>
    <tr><td>Constant hydrostatic 512×512×129</td><td>692.773</td><td>392.815</td><td>1.764x</td><td>1.916</td><td>0.013</td><td>2.298e-14</td></tr>
    <tr><td>Constant nonhydrostatic 512×512×129</td><td>868.107</td><td>526.656</td><td>1.648x</td><td>1.916</td><td>0.068</td><td>1.568e-14</td></tr>
  </tbody>
</table>

Supported: constant-stratification hydrostatic and nonhydrostatic models with the default nonlinear-advection forcing. Unavailable: variable stratification, QG transforms, additional forcing, and the explicit-antialias forcing workflow.
<!-- BENCHMARKS:COMPILED_PREVIEW:END -->

## Complete-workflow interface comparison

The matched comparison below separates a single nonlinear-flux evaluation from fixed-step and adaptive model continuations. Each row uses the same initial model, forcing, integration settings, observer graph, output schedule, provider, thread policy, and fresh-process boundary across MATLAB builtin, MATLAB compiled, and standalone compiled execution.

<!-- BENCHMARKS:THREE_INTERFACES:START -->
Matched on Apple M5 Max with `native-neon-pthreads` 3.3.11 at 18 threads. Ratios are relative to MATLAB builtin within each case; process wall includes interface launch, while integration time isolates the matched operation and output work.

<table>
  <thead>
    <tr><th scope="col">Case</th><th scope="col">Interface</th><th scope="col">Process wall</th><th scope="col">Integration only</th><th scope="col">Peak RSS</th><th scope="col">RSS above baseline</th><th scope="col">Integration ratio</th><th scope="col">Maximum error</th></tr>
  </thead>
  <tbody>
    <tr><td>nonlinear-flux</td><td>MATLAB builtin</td><td>4.593 s</td><td>0.07759 s</td><td>0.841 GiB</td><td>0.00517 GiB</td><td>1.000×</td><td>8.755e-13</td></tr>
    <tr><td>nonlinear-flux</td><td>MATLAB compiled</td><td>5.824 s</td><td>0.00531 s</td><td>0.847 GiB</td><td>0.00346 GiB</td><td>0.068×</td><td>8.755e-13</td></tr>
    <tr><td>nonlinear-flux</td><td>Standalone compiled</td><td>1.287 s</td><td>0.003978 s</td><td>0.0307 GiB</td><td>0.000549 GiB</td><td>0.051×</td><td>8.755e-13</td></tr>
    <tr><td>fixed-rk4-continuation</td><td>MATLAB builtin</td><td>5.546 s</td><td>0.9732 s</td><td>0.923 GiB</td><td>0.0262 GiB</td><td>1.000×</td><td>4.523e-16</td></tr>
    <tr><td>fixed-rk4-continuation</td><td>MATLAB compiled</td><td>7.105 s</td><td>0.7337 s</td><td>0.938 GiB</td><td>0.0261 GiB</td><td>0.754×</td><td>4.523e-16</td></tr>
    <tr><td>fixed-rk4-continuation</td><td>Standalone compiled</td><td>1.449 s</td><td>0.1471 s</td><td>0.0513 GiB</td><td>0.018 GiB</td><td>0.151×</td><td>4.523e-16</td></tr>
    <tr><td>adaptive-rk23-observer-output</td><td>MATLAB builtin</td><td>5.573 s</td><td>0.9774 s</td><td>0.926 GiB</td><td>0.0289 GiB</td><td>1.000×</td><td>5.057e-16</td></tr>
    <tr><td>adaptive-rk23-observer-output</td><td>MATLAB compiled</td><td>7.122 s</td><td>0.7411 s</td><td>0.94 GiB</td><td>0.026 GiB</td><td>0.758×</td><td>5.057e-16</td></tr>
    <tr><td>adaptive-rk23-observer-output</td><td>Standalone compiled</td><td>1.46 s</td><td>0.1492 s</td><td>0.0518 GiB</td><td>0.0187 GiB</td><td>0.153×</td><td>5.057e-16</td></tr>
  </tbody>
</table>
<!-- BENCHMARKS:THREE_INTERFACES:END -->

## Scaling with model size

The plots separate horizontal and vertical scaling for the representative nonhydrostatic constant-stratification transform. Limiting each chart to one transform keeps the machine and suite comparisons legible; the expandable tables retain results for every transform family. Each point is the median of the retained timing samples. Memory plots report the peak resident memory of the MATLAB or C++ process, including the language runtime and numerical libraries.

<!-- BENCHMARKS:SCALING:START -->
### Runtime versus horizontal resolution

![Runtime versus horizontal resolution — constant nonhydrostatic](/assets/benchmarks/runtime-horizontal.svg)

<details>
<summary>View all benchmark data</summary>

<table>
  <thead>
    <tr><th scope="col">Suite</th><th scope="col">Transform</th><th scope="col">Dataset</th><th scope="col">Resolution</th><th scope="col">Value</th><th scope="col">Status</th><th scope="col">Reason</th></tr>
  </thead>
  <tbody>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>2048</td><td>0.03453 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>2048</td><td>0.03972 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>2048</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>4096</td><td>0.124 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>4096</td><td>0.1439 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>4096</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>1024</td><td>2.854 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>0.1856 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>0.1763 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>0.816 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>0.6859 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>1024</td><td>3.435 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>0.2345 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>0.201 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>0.9271 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>0.7217 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>0.05811 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>0.0614 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>0.248 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>0.2291 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>0.4014 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>0.4398 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>1.54 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>1.597 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>0.1738 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>0.1775 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>0.7167 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>0.66 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>1024</td><td>0.009262 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>1024</td><td>0.01047 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>1024</td><td>0.01742 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.003954 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.006815 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.006729 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.003074 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.003979 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.005184 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>512</td><td>0.004114 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>512</td><td>0.004362 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>512</td><td>0.006939 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.02826 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.02966 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.05619 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.09103 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.0869 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1598 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.01337 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.01423 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.02684 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.03409 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.03576 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.0696 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1167 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1082 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1926 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.02724 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.02937 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.05307 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.009861 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.01117 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.02029 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.02719 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.02942 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.05191 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.005456 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.01227 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.01083 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.05228 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.05764 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.1045 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1817 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1912 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.3497 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.02505 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.03291 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.04632 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.02623 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.02721 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.05178 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.08155 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.08305 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.1511 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.01629 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.02567 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.02823 s</td><td>complete</td><td>—</td></tr>
  </tbody>
</table>

</details>

### Runtime versus vertical resolution

![Runtime versus vertical resolution — constant nonhydrostatic](/assets/benchmarks/runtime-vertical.svg)

<details>
<summary>View all benchmark data</summary>

<table>
  <thead>
    <tr><th scope="col">Suite</th><th scope="col">Transform</th><th scope="col">Dataset</th><th scope="col">Resolution</th><th scope="col">Value</th><th scope="col">Status</th><th scope="col">Reason</th></tr>
  </thead>
  <tbody>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>0.816 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>0.6859 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>1.801 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>1.43 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>0.9271 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>0.7217 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>2.179 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>1.728 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>0.248 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>0.2291 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>0.5596 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>0.4844 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>1.54 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>1.597 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>3.508 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>0.7167 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>0.66 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>1.642 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>1.356 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.0498 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>0.04905 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.08932 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.1009 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>0.08696 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.1628 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.01933 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.01874 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.0365 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.02826 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>0.02966 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.05619 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.06709 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>0.06571 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.1153 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.1235 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>0.1062 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.1914 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.02295 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.02228 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.04987 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.03409 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>0.03576 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.0696 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.01775 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>0.01803 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.03102 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.03073 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>0.02928 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.05096 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.006398 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.006322 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.01132 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.009861 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>0.01117 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.02029 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.1068 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>0.1163 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.2006 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.2396 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>0.2426 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.4833 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.02798 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.03268 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.05663 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.05228 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>0.05764 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.1045 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.04556 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>0.04562 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>0.08205 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.0917 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>0.08277 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>0.1551 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.01616 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.01546 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.03153 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.02623 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>0.02721 s</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.05178 s</td><td>complete</td><td>—</td></tr>
  </tbody>
</table>

</details>

### Peak process memory versus horizontal resolution

![Peak process memory versus horizontal resolution — constant nonhydrostatic](/assets/benchmarks/memory-horizontal.svg)

<details>
<summary>View all benchmark data</summary>

<table>
  <thead>
    <tr><th scope="col">Suite</th><th scope="col">Transform</th><th scope="col">Dataset</th><th scope="col">Resolution</th><th scope="col">Value</th><th scope="col">Status</th><th scope="col">Reason</th></tr>
  </thead>
  <tbody>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>2048</td><td>1.57 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>2048</td><td>1.55 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>2048</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>4096</td><td>4.11 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>4096</td><td>3.96 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>4096</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>1024</td><td>32.8 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>2.8 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>2.75 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>8.79 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>8.74 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>1024</td><td>34.6 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>1024</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>2.9 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>2.86 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>8.43 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>9.17 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>1.79 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>1.75 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>4.77 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>4.73 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>3.86 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>3.75 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>10.6 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>12.3 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>2.76 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>256</td><td>2.71 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>256</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>8.52 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>512</td><td>8.46 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>512</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>1024</td><td>0.952 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>1024</td><td>0.911 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>1024</td><td>0.949 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.756 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.706 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.764 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.755 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>0.708 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>0.756 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>512</td><td>0.8 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>512</td><td>0.754 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Barotropic QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>512</td><td>0.801 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.04 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>1.02 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.04 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.81 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>1.75 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.77 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.853 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.802 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.85 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.06 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>1.01 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.05 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.86 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>1.82 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.85 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.856 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.809 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.854 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.913 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>0.871 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>0.906 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.29 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>1.25 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.27 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.819 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.769 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.81 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.17 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>1.12 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.16 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>2.1 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>2.04 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>2.08 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.923 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.873 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.933 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.07 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>128</td><td>1.03 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>128</td><td>1.06 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.77 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>256</td><td>1.75 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>256</td><td>1.76 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.886 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>64</td><td>0.83 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>64</td><td>0.884 GiB</td><td>complete</td><td>—</td></tr>
  </tbody>
</table>

</details>

### Peak process memory versus vertical resolution

![Peak process memory versus vertical resolution — constant nonhydrostatic](/assets/benchmarks/memory-vertical.svg)

<details>
<summary>View all benchmark data</summary>

<table>
  <thead>
    <tr><th scope="col">Suite</th><th scope="col">Transform</th><th scope="col">Dataset</th><th scope="col">Resolution</th><th scope="col">Value</th><th scope="col">Status</th><th scope="col">Reason</th></tr>
  </thead>
  <tbody>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>8.79 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>8.74 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>14.9 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>16.7 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>8.43 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>9.17 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>16.9 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>17.6 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>4.77 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>4.73 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>8.73 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>8.68 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>10.6 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>12.3 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>30.7 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>8.52 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>129</td><td>8.46 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>129</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>14 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1</td><td>257</td><td>16.2 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-large-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1</td><td>257</td><td>Unavailable</td><td>unavailable</td><td>No scaling-large-v1 dataset was collected for this environment.</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.31 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>1.26 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.31 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.81 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>1.76 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.77 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.927 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.88 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.92 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.04 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>1.02 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.04 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.33 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>1.28 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.34 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.86 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>1.82 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.87 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.929 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.895 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.923 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.06 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>1.01 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Constant nonhydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.05 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.05 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>0.996 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.04 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.32 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>1.27 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.31 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.849 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.806 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.844 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.913 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>0.871 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Stratified QG</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>0.906 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.63 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>1.59 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.6 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>2.87 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>2.82 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>2.89 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.987 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.952 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.995 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.17 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>1.12 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable Boussinesq</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.16 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.33 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>129</td><td>1.27 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>129</td><td>1.31 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.83 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>257</td><td>1.78 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>257</td><td>1.82 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.947 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>33</td><td>0.907 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>33</td><td>0.938 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.07 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1</td><td>65</td><td>1.03 GiB</td><td>complete</td><td>—</td></tr>
    <tr><td>scaling-standard-v1</td><td>Variable hydrostatic</td><td>Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1</td><td>65</td><td>1.06 GiB</td><td>complete</td><td>—</td></tr>
  </tbody>
</table>

</details>
<!-- BENCHMARKS:SCALING:END -->

## Compare computers

Processor, memory, operating-system, toolchain, and thread information accompany every published dataset. Results from different environments remain machine-dependent measurements rather than universal performance guarantees.

<!-- BENCHMARKS:COMPUTERS:START -->
<table>
  <thead>
    <tr><th scope="col">Implementation</th><th scope="col">Platform</th><th scope="col">Processor</th><th scope="col">Physical memory</th><th scope="col">OS / architecture</th><th scope="col">Toolchain</th><th scope="col">Threads</th></tr>
  </thead>
  <tbody>
    <tr><td>WaveVortexModel MATLAB unreleased-preview (builtin)</td><td>Donut (Apple M5 Max)</td><td>Apple M5 Max</td><td>48 GiB</td><td>Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:28:34 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6050 arm64 / maca64</td><td>MATLAB 26.1.0.3312084 (R2026a) Update 4</td><td>18</td></tr>
    <tr><td>WaveVortexModel compiled preview unreleased-preview (native-fftw)</td><td>Donut (Apple M5 Max)</td><td>Apple M5 Max</td><td>48 GiB</td><td>Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:28:34 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6050 arm64 / maca64</td><td>Apple Clang + FFTW 21.0.0</td><td>18</td></tr>
    <tr><td>WaveVortexModel MATLAB 4.2.1 (builtin)</td><td>Lyra (Apple M4 Max)</td><td>Apple M4 Max</td><td>128 GiB</td><td>Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:28:34 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6041 arm64 / maca64</td><td>MATLAB 25.2.0.3150157 (R2025b) Update 4</td><td>16</td></tr>
    <tr><td>WaveVortexModel MATLAB 4.2.1 (builtin)</td><td>Matilda (Apple M1 Max)</td><td>Apple M1 Max</td><td>64 GiB</td><td>Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:18:58 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6000 arm64 / maca64</td><td>MATLAB 26.1.0.3312084 (R2026a) Update 4</td><td>10</td></tr>
  </tbody>
</table>
<!-- BENCHMARKS:COMPUTERS:END -->

<!-- BENCHMARKS:HISTORY:START -->
<!-- BENCHMARKS:HISTORY:END -->

## Run the benchmark yourself

Benchmark tools are authoring utilities and are not installed on the runtime package path. From a clean WaveVortexModel authoring checkout, run:

```matlab
addpath("Benchmarks")
results = runWaveVortexBenchmark(suites="scaling-standard-v1")
```

The larger `scaling-large-v1` suite can require substantially more memory. The [benchmark authoring guide](https://github.com/JeffreyEarly/wave-vortex-model/tree/main/Benchmarks) explains suite selection, reference generation, raw artifacts, and normalization for publication.

## Methodology and interpretation

The measured operation advances the coefficient state and evaluates `nonlinearFlux` with ordinary production caches retained. It is not a complete model time step. Published cases must pass their numerical correctness tolerance before their timing can be shown.

Runtime is the median of the recorded post-warmup samples. **Peak process memory** is the largest observed resident-memory value for the process. **Memory above baseline** subtracts the fresh-process value measured before constructing the model; it is the better estimate of the additional memory associated with WaveVortexModel, while still including allocator and library behavior.

Only datasets approved in the benchmark catalog are published. Comparisons require the same suite contract, operation, case, domain, resolution, numerical options, random seed, warmup count, and sample count. MATLAB release and update are recorded as part of the toolchain: when two machines use different MATLAB releases, their measurements reflect both hardware and MATLAB implementation differences rather than isolating hardware alone. Missing implementation or suite coverage is reported as unavailable and never as zero runtime or memory.

## Downloadable results

The normalized files use the language-neutral `published-benchmark-v1` contract. The corresponding raw artifacts retain implementation-specific diagnostics and provenance.

<!-- BENCHMARKS:DOWNLOADS:START -->
<table>
  <thead>
    <tr><th scope="col">Dataset</th><th scope="col">Implementation</th><th scope="col">Platform</th><th scope="col">Suite</th><th scope="col">Collected</th><th scope="col">Normalized</th><th scope="col">Raw artifact</th></tr>
  </thead>
  <tbody>
    <tr><td>core-v1--cpp-native-fftw--m5-max--20260812T195257Z</td><td>WaveVortexModel compiled preview unreleased-preview</td><td>Donut (Apple M5 Max)</td><td>core-v1</td><td>2026-08-12T19:52:57Z</td><td><a href="/benchmarks/data/core-v1--cpp-native-fftw--m5-max--20260812T195257Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/core-v1--cpp-native-fftw--m5-max--20260812T195257Z.json">Raw JSON</a></td></tr>
    <tr><td>core-v1--matlab-builtin--m5-max--20260812T195257Z</td><td>WaveVortexModel MATLAB unreleased-preview</td><td>Donut (Apple M5 Max)</td><td>core-v1</td><td>2026-08-12T19:52:57Z</td><td><a href="/benchmarks/data/core-v1--matlab-builtin--m5-max--20260812T195257Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/core-v1--matlab-builtin--m5-max--20260812T195257Z.json">Raw JSON</a></td></tr>
    <tr><td>scaling-large-v1--matlab-builtin--lyra--20260811T213524Z</td><td>WaveVortexModel MATLAB 4.2.1</td><td>Lyra (Apple M4 Max)</td><td>scaling-large-v1</td><td>2026-08-11T21:35:24Z</td><td><a href="/benchmarks/data/scaling-large-v1--matlab-builtin--lyra--20260811T213524Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/scaling-large-v1--matlab-builtin--lyra--20260811T213524Z.json">Raw JSON</a></td></tr>
    <tr><td>scaling-large-v1--matlab-builtin--m5-max--20260812T023122Z</td><td>WaveVortexModel MATLAB 4.2.1</td><td>Donut (Apple M5 Max)</td><td>scaling-large-v1</td><td>2026-08-12T02:31:22Z</td><td><a href="/benchmarks/data/scaling-large-v1--matlab-builtin--m5-max--20260812T023122Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/scaling-large-v1--matlab-builtin--m5-max--20260812T023122Z.json">Raw JSON</a></td></tr>
    <tr><td>scaling-standard-v1--matlab-builtin--lyra--20260811T204835Z</td><td>WaveVortexModel MATLAB 4.2.1</td><td>Lyra (Apple M4 Max)</td><td>scaling-standard-v1</td><td>2026-08-11T20:48:35Z</td><td><a href="/benchmarks/data/scaling-standard-v1--matlab-builtin--lyra--20260811T204835Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/scaling-standard-v1--matlab-builtin--lyra--20260811T204835Z.json">Raw JSON</a></td></tr>
    <tr><td>scaling-standard-v1--matlab-builtin--m5-max--20260812T020708Z</td><td>WaveVortexModel MATLAB 4.2.1</td><td>Donut (Apple M5 Max)</td><td>scaling-standard-v1</td><td>2026-08-12T02:07:08Z</td><td><a href="/benchmarks/data/scaling-standard-v1--matlab-builtin--m5-max--20260812T020708Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/scaling-standard-v1--matlab-builtin--m5-max--20260812T020708Z.json">Raw JSON</a></td></tr>
    <tr><td>scaling-standard-v1--matlab-builtin--matilda--20260811T205115Z</td><td>WaveVortexModel MATLAB 4.2.1</td><td>Matilda (Apple M1 Max)</td><td>scaling-standard-v1</td><td>2026-08-11T20:51:15Z</td><td><a href="/benchmarks/data/scaling-standard-v1--matlab-builtin--matilda--20260811T205115Z.json">Published JSON</a></td><td><a href="/benchmarks/raw/scaling-standard-v1--matlab-builtin--matilda--20260811T205115Z.json">Raw JSON</a></td></tr>
  </tbody>
</table>
<!-- BENCHMARKS:DOWNLOADS:END -->
