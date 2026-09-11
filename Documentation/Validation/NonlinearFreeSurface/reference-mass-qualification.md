# Internal reference-geometry mass inverse

> Historical evidence. This report describes the retired weak/pressure implementation or its comparison studies. The executable solvers have been removed; see the [direct runtime qualification](direct-runtime-qualification.md) for the current implementation. Historical source links refer to revision `7b9ccda7`.

`WVInternal.freeSurfaceReferenceMass(wvt)` constructs a context with `solve(covector)`. It inverts the full positive reference-geometry weak mass using independent compact Fourier columns. It is not `projectSources`, a nonlinear pressure closure, or an activated evolution path. No new modal families or global realified basis matrix are introduced.

For one nonzero Fourier column, let $U,V,W,E,C$ be its stored-mode reconstruction matrices in family order `Ag_q`, `Ag_0`, `Aw_p`, `Aw_m`, retaining only the page's active wave prefix. The raw complex coefficient Gram is

$$
H_0 = 2\left(U^* Q U + V^* Q V + W^* Q W + E^* Q N^2 E + g C^* C\right),
$$

where $Q$ contains the stored vertical quadrature weights. The factor two accounts for the represented Fourier conjugate. All cross terms are retained, including the generally nonzero APV/endpoint terms. The horizontal mean has separate inertial Gram $4 F^* Q F$ and real MDA Gram $G^* Q N^2 G + g C_{\rm mda}^* C_{\rm mda}$, using the actual stored MDA pressure trace divided by $g$ for $C_{\rm mda}$.

Orientation sharing follows from the actual polarization equations. At horizontal magnitude $\kappa$, balanced horizontal velocity is $i\kappa\psi e_\perp$, while a wave's horizontal velocity is $F(e_\parallel + i\sigma f e_\perp/\omega)$. The real orthogonal rotation carrying these unit vectors into the horizontal Cartesian axes preserves every horizontal inner product. The vertical velocity, displacement, and SSH columns depend only on $\kappa$. Thus every orientation on a stored `khUnique` page has the same full reference Gram, including the cross-family entries. The implementation computes one block in the orientation $(k,l)=(\kappa,0)$ and shares it across the page's columns. This reasoning applies to the horizontally uniform reference metric; it does not justify sharing blocks for a nonflat or horizontally varying nonlinear mass.

For each block, diagonal scaling $S=\operatorname{diag}(\sqrt{\operatorname{diag}H_0})$ and Cholesky $R^* R = S^{-1}H_0S^{-1}$ give the raw coefficient whitening map $T=S^{-1}R^{-1}$, with $T^*H_0T=I$. The context exposes the small `upperFactor`, `diagonalScale`, and `whitening` matrices, as well as page `columns`, `familyOrder`, `familySizes`, and positive-wave `frequency`. Mean factors use the same convention. These are internal solver metadata. The full field reconstruction matrices are temporary per-page construction arrays and are not stored in the context.

At current time $\tau=t-t_0$, let $D$ have entries one on balanced families and $\exp(\pm i\omega\tau)$ on the wave families. Then $R_\tau=R_0D$, $H_\tau=D^*H_0D$, and $H_\tau^{-1}=D^*H_0^{-1}D$. The returned solve reads the transform's current clocks, rotates the covector by $D$, applies the stored scaled triangular solves, then rotates the result by $D^*$. Inertial coefficients use their corresponding unitary phase. Covectors must have the canonical six-family shapes, real MDA entries, and zero inactive wave entries. Unsupported entries are rejected rather than silently discarded.

The context freezes the modes, geometry, counts, vertical weights, reference $N^2$, $f$, and $g$ at construction. Its owner must rebuild it if those dependencies change. Advancing either clock does not require rebuilding. It does not read or alter evolving coefficients when applying a solve.

## Verification ledger

The helper depends on the independently authored reconstruction adjoint and frozen-stage mass action from upstream workstream commits `a7569d2c` and `f20fe96c`. Those were cherry-picked locally only to execute the focused tests; they are not additional authored changes in this increment.

`UnitTests/TestFreeSurfaceReferenceMass.m` exercises three independent numerical checks:

- Exponentially stratified 8-by-8-by-65 grids with page counts cycling through 0, 1, 2, and 3. At three clocks, applying the existing full `freeSurfaceWeakMassAction` with flat metric and then the new inverse recovers a deterministic mixed state. Every family's relative coefficient error is below $2\times10^{-9}$ and the reapplied covector error is below $2\times10^{-10}$. The context is constructed once before changing clocks; inactive padding and original state are checked. Invalid nonzero padding and complex MDA covectors are rejected.
- Every retained orientation on an 8-by-8-by-33 grid is independently reconstructed through `reconstructSpectralState`. Its resulting physical Gram obeys $\|T^*H T-I\|_2 < 5\times10^{-11}$ using the shared page whitening. The fixture's normalized APV/endpoint cross block has norm greater than $10^{-3}$, so dropping balanced cross terms would be detected.
- A southern-hemisphere 4-by-4-by-33 fixture with all wave pages zero and both endpoint families inactive recovers the remaining APV, inertial, and MDA coefficients. The two mean whitening identities hold to $5\times10^{-13}$ absolute tolerance. The supported empty wave/endpoint arrays remain empty; the authoring factory requires positive APV, inertial, and MDA counts, so no unsupported empty-mean constructor was invented.

All three focused tests passed after final preallocation changes; Code Analyzer passed for both new MATLAB files. Whitespace and repository-scope checks passed. No package manifest, released snapshot, public API, generated documentation, or production evolution entry point changed. This qualifies only the reference mass inverse on the stated fixtures. Nonflat preconditioner effectiveness, the coupled constrained solve, and trajectories using that solve remain separate integration gates.
