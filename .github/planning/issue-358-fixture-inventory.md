# Issue 358 fixture inventory

Inventory baseline: WVM checkout `8d08ba48b554a84b9920e349e6d4c69dccd6c0dd` (`wvm-v4-cpp-adoption-audit`). No benchmark or snapshot files were changed.

## Resolutions and existing harnesses

The current benchmark suite defines the requested production-shaped constant workloads in `Benchmarks/waveVortexBenchmarkSuites.m`: `constant-{hydrostatic,nonhydrostatic}-{256x256x129,512x512x257}`. Public MATLAB full-flux entry is `WVTransformConstantStratification.nonlinearFlux`; focused checks are `UnitTests/TestNonlinearFlux.m`, `UnitTests/TestHydrostaticCompiledKernel.m`, and `UnitTests/TestWVCompiledBackend.m`. Lifecycle/integration checks are `UnitTests/TestWVModelIntegration.m`, `UnitTests/TestForcingLifecycle.m`, and `UnitTests/TestCompiledKernelIntegration.m`.

The three-interface current control is `Benchmarks/runThreeInterfaceBenchmark.m` (MATLAB builtin, MATLAB compiled, standalone compiled) and its workers `Benchmarks/threeInterfaceMatlabWorker.m`, `Benchmarks/compiledPreviewBenchmarkWorker.m`, and `Benchmarks/standalone/WVStandaloneNonlinearFluxBenchmark.cpp`. The standalone runner is configured in `PortableRuntime/CMakeLists.txt`; the compiled MATLAB path is `CompiledKernel/adapters/native-fftw/wv_compiled_backend_mex.cpp`, staged locally as `wv_compiled_backend_mex.mexmaca64`.

## Fixtures

The historical benchmark result containing the named `256x256x129` and `512x512x257` cases is `Benchmarks/results/reference/scaling-large-v1-m5-max-r2026a-builtin/benchmark.json` (SHA-256 `8b0b8bb4f4204bd7d9fc06678630cbf63b4ca48f60cd92f540096adf07ea6c32`). It is a result manifest, not a reusable MATLAB state fixture, and records source commit `0d36eae...`; it cannot establish parity for the current baseline.

Local authoritative spectral-flux payloads exist outside this checkout under `spectral-kernel-benchmarks/results/local/issue20-constant-flux-authoritative-reference-20260830-v2/fixtures/`:

- `wvm-current-256-nz129-f4/{export,prepared.bin}`; prepared SHA-256 `a751394bd3dc67e98039e29c2b99efcdaaee752886b736343b16060e6427b27d`.
- `wvm-current-512-nz257-f4/{export,prepared.bin}`; prepared SHA-256 `1722ae2ac8475235607f02c567c7288c673069bda15e0c5b792e6bb4230cb785`.

The exported manifest identifies `constant-stratification-flux-fixture-v1`. Its `provenance` records clean WVM commit `6ad254fb9756ac918bb72e036020d004879df1f2`, tree `f4cd36f0c6c8f0e0f08191be9994baf027e12172`, MATLAB R2025b Update 4. Its generator is separately pinned to benchmark commit `751aebf30d8aa4320fddd2f4adcb3c142a239df6`. Read those nested authorities, not an absent top-level `waveVortexModelCommit` key. These local payloads are available historical controls; they do not establish current MATLAB parity. The coordinator's current exporter retains the same seed/formula family and creates new current MATLAB oracles for both hydrostatic settings.

## Native provider and machine

`CompiledKernel/native-fftw-provider.env` pins native-neon-pthreads FFTW 3.3.11, source digest `5630c24cdeb33b131612f7eb4b1a9934234754f9f388ff8617458d0be6f239a1`, NEON/pthreads, no OpenMP, and `-O3 -mcpu=native`. The file SHA-256 is `9e644f9f4baea4becd6f7eeb774fb5a98ca86d136077476672bdbe85e39eca63`; `CompiledKernel/source-selection.json` SHA-256 is `e7a1cf3690edd1738dbd1f819dff8ad68a28c82c5faf58de4865011dfa56de34`.

The host is an Apple M4 Max Mac Studio, 16 cores (12 performance, 4 efficiency), 128 GB RAM. Root identified the validated provider at `/Users/jearly/Documents/OceanKitRepositories/wave-vortex-model/.compiled-backend-cache/provider/native-neon-pthreads`. The current-control checkout is `/Users/jearly/Documents/OceanKitRepositories/wvm-v4-issue358-control` at `8d08ba48`; its fresh Release build is `/private/tmp/wvm358-control-runtime`. Runner SHA-256 is `bac9b9c76cd4f0960a8225b0319e46d54dafc6e091a94917305d6cddb417fca2`; flux worker is `/private/tmp/wvm358-control-runtime/wv-standalone-nonlinear-flux-benchmark`, SHA-256 `a6f79e74fd66a9f24c4e3dc8fdee619ff9a8c57f3de4cc6138f3fa6671486b23`. The staged MEX and cache copy are byte-identical, SHA-256 `310afe393d55416ec41c3b4caf085018080c7bbd94addbf92c47dba706d861f3`.

## Recommended bounded path

1. Generate current NetCDF inputs and independent MATLAB flux arrays with `Benchmarks/constant-adoption/writeConstantAdoptionFixtures.m`. The original benchmark preparer enforces its historical source identity and is not relabeled as a current export. Existing historical exports remain separate, available evidence.
2. Build the current standalone control with `PortableRuntime/CMakeLists.txt`, `-DWV_RUNTIME_ENABLE_NATIVE_FFTW=ON`, and the pinned provider root; validate provider identity before running.
3. Run only correctness first: `TestNonlinearFlux`, compiled-kernel constant hydrostatic/nonhydrostatic tests, and one small `TestWVModelIntegration` lifecycle case. Compare ordinary velocity/scalar fields and aliases through existing observer/field tests, then run the fixture-backed full-flux control at 256 and 512 shapes.
4. Defer RSS/performance campaigns until fixture provenance and numerical equality pass. Historical benchmark manifests and current local prepared bins are evidence of available assets, not current MATLAB parity.
