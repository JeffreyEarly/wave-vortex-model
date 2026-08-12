# Issue 152 FFTW++ optimizer audit — CORE-REJECT

This standalone, four-thread Lyra audit uses upstream FFTW++ commit `e685733aba768d77e9234ca02092632f7ccb4c86`, which contains the maintainer's asymmetric two-loop repair. The direct 1-D/2-D reproducer passes all ten centered/Hermitian implicit and hybrid cases, including the WaveVortex 15->3 and 19->4 named-output arities, with maximum relative infinity error `9.995248e-16`.

The optimizer itself selected explicit-looking schedules (`p = q`) and the audit reconstructed those selected `m,D,I` values in a new engine before any timed calls. That reconstruction is numerically invalid for the named WaveVortex adapter: relative infinity error is `5.010080e-1` hydrostatically and `5.010247e-1` nonhydrostatically. The result fails before the performance gate.

| Medium 128x128x33, four threads | Native pthread explicit | Native OpenMP explicit | Forced FFTW++ hybrid | Optimizer-selected FFTW++ |
|---|---:|---:|---:|---:|
| Hydrostatic median complete nonlinearFlux | 0.016225 s | 0.016961 s | 0.027364 s | 0.023566 s (invalid) |
| Nonhydrostatic median complete nonlinearFlux | 0.021155 s | 0.021293 s | 0.033898 s | 0.021674 s (invalid) |
| Hydrostatic relative infinity error | 0 | 1.38e-14 | 2.44e-14 | 5.01e-1 |
| Nonhydrostatic relative infinity error | 0 | 1.73e-14 | 2.51e-14 | 5.01e-1 |

The hydrostatic optimizer selection is centered `(m,D,I,p,q) = (64,1,1,2,2)` and Hermitian `(128,1,1,1,1)`; the nonhydrostatic selection is `(64,1,1,2,2)` and `(64,2,0,2,2)`. Optimizer discovery costs 0.109 s / 0.019 s and fixed selected-plan construction costs 1.275 s / 1.190 s for hydrostatic/nonhydrostatic configurations, respectively; neither is included in measured execution samples.

All cases report non-overlapping FFT/OpenMP worker regions, at most four workers, active OpenMP level one, and balanced FFTW plan construction/destruction. Exact max-live storage for the invalid optimizer choice is 64,797,285 B hydrostatically and 72,803,365 B nonhydrostatically; RSS is larger than native pthread explicit in both cases.

No large, MATLAB, repeated-process finalist, or Donut run was performed because a correctness-valid candidate is required before those stages. The correct conclusion is **CORE-REJECT — OPTIMIZER AUDITED**: upstream fixed the asymmetric non-multiple scheduler defect, but its general optimizer selects a `p=q` schedule that is not correct for this named asymmetric MIMO adapter. FFTW++ remains LGPL-3.0-or-later; no source or binary is tracked, and any redistribution of a linked binary must preserve notices and permit relinking.
