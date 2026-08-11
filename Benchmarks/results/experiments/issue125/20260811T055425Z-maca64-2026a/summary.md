# MATLAB nonlinear-flux optimization benchmark

- Status: `complete`
- Source: `8d0d9b3606b71f66b463322f8477868c3691e84a`
- MATLAB: `2026a`
- Architecture: `maca64`
- Fresh processes per variant/case: `3`

## Complete nonlinearFlux timing and memory

| Case | Variant | Median (ms) | Speedup | Peak RSS ratio | Error | Workspace (MiB) |
|---|---|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | current | 112.193 | 1.000x | 1.000x | 0 | 0.000 |
| constant-nonhydrostatic-256x256x65 | scalar-zero | 111.612 | 1.005x | 1.027x | 0 | 0.000 |
| constant-nonhydrostatic-256x256x65 | reusable-reset | 117.003 | 0.959x | 0.927x | 0 | 130.000 |
| constant-nonhydrostatic-256x256x65 | reusable-overwrite | 109.648 | 1.023x | 1.000x | 0 | 130.000 |
| constant-nonhydrostatic-256x256x65 | forward-batch-cat | 115.796 | 0.969x | 0.755x | 0 | 0.000 |
| constant-nonhydrostatic-256x256x65 | forward-batch-preallocated | 115.486 | 0.971x | 0.755x | 0 | 130.000 |
| constant-nonhydrostatic-256x256x65 | full-batch-cat | 115.198 | 0.974x | 0.611x | 0 | 0.000 |
| constant-nonhydrostatic-256x256x65 | full-batch-preallocated | 109.854 | 1.021x | 0.610x | 0 | 390.000 |
| constant-hydrostatic-256x256x65 | current | 91.343 | 1.000x | 1.000x | 0 | 0.000 |
| constant-hydrostatic-256x256x65 | scalar-zero | 94.086 | 0.971x | 1.028x | 0 | 0.000 |
| constant-hydrostatic-256x256x65 | reusable-reset | 97.722 | 0.935x | 0.948x | 0 | 97.500 |
| constant-hydrostatic-256x256x65 | reusable-overwrite | 95.583 | 0.956x | 1.000x | 0 | 97.500 |
| constant-hydrostatic-256x256x65 | forward-batch-cat | 96.814 | 0.943x | 0.801x | 0 | 0.000 |
| constant-hydrostatic-256x256x65 | forward-batch-preallocated | 94.438 | 0.967x | 0.801x | 0 | 97.500 |
| constant-hydrostatic-256x256x65 | full-batch-cat | 96.256 | 0.949x | 0.610x | 0 | 0.000 |
| constant-hydrostatic-256x256x65 | full-batch-preallocated | 90.998 | 1.004x | 0.609x | 0 | 357.500 |
| constant-nonhydrostatic-512x512x129 | current | 848.653 | 1.000x | 1.000x | 0 | 0.000 |
| constant-nonhydrostatic-512x512x129 | scalar-zero | 841.103 | 1.009x | 1.031x | 0 | 0.000 |
| constant-nonhydrostatic-512x512x129 | reusable-reset | 878.775 | 0.966x | 0.916x | 0 | 1032.000 |
| constant-nonhydrostatic-512x512x129 | reusable-overwrite | 856.724 | 0.991x | 1.000x | 0 | 1032.000 |
| constant-nonhydrostatic-512x512x129 | forward-batch-cat | 875.236 | 0.970x | 0.725x | 0 | 0.000 |
| constant-nonhydrostatic-512x512x129 | forward-batch-preallocated | 870.446 | 0.975x | 0.726x | 0 | 1032.000 |
| constant-nonhydrostatic-512x512x129 | full-batch-cat | 920.935 | 0.922x | 0.573x | 0 | 0.000 |
| constant-nonhydrostatic-512x512x129 | full-batch-preallocated | 889.886 | 0.954x | 0.573x | 0 | 3096.000 |
| constant-hydrostatic-512x512x129 | current | 705.047 | 1.000x | 1.000x | 0 | 0.000 |
| constant-hydrostatic-512x512x129 | scalar-zero | 693.224 | 1.017x | 1.033x | 0 | 0.000 |
| constant-hydrostatic-512x512x129 | reusable-reset | 720.312 | 0.979x | 0.939x | 0 | 774.000 |
| constant-hydrostatic-512x512x129 | reusable-overwrite | 703.036 | 1.003x | 1.000x | 0 | 774.000 |
| constant-hydrostatic-512x512x129 | forward-batch-cat | 731.458 | 0.964x | 0.774x | 0 | 0.000 |
| constant-hydrostatic-512x512x129 | forward-batch-preallocated | 729.048 | 0.967x | 0.774x | 0 | 774.000 |
| constant-hydrostatic-512x512x129 | full-batch-cat | 769.555 | 0.916x | 0.570x | 0 | 0.000 |
| constant-hydrostatic-512x512x129 | full-batch-preallocated | 734.829 | 0.959x | 0.570x | 0 | 2838.000 |

## Issue #125 adoption decisions

| Variant | Complexity | Production eligible | Required improvement | Outcome | Qualifying size |
|---|---|---|---:|---|---|
| scalar-zero | local | true | 5% | NOT_ADOPTED | — |
| reusable-reset | persistent-state prototype | false | 5% | NOT_ADOPTED | — |
| reusable-overwrite | persistent-state prototype | false | 5% | NOT_ADOPTED | — |
| forward-batch-cat | contained prototype | false | 5% | NOT_ADOPTED | — |
| forward-batch-preallocated | persistent-state prototype | false | 5% | NOT_ADOPTED | — |
| full-batch-cat | architectural prototype | false | 5% | NOT_ADOPTED | — |
| full-batch-preallocated | architectural persistent-state prototype | false | 5% | NOT_ADOPTED | — |

## Diagnostic component medians

| Case | Variant | Inverse batch (ms) | Spatial forcing (ms) | Projection (ms) |
|---|---|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | current | NaN | NaN | NaN |
| constant-nonhydrostatic-256x256x65 | scalar-zero | NaN | 87.553 | 20.854 |
| constant-nonhydrostatic-256x256x65 | reusable-reset | NaN | 92.709 | 20.525 |
| constant-nonhydrostatic-256x256x65 | reusable-overwrite | NaN | 87.709 | 20.628 |
| constant-nonhydrostatic-256x256x65 | forward-batch-cat | NaN | 88.628 | 25.402 |
| constant-nonhydrostatic-256x256x65 | forward-batch-preallocated | NaN | 87.627 | 25.227 |
| constant-nonhydrostatic-256x256x65 | full-batch-cat | 31.986 | 57.780 | 25.645 |
| constant-nonhydrostatic-256x256x65 | full-batch-preallocated | 26.101 | 58.270 | 25.581 |
| constant-hydrostatic-256x256x65 | current | NaN | NaN | NaN |
| constant-hydrostatic-256x256x65 | scalar-zero | NaN | 74.743 | 16.779 |
| constant-hydrostatic-256x256x65 | reusable-reset | NaN | 77.577 | 16.739 |
| constant-hydrostatic-256x256x65 | reusable-overwrite | NaN | 73.723 | 17.319 |
| constant-hydrostatic-256x256x65 | forward-batch-cat | NaN | 72.627 | 20.396 |
| constant-hydrostatic-256x256x65 | forward-batch-preallocated | NaN | 72.972 | 20.296 |
| constant-hydrostatic-256x256x65 | full-batch-cat | 32.135 | 43.531 | 20.895 |
| constant-hydrostatic-256x256x65 | full-batch-preallocated | 26.794 | 43.770 | 20.827 |
| constant-nonhydrostatic-512x512x129 | current | NaN | NaN | NaN |
| constant-nonhydrostatic-512x512x129 | scalar-zero | NaN | 649.804 | 192.367 |
| constant-nonhydrostatic-512x512x129 | reusable-reset | NaN | 687.135 | 189.843 |
| constant-nonhydrostatic-512x512x129 | reusable-overwrite | NaN | 662.571 | 193.034 |
| constant-nonhydrostatic-512x512x129 | forward-batch-cat | NaN | 646.787 | 223.251 |
| constant-nonhydrostatic-512x512x129 | forward-batch-preallocated | NaN | 644.156 | 222.817 |
| constant-nonhydrostatic-512x512x129 | full-batch-cat | 253.016 | 432.622 | 226.020 |
| constant-nonhydrostatic-512x512x129 | full-batch-preallocated | 213.508 | 428.146 | 223.164 |
| constant-hydrostatic-512x512x129 | current | NaN | NaN | NaN |
| constant-hydrostatic-512x512x129 | scalar-zero | NaN | 546.027 | 149.143 |
| constant-hydrostatic-512x512x129 | reusable-reset | NaN | 570.502 | 150.250 |
| constant-hydrostatic-512x512x129 | reusable-overwrite | NaN | 553.368 | 150.169 |
| constant-hydrostatic-512x512x129 | forward-batch-cat | NaN | 563.175 | 175.743 |
| constant-hydrostatic-512x512x129 | forward-batch-preallocated | NaN | 547.871 | 174.929 |
| constant-hydrostatic-512x512x129 | full-batch-cat | 255.631 | 331.553 | 174.007 |
| constant-hydrostatic-512x512x129 | full-batch-preallocated | 212.070 | 327.663 | 172.988 |

## Allocation controls

| Case | Bytes (MiB) | Allocate zeros (ms) | Reset to zero (ms) | Overwrite (ms) |
|---|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 130.000 | 0.983 | 4.218 | 4.031 |
| constant-hydrostatic-256x256x65 | 97.500 | 0.408 | 3.131 | 2.990 |
| constant-nonhydrostatic-512x512x129 | 1032.000 | 4.449 | 31.785 | 31.608 |
| constant-hydrostatic-512x512x129 | 774.000 | 3.220 | 24.799 | 24.086 |
