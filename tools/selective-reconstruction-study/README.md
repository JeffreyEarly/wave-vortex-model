# Selective free-surface reconstruction (#453)

Surface requests now synthesize endpoint rows and use a one-level Fourier geometry. Selected volume requests synthesize only their dependencies. The default `reconstructSpectralState` still returns the complete spectral state with vertically repeated SSH, including explicit-state evaluation; both routes share the internal synthesis routine.

## Cache behavior

The existing variable cache and annotation-based invalidation remain authoritative. An internal `WVOperation` specialization lets `variableWithName` request only missing outputs from the Boussinesq reconstruction operation; other operations retain their grouped-output behavior. Explicit `performOperation` still computes its declared outputs.

`reconstructFields` also reads and populates eligible registered field entries, so direct diagnostics and operation-backed reads can share results. It accepts cached data only from the corresponding reconstruction operation and component. Requested outputs and required SSH geometry are retained; unused volume intermediates are not automatically cached. Existing cached hatted fields or pressure can supply endpoint values. Registered physical component velocities continue to use total-state geometry, including its clock invalidation.

The only new object cache is a transient surface Fourier geometry, following the QG endpoint-geometry pattern. Its dimensions and layout depend on immutable transform geometry, and it is rebuilt after restart. There is no second field cache and no persistent volume cache for surface queries. Reconstruction does not call `variableWithName` for its own outputs, avoiding recursion.

## Measurements

Baseline: frozen reconstruction and grouped-operation scheduling from WVM `1353067a`. MATLAB R2026a on Apple M5 Max; InternalModes `v2.0.0-beta.4`, ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, and the local Chebfun checkout. Both paths use populated six-family states on 8×8 horizontal grids, variable stratification, unequal family counts, and fixed mode counts across Z=33,65,129.

Cold timings invalidate fields while retaining warmed geometry/transform setup. Direct-reference and selective timings alternate measurement order and use the median of three `timeit` pairs. The old registered operation is measured separately because its first miss computes and caches all fields. Warm reads and successive-clock requests are also recorded in [the complete results](results/comparison.csv). No other task-owned MATLAB worker ran during these timings.

| Z | Old registered SSH miss (ms) | Selective miss (ms) | Warm SSH read (µs) |
| --- | ---: | ---: | ---: |
| 33 | 3.42 | 1.32 | 11.7 |
| 65 | 2.77 | 1.16 | 10.6 |
| 129 | 3.03 | 1.27 | 10.5 |

SSH misses are approximately 2.4–2.6× faster than the old cache-backed operation. The ordinary combined request `u,v,w,eta,p,ssh` also improved in this run, including comparison with the old uncached worker. The small Z=33 `u,v` request was about 5% slower than that uncached worker, but faster than the old registered operation; selective evaluation does not guarantee every uncached request is faster. These are local measurements, not cross-platform performance guarantees. Setup and mode construction are excluded.

At 8×8×129, an SSH miss retains 512 bytes of cached arrays instead of 794,112 bytes from the old grouped operation. Three separate process-peak measurements per implementation gave overlapping RSS ranges near 825 MB: MATLAB startup and allocator variation obscure the small temporary-memory difference at this grid size. [Memory measurements](results/memory.csv) therefore report both process peaks and cached-array bytes; they do not establish a process-RSS improvement. Larger-grid peak-memory qualification remains useful.

At fixed retained mode counts, surface synthesis costs O(KM) and its Fourier work O(H log H), with surface work arrays rather than O(KZM) synthesis and O(HZ log H) transforms. Surface-only requests do not build a vertical coordinate array. Stored modal bases and coefficient-state extraction still carry their existing storage/work. Full-volume reconstruction retains its original asymptotic cost.

## Verification

26 focused tests passed across selective reconstruction, Boussinesq transforms, variable wave counts, nonlinear evolution, and operation registration/caching. The new tests compare each family and mixed states with the frozen pre-change implementation at three clocks, with multiple requests, custom and registered components, total-state geometry, restart, partial grouped operations, and cached-dependency reuse. Existing tests cover inactive padding, coefficient setters, phase conventions, projection, and energy tendency. Maximum relative differences in the timed fields were below 3e-16; comparison tolerances allow roundoff from endpoint versus full-column arithmetic.

Production Code Analyzer passed with zero blocking findings. Direct analysis of the new internal code and tests found no issues; two authoring-only unused-variable notices arise from values deliberately inspected with `whos`. Whitespace, package-manifest, and authored-file scope checks passed. `docs:check` reported only the same two previously established baseline differences: the density-diffusion index and version-history page. No website or released-snapshot files changed.

The experiment-local `surface-gravity-wave-experiment/reconstructSurface.m` was inspected. It specializes one wave mode and prescribed coefficients and also returns spectral slopes. Keep it unchanged here; adopting the general shared path needs an explicit comparison of that experiment's complete SSH-and-slopes workload. No movies or experiment outputs were regenerated.

## Reproduction

Configure manifest-compatible dependencies before running; the default local MATLAB path may select an older InternalModes. From the WVM root:

```matlab
addpath('tools/selective-reconstruction-study');
runSelectiveReconstructionComparison('/tmp/wvm-selective');
assertSuccess(runtests('UnitTests/TestSelectiveFreeSurfaceReconstruction.m'));
```

The comparison saves scientific-state fixtures and measurements. In separate workers with the same dependency setup, measure each of `reference` and `selected` three times:

```sh
/usr/bin/time -l matlab -batch "addpath('tools/selective-reconstruction-study'); measureReconstructionMemory('/tmp/wvm-selective/state-129.mat','selected');"
```

Frozen references live in `UnitTests/ReferenceImplementations` and are never used by production. This increment does not alter the nonlinear RHS evaluation schedule, thermodynamic formulation, derivative backend, or public reconstruction signatures.
