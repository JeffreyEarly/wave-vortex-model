# Displacement performance follow-up

## Scope

Following the APE speedup, the owner requested investigating block processing and removal of converged parcels from the density inverse's work list. The inverse remains the same safeguarded Newton/bisection calculation for the same monotone cubic profile. Density bounds, roundoff allowance, height tolerance, exact-root stopping rule and 64-iteration limit remain unchanged.

The earlier warmed inspection of the 512×512×86 snapshot measured 1.044 seconds for inversion alone. Its coefficient expansion held four doubles for each of 22,544,384 queries (688 MiB), alongside other field-sized temporary arrays. Residual, derivative, bracket and candidate calculations continued for converged parcels even though their final height was frozen.

## Implementation and rejected candidate

The selected implementation processes at most 1,048,576 parcels per block and retains the original contiguous arithmetic and active-height mask within each block. The block coefficient matrix is at most 32 MiB rather than 688 MiB on the large captured state. Input validation and the required output still scale with field size. This is an arithmetic-workspace bound, not a measured whole-process memory reduction. Each parcel follows the same arithmetic and safeguard decisions; converged heights stay frozen. Failure after the sixty-fourth iteration still throws, and no partial output escapes if a later block fails.

An initial candidate compacted remaining coefficients, targets, brackets, heights and original indices after each iteration in blocks of 65,536. Its results were bitwise identical, but three paired trials measured slower public displacement operations on both states: day3000 0.139300→0.192345 seconds and day3250 0.912998→1.24864 seconds. Array selection and copying outweighed the saved arithmetic. That candidate was rejected; its source, reports and explicit rejection assessment are preserved in the `candidate-compacted` evidence subdirectory.

Exploratory chunk-only screening on day3250 favored larger blocks. Three-trial medians were 0.946 seconds at 262,144, 0.725 seconds at 1,048,576 and 0.721 seconds at 4,194,304 parcels. All arrays matched the original bitwise. The selected block size bounds workspace with essentially the same observed throughput as the largest size. These screening times are tuning evidence; the paired acceptance measurements are reported separately.

## Verification ledger

- Read the applicable shared MATLAB and profiling guides. The first candidate passed 31 affected methods and an independent read-only review, establishing numerical parity but not acceptable performance.
- Added an analytic nonlinear inverse test, enlarged for the selected block size to 1,081,665 queries spanning the block boundary and final tail. It includes exact knots, a zero-slope endpoint and near-endpoint queries. Known material heights and independent density closure are the primary oracles; scalar/grouping agreement is supplemental. A separate test covers irregular-profile row queries and several empty array shapes.
- The frozen `APEReference7c26` class is reused for inverse comparisons. Its inverse method is byte-identical to the pre-optimization method in commit `414eae4b`; no additional reference class or runtime dependency is introduced.
- Paired captured-state performance evidence is separate from the previous density/adoption and APE receipts, which retain their original source hashes. No optional full suite or long model integration is part of this follow-up.

## Paired captured-state results

Both paths were warmed once, then timed in three serial trials with alternating order and no concurrent MATLAB workloads. Kernel timing uses fixed profiles and density. Operation timing includes profile construction with cached `rho_nm` and `rho_total`; only `eta_true` is cleared outside the timer. The current operation uses public `wvt.eta_true`, while the frozen reference reproduces the old expressions without public variable-dispatch overhead. The harness retains both implementations' outputs for correctness comparisons, so its memory footprint exceeds a single isolated call.

| State | Old kernel median | New kernel median | Old operation median | New operation median | Operation ratio |
|---|---:|---:|---:|---:|---:|
| day3000, 256×256×43 | 0.1404 s | 0.1322 s | 0.1421 s | 0.1220 s | 1.164× |
| day3250, 512×512×86 | 1.0173 s | 0.8952 s | 1.0448 s | 1.0318 s | 1.013× |

The smaller-state operation takes about 14% less time. The large-state operation is effectively unchanged within trial variation; this is not a robust end-to-end speedup claim. The measured large-state inverse kernel improves by about 12%, and the expanded coefficient workspace has a substantially lower fixed bound. Full material-height, displacement and downstream APE arrays remain bitwise identical; captured density closure is exact at stored precision. No whole-model timing or peak process memory claim is made.

One final exploratory variant compacted active arrays just once after iteration 3 or 5 if fewer than one-quarter of parcels remained. It did not establish a substantial benefit: the 1M-block screening medians were 0.836 seconds without compaction, 0.839 seconds at iteration 3 and 0.818 seconds at iteration 5. At 4M the corresponding medians were 0.814, 0.810 and 0.789 seconds. All results were bitwise identical. This extra machinery was not adopted; the simpler 1M-block implementation retains the best workspace bound among these final candidates.

Reproduce the paired results with `tools/density-diagnostics/benchmarkCapturedDisplacement.m` after configuring the v4 checkout and its pinned dependencies. Source-bound reports and the rejected first candidate are in `.github/ci-evidence/issue-391-displacement-performance/`. The two NetCDF inputs remain in `along-track-velocity-decomp/data/`; no large state files are committed. Reproducing the frozen-reference check requires Git objects for commits `7c26eca05561e1fda4e99f641080efc5f6a7a449` and `414eae4b527454024b09eb02f852fc986891fdbb`.

Final selected implementation: all 31 affected MATLAB test methods pass, with zero failed or incomplete methods. Production primitive, test class and benchmark driver each have zero Code Analyzer findings. Independent review found no arithmetic, bounds, shape, convergence or failure-semantics defects. Existing tolerances were not loosened.

Final handoff checks: regenerated the changelog-derived documentation once, then validated 2,026 files and 4,145 routes with zero failures or comparison differences. JSON evidence, source/artifact hashes, staged whitespace and repository scope checks pass. Only the generated version-history page changes. Package manifest/dependencies, persistence schema, C++ support status and v5 files are untouched. No missing local asset prevented verification.
