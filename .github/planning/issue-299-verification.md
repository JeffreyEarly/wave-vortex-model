# Hydrostatic numerical kernel — issue 299

Base: v4 main `2292e87173c488902f7e7081babcaa4bc4ad63fe` (#371 / #298). Work is isolated on `issue-299-hydrostatic-kernel`. The user authorized the goal and GitHub integration. MATLAB public behavior remains backward compatible; the separate v5 checkout and released package snapshots are untouched.

## Scope and design

- Add a MATLAB/NetCDF-independent `WVTransformHydrostaticKernel` consuming the existing immutable scientific source. Reuse the prepared retained-horizontal and four F/G matrix operators with injectable scalar/Accelerate backends.
- Preserve compact Ap/Am/A0 factors, phases, component masks, exact retained j keys, hydrostatic nonlinear advection, accepted-state constraints, fields and derivatives, modal/spatial energy and spectral enstrophy.
- Implement raw F/G transforms and vertical calculus through prepared operators. Raw vertical calculus processes all physical horizontal columns and retains MATLAB's intermediate projections for higher derivatives. It does not build dense Nz-by-Nz derivative caches.
- One kernel owns its mutable workspaces: numerical scratch is four spectral coefficient arrays, two retained horizontal grid arrays and ten physical volumes. Prepared execution has no application allocations. Sources may be shared; concurrent callers need separate kernels.
- Keep complete model dispatch, forcing composition, observers, integrators, output and restart in #300, and end-to-end readiness/evidence in #301. No MATLAB production source or existing numerical kernel changes.

## Verification ledger

- AppleClang warnings-as-errors build passes. All 37 portable-runtime CTests pass, including the new Hydrostatic boundary test and existing constant-stratification/BQG/SQG integration and output contracts (`/private/tmp/wvm-299-native-contracts.log`).
- MATLAB parity passes both methods: 13 geometry/profile cases on each of reference/scalar, native FFTW/scalar and native FFTW/Accelerate, 39 case/provider combinations total (`/private/tmp/wvm-299-parity.log`). Coverage includes two variable profiles, odd/even nonsquare grids, antialiasing on/off, Nz/Nj variations including Nj=1, and retained j=[0,2,4] at negative latitude. Tests compare factors, all standard fields/components, first derivatives, F/G transforms and calculus, projections/round trips, energy/enstrophy, phases, constraints, nonlinear tendencies and four RK4 steps. Per-quantity tolerance is `2e-10*max(abs(expected)) + 1e-18`.
- The first probe run correctly rejected a raw complex Fourier mean: an individual Ap mean is not a real scalar field, even though its paired inertial velocity is real. The raw F/G fixture now uses real mean coefficients. Scientific kernel arithmetic and tolerances were unchanged.
- Every parity case checks zero prepared application allocations, unchanged input amplitudes, stable reported storage and scientific-owner release. The C++ boundary test adds shape/pointer/alias/enum/time/nonfinite-state rejection, unchanged outputs on invalid metadata, exact in-place evolution, each FFT/backend setup failure and an allocation-failure sweep.
- ASan/UBSan reference contracts and all 13 MATLAB parity cases pass (`/private/tmp/wvm-299-asan-contracts.log`, `/private/tmp/wvm-299-asan-parity.log`). macOS uses `detect_leaks=0:alloc_dealloc_mismatch=1:halt_on_error=1`; Linux focused CI enables LeakSanitizer as well.
- GCC 14.2 warnings-as-errors build and Hydrostatic contracts pass with the reference provider (`/private/tmp/wvm-299-gcc-build.log`, `/private/tmp/wvm-299-gcc-contracts.log`). The existing macOS deployment-version linker warnings are unchanged.
- The source-linked ATS consumer rebuild passes all 7 tests (`/private/tmp/wvm-299-ats-tests.log`).
- Existing compiled-kernel integration/source-hash tests pass 5/5 and the focused runtime source-export contract passes. Code Analyzer reports no messages for the new MATLAB test. One `docs:check` passes: 2,026 files, 4,145 routes, zero validation failures or generated differences (`/private/tmp/wvm-299-authoring-checks.log`). Diff/whitespace and repository scope checks pass; no required local assets are missing.
- Source export retains the new kernel through the existing CompiledKernel subtree. Source-selection manifests add issue-299 provenance without replacing historical scientific hashes or changing the stable runtime source API.

## Integration and handoff

The focused Linux workflow runs Hydrostatic boundary contracts and MATLAB parity in release and ASan/UBSan builds independently of optional Full CI. Required branch checks and these focused results are integration gates; the unchanged 35-minute SQG end-to-end qualification is not an additional foreground gate. Hosted results and final merge are recorded on the PR and issues.

After integration, close #299 and update #300/#301 with the kernel API and reproducible qualification commands from CompiledKernel/README.md. The runtime must still reject Hydrostatic complete model execution until #300 provides its adapters. No full-model performance, forcing or restart readiness is claimed by this kernel increment.
