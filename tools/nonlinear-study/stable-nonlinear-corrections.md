# Stable nonlinear corrections (#480)

Implemented against v5 revision `8a7c336c1d7b2648fd1904d7cf914c334274c34c` on `feature/v5.0-free-surface-qg`.

The vertical pressure prefactor now uses `-ssh/(D+ssh)`. Thermodynamics accumulates the buoyancy remainder from `N2(node)-N2(xi)` in the existing Gauss quadrature; the RHS receives that remainder directly. Node evaluations are reused, so this adds pointwise work and one volume accumulator without changing the quadrature complexity or profile-evaluation count. Full buoyancy and APE evaluation are unchanged.

For the upper-constant-density continuation, the remainder also includes `-N2(xi)*max(z,0)`. Bounded endpoint label adjustments contribute `-N2(xi)*labelAdjustment`, preserving the original displacement in the linear term. Both signs of displacement are supported. The authoring study retains its independent analytic integral and subtraction as an ordinary-amplitude comparison; it is not the small-amplitude accuracy oracle.

## Accuracy

`TestFreeSurfaceNonlinearEvolution/stableCorrectionsReachEverySourceAndCoefficientFamily` uses the existing 8×8×65 mixed-state fixture, constant stratification, and nonzero phase clocks. It compares all four production sources and all six projected families against a closed-form buoyancy remainder. Repeating the former pressure/remainder arithmetic on the same fields gives:

| State amplitude multiplier | Former maximum P_w error (m s⁻²) | New maximum P_w error (m s⁻²) |
| --- | ---: | ---: |
| 1 | 5.77e-19 | 2.46e-20 |
| 1e-8 | 6.71e-27 | 1.87e-28 |
| 1e-12 | 4.22e-31 | 2.25e-32 |

These are correction-arithmetic errors against the analytic correction, not discretization errors or performance measurements. Scalar tests additionally confirm a nonzero pressure correction when `1+ssh/D` rounds to one, exact zero constant-stratification interior remainders, surface crossings, and endpoint adjustments. A signed linear-stratification amplitude sweep from 1e-1 to 1e-11 m agrees with its analytic integral within explicit profile/coordinate roundoff bounds.

Direct profile subtraction still has an absolute evaluation error floor: arbitrarily small quadratic remainders in variable stratification are not guaranteed relative accuracy. Stable divided differences and alternative profile integration remain #482; this change retains the existing quadrature method.

## Verification

MATLAB R2026a: 21 focused tests passed across thermodynamics, manuscript nonlinear terms, nonlinear evolution, and nonlinear stage. This includes variable stratification, changing phase clocks, quadratic small-amplitude scaling, and the energy-tendency finite-difference check. Production Code Analyzer passed its correctness gate; the changed helper, test, and study files had no `checkcode` findings. Whitespace and scope checks passed; no package metadata, website files, or released snapshots changed.

Tests used InternalModes `v2.0.0-beta.4` exported from its local tag, ClassAnnotations 1.2.1, NetCDF 1.0.2, and SplineCore 2.2.0. The default MATLAB path selected InternalModes beta.1 and could not construct the v5 fixtures; the isolated path resolved this mismatch.

`docs:check` validated 2,362 files and 4,827 routes with zero validation failures, but its comparison failed on pre-existing drift in `classes/developer-internals/wvdensitydiffusionintegrator/index.md` (whitespace) and `version-history.md`. Repeating the check on an unmodified export of the base revision produced the same two differences. This numerical change leaves that unrelated documentation drift untouched.
