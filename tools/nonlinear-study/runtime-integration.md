# Direct manuscript integration into WVM

The runtime now follows `dA/dt = S - Pi[N+P]`: reconstruct the resolved modal state, evaluate Appendix C, sum registered equation sources and apply the source projector once. Analytical phases remain in reconstruction. The previous weak mass, trace-constraint and pressure-solver implementation has been removed, including its executable authoring solvers. No fallback or solver-selection API remains.

See the [field and runtime contract](field-and-runtime-contract.md) for variable, pressure, forcing, energy and restart semantics, and the [runtime qualification](../../Documentation/Validation/NonlinearFreeSurface/direct-runtime-qualification.md) for current evidence. The manuscript [boundary and trajectory studies](../../Documentation/Validation/NonlinearFreeSurface/manuscript-evolution-qualification.md) remain available as reproducible authoring tools. Their analytic thermodynamics and physical budget diagnostics provide independent controls for the production callback.

Historical weak/pressure comparisons and their measured results are retained as labelled reports. Their executable sources are available at [the last pre-replacement revision](https://github.com/JeffreyEarly/wave-vortex-model/tree/7b9ccda7/tools/nonlinear-study); they do not qualify or describe the current runtime.
