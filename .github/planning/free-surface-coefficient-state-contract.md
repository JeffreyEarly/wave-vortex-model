# Free-Surface Coefficient-State Contract

Status: Accepted Phase 1 design contract for [issue #343](https://github.com/JeffreyEarly/wave-vortex-model/issues/343) and [issue #344](https://github.com/JeffreyEarly/wave-vortex-model/issues/344).

This document freezes the logical coefficient state for the free-surface quasigeostrophic prototype before storage, integration, or persistence code is implemented. The prototype is the proving ground for a later full-Boussinesq coefficient model. Existing transforms are not compatibility constraints for this phase and may temporarily break as the prototype changes shared infrastructure.

## Authoritative sources

The scientific definitions come from the free-surface APE/APV manuscript and its closed QG note. Those sources are maintained in the workspace literature repository at commit `361a8dc0031fd5dc355dd06141cb0881dd23699e`:

- `literature/ape-apv-free-surface/main.tex`, especially `projection-complete-modal-expansion`, `surface-modes-boundary-coefficient-vector`, and `zero-apv-boundary-depth-rotation`
- `literature/ape-apv-free-surface/notes/gpt-closed-free-surface-qg.tex`, especially `closed-qg-apv-reconstruction`, `closed-qg-zero-apv-reconstruction`, `closed-qg-mda-reconstruction`, and `closed-qg-orthogonal-coordinate-tendency`

[Issue #341](https://github.com/JeffreyEarly/wave-vortex-model/issues/341) records the closed mathematical contract and its sign audit. The reviewed provider interface is [`IMGeostrophicTransform`](https://github.com/JeffreyEarly/internal-modes/blob/b0ab431f8b1ed2f36c1b1acad10684ac80b669a3/%40IMGeostrophicTransform/IMGeostrophicTransform.m) at InternalModesEVP commit `b0ab431f8b1ed2f36c1b1acad10684ac80b669a3`. This hash identifies the review baseline; it does not pin the installed package to a tag or commit. During rapid development, the active MATLAB installation must resolve to the `InternalModesEVP` branch as established by issue #342.

## Coefficient-family names

An underscore separates a modal family from its subtype. The QG prototype implements the geostrophic APV, geostrophic zero-APV, and mean-density-anomaly families. Names for the oscillatory families are reserved now so the convention extends without reinterpretation.

| Mathematical amplitude | MATLAB identifier | Horizontal domain | QG prototype |
| --- | --- | --- | --- |
| $A_{\mathrm{g},q}$ | `Ag_q` | $k_h>0$ | canonical state |
| $A_{\mathrm{g},0}$ | `Ag_0` | $k_h>0$ | canonical state |
| $A_{\mathrm{mda}}$ | `Amda` | $k_h=0$ | canonical state |
| $A_{\mathrm{w},+}$ | `Aw_p` | $k_h>0$ | reserved |
| $A_{\mathrm{w},-}$ | `Aw_m` | $k_h>0$ | reserved |
| $A_{\mathrm{io}}$ | `Aio` | $k_h=0$ | reserved |

`Aio` and `Amda` contain no underscore because `io` and `mda` each identify a complete family rather than a family/subtype pair. The legacy identifier `A0` is not an alias for `Ag_0`: `A0` historically combines several zero-frequency roles, whereas `Ag_0` denotes only the boundary-normalized zero-APV family at nonzero horizontal wavenumber.

## QG logical state

The canonical public state consists of three directly mutable properties. Dimension order keeps the family-local vertical or endpoint axis first and the compact horizontal axis second, matching the leading-dimension convention of InternalModesEVP.

| Property | Dimensions | Shape | MATLAB values | Units | Canonical basis |
| --- | --- | --- | --- | --- | --- |
| `Ag_q` | `apvMode, klNonzero` | `Nj × NklNonzero` | complex `double` | $\mathrm{s^{-1}}$ | generalized-energy APV modes |
| `Ag_0` | `activeEndpoint, klNonzero` | `Ne × NklNonzero` | complex `double` | $\mathrm{s^{-1}}$ | boundary-normalized zero-APV responses |
| `Amda` | `mdaMode` | `Nj × 1` | real `double` | $\mathrm{m}$ | signed-normalized MDA modes |

`Nj` is one retained-count decision applied to both the APV and MDA bases. Equal counts do not make those bases interchangeable. `apvMode` and `mdaMode` are distinct ordinal dimensions of length `Nj`, with the physical labels stored separately as `apvModeNumber(apvMode)` and `mdaModeNumber(mdaMode)`.

`klNonzero` contains exactly the entries of the existing compact `kl` grid for which $k_h>0$. Its coordinate values retain the original `kl` indices rather than being renumbered. The corresponding `k`, `l`, and $k_h$ values are auxiliary coordinates. The horizontal mean is therefore absent from `Ag_q` and `Ag_0`, not represented by a constrained zero column.

`activeEndpoint` is the finite-acceleration subset of `["surface","bottom"]` in that canonical order. `Ne` is its length. Inactive endpoints do not occupy zero-filled rows. When both endpoints are inactive, `Ag_0` is a valid complex array with shape `0 × NklNonzero`.

The three amplitudes are zero-frequency state, so the QG prototype does not define separate current-time amplitude views analogous to legacy `Apt`, `Amt`, or `A0t`.

## Projection coordinates

For each nonzero horizontal wavenumber, `Ag_q` is obtained by projecting APV first. In manuscript notation,

$$
\widehat q^{k\ell}(\xi)=\sum_j A_{\mathrm{g},q}^{k\ell j}F_\mathrm{g}^j(\xi).
$$

`Ag_0` then contains the residual boundary-normalized endpoint response. Restricted to active endpoints,

$$
\mathbf A_{\mathrm{g},0}^{k\ell}=-\frac{g k_h^2}{f}\left(\widehat{\mathbf b}^{k\ell}-\mathsf R_{\mathrm{g},q}^{k_h}\mathbf A_{\mathrm{g},q}^{k\ell}\right),
$$

and reconstruction satisfies

$$
\widehat{\mathbf b}^{k\ell}=\mathsf R_{\mathrm{g},q}^{k_h}\mathbf A_{\mathrm{g},q}^{k\ell}-\frac{f}{g k_h^2}\mathbf A_{\mathrm{g},0}^{k\ell}.
$$

The rows of public and persisted `Ag_0` therefore retain stable surface and bottom identities. An implementation may rotate to generalized-energy-orthogonal coordinates internally using

$$
\mathbf A_{\mathrm{g},0}^{k\ell}=C^{k_h}\mathbf A_{\mathrm{g},0,\mathrm{orth}}^{k\ell},
$$

but the rotation, its coordinates, and any packed storage are not canonical state. Public reads, public writes, forcing interfaces, and persistence all cross the boundary-normalized interface.

At $k_h=0$, `Amda` reconstructs the horizontally averaged interior displacement in the zero-mean SSH gauge,

$$
\overline\eta_i(\xi)=\sum_j A_\mathrm{mda}^jG_\mathrm{mda}^j(\xi).
$$

The MDA coefficients are an independent mean-state vector; they are never stored in a mean column of either geostrophic nonzero-wavenumber family.

## Endpoint configurations

Finite includes zero. Positive infinity makes an endpoint inactive, removes its zero-APV response, and imposes its MDA endpoint constraint.

| `g0` | `gd` | `activeEndpoint` | `Ag_0` shape | MDA endpoint conditions | Constant MDA null mode |
| --- | --- | --- | --- | --- | --- |
| finite | finite | `surface, bottom` | `2 × NklNonzero` | Robin, Robin | permitted |
| finite | `Inf` | `surface` | `1 × NklNonzero` | Robin, $G_\mathrm{mda}(-D)=0$ | excluded |
| `Inf` | finite | `bottom` | `1 × NklNonzero` | $G_\mathrm{mda}(0)=0$, Robin | excluded |
| `Inf` | `Inf` | empty | `0 × NklNonzero` | $G_\mathrm{mda}(0)=G_\mathrm{mda}(-D)=0$ | excluded |

When no endpoint is active, WVM uses the APV transform directly for $k_h>0$; it does not construct `IMGeostrophicTransform`, which intentionally requires at least one active endpoint. The empty `Ag_0` property and tendency field remain present so the public family set does not depend on endpoint configuration.

## Public mutation and tendencies

Canonical state is read and written directly:

```matlab
wvt.Ag_q = Ag_q;
wvt.Ag_0 = Ag_0;
wvt.Amda = Amda;
```

Assignment must validate the declared shape, numeric domain, and reality constraint, then invalidate every diagnostic cache derived from coefficient state. No `Ap`, `Am`, or `A0` compatibility aliases are part of the prototype.

Nonlinear dynamics and spectral forcing exchange one scalar, family-keyed tendency structure:

```matlab
tendency.Ag_q
tendency.Ag_0
tendency.Amda
```

All three fields are always present in canonical order, including an empty `Ag_0` field for the inactive-both configuration. Each field has the same shape and numeric domain as its state property. Its units are the corresponding state units per second: `Ag_q` and `Ag_0` tendencies have units $\mathrm{s^{-2}}$, and the `Amda` tendency has units $\mathrm{m\,s^{-1}}$.

Generic integration and forcing machinery must discover coefficient families from an ordered descriptor rather than hard-code property names or output positions. Each descriptor record contains these fields:

| Field | Meaning |
| --- | --- |
| `identifier` | coefficient property and tendency-field name |
| `dimensions` | ordered logical dimensions |
| `auxiliaryCoordinates` | physical labels and coordinate mappings |
| `units` | canonical state units |
| `numericDomain` | real or complex `double`, including empty-state validity |
| `canonicalBasis` | scientific coordinate basis exposed publicly |
| `persistenceRole` | `canonicalState` for persisted coefficient families |

The QG descriptor order is `Ag_q`, `Ag_0`, `Amda`. The descriptor defines the logical interface only. It does not prescribe whether an integrator receives separate arrays, cells, views into packed storage, or another benchmarked adapter.

## Persistence boundary

The three logical coefficient families are canonical restart state. Their family identities, logical dimensions, auxiliary coordinates, and canonical bases must survive a round trip. In particular, a file never exposes orthogonal zero-APV coefficients in place of boundary-normalized `Ag_0`.

Persistence also includes the complete sampled mathematical representation needed to resume without rerunning an InternalModes solver: APV and MDA mode labels, sampled `F/G` modes, equivalent depths, forward matrices, zero-APV pages, endpoint responses, `F/G` source-pairing matrices, source-solve matrices, resolved coordinates and endpoint parameters, and compact certification results. These arrays are scientific restart state, not disposable runtime caches.

Packed integrator buffers, Fourier plans, horizontal masks, derived-variable caches, and runtime forcing or closure caches are not persisted. Orthogonal zero-APV rotations may be persisted as diagnostic operators when useful, but they never replace the canonical boundary-normalized coefficient state.

An inactive zero-APV family is physically omitted. When `activeEndpointCount=0`, the file contains no `activeEndpoint`, `Ag_0`, or zero-APV mode/operator variable. The logical MATLAB property and tendency field remain empty arrays with shape `0 × NklNonzero`.

Model-output records use their unlimited `t` coordinate as the commit marker. Payload variables are staged and synchronized before the corresponding finite `t` value is written and synchronized. Readers accept only the contiguous finite prefix of `t`, reject finite values after a fill-valued hole, and overwrite the first uncommitted index when resuming.

## Full-Boussinesq extension

The later full-Boussinesq model extends the ordered family set with `Aw_p`, `Aw_m`, and `Aio` while retaining `Ag_q`, `Ag_0`, and `Amda`. This contract reserves the identifiers and their modal roles, not their storage layouts.

Wave bases may have page-dependent physical mode labels and page-dependent retained counts. A future wave-family descriptor must therefore be able to associate mode metadata and validity with horizontal pages. Phase 1 does not choose a padded rectangular matrix, a ragged coefficient vector, or another representation. State and tendency fields will share whichever logical shape that later contract selects.

The QG prototype must not introduce a universal one-dimensional `j` coordinate or another descriptor restriction that would prevent such page-dependent metadata. `Aio` and `Amda` remain separate $k_h=0$ families rather than occupying special columns of `Aw_p`, `Aw_m`, or a generic zero-frequency array.

## Acceptance matrix for later implementation

These scenarios define the executable contract to be implemented after the storage decision.

| Scenario | Required result |
| --- | --- |
| Pure APV | Random complex `Ag_q` with zero `Ag_0` reconstructs APV and the APV endpoint signature, then recovers the original coefficients. |
| Pure zero APV | Each active unit row of `Ag_0` reconstructs zero APV and its prescribed unit boundary-normalized response, then round-trips. |
| Mixed nonzero state | Random `Ag_q` and `Ag_0` reconstruct $(q,b_0,b_d)$ and recover both arrays at every retained horizontal page. |
| MDA mean state | Random real `Amda` reconstructs the permitted horizontal-mean displacement, respects inactive endpoint constraints and the zero-mean SSH gauge, and round-trips independently. |
| No active endpoint | `Ag_0` and its tendency are `0 × NklNonzero`; APV and MDA remain independently usable. |
| Direct mutation | Assigning any canonical property validates its contract and invalidates all coefficient-dependent cached diagnostics. |
| Tendency dispatch | Dynamics and every spectral forcing stage receive and return exactly the three family fields with state-matching shapes. |
| Coordinate identity | `klNonzero`, APV mode numbers, MDA mode numbers, and active endpoint identities survive logical persistence without renumbering or conflation. |

Round-trip tolerances, representative grids, and performance cases belong to their implementation and benchmark issues. The scientific pass condition is comparison to the admissible state projected by InternalModesEVP, not comparison to legacy `A0` layout.

## Deferred decisions and non-goals

The reference implementation uses separate coefficient arrays and separate integrator entries. Issue #343 retains a packed candidate behind a private adapter and owns measurements of warmed RHS time, projection/reconstruction time, integrator copying, and memory after the complete nonlinear RHS exists. Public properties and NetCDF storage do not change with that benchmark. An internal orthogonal `Ag_0` representation is one candidate, not a public contract change.

Future full-Boussinesq wave storage remains deferred. The QG prototype does not add compatibility aliases or a migration from the legacy `A0` layout.
