# Free-Surface QG Coefficient-Storage Benchmark

Decision: `separate`.

Separate backing is retained because packed backing did not prove a practically meaningful fixed-RK4 improvement in every case.

| Case | packed/separate RK4 median | 95% interval | packed/separate state bytes |
| --- | ---: | ---: | ---: |
| small-zero-endpoint | 1.0921 | [0.8259, 1.4060] | 1.0007 |
| small-one-endpoint | 1.0473 | [0.7847, 1.4033] | 1.0006 |
| small-two-endpoint | 1.0209 | [0.6545, 1.3233] | 1.0005 |
| representative-zero-endpoint | 1.0134 | [0.9748, 1.0525] | 1.0000 |
| representative-one-endpoint | 1.0129 | [0.9676, 1.0588] | 1.0000 |
| representative-two-endpoint | 0.9988 | [0.9148, 1.0379] | 1.0000 |

RSS values are fresh-process total live-process-tree measurements; exact state bytes are MATLAB payload bytes reported by `whos`.
