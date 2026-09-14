# v4.4.1 benchmark table refresh

The current matched-model-runtime-v1 RK78 campaign was rerun at 256 × 256 × 129: three models, two workloads, three interfaces, and three fresh processes per configuration (54 runs). Every canonical endpoint, control, tracer, particle, and output comparison passed its existing tolerance. No warmup samples were discarded. The original records and archives, including the 114.205-second constant compiled composite sample, remain unchanged.

All runs used release commit c08b70471099682b5dc5d30c7ed0993b5c697c42 on Apple M4 Max, MATLAB R2025b Update 4, and the qualified native-neon-pthreads FFTW 3.3.11 provider. The 319 compiled source inputs match the previously qualified implementation; source and binary hashes are retained alongside the complete samples. Runs were sequential, without competing local MATLAB tests or builds. The scientific setup and integration controls match the previous published campaign.

`measurements.json` retains all 54 integration times and peak-RSS samples, medians, and comparisons against the previous published cohort. No runtime median regressed by more than 3%; the largest increase was 0.4024%. The largest peak-RSS median increase was 0.6095%. Constant compiled composite samples are 42.30159625, 42.40030154, and 42.57893863 seconds; the prior high outlier was not reproduced. Three samples do not establish a tail-latency distribution.

Verification ledger:

- Canonical numerical validation: all 54 fresh-process runs passed.
- Three focused benchmark documentation tests: passed (see CSV).
- Documentation generation and docs:check: 2058 files and 4203 routes, no differences or failures.
- Compressed raw archives: SHA256 and decompressed-byte equality verified; locations are in archives.json.
- Benchmark page changes are generated numerical tables, provenance values, and dataset links only. Canonical page prose, older datasets, renderer, package manifest, and runtime source are unchanged.

This refresh covers only the current three-interface model tables. Historical scaling and integrator campaigns were not rerun or replaced.

- Released OceanKit WaveVortexModel-4.4.1 package: all 319 compiled source inputs match the benchmark source. Isolated public MPM install verified version, six pinned dependencies, symbol resolution, constant/hydrostatic fields, linear integration, and NetCDF roundtrip. Two initial local setup attempts failed before consumer checks (pre-existing v4.2.0 install conflict, then an unwritable inferred add-on path); a fresh writable preference/install root resolved both without changing package contents.
- Independent read-only review: all dataset hashes, sample counts, medians, displayed rounding, contracts, and page-only numerical/provenance changes passed.
- Final whitespace/scope checks passed; primary v5 checkout and historical archives were untouched.
