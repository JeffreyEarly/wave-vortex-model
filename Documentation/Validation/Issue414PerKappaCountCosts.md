# Per-wavenumber retained-count construction trial

The rectangular representation supports unequal physical wave-mode prefixes without a new storage hierarchy. This bounded trial checks the resulting construction and reconstruction costs; it does not establish a general speedup or a final-grid capacity limit.

Run `runPerKappaWaveCountBenchmark` from `Benchmarks/` after configuring WVM and its dependencies. The [raw measurements](issue-414-count-costs.csv) were generated on 2026-09-09 using MATLAB R2025b Update 4 (`25.2.0.3150157`, `MACA64`) and the coordinated WVM #414/InternalModes #10 authoring changes, before provider release. The source branches were based on WVM `fc4a39ea` and InternalModes `9ff1b678`. No additional convergence-reference solve was requested.

The domain is 100 km × 100 km × 1000 m, with 65 WKB-Chebyshev samples, `N2(z)=1e-4*exp(2*z/700)`, `nEVP=64`, and the factory defaults for independent APV, MDA and inertial families. Both cases have a maximum wave count of four. Uniform counts retain four at every positive κ; varying counts cycle through `[0,2,4,1]` over sorted distinct κ pages. These are deliberately different retained workloads. Their timing comparison is not a before/after implementation regression test.

Each grid has one warm-up construction/reconstruction per policy, followed by three measured repetitions with alternating policy order. Reconstruction returns real `u`, `v`, `w`, `eta` and `ssh` fields from deterministic active wave amplitudes and an independent inertial amplitude. The table reports medians.

| Horizontal grid | Counts | Positive κ solves | Active wave page columns | Construction (s) | Reconstruction (ms) | Stored wave bytes | Active-only lower bound (bytes) |
|---|---|---:|---:|---:|---:|---:|---:|
| 16² | Uniform | 14 | 56 | 0.437 | 6.705 | 93,888 | 93,888 |
| 16² | Varying | 10 | 23 | 0.487 | 7.858 | 93,888 | 38,424 |
| 32² | Uniform | 48 | 192 | 0.611 | 12.350 | 325,376 | 325,376 |
| 32² | Varying | 36 | 84 | 0.521 | 8.592 | 325,376 | 142,496 |

Zero-count pages skip positive-wavenumber solves; all cases still construct the separate inertial basis once. Remaining positive pages use exact requested prefixes. The full generalized eigensolve at a retained page still depends on `nEVP`, so reducing the requested column count does not proportionally reduce its eigensolve cost.

Stored bytes cover `waveF`, `waveG`, `waveGForward`, `waveEquivalentDepth`, `waveFrequency`, `Aw_p` and `Aw_m`; shared geometry and other coefficient families are excluded. With the same maximum count and page layout, rectangular storage is unchanged. The active-only number counts the entries a hypothetical packed implementation would need, without its indexing overhead; no packed implementation is included or claimed.

The 32² case reduced measured construction and reconstruction times, while the 16² medians increased. These millisecond-scale, three-repetition measurements do not justify a speed guarantee. They do show bounded storage and execution for the tested representation, with explicit visibility into padding. Larger production grids should be measured separately before choosing a more complicated storage layout.

Scientific checks are separate from this cost trial: `TestFreeSurfaceVariableWaveCounts` checks exact prefixes, masked reconstruction/projection, conservation, forced evolution, absent waves and count-map validation. `TestPerKappaWaveAssessment` checks actual constructed-basis identities, explicit reference solves, separate sampled-grid and convergence evidence, unchanged operators, and unverified convergence when no reference is requested.
