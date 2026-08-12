# WaveVortexCheckpoint

`WaveVortexCheckpoint` is the read-only NetCDF adapter for the portable constant-stratification WaveVortex runtime. It consumes the existing `wave-vortex-4x-v1` structural profile and returns owned configuration, coefficient, and frozen-forcing records suitable for constructing portable runtime objects.

The library deliberately does not reproduce the general MATLAB `NetCDFFile` or `CAAnnotatedClass` APIs. Its private NetCDF-C layer supports only the group, attribute, dimension, variable, hyperslab, and complex-pair reads required by compatible WaveVortex checkpoints.

The data-only `wave-vortex-forcing-v1` contract preserves MATLAB forcing class names, resolved stages, priorities, stable source order, and immutable source parameters. It does not reproduce MATLAB handle objects. Derived damping operators, response arrays, masks, plans, and caches are rebuilt by later runtime layers.

Runtime v1 recognizes six forcing records:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVFixedAmplitudeForcing`
- `WVBottomFrictionQuadratic`
- `WVPseudoTopographicWaveGeneration`
- `WVBetaPlanePVAdvection`

Transform-level antialiasing is carried by `shouldAntialias`. Explicit `WVAntialiasing`, the other supplied forcing classes, and arbitrary subclasses are reported as unsupported before runtime construction.

The numerical target `WaveVortexKernel` has no NetCDF dependency. `WaveVortexCheckpoint` links the two boundaries:

```text
existing WaveVortex NetCDF file
            |
    WaveVortexCheckpoint  -- NetCDF C
            |
      WaveVortexKernel    -- no NetCDF or MATLAB APIs
```

The authoring contract suite builds this target and its standalone inspector through:

```sh
tools/compiled-kernel/run_contract_tests.sh
tools/compiled-kernel/build/wv_checkpoint_inspect checkpoint.nc
tools/compiled-kernel/build/wv_checkpoint_inspect --forcing-capabilities
```

Checkpoint writing and append/continuation behavior are deferred to the portable runtime restart implementation.
