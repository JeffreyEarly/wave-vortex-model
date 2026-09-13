# MATLAB stratified primitive boundary (#504 / #505)

This increment generalizes the private #503 adapter to Hydrostatic, Boussinesq and Stratified QG. It does not yet enable public `computationalBackend="compiled"` construction for these families. Public routing, constant and Barotropic QG migration, shared consumer events and final package qualification remain campaign work.

One variant-owned forcing engine and its borrowed field service reuse each model's solved MATLAB matrices. Boussinesq transfers exact one-based group membership and wave matrices once. QG stores only A0. Mixed evaluation returns three wave fluxes or one QG flux; its current QG mixed request shares u/v only. Fields-only evaluation remains a separate call scope. Full cross-consumer sharing belongs to #506.

`transformOperation(handle,name,inputs,options)` returns ordered `values` cells and metrics. Raw vertical operators accept complex `[Nj,Nkl]` or `[Nz,Nkl]` arrays; column operations accept `[rows,1]` and a one-based retained column. They call the existing prepared matrix operators without an FFT. H/QG expose four F/G operators; B exposes its eleven prepared balanced/wave operators. Compact staging uses existing scratch and adds no persistent matrix, FFT plan or scientific workspace.

Horizontal operations preserve MATLAB retained Fourier order and normalization. Full-grid derivatives use one existing FFT pair and `(ik)^n` with normalization once. Even-order Nyquist terms survive; odd-order terms vanish. The existing order-one arithmetic is retained. Raw spatial-to-wave projections take explicit t/t0. MATLAB's SQG `transformUVEtaToWaveVortex` retains its three-output signature with A0 as the third result; the internal native QG ABI returns only A0. Public routing must preserve that distinction.

Inputs are borrowed for one MEX invocation. Outputs are MATLAB-owned and publish only after success; strict shapes and operation names reject unsupported requests. Source identity, mixed legacy handles, deletion, exception unwinding and bounded plan replacement retain the #503 ownership contract. Bridge version 2 prevents use of an older installed module.

## Verification ledger

- Existing Hydrostatic/Boussinesq/StratifiedQG kernel tests pass after the primitive additions.
- Independent raw primitive test passes in established and compact schedules for all three families, including every fixture column, all eleven B operators, retained Fourier roundtrips, full-grid derivative orders 1/2/4, Nyquist, alias rejection and unchanged persistent storage.
- MEX build and its constant-family installation checks pass on R2025b Update 4 with FFTW 3.3.11 and Accelerate.
- Five new MATLAB primitive/field methods pass, using the latest isolated rerun for a corrected complex-zero assertion. Seven existing adapter lifecycle methods pass. No production tolerance was relaxed. Initial draft test failures included incorrectly sized column inputs and treating SQG's first MATLAB output as A0; these were harness errors corrected before qualification.
- Small exponential H/B/SQG mixed and fields-only errors are below 6.3e-16. These are correctness checks, not performance measurements.
- One Code Analyzer pass reports no messages for the two changed production MATLAB files and the new test. One docs check passes: 2026 files, 4145 routes, no generated differences.
- The checked-in receipt records this bounded proof and changed-source hashes. The full installed-module source receipt and all-six public campaign qualification remain #507. No performance claim or release tag is made here.
