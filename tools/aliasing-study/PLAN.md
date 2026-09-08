# Issue 400: sparse quadratic-product assessment

Status: pilot development; the case matrix and policies are not yet frozen.

## Provenance and scope

The authoring base is WVM `9fefcc9a528de65e2f348706c45b13f741754a78` on `feature/v5.0-free-surface-qg`. Dependency PR 397 merged on 2026-09-08. InternalModes is the published `2.0.0-beta.1` snapshot exported by OceanKit `80006f5040da787465860249f975def9831624c8`, from provider `4086f978b36a4100e7419688ab355591c8253ef1`. Other dependencies come from that same OceanKit revision. This authoring study must not modify released snapshots or runtime defaults.

The study measures individual products projected into retained families. It does not bound arbitrary superpositions, trajectory errors, or the full nonlinear Boussinesq operator. Keep eigenproblem convergence, sampled linear projection, product aliasing, and physical truncation separate. No fitted modes, fitted weights, or silently reduced explicit counts are permitted.

## Before observing pilot results

- Initial pilot: constant stratification, depth 1000 m, horizontal domain 10 km square, an actual 8 by 8 Fourier grid with the existing horizontal retention mask, 17 vertical WKB-Chebyshev points, 8 candidate wave modes including the external mode. Both boundary modes are active.
- Initial independent counts: 4 APV, 3 MDA, 6 inertial. Wave-count comparisons must preserve these independent counts. APV's existing same-family assessment is a separate control.
- Candidate production-mode EVP order 128; independent resolution check at 192. Reference integrations at 257 and 513 points, evaluating the same modes. These are study choices, not proposed runtime defaults.
- Reference-stability allowance: 0.0001 absolute normalized product error (1% of the smallest tested tolerance, 0.01). Also require relative eigenvalue and positive mode/derivative norm convergence below 0.000001. Any failure makes the affected case inconclusive, never accepted evidence.
- Product tolerances: 0.1, 0.03, 0.01. Linear Gram gate: 0.0000001.
- Measure construction separately from product assessment. Record evaluation inventory, elapsed time, and process peak memory. Freeze a feasible calibration/withheld inventory only after this pilot establishes cost.

## Channel derivation and coverage decisions

`Forcing/WVNonlinearAdvection.m` specifies horizontal momentum advection with vertical factors FF, vertical advection of horizontal momentum with G dF/dz, horizontal advection of vertical velocity and displacement with FG, vertical advection with G dG/dz, and the stratification contribution GG d(log N2)/dz. `@WVTransformFreeSurfaceBoussinesq/projectSources.m` specifies the actual source pairings and the separate inertial/MDA outputs at zero horizontal wavenumber. The provider's FF->F, GG->F, and FG->G controls are useful but do not cover that inventory.

First establish a shared signed scalar-product error engine against the provider controls, then connect the physical channels. Every reported physical channel must identify its input variables/families, derivative or coefficient factors, output pairing, and omitted terms. In particular, a scalar G-channel result must not be reported as qualification of the full wave generalized-energy source projection.

Enumerate actual Fourier-vector closure k3=k1+k2. Equal magnitudes may share modes, but cannot establish closure, geometry, or monotonicity. Include high outputs, cancellation to small and zero outputs, disparate scales, the external mode, and localized surface/bottom modes. Zero outputs must use inertial/MDA families.

## Comparison and validation

Compare linear-only, fixed sparse, and sparse with budgeted targeted additions using identical saved reference errors. Initial fixed selection uses 6–8 representative magnitude pages, low/middle/high modes and near-cutoff neighbors. Targeted additions may use rapid variation or mode/derivative Chebyshev tails; neither is assumed to predict error reliably.

Proposed calibration profiles: constant and smooth exponential. Proposed withheld profiles include a shifted exponential and a sharper smooth pycnocline with N2>f^2, withheld Nz and rectangular domains. Freeze exact cases, interaction-selection rules, budgets, and any mode-count margin before examining withheld errors. Retuning requires new withheld cases.

For every tolerance report false acceptance against the bounded dense survey, lost retained modes, worst missed error with exact vectors/families/modes/channel, product counts, assessment/construction time, and peak memory. At one larger resolution run only the sparse policies plus an independently selected fixed spot sample. Record a negative finding if no useful reliable policy emerges.

## Required completion artifacts

1. Frozen inventory, dependency pins, reproducible commands, machine-readable errors and scores.
2. Independent convergence evidence and focused regression tests of the error engine, including trigonometric and signed-APV controls.
3. Calibration and withheld tables for all three policies and a larger cost check.
4. Measured recommendation and an API proposal exposing coverage, limiting cases, and “largest count passing the sampled interaction checks,” with strict explicit-count handling.
5. Verification ledger and clear limitations. Runtime adoption is a separate reviewable increment.
