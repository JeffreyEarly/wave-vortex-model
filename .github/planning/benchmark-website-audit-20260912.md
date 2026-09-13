# Website benchmark audit, September 12, 2026

## Decision and scope

Keep the matched interface comparison and MATLAB scaling records as dated historical evidence. Generate the selected interface record identity and measurement boundaries with its tables, so publishing a newer compatible record cannot leave a stale hard-coded dataset name in the prose. Separate the MATLAB builtin storage diagnostic from total process-tree RSS. Link recent native C++ optimization reports as incremental evidence with their own fixtures and timing boundaries; do not apply their ratios to the older MATLAB/C++ comparison or add cumulative speedups.

The selected interface record is `three-interface--m5-max--20260828T143049Z`, source `6d41ce0b`, an unreleased preview on Apple M5 Max using the native NEON/pthreads FFTW provider. MATLAB scaling records describe v4.2.1. These records do not measure current v4 main. Their canonical normalized JSON and published downloads are present. The representative constant-stratification three-interface study remains useful for interface/output and integrator comparisons; it does not substitute for variable-stratification Hydrostatic or Boussinesq qualification.

## Reproducibility limit

The provenance records name these external raw archives, but neither was found in the local sibling artifact repository during this audit:

- `wave-vortex-model-benchmark-artifacts/three-interface/20260827T151230000Z-three-interface-benchmark.json.gz`, SHA256 `68714c20e30a7d5d553aea914e80028a75581d96787a574523b49309f32aaa9b`.
- `wave-vortex-model-benchmark-artifacts/three-interface/20260828T143049953Z-three-interface-benchmark.json.gz`, SHA256 `54f3d6d104ec14e0289acb551fd51b46139b1a9181cd6a7f36bd94db6caa5329`.

Paths are relative to the OceanKitRepositories workspace. Public normalized results remain available; their existence does not establish retention of the original raw archives or fixture payloads. Preserve the recorded hashes. Recover these artifacts or publish a fresh matched record before claiming a fully retained current interface campaign.

## Future refresh

`addpath("Benchmarks"); results = runThreeInterfaceBenchmarkComparison;` is the existing complete publication path: eight cases, three interfaces and three fresh processes per case (72 workers). The old primary integration samples total approximately 97 minutes; budget at least a two-hour quiet-host window plus validation/build/archive overhead on that historical hardware. The RK78-only subset requires 18 workers and had about 13 minutes of primary integration, but does not satisfy the current eight-case publication schema. This audit does not weaken that schema or run an incomplete subset and label it complete.

A future current-performance refresh should retain the full raw archive in durable storage, validate its hash and frozen source/provider identities, and publish via the existing catalog/generator. Include an explicit variable-stratification complete-model comparison if the intended claim covers the two matrix models. Do not interrupt a running scientific experiment to obtain timings.

## Verification ledger

- Read-only audit: canonical pages, selected catalog records, generator selection/validation, normalized public assets and raw-archive references checked. Public data links resolve to existing generated assets.
- Source and generated documentation verification pass: all ten distinct focused methods covered, `docs:build` plus one `docs:check` validate 2,026 files/4,145 routes without failures, and the edited MATLAB tooling has no new Code Analyzer findings. The native table uses the final paired #496 measurements with explicit hardware, controls and order/host caveats. Repository/provenance and whitespace checks pass.
- No new timing campaign is represented as a fresh MATLAB/C++ website comparison. The separate PR #496 campaign qualifies only its frozen standalone native increment.
