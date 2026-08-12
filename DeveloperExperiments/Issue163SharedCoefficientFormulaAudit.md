# Issue #163 shared coefficient-formula preparation

This authoring-only note records the issue #163 formula audit rooted at exact commit `8d0b49236c703dfa7230a8875022fdb3e30283b0`. It is preparation evidence for #171, not a canonical engineering benchmark and not a public API or package contract.

## Formula inventory and disposition

| Formula family | Mathematically shared expression | Specialized production structure retained |
|---|---|---|
| Phase evolution | `Ap*exp(i*omega*dt)`, `Am*exp(-i*omega*dt)`, invariant `A0`, and the inverse mapping to reference time | The phase-once `H` reservation and nonlinear-flux phase evaluation schedule |
| WV coefficients to fields | The scalar `U`, `V`, `W`, and `N` combinations of evolved `Ap`, `Am`, and `A0` | Four-field general reconstruction versus three-velocity streamed reconstruction; channel layout, normalization placement, and FFT execution schedule |
| Field derivatives | The scalar `(value,ik*value,il*value,+/-m*value)` expressions and DCT/DST endpoint normalization | F/G transform plans, cosine/sine family execution, general evolved-coefficient source versus streamed state-and-phase source |
| Half-spectrum mapping | Direct values versus conjugated values, including the corresponding horizontal-wavenumber signs | Canonical WV ordering, storage rows, Hermitian-boundary completion, and no persistent full Hermitian spectrum |
| Field to WV coefficients | Horizontal vorticity, geostrophic coefficient, buoyancy projection, symmetric/antisymmetric wave pair, and reference-time phase mapping | Hydrostatic divergence projection versus nonhydrostatic horizontal/vertical projection; target-specific accumulation into `Fp`, `Fm`, and `F0` |
| Inertial modes | `Ap=(U-iV)*scale`, `Am=conj(Ap)`, plus single-target `U` and `V` contributions | Zero-horizontal-mode ownership and target scheduling |
| Geostrophic and mean-density modes | The same `A0FromVorticity`, `A0FromBuoyancy`, and `NA0Field` scalar relations | Descriptor-owned mode classification and compact `[Nj,Nkl]` storage |

The shared expressions live in `CompiledKernel/src/WVCoefficientFormulas.hpp` as internal `inline` or template helpers. Runtime choices for target, hydrostatic state, F/G family, direct/conjugated storage, phase source, and inertial mode are resolved before the vertical-mode inner loops. The general and streamed kernels intentionally keep separate loop layouts and ownership schedules.

## Preserved contracts

- kernel contract version 4
- canonical column-major `[Nj,Nkl]` coefficient shape
- 17 FFT plans
- 4H half-spectrum scratch and 6R real scratch
- two joined coefficient workers
- `streamed-target-three-channel` nonlinear-flux schedule
- unchanged public interfaces and native-provider behavior
- zero persistent full-Hermitian-spectrum bytes

## Verification

- Portable C++ contract tests include independent `std::complex<double>` reference formulas across hydrostatic and nonhydrostatic descriptors, odd/even nonsquare grids, direct/conjugated half storage, zero and vertical-end modes, F/G derivative families, geostrophic and mean-density projections, phase evolution, and inertial targets.
- Focused MATLAB/MEX tests compare isolated wave, geostrophic, mean-density, and inertial states with the MATLAB transform at tolerance `1e-12`; they also cover even nonsquare grids in both orientations, direct/conjugated modes, F/G derivatives, zero/Nyquist inputs, contract metadata, and MEX lifecycle cleanup. Odd nonsquare formula coverage is provided by the portable contract tests because the current MATLAB geometry constructor's Nyquist-mask path requires even horizontal dimensions.
- The existing phase-once nonlinear-flux and injected-failure lifecycle tests remain green. The exact-base `fusedTransformsMatchMatlab` fixture begins with odd horizontal sizes and does not complete when run directly from this checkout because the unchanged MATLAB geometry constructor indexes Nyquist rows as `N/2+1`; the new formula test covers its forward, inverse, and F/G derivative paths on supported even nonsquare grids. Portable contract tests cover the odd-grid formulas independently.
- Apple Clang `-O3 -mcpu=native` emits no out-of-line helper symbols. Its optimization remarks report width-2 vectorization for the new hydrostatic, nonhydrostatic, F/G derivative, and flux-projection vertical loops.

## Compact Matilda screen

The compact screen compares an archived, unchanged `8d0b492` MEX with the candidate MEX in one MATLAB process, alternating paired control/candidate calls for both `[256 256 65]` physical configurations. It uses three warmups and fifteen complete `nonlinearFlux` samples per implementation and configuration. This is deliberately noncanonical preparation evidence.

The selected issue #137 `native-neon-pthreads` cache was unavailable locally, so provider selection was not rerun. The paired screen uses the same MATLAB-bundled FFTW 3.3.8 library and 10 threads for both modules. See `DeveloperExperiments/Issue163SharedCoefficientFormulaVerification.json` for raw samples, medians, errors, contract metadata, and the provider limitation.

| Configuration | Exact `8d0b492` median | Candidate median | Regression | Maximum relative error |
|---|---:|---:|---:|---:|
| Hydrostatic | 0.142422083 s | 0.141108250 s | -0.922% | 0 |
| Nonhydrostatic | 0.178177292 s | 0.178992708 s | +0.458% | 0 |

Both complete-call median regressions pass the 3% preparation gate. Immediately before timing, no benchmark, compiler, or RSS sampler was active. The open interactive MATLAB engine ended at 0.0% CPU after accruing 0.29 CPU-seconds over a 20-second sample; the GUI launcher accrued 0.28 CPU-seconds and remained open.

## Reconstruction for #171

```sh
git fetch origin
git worktree add -b issue-171-coefficient-formulas ../wave-vortex-model-issue-171 8d0b49236c703dfa7230a8875022fdb3e30283b0
git -C ../wave-vortex-model-issue-171 cherry-pick origin/prep/issue-163-shared-coefficient-formulas
git -C ../wave-vortex-model-issue-171 rev-parse HEAD^ HEAD
```

Then run the portable contract and focused MATLAB/MEX checks:

```sh
tools/compiled-kernel/run_contract_tests.sh /private/tmp/wvm-issue171-contract
matlab -batch "cd('/absolute/path/to/wave-vortex-model-issue-171'); addpath('UnitTests','Benchmarks','FastTransforms'); suite=matlab.unittest.TestSuite.fromFile('UnitTests/TestCompiledKernelTransforms.m'); methods=[\"nonlinearFluxEvaluatesPhaseOnce\",\"coefficientFormulaModesMatchMatlab\",\"mexFailuresAndLifetimeRemainBalanced\"]; names=string({suite.Name}); mask=false(size(names)); for k=1:numel(methods), mask=mask | endsWith(names,\"/\"+methods(k)); end; assert(nnz(mask)==3); results=run(suite(mask)); assert(all([results.Passed]));"
```

Before repeating any performance screen, verify an idle host, use the exact same provider and thread count for control and candidate, alternate paired calls, and require each complete-call median regression to remain at or below 3%. Do not treat this compact artifact as a replacement for canonical engineering evidence.
