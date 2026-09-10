# Forcing integration foundation

The base registry calls the protected `validateForcingInventory(self,forcing)` hook after resolving names and sorting priorities, before committing state or firing removal/change callbacks. The base hook is a no-op. The free-surface Boussinesq override accepts reference-coordinate prescribed sources in linear mode; physical-coordinate sources require nonlinear advection in the effective inventory. Nonlinear advection requires existing `shouldAntialias` and `shouldCheckQuadraticAliasing` qualification, and only advection/prescribed-source classes are supported. Registration never reselects modes.

`nonlinearAdvectionSources(self,stage)` returns the four hatted zero-pressure excesses $F_{\rm full}(p=0)-(f\hat v,-f\hat u,-N^2\eta,\hat w)$. It uses the existing full mapped tendency, including its geometric vertical-momentum coupling. Optional shared hatted/physical/thermodynamic fields avoid spectral reconstruction and thermodynamic reevaluation; the standalone path uses the transform's cached thermodynamics and performs no pressure or weak solve. Portable implementation capability remains unavailable for this transform, while legacy contracts remain supported.

Verification on the pinned `../oceankit-beta-publish` dependencies:

- New forcing integration tests: 4 passed. Covers effective-name replacement, batch atomicity, removal atomicity, both qualification flags, unchanged scientific inventory, portable status, independent analytic mapped mean flow, and standalone/shared callbacks.
- Updated nonlinear-advection activation guard plus legacy forcing lifecycle: 8 passed. Object construction, conversion, and restoration are permitted; unqualified registry activation remains rejected. Legacy flux, registry, conversion and persistence controls remain green.
- Code Analyzer on all six changed MATLAB files: zero blocking findings; 11 existing style/performance findings in the base transform and legacy advection methods.
- Whitespace and authored-file scope checks passed; package metadata unchanged. No missing assets.

The Boussinesq class declarations are supplied by root commit `37a21267` (locally cherry-picked as `1ae3f734`), outside this authored commit. The coordinator owns runtime stage/evolution wiring and physical-source fixture updates. Canonical advection help now distinguishes legacy formulas from mapped free-surface excesses; documentation generation/check belongs to the coherent integration batch, avoiding competing generated-site updates.
