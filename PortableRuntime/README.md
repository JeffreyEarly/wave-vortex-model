# WaveVortexCheckpoint

`WaveVortexCheckpoint` is the read-only NetCDF adapter for the portable constant-stratification WaveVortex runtime. It consumes the existing `wave-vortex-4x-v1` structural profile and returns owned configuration and coefficient records suitable for constructing `WaveVortexKernel` objects.

The library deliberately does not reproduce the general MATLAB `NetCDFFile` or `CAAnnotatedClass` APIs. Its private NetCDF-C layer supports only the group, attribute, dimension, variable, hyperslab, and complex-pair reads required by compatible WaveVortex checkpoints.

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
```

Checkpoint writing and append/continuation behavior are deferred to the portable runtime restart implementation.
