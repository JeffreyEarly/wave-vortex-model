# Internal reference boundary Schur inverse

`WVInternal.freeSurfaceBoundarySchur(wvt,boundary,referenceMass)` returns an internal context whose `solve(traceVector)` applies the inverse of $S=K H_{\rm ref}^{-1}K^*$. It consumes the retained-boundary metadata and Fourier-page reference-mass whitening; it does not change modes, remove traces, activate dynamics, or construct a global matrix.

For a nonzero page, write the unweighted complex trace map as $C$ and the raw coefficient whitening as $T$, with $T^*H_0T=I$. The boundary operator packs the real and imaginary traces with $\sqrt{2}$, so its Schur action on the packed complex vector $v_{\rm Re}+i v_{\rm Im}$ is

$$
S_{\rm complex}=2 C T T^* C^*.
$$

The implementation factors this small complex Hermitian matrix. Its action on a real packed vector automatically includes the real/imaginary coupling represented by $[\operatorname{Re}S,-\operatorname{Im}S;\operatorname{Im}S,\operatorname{Re}S]$. The actual current physical trace blocks are real; a synthetic complex invertible trace change independently exercises the more general coupling in the tests. Endpoint means use the real block $C_{\rm mean}T_{\rm mda}T_{\rm mda}^*C_{\rm mean}^*$ without the factor two.

Reference phases cancel: $K_\tau=K_0D$ and $H_\tau^{-1}=D^*H_0^{-1}D$ imply $K_\tau H_\tau^{-1}K_\tau^*=K_0H_0^{-1}K_0^*$. These Schur factors are therefore independent of both phase clocks. The owner must rebuild the boundary, reference mass, and Schur contexts together when changing their frozen scientific dependencies.

Each page and the mean expose `diagonalScale`, `upperFactor`, and `reciprocalCondition`; pages also expose their `kh` and compact `columns`. The context records the trace names, packed dimension, and `minimumReciprocalCondition=1e-12`. Cholesky and conditioning checks operate after diagonal normalization. A nonpositive, rank-deficient, or insufficiently conditioned block throws `WV:BoundarySchurRank`; no dependent trace is silently dropped. An empty trace inventory, including an empty mean block, has a well-defined empty solve. The conditioning cutoff is an explicit numerical admissibility gate, not an assertion that every formally full-rank inventory is well resolved.

## Verification ledger

The helper uses root workstream commits `7b793acd` and `edd0882d` for the real coefficient layout and boundary operator, and `057e547b` for the reference mass. The first two were cherry-picked locally as dependencies, not authored again in this increment.

All three methods in `UnitTests/TestFreeSurfaceBoundarySchur.m` passed:

- Four endpoint inventories (both, surface only, bottom only, neither) on exponentially stratified 8-by-8-by-65 grids, with wave counts cycling through zero, one, and two, at three changing phase clocks. The solve is compared in both directions with the independently composed `boundary.apply(reference.solve(boundary.adjoint(v)))`; relative errors are below $2\times10^{-10}$. The same Schur context is reused, and original coefficients and clocks are checked.
- A transform with one MDA mode and two active mean endpoint traces explicitly rejects the unsupported mean constraint inventory with the rank/conditioning error.
- A complex invertible change of nonzero trace coordinates recovers an independently applied metadata Schur action within $2\times10^{-11}$ relative error. A fully empty trace inventory returns a 0-by-1 result.

The focused suite took approximately 10.4 s including transform construction. Code Analyzer passed for both new MATLAB files, and whitespace/scope checks passed. No public API, package metadata, released snapshot, generated documentation, or production evolution path changed. This qualifies the reference Schur inverse on these fixtures; it does not establish convergence or efficiency of the forthcoming coupled nonlinear solver.
