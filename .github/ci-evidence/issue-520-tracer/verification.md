# Tracer derivatives: verification ledger

Runtime base: v4 `939eb5797053a6c5a3a019e411ef807aa1fb3a4d`. Worktree `wvm-v4-tracer-optimization`; branch `perf/520-tracer-derivatives`. The primary authoring checkout uses v5 and was untouched.

The combined candidate accelerates public operations used by real tracer volumes. Horizontal derivatives use independent axis-only real FFT pairs shared by compiled transform families. Variable-stratification Hydrostatic and Boussinesq vertical calculus applies prepared balanced F/G matrices directly to the original `[Nx Ny Nz]` volume. Tracer multiplication, final antialias projection, initial conditions and integration remain unchanged.

Frozen candidate commit: `e9cba05235ce1a2f7988f3d402d1a56537067faf`. Frozen compiled source aggregate: `91487ae2e6311d95e0d41aaa591247bba420c0a7ca943cee0e664c88873454e1`. Frozen MEX SHA-256: `a16e7d1cc83707d028f1665dbdd5cff9f411e0c99072d9e7334b3cbeb25796fa`.

## Implemented boundary

- `diffX` and `diffY` use the native provider's persistent axis-only real FFT plans and bounded workers. They operate on the complete real input spectrum and preserve antialias-disabled behavior.
- Real `[Nx Ny Nz]` inputs to `WVTransformHydrostatic` and `WVTransformBoussinesq` `diffZF`, `diffZG`, `intZF` and `intZG` use the direct-volume primitive. Complex volumes and matrices retain the generic compiled path. Constant-stratification and QG vertical paths are unchanged.
- Five prepared elementary matrices represent F first derivative, G first derivative, G second derivative, F integral and G integral. Orders 2–4 reuse the existing F/G compositions.
- Boussinesq preparation uses only the first four balanced F/G operators when each has one retained matrix. Wave-dependent operators remain on the established grouped path, and aliased internal reconstruction retains the established helper.
- The direct kernel evaluates the equivalent of `A*D.'` without MATLAB permutations. Its packed matrix path processes no more than `Nx*Ny` columns per chunk. Prepared real workspace is reused during warmed calls.

## Passed development gates

- Apple Clang Release: `WVPrunedHorizontal`, `WVSpectralOperators` (2026-09-13). Orders 1–4, nonsquare odd/even grids, full-spectrum modes, Nyquist, strides, immutable inputs, warmed zero allocations and stable prepared storage.
- Apple Clang Release: `WVNativeFFTWOwnership`, `matlab-raw-primitives`, Hydrostatic and Boussinesq kernel/runtime tests. Includes failure of either new y-plan acquisition, cleanup and successful retry, vertical chunk-tail execution, F/G orders 1–4, both integrals, stable storage and warmed zero allocations. The final native suite first passed 61 of 62 tests and exposed an aliased Boussinesq reconstruction; after the guard correction, all five affected tests passed and the 61 unaffected results were retained.
- MATLAB R2025b final focused run: `TestBoussinesqCompiledKernel/variableStratificationMatchesMatlab`, `TestHydrostaticCompiledKernel/variableStratificationMatchesMatlab`, `TestWVCompiledConsumers/sampledObserversShareCompiledStateScope`, `TestWVCompiledPublicAdapters/verticalCalculusPreservesMatlabLayouts` (4 passed, no failures or incomplete tests).
- Independent review passed after resolving extent arithmetic, active-resource cleanup, backend factory accounting, idempotent preparation, retry behavior and numerical-overflow status. Existing guru-plan failure wrappers cover the new acquisition path without a production test seam.
- The final MATLAB adapter check covers real Hydrostatic and Boussinesq F/G orders 1–4 and both integrals, plus complex-volume and matrix fallbacks.
- Exploratory composite output comparisons against the frozen audit compiled baseline passed existing tolerances. Redundant successful output payloads were removed after comparison; hashes, timings, profiles and comparison records remain.

## Exploratory results, not qualification

The earlier horizontal-only profile took 42.6575 s for integration and 12.4569 s in tracer flux, including 0.5182 s in `diffX`, 0.9247 s in `diffY` and 8.6276 s in `diffZF`. Its seven-sample `diffX` diagnostic had a 2.9375 ms compiled median and 3.4524 ms MATLAB median. The frozen audit profile took 60.8147 s for integration and 30.420 s in tracer flux.

The historical direct-volume profile took 32.3362 s for integration and 5.1794 s in tracer flux. Its tracer calls accumulated 0.5186 s in `diffX`, 0.9268 s in `diffY` and 1.4242 s in `diffZF`. The run used 15 accepted steps, zero rejected steps and 199 RHS evaluations. Its seven-sample primitive medians were 7.7548 ms compiled versus 10.3846 ms MATLAB for `diffZF`, and 3.5208 ms compiled versus 3.4713 ms MATLAB for `diffX`. This profile used source aggregate `48aad8e068fe2c950c98db6d7a52a8ed18e5b2ae2664c64f2e274a729e405748` and MEX SHA-256 `55c084de8dabb722fd73bba875100642c43136e61bebeb14c11a074cdff7c491`; it predates the final Boussinesq extension.

The historical direct-run output graph comparison passed across 70 variables and 64 records. Maximum relative error was `7.888164409073408e-13`, and maximum absolute error was `1.8189894035458565e-12`. These separately collected profiles remain diagnostic rather than idle-host paired qualification. Earlier samples remain retained as development history; frozen archives and published benchmark rows are unchanged.

## Hosted integration and release

The horizontal-only hosted campaign passed GCC Release before cancellation. It predates the variable-stratification vertical changes and is historical evidence only. Final combined hosted checks and patch publication are recorded on the associated PR and release. No runtime change is permitted without repeating the affected source-bound gates and qualification.

## Final source-bound checks

At runtime commit `e9cba05235ce1a2f7988f3d402d1a56537067faf`, all six representative forward-integration cases passed with both reference and native providers, including coefficients, tracer and particle evolution, restart and dense-output behavior. Both assembled forward receipts and their content-addressed fragments were refreshed; the committed receipt contract passed. Code Analyzer reported zero blocking findings (303 existing/nonblocking findings across 187 production MATLAB files). See `forward-refresh-tests.csv`, `forward-receipt-contract-tests.csv`, and `focused-matlab-final.csv`. These gates remain valid while their tested source inputs remain unchanged.

## Qualification decision

All twelve fresh-process runs passed with frozen runtime `e9cba052`, source aggregate `91487ae2...`, and MEX `a16e7d1c...`. Composite medians: 53.7568365833 → 32.0235805417 s (40.4288% less time). Coefficient medians: 12.4617622917 → 12.4567948333 s (0.0399% less time). Every sample and numerical comparison is in `qualification-summary.json`; none was excluded. Adopt for patch release v4.4.1. Documentation build and check passed with pinned ClassDocumentation 1.3.2: 2055 files, 4200 routes, zero validation failures and zero generated differences. Final combined hosted checks and release/export verification are recorded on the PR and release.

## Durable archive

The raw archive contains 163 files totaling 2,582,419,279 bytes; manifest SHA-256 `6ea247510c02531feae65f4ec263eaf0173f29f504f146b91979fbe5feb1b39c`. See `archive.json`. All timing samples and comparisons are retained. Successful repeat-two/three output payloads were hashed before removal; representative baseline/candidate outputs remain. Historical failed development checks and all intermediate profile observations are preserved.
