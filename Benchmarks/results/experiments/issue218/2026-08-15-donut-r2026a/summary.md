# Issue #218 tracer-advection result

Outcome: **RESOLVED**.

The apparent portable tracer bottleneck was not the steady numerical pipeline. The first antialiased tracer call lazily constructed an FFTW scalar inverse plan inside the first timed RK4 right-hand-side evaluation. Preparing that plan when the integration system is constructed reduced complete one-step integration time by 76.8–79.6% while preserving the complete saved output graph.

| Configuration | Control integration | Candidate integration | Speedup | Control tracer | Candidate tracer | Tracer speedup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hydrostatic | 3.785 s | 0.774 s | 4.89× | 3.195 s | 0.165 s | 19.31× |
| Nonhydrostatic | 3.854 s | 0.894 s | 4.31× | 3.083 s | 0.166 s | 18.57× |

Candidate antialiasing itself took 0.0288 s hydrostatically and 0.0284 s nonhydrostatically. Construction increased by approximately 2.8–3.4 s because the work moved to the intended preparation phase. Peak RSS did not regress.

The hydrostatic complete-output comparison covered 54 variables and 80 records, with maximum relative error `2.70e-16`. The nonhydrostatic comparison also passed, with maximum relative error `1.75e-19`.

The implementation is deliberately small: expose scalar-advection preparation in the kernel, call it during integration-system construction only when an antialiased tracer exists, and verify that RHS evaluation creates no plans or array-sized storage. No tracer algorithm, storage layout, or public MATLAB API changes.
