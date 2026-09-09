# APE performance follow-up

## Scope and numerical choice

The owner requested reducing the corrected MATLAB APE cost after the first actual-profile implementation measured approximately 3.52 seconds on the 512×512×86 JAMES state. This follow-up keeps the default, solver, selected profile, inversion, APE definition and persistence contracts unchanged.

The requested manuscript path `literature/ape-apv-orthogonality-paper/main.tex` is absent. The corresponding manuscript is available at `literature/ape-apv-rigid-lid-orthogonality-paper/main.tex`. Its equations `total-energy-lorenz-pre`, `total-energy-hm` and `KE-APE-definition` establish the equivalent three-term pressure and derivative-integral forms. Its later integration-by-parts expression separates a quadratic term from a curvature integral; dropping that integral would change the nonlinear APE.

The implementation retains the derivative integral, per unit reference mass:

$$\mathrm{APE}(z,s) = \frac{g}{\rho_0}\int_s^z (r-z)\rho'_{\mathrm{nm}}(r)\,dr.$$

The existing local cubic polynomial evaluation and ascending summation order are preserved. Neither large hydrostatic pressures nor nearby global antiderivative values are subtracted, so tiny displacements and knot crossings retain their existing precision treatment.

## Implementation

The old implementation scanned and masked the entire spatial field once for every vertical interval, even when most parcels remained within one interval. A warmed day3250 profiler run took 3.619 seconds; three gather/scatter lines alone accounted for approximately 2.27 seconds. This identified repeated selection work as the main target.

The replacement processes at most 65,536 queries per block, locates their starting intervals once, and advances only the remaining parcels across their actual crossed knots. The local polynomial is unchanged. Arithmetic workspace is bounded by block size, while input validation and the required output still scale with field size. Full-column displacements retain the old worst-case interval count; ordinary short displacements avoid unrelated intervals.

## Verification ledger

- Read the shared MATLAB and profiling guides and the manuscript equations. Independent read-only review found no shape, endpoint, termination or summation-order defect in the replacement.
- Twenty-nine affected MATLAB methods pass: eighteen independent density/reference/calculus methods and eleven default/cache/output/restart methods. Existing ulp-scale, weak-gradient and knot-crossing checks pass without loosening tolerances.
- Added an analytic linear test with 69,649 queries spanning multiple blocks, mixed directions, zero displacements and full-column moves. Added an irregular, steep profile compared with independent numerical quadrature of MATLAB's density PCHIP derivative.
- Production primitive and changed test class have zero Code Analyzer findings. The first test invocation mistakenly concatenated char paths; it failed during selection before tests ran. The corrected string-array invocation selected exactly twenty-nine methods and passed.
- Captured-state paired benchmark and successor profiling records are kept separately from the earlier adoption evidence. Original receipts remain tied to their original source hashes.

## Paired captured-state results

Each path was warmed once, followed by three serial trials in alternating order, with no other MATLAB jobs running. Both kernels use the same already diagnosed profile and material heights. Kernel timing excludes profile construction. Operation timing includes profile construction and cached `rho_nm`/`eta_true`; the optimized path uses the real public `wvt.ape` dispatch, while the frozen original wrapper reproduces its expressions without that public dispatch overhead. Only the `ape` cache is cleared, outside the timer.

| State | Old kernel median | New kernel median | Old operation median | New operation median | Operation speedup |
|---|---:|---:|---:|---:|---:|
| day3000, 256×256×43 | 0.2677 s | 0.1013 s | 0.3035 s | 0.1077 s | 2.82× |
| day3250, 512×512×86 | 3.5715 s | 0.7457 s | 3.5781 s | 0.7555 s | 4.74× |

All full kernel arrays and operation arrays are bitwise identical between implementations. Zero masks are identical, no negative APE occurs, and captured-profile probes from ulp-sized displacements through full-column crossings are also bitwise identical. The benchmark verifies that its renamed frozen reference class differs from commit `7c26eca05561e1fda4e99f641080efc5f6a7a449` only in the class/constructor name and reference comments.

These measurements quantify the APE change on these two states, not a whole-model integration speedup. Larger displacements can cross more intervals and reduce the speedup. Historical solver/inverse/APV performance records were not rerun or relabeled.

Reproduce with `tools/density-diagnostics/benchmarkCapturedAPE.m` after configuring the v4 checkout and pinned dependencies. The full NetCDF inputs remain in `along-track-velocity-decomp/data/`; no large state files are committed. Source-bound paired reports and before/after hotspots are in `.github/ci-evidence/issue-391-ape-performance/`.

Final handoff: paired benchmark and all three authoring-file Code Analyzer checks pass. Regenerated the changelog-derived documentation once; documentation validation and comparison report 2,026 files, 4,145 routes and no differences. No package dependencies, persistence schema, C++ support status or v5 files changed. Reproduction of the frozen-reference check requires the local Git object for baseline commit `7c26eca05561e1fda4e99f641080efc5f6a7a449`. No missing asset prevented verification.
