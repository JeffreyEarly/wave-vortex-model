# Advisory assessment integration proposal

This proposal introduces no runtime API or default change. It describes a separately reviewable increment if the completed comparison justifies one.

## Reuse the existing calculation contracts

InternalModes already owns resolved F/G bases, fixed-grid sampled pairings, signed target Gram matrices, positive target majorants, active-mode masks, and prefix diagnostics. Factor the common product-projection calculation into an internal stateless engine that accepts prepared sampled/reference pairings and an explicit target pairing recipe. Its existing same-family FF->F, GG->F, and FG->G assessment should remain a client with unchanged results. WVM would supply the physical wave generalized-energy source dual and actual mean/inertial recipes. The study's `prepareProductProjection`, `sourceProjectionContext`, and `measureProductProjection` demonstrate these boundaries; their regression tests compare the provider controls and WVM's actual source route.

Keep signed projection and positive error measurement separate. A target majorant must never be substituted for the signed projection Gram matrix. Wave volume-source projection has zero independent surface source; the surface contribution to the target energy remains in the continuous normalization. MDA and APV pairings retain their required signed endpoint terms.

## WVM orchestration and result

An authoring or advisory method, provisionally `assessWaveQuadraticResolution`, should reuse already-resolved page modes and the constructor's fixed z/weights. Its inputs should include independent family counts, a documented interaction policy, product tolerance, reference allowances, and an explicit evaluation budget. The first version retains a uniform wave count across pages and both frequency signs. It does not alter storage, persistence, the physical grid, quadrature weights, or eigenfunctions.

A result should expose:

- `status`: assessed, rejected, or reference-inconclusive.
- `largestSampledCount`: explicitly described as “largest count passing the sampled interaction checks.”
- Separate eigenvalue/mode/derivative resolution, linear Gram, quadratic-prefix, and reference-stability diagnostics.
- Requested and examined family counts; unchanged fixed-family counts; any rejection of their existing independent gates.
- Per-count limiting interactions with exact integer/physical wavevectors, family names, scientific mode labels, frequency signs, source term, and output pairing.
- Coverage: candidate/selected interaction and mode-pair inventories, known structural zeros, omitted source/output channels, total possible bounded-survey inventory when known, policy version, and selection provenance.
- Evaluation count, reference-construction/assessment time, and numerical dependencies.

Reports should identify the maximum over tested individual products. They must not call it a guarantee for every triad, a worst-case superposition bound, or a trajectory-error estimate. Chebyshev tails describe why a test was selected, not whether it is numerically acceptable.

## Strict counts and adoption

Explicit counts remain strict. If an explicit wave count fails a required gate, report/reject it with the limiting evidence; do not replace it with the sampled accepted count. If references are inconclusive, report that distinct status rather than silently accepting or shrinking. Fixed APV, boundary, MDA, and inertial counts remain independent. Only a separately authorized omitted-wave-count workflow could adopt a selected common prefix.

The current constructor's wave count and Gram gate remain unchanged in this study. Runtime adoption would need its own tests of constructor failure behavior, omitted versus explicit counts, reuse of resolved modes, and preserved coefficient shapes. No release/dependency change is needed for the authoring comparison itself. If a later provider API is published, release/export that provider before raising WVM's dependency floor.
