# Prepared spectral execution

The v4 constant-stratification kernel prepares its FFT plans, scratch arenas and coefficient executor at construction. A workspace permits one synchronous active call. The default coefficient execution uses the calling thread and one persistent background thread; `WV_KERNEL_COEFFICIENT_WORKERS=1` selects serial execution. Every coefficient stage completes before FFT execution begins. Construction joins any workers already launched if a later launch fails, and destruction joins the retained workers.

The seventeen base plans and `4H+6R` numerical scratch bound are unchanged. Call `prepareScalarAdvection()` during setup when scalar advection is configured. It prepares one additional inverse plan, is idempotent, and can be retried after setup failure. The portable integration system already does this for its configured tracers. Ordinary RHS, RHS that returns velocity, and RHS that consumes prepared velocity retain their existing interfaces and shared particle/tracer velocity behavior.

Successful prepared native execution performs no application C++ allocations or thread launches. This covers forward/inverse transforms, F/G derivatives, the three RHS forms, and scalar advection with and without antialiasing. Failure reporting can allocate diagnostic strings. The reference FFT provider still allocates for vertical real-to-real execution. Its horizontal real/complex execution is allocation-free after preparation.

## Native FFTW ownership

`destroysInput=false` requires preservation for out-of-place execution. Native r2c and out-of-place DCT-I/DST-I plans request `FFTW_PRESERVE_INPUT`. Multidimensional c2r has no preserving algorithm in FFTW, so setup returns `unsupportedOperation`; callers must explicitly prepare destructive scratch and set `destroysInput=true`. The existing production inverse paths already use that scratch. No hidden preservation copy is retained.

In-place execution inherently overwrites shared storage and requires identical input/output pointers. This adapter supports in-place vertical real-to-real transforms with matching strides. Padded in-place horizontal transforms are rejected during setup. Out-of-place execution rejects identical pointers and partially overlapping addressed spans before entering FFTW. Positive strides, supported ranks, span arithmetic and declared buffer capacities are checked during setup. A failed setup leaves any existing output plan unchanged.

Planning buffers and raw plans have RAII ownership immediately after acquisition. All plan destruction, including cleanup after a wrapper allocation failure, takes the same mutex as planning. Lifetime plan counters include raw plans, so partial construction is visible and must balance.

These choices follow FFTW's [planner flags](https://www.fftw.org/fftw3_doc/Planner-Flags.html) and [thread safety](https://www.fftw.org/fftw3_doc/Thread-safety.html) contracts.

## Storage accounting

`kernelManagementBytes` includes the executor object and its retained `std::thread` vector capacity. Descriptor storage, scratch capacity, engine storage and plan wrapper storage remain separately reported. `persistentBytes` sums the known retained C++ storage. FFTW's internal plan storage and the thread runtime's heap bookkeeping, stacks and operating-system resources are opaque; these totals are lower bounds, not RSS or a complete process-memory bound. The native allocation test counts application `new`/`new[]`, including aligned allocation, and does not interpose FFTW/libc internal allocation.

## Verification

Run the portable tests with `tools/compiled-kernel/run_contract_tests.sh`. To include the native ownership and allocation tests, configure the same CMake project with the installed FFTW prefix:

```sh
cmake -S tools/compiled-kernel -B /tmp/wvm-kernel-tests \
  -DCMAKE_BUILD_TYPE=Release -DWV_KERNEL_FFTW_ROOT=/path/to/fftw-prefix
cmake --build /tmp/wvm-kernel-tests --parallel
ctest --test-dir /tmp/wvm-kernel-tests --output-on-failure
```

`TestWVPreparedModeExecutor` tests repeated serial/parallel partitions, exceptions, partial worker startup and allocation/thread-launch counts. `TestWVNativeFFTWOwnership` links the real FFTW library through test-only acquisition wrappers. It injects planning-buffer, raw-plan and wrapper failures, sweeps kernel application allocations, checks serialized planning/destruction, and compares even/odd hydrostatic/nonhydrostatic numerical results and immutable inputs. Production code contains no FFTW fault-injection hooks.

Issue [#356](https://github.com/JeffreyEarly/wave-vortex-model/issues/356) tracks this change. The task verification ledger is in `.github/planning/issue-356-verification.md`.


## Prepared retained-horizontal and matrix services

`WaveVortexKernel/WVSpectralOperators.hpp` defines internal contract `wave-vortex-spectral-operators-v1`. It is additive to kernel contract 4 and portable extension source API v1. The existing kernels keep their canonical interleaved coefficients and execution schedules. These services establish the boundary for the hydrostatic implementation in issue #295 and subsequent schedule adoption in #358; they do not decode modal checkpoint records or enable additional MATLAB preview transforms.

Create an immutable operator with `create(specification, provider, result)`, then call `createWorkspace(workspace)` during setup. A failed construction leaves the previous result unchanged. Operators copy scientific values and exact identities; callers may release their source arrays after successful preparation. Workspaces retain the operator's immutable dependencies and can outlive its handle. Rebuild the operator and create new workspaces when geometry, stratification, retained basis, normalization, source matrices, mode membership or layout changes. Ordinary state/time updates only change execution inputs. A workspace from another preparation is rejected even if its dimensions match.

Each workspace permits one synchronous active call and rejects reentry. Distinct workspaces may execute concurrently against one immutable operator. Custom providers must support that usage; workspace creation itself is a setup operation and must be serialized if the provider requires it. No application workers are created by these services. Vendor BLAS may manage its own opaque resources; the Accelerate adapter does not change process-wide threading settings.

### Horizontal mapping and normalization

`WVRetainedHorizontalSpecification` contains the real `[Nx,Ny,planes]` grid, positive domain lengths, the complex `[planes,Nretained]` layout and the exact ordered signed `(k,l)` keys. `planes` may be a truncated vertical extent and does not imply the physical `Nz`. The real and retained family names must match. `modeSet` names the supplied ordered set; it is the caller's responsibility to associate the correct identity with that set. No radius rule or approximate grouping substitutes for the explicit keys.

Supply one representative per retained Hermitian orbit. Signed keys lie within `[-floor(N/2),floor(N/2)]`; aliases such as the two signs of an even-grid Nyquist index, repeated keys and both members of a conjugate pair are rejected. Arbitrary retained order and negative representatives are supported. Forward execution performs the full provider FFT and gathers that order. Inverse execution zeroes omitted modes, embeds retained values, completes boundary conjugates and runs the full inverse. DC and self-conjugate Nyquist coefficients must have exactly zero imaginary part on inverse input; forward output sets those imaginary parts to zero.

For `N = Nx*Ny`, normalization scales the provider's unnormalized forward and inverse transforms as follows. All three conventions recover retained coefficients after synthesis and analysis; synthesis discards modes outside the retained set.

| Convention | Forward scale | Inverse scale |
| --- | --- | --- |
| `forwardUnit` (WVM default) | `1/N` | `1` |
| `unitary` | `1/sqrt(N)` | `1/sqrt(N)` |
| `inverseUnit` | `1` | `1/N` |

The workspace owns a dense real grid and a full horizontal half-spectrum, plus forward and inverse plans. Only this disposable scratch is passed to destructive c2r. Caller inputs and output padding remain unchanged. Provider failure occurs before any caller output is written. This reference schedule works with the reference DFT or native FFTW adapter; it does not implement the benchmark's pruned schedule.

### Vertical matrices and exact groups

`WVVerticalSpecification` selects reconstruction `[Nz,Nj]`, projection `[Nj,Nz]` or cross-family `[Nj,Nj]`. It supplies real matrix records with explicit action, input/output family, source identity, operator name, extents, strides and capacity. The source identity must describe the authoritative geometry, stratification, basis and normalization revision. The service validates consistency among these supplied identities; it cannot establish their scientific provenance. The future modal decoder owns that responsibility. Zero G/barotropic operators and truncated bases are valid.

Each group gives an exact group identity, matrix record index and an explicit list of retained columns. Lists may be discontiguous or reordered. Every retained column must occur exactly once, group identities must be unique and all input records must be used. Input and output share the same ordered mode-set identity and complex representation. Repeated `(source,name)` matrix identities reuse storage only after all addressed matrix values compare bit-for-bit. Different identities remain distinct even when their values are equal; conflicting values under one identity are rejected. There is no approximate deduplication or matrix expansion per Fourier mode.

Split execution prepares one real matrix per identity and applies two real matrix products. Interleaved execution prepares one complex matrix per identity with zero imaginary components and applies one complex product directly to interleaved fields. `WVCreateScalarMatrixBackend` provides independent scalar multiplication. The optional `WaveVortex::AccelerateMatrix` adapter supplies two DGEMMs or one ZGEMM; vendor headers remain outside the portable core. Set `WV_ENABLE_ACCELERATE=OFF` for the portable implementation, including non-Apple builds. Calling the disabled adapter factory returns `unsupportedOperation`.

Contiguous groups with unit row strides and valid BLAS leading dimensions use direct field views. Other valid layouts gather into prepared scratch, multiply, and scatter. Scratch capacity is bounded by the largest group requiring packing. Accumulation explicitly selects overwrite or add; overwrite does not read the previous destination. Packing preserves the selected split or interleaved representation and does not introduce hidden state-layout conversion.

### Views, ownership and accounting

All extents and element strides are positive. Complex strides count complex elements for interleaved storage and doubles for each split component. Matrix strides count doubles. Capacity is in bytes, including addressed padding; for split fields it is the minimum capacity of the two component buffers. Set only the pointers for the declared representation. Execution checks null/alignment, overflow, capacities, split-component overlap and cross-input/output overlap before mutation. Capacity declarations must truthfully describe live caller-owned allocations. Only out-of-place execution is supported.

Complex and matrix layouts reject repeated addressed elements. Real-grid layouts support permuted padded nested dimensions; unusual interleaved dimensions with overlapping bounding intervals are conservatively rejected. Alias checks also use addressed bounding spans, so sharing padding within those spans is rejected. Provider integer limits are checked before BLAS execution. A single-column view may have an unused small column stride; it is packed when that stride is not a valid BLAS leading dimension.

Successful prepared execution performs no application C++ allocation with the reference horizontal FFT, native FFTW, scalar matrix backend or Accelerate backend. Preparation and failure diagnostics may allocate. Tests count application `new`/`new[]`, not vendor `malloc` or internal worker activity.

Horizontal `persistentBytes()` reports the operator's objects, identities and mapping capacity; add `providerBytesLowerBound()` once, plus each workspace's `persistentBytes()` and `planBytesLowerBound()`. Vertical operator accounting includes its backend and prepared matrix capacity; `matrixBytes()` is the numerical-matrix subtotal, not an additional allocation. Add each vertical workspace's accounting once. Shared immutable data is not counted again per workspace. Object/vector capacities and string capacities are accounting estimates: small-string storage can already be inline, while shared-ownership control blocks, allocator overhead and vendor internals are excluded. These numbers are not RSS or an exact process-memory bound.

`TestWVSpectralOperators` checks independent long-double DFT and matrix oracles, odd/even nonsquare grids, masked/unmasked WVM retained sets, truncated bases, all normalization conventions, DC/Nyquist handling, split/interleaved direct and packed groups, accumulation, immutable preparation, identity conflicts, invalid spans/aliases, setup failures, separate concurrent workspaces and zero prepared allocations. The verification ledger is `.github/planning/issue-357-verification.md`.

## Stratified QG numerical kernel

`WaveVortexKernel/WVTransformStratifiedQGKernel.hpp` implements the standalone variable-stratification A0/QGPV kernel under internal contract `wave-vortex-stratified-qg-kernel-v1`. It consumes an immutable `WVStratifiedModalSource`; the runtime's `WVStratifiedModalRecord` implements that interface after validating the MATLAB file. The numerical core has no NetCDF/MATLAB dependency and does not solve an eigenproblem. This kernel does not enable Stratified QG runner execution or forcing/observer/output graph integration; those remain #297–#298.

Create the kernel from a shared scientific source and a caller-owned FFT engine. The optional setup-only matrix-backend factory defaults to the scalar reference backend; callers can supply a native matrix adapter. Preparation uses #357's full-FFT gather/embed service and four shared F/G projection/reconstruction operators. Coefficients remain canonical interleaved `[Nj,Nkl]`; physical arrays use MATLAB column-major `[Nx,Ny,Nz]`. Surface fields require `[Nx,Ny,1]`. No `Ap`/`Am` state or per-horizontal-mode matrix expansion is introduced.

The API provides raw QGPV and U/V/displacement projection, field reconstruction and first x/y/z derivatives, nonlinear PV advection, explicit beta-plane tendencies and exact linear Rossby evolution, spectral and spatial energy/enstrophy, and maximum horizontal speed. Fields include u/v, zero w, displacement, pressure height `pi`, pressure `p=rho0*g*pi`, streamfunction, QGPV, excess/total density, vertical vorticity and surface height/velocity. F-plane `evolveA0` is stationary regardless of reference time. Beta is an explicit argument to evolution and tendency methods; the geometry's planetary beta is available in `factors()` but is not silently enabled.

MATLAB's geostrophic mask excludes every horizontal-mean mode, including baroclinic means. Raw QGPV projection retains its mean as MATLAB does; reconstruction and quadratic diagnostics apply the geostrophic mask. Barotropic displacement and the barotropic deformation wavenumber are zero. The retained Fourier list carries the horizontal antialias selection; projection cannot generate omitted modes. Vertical truncation uses the authoritative matrices and exact j keys, including non-prefix subsets.

Spatial energy uses the stored modal quadrature. `totalEnstrophySpatiallyIntegrated` deliberately matches MATLAB's current diagnostic, which uses trapezoidal integration on z; it need not equal spectral enstrophy on a nonuniform grid. Density derivatives use the product rule with N2 and `dLnN2`; horizontal derivatives of total density differentiate the anomaly, avoiding cancellation against the horizontally uniform background.

A kernel retains the scientific owner and owns its prepared operators and mutable workspaces. Reuse it during time evolution; changed scientific geometry or basis requires a new source and preparation. Calls using mutable scratch reject overlapping execution. Distinct kernels provide independent workspaces. Input/output buffers must be disjoint, except exact in-place linear tendency/evolution; partial overlaps are rejected. Array views describe their full required extent, so callers must supply storage for those shapes. Failed setup leaves an existing kernel untouched; FFT and backend execution failures propagate without promising rollback of output already written.

`storage()` separates shared scientific ownership, prepared operators, workspace capacities, mode factors and numerical scratch. Application scratch is two `[Nj,Nkl]` complex arrays, one `[Nz,Nkl]` complex array and four physical real volumes; retained-horizontal internal workspace and backend scratch are counted separately. Shared-source bytes must not be multiplied by the number of kernels sharing that owner. These are capacity estimates, not RSS: allocator overhead, small object/string/control-block storage and vendor internals are not exact process-memory measurements. Provider/plan figures remain lower bounds.

`TestWVStratifiedQGKernel` tests ownership, bad shapes/pointers/aliases, failed FFT/backend setup, allocation-failure cleanup and zero prepared application allocations. `UnitTests/TestStratifiedQGCompiledKernel.m` compares independent MATLAB fields, factors, projections, derivatives, round trips, nonlinear and beta tendencies, linear evolution and diagnostics over two variable profiles, odd/even nonsquare grids, masks on/off, several modal resolutions and a non-prefix subset. Set `WV_QG_KERNEL_DUMP` to a built `WVStratifiedQGKernelDump`; `WV_QG_TEST_NATIVE=1` adds the native FFT provider when that executable was built with it. Otherwise the test builds its own temporary reference executable. Production MATLAB code is unchanged by #296.

The SQG kernel also provides vertical-diffusivity and linear/quadratic bottom-friction flux operations used by the #297 runtime. They preserve MATLAB's intermediate F/G projections and bottom quadrature normalization. `advectScalarWithAdvectionFields` differentiates a full three-dimensional tracer grid horizontally, then optionally projects its flux onto the retained horizontal set. `WVRetainedHorizontalOperator::spatialDerivative` reuses its full FFT workspace without restricting the derivative to the retained modes; the selected even-grid Nyquist derivative is zero. These prepared calls reuse existing scratch storage.
