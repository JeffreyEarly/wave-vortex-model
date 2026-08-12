# Issue #128 Donut confirmation

Decision: **CORE-REJECT confirmed**.

This reduced same-host check confirms Lyra's complete standalone result using the exact pinned FFTW++, FFTW 3.3.11, and LLVM OpenMP sources on Donut. It compares the best FFTW++ hybrid candidate with the matched pthread explicit implementation at 16 threads on the medium \(128\times128\times33\) workload. Each run used two warmups and three samples.

| Case | pthread explicit | FFTW++ hybrid | Hybrid speedup | Exact max-live change | Error |
|---|---:|---:|---:|---:|---:|
| Hydrostatic | 0.007160 s | 0.025937 s | 0.276x | -5.18% | 1.76e-14 |
| Nonhydrostatic | 0.009216 s | 0.031707 s | 0.291x | +0.46% | 1.98e-14 |

Hybrid is 3.62 times slower hydrostatically and 3.44 times slower nonhydrostatically. It does not reach either the 10% speed gate or the 10% exact maximum-live memory gate for both configurations. The full Lyra finding is therefore directionally reproduced on Donut; repeating the finalist protocol would not change the decision.

The selected boundary passed to issue #130 remains explicit native FFTW 3.3.11 NEON/pthreads with the issue #126 coefficient representation and issue #127 fused inverse normalization.
