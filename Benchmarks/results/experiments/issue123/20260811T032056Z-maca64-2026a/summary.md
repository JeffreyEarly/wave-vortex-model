# Compiled-kernel phase-once benchmark

- Status: `complete`
- Decision: **QUALIFIED**
- Reason: Phase-once execution passed the 5% local-change gate at 256x256x65 without a correctness, storage, RSS, or regression failure.

| Case | Baseline (ms) | Phase once (ms) | Speedup | Phase count | Live storage ratio | Peak RSS ratio |
|---|---:|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 114.555 | 107.070 | 1.070x | true | 1.000 | 1.000 |
| constant-hydrostatic-256x256x65 | 89.609 | 84.680 | 1.058x | true | 1.000 | 0.996 |
| constant-nonhydrostatic-512x512x129 | 920.002 | 817.414 | 1.126x | true | 1.000 | 0.999 |
| constant-hydrostatic-512x512x129 | 725.087 | 722.538 | 1.004x | true | 1.000 | 1.000 |
