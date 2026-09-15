# Direct manuscript integration into WVM

The runtime now follows `dA/dt = S - Pi[N+P]`: reconstruct the resolved modal state, evaluate Appendix C, sum registered equation sources and apply the source projector once. Analytical phases remain in reconstruction. The previous weak mass, trace-constraint and pressure-solver implementation has been removed, including its executable authoring solvers. No fallback or solver-selection API remains.

See the [field and runtime contract](field-and-runtime-contract.md) for variable, pressure, forcing, energy and restart semantics. The boundary and trajectory drivers in this directory retain the analytic thermodynamics and physical budget diagnostics used as independent controls for the production callback. The implementation history and review are available in [commit `84c9346a`](https://github.com/JeffreyEarly/wave-vortex-model/commit/84c9346a).

Historical weak/pressure comparison sources are available at [the last pre-replacement revision](https://github.com/JeffreyEarly/wave-vortex-model/tree/7b9ccda7/tools/nonlinear-study); they do not qualify or describe the current runtime.
