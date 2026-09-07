# Resolved-mode seasonal response assessment (#351)

`WVVerticalDiffusivity.assessSeasonalResponse` provides a public, problem-specific estimate of seasonal-response accuracy at the caller's chosen resolution. It preserves the resolved APV/zero-APV/MDA design and the existing ordinary/exponential diffusion generator. There is no default 1% pass/fail requirement.

## Public preflight API

For an existing two-active-boundary transform `w`, its seasonal surface anomaly forcing `forcing`, and two compatible finer modal transforms:

```matlab
diffusion = WVVerticalDiffusivity(w,kappa_z=1e-5);
assessment = diffusion.assessSeasonalResponse(forcing, ...
    forcing.period*[0 .25 .5 .75 1], ...
    referenceTransforms={referenceCoarse,referenceFine});
assessment.total.relative
assessment.reference.convergence.relative
```

Reference construction is explicit and reusable. Both the grid and APV count must increase from candidate to first reference to second reference. References must share physical parameters, horizontal Fourier layout, two active endpoints, and the stratification profile. A common quadrature checks stratification compatibility; `stratificationTolerance` controls that check, not scientific response acceptance. The default common integration count is `max(129,2*referenceFine.Nz+1)` and can be increased to check quadrature sensitivity. The assessment uses stored modes and the stored coordinate map, including restored snapshots; it does not require the original stratification function.

The calculation starts from rest at elapsed time zero with the supplied source phase. It excludes current coefficients, other registered forcing, nonlinear advection, and mean-density-anomaly evolution. It may populate rebuildable metric caches, but does not change time, state, or registered forcing. This is an estimate for that specified linear problem, not an error bound on a nonlinear simulation.

The finest reference QGPV is projected by a continuous depth-L2 fit into the candidate's resolved APV modes. The remaining endpoint anomalies are assigned to its two zero-APV modes. This diagnostic projection preserves both reference endpoint values and avoids aliasing unresolved reference QGPV through coarse-grid sampling. It does not change the production transforms.

- `representation`: projected reference versus finest reference.
- `evolution`: candidate response versus projected reference.
- `total`: candidate response versus finest reference.
- `reference.convergence`: first reference versus finest reference.

Each contains `absolute`, `relative`, and `referenceMagnitude` tables, with elapsed `time` and nine observables: `qgpv`, `buoyancy`, `ssh`, `surfaceAnomaly`, `bottomAnomaly`, `energy`, `enstrophy`, `energyTendency`, and `enstrophyTendency`. Field errors use depth/horizontal RMS; surface observables use horizontal RMS. Quadratic inventories use horizontal means of half depth integrals, including physical free-surface potential energy. Tendencies are directional derivatives along the forced linear response. Units accompany the result. `perWavenumber` retains the same comparisons grouped by horizontal wavenumber magnitude; its `forcingPower` is the sum of squared compact Fourier source amplitudes.

Evolution relative errors use the projected-reference magnitude. Other relative errors use the finest-reference magnitude. A zero error divided by zero is zero; a nonzero error divided by zero is Inf. Norms of representation and evolution errors generally do not add; the orthogonal QGPV L2 projection does give a sum-of-squares identity. Reference refinement differences are convergence evidence and do not certify an upper bound or catch every common systematic error. The independent physical-depth tests below provide a separate check on operator physics.

Callers can request acceptance tables for selected observables:

```matlab
assessment = diffusion.assessSeasonalResponse(forcing,forcing.period/4, ...
    referenceTransforms={referenceCoarse,referenceFine}, ...
    absoluteTolerance=struct(qgpv=1e-9), ...
    relativeTolerance=struct(energy=0.02), ...
    referenceRelativeTolerance=struct(qgpv=0.001));
assessment.acceptance
assessment.reference.acceptance
```

These numbers are illustrative caller choices. For each specified observable and time the test is `absoluteError <= absoluteTolerance + relativeTolerance*referenceMagnitude`, with omitted components zero. The two acceptance tables are separate; without supplied tolerances they are empty. Inspect reference convergence before interpreting total-error estimates.

## Physical contract and independent reference

The reference uses the workspace mathematics in `literature/ape-apv-free-surface/notes/gpt-closed-free-surface-qg.tex` and `notes/gpt-free-surface-qg-space-time-diffusion-modes.tex`. The older active-surface/inactive-bottom defaults in some notes are historical; this comparison explicitly sets both finite endpoint parameters to the negative/positive stratification integral.

At one nonzero horizontal wavenumber, write the streamfunction as a linear combination of Legendre polynomials in **physical depth**. Compute their first and second derivatives by differentiated polynomial recurrences and integrate with independently constructed Gauss quadrature. No WVM or InternalModes modal arrays, mapped derivatives, or physical-metric helpers enter construction of the reference operator.

The reconstructed fields are

$$\eta=-\frac{f}{N^2}\varphi_z,\qquad \zeta=\frac{f}{g}\varphi(0),\qquad \mathfrak b=-N^2\left[\eta-\left(1+\frac zD\right)\zeta\right],\qquad q=-k_h^2\varphi-f\eta_z.$$

Integration by parts in the QG inversion gives the positive physical-energy bilinear form

$$M(v,\varphi)=\int_{-D}^{0}\left(k_h^2v\varphi+\frac{f^2}{N^2}v_z\varphi_z\right)\,dz+\frac{f^2}{g}v(0)\varphi(0).$$

For insulated buoyancy diffusion at both active endpoints,

$$M(v,\dot\varphi)=\int_{-D}^{0}\kappa\,\eta_z[v]\,\mathfrak b_z[\varphi]\,dz.$$

A strict surface-displacement source adds $-f v(0)S_0$; a strict bottom source adds $+f v(-D)S_d$. A physical inward buoyancy flux instead adds $-\eta[v](0)Q_0-\eta[v](-D)Q_d$. These are distinct source contracts. Manufactured quadratic buoyancy profiles check both flux signs against the strong thermal tendency.

QR rescales the reference polynomial coordinates using physical energy. From-rest seasonal responses use an augmented matrix exponential with a sine/cosine oscillator, eliminating a time-step error. This reference includes the QG balance projection; a scalar heat solution alone would not test the nonzero-wavenumber model.

WVM fields are independently evaluated by interpolating its stored streamfunction at the **actual physical grid points**, using the known analytic WKB map for the two stratification profiles, then differentiating that polynomial analytically. Using idealized mapped nodes instead of the actual stored points introduced a spurious approximately $10^{-4}$ relative PV cancellation residual in an early diagnostic; correcting the reference interpolation removed that artifact without changing production code or the acceptance tolerance.

## Historical independent audit parameters

- Depth 4,000 m; $N^2=(5.2\times10^{-3})^2\exp(2z/B)$ with $B=\infty$ or 1,300 m; latitude 24 degrees; $g=9.81$ m/s².
- $k_h=2\pi/(100\,\mathrm{km})$, equal to meridional mode 5 in the experiment's 500 km domain. A 4-by-4 horizontal tile isolates this mode without nonlinear products, drag, damping, beta, or a seed.
- Constant buoyancy diffusivity $10^{-5}$ m²/s; period 365.25 days; a unit sine endpoint-displacement source, starting from zero APV, zero endpoint anomalies, and zero MDA at time zero. Relative errors are independent of forcing amplitude.
- Annual diffusion length $\sqrt{2\kappa/\omega}$ is about 10 m. Exact time propagation does not add the vertical bandwidth needed to represent it.
- The earlier audit used illustrative field/inventory/budget thresholds of 1%/2%/5%. Those were audit choices, not user requirements or the completion criterion for #351. Recorded numerical errors are retained; the study runner and CSVs no longer attach a universal pass/fail flag. Numerical regression tolerances for independent reference convergence, operator identities, flux signs, and conservation remain test assertions.

Field errors use physical-depth weighted L2 norms; endpoint error is the Euclidean norm of the surface/bottom pair. Inventory and instantaneous budget errors are relative to their reference values. Near a small reference inventory or budget, inspect the absolute physical values before interpreting a relative spike.

## Results

Increasing the physical-depth reference from 129 to 193 polynomials changes quarter-year QGPV by $5.7\times10^{-7}$ relative for constant stratification and $1.5\times10^{-6}$ for exponential stratification. Increasing 193 to 257 changes these by $6.4\times10^{-11}$ and $2.1\times10^{-10}$ respectively. Reference errors are far smaller than the model discrepancies.

For exponential stratification at one quarter year:

| Physical nodes | APV modes | QGPV error | Potential-enstrophy error | Physical-energy error |
| ---: | ---: | ---: | ---: | ---: |
| 33 | 14 | 94.46% | 98.34% | 0.00522% |
| 65 | 27 | 82.39% | 89.39% | 0.00334% |
| 129 | 54 | 55.28% | 52.90% | 0.00111% |
| 257 | 108 | 26.01% | 11.69% | 0.000155% |
| 513 | 217 | 9.82% | 1.55% | 0.0000174% |

The additional 257-node exponential case has 11.20% QGPV error and 1.57% buoyancy error at one year.

At one year, the 129-node exponential case still has 32.77% QGPV error, 3.82% enstrophy error, 6.45% buoyancy error, and 6.86% endpoint-pair error. Errors vary across the 24 combinations of two stratifications, 33/65/129 nodes, and quarter-year sampling through year one. Accurate energy at an earlier seasonal phase therefore does not establish field or budget accuracy.

The experiment's default **513-node** exponential configuration retains 217 APV modes. Its QGPV errors at years 0.25, 0.5, 0.75, and 1 are **9.82%, 3.43%, 1.77%, and 3.48%**. For comparison, quarter-year enstrophy error is 1.55%, buoyancy error is 0.0163%, and endpoint-pair error is 0.0195%. This distinction matters: the default is substantially more accurate than the reduced cases, and QGPV accuracy differs substantially from energy and endpoint accuracy.

![Seasonal error versus retained APV bandwidth](Issue351SeasonalErrors.png)

Raw tables: [seasonal 33/65/129-node cases](issue-351-seasonal.csv), [257-node exponential cases](issue-351-high-resolution.csv), [default 513-node exponential cases](issue-351-default-resolution.csv), [fixed APV bandwidth](issue-351-fixed-bandwidth.csv), and [fixed physical grid](issue-351-fixed-grid.csv).

### Separating spatial errors

At a **fixed 14-mode APV bandwidth**, increasing the grid from 33 to 65 to 129 nodes leaves the exponential quarter-year QGPV error at 94.46%. At a **fixed 129-node grid**, increasing APV bandwidth from 14 to 27 to 54 lowers the QGPV error from 94.46% to 82.39% to 55.28%. All these cases retain both zero-APV endpoint coordinates. Reduced operators are reassembled in their retained subspace, rather than truncating a full coefficient generator by deleting rows and columns.

Independent 257/513-point physical-depth quadratures agree within the $10^{-6}$ operator target. Independently differentiating the stored streamfunction and assembling the weak operator agrees with the production generator within the $10^{-4}$ relative target. At 65 and 129 nodes the seasonal streamfunction-derived PV agrees closely with the separately represented PV; their discrepancy is much smaller than the seasonal reference error. These controls identify missing retained bandwidth as the dominant error in the measured cases. They do not claim that every future stratification map is qualified.

### Mean-density diffusion

The separate MDA test starts with physical buoyancy $10^{-6}[1+0.2\cos(\pi(z+D)/D)]$ and compares against the analytic insulated-column heat solution at $\kappa t\pi^2/D^2=0.2$. It includes a nonzero mean and a decaying cosine, and reconstructs buoyancy from the MDA displacement directly, avoiding the known public-field omissions tracked in #348.

At 129 nodes the relative evolved buoyancy error is approximately $8.9\times10^{-7}$ for constant stratification and $1.6\times10^{-3}$ for exponential stratification. Both improve on 65 nodes. Column buoyancy is conserved within $10^{-8}$. The initial projection error is measured separately; constant buoyancy is not assumed to lie exactly in every truncated variable-stratification MDA space.

## Reproduction

Use the WVM authoring checkout and its compatible InternalModes dependency, add `UnitTests` to the MATLAB path, and run:

```matlab
results = runtests('UnitTests/TestFreeSurfaceQGDiffusionQualification.m');
assertSuccess(results);
seasonal = TestFreeSurfaceQGDiffusionQualification.runStudy;
fixedBandwidth = TestFreeSurfaceQGDiffusionQualification.runStudy(maximumAPVCount=14,timeFractions=.25);
fixedGrid = TestFreeSurfaceQGDiffusionQualification.runStudy(gridCounts=129,maximumAPVCount=27,timeFractions=.25);
defaultResolution = TestFreeSurfaceQGDiffusionQualification.runStudy(gridCounts=513,scales=1300);
```

To redraw the figure from the recorded CSV tables, add `Documentation/Validation` to the MATLAB path and call `plotIssue351SeasonalErrors`.

The independent tests verify the reference, strict forcing, weak assembly/quadrature, inward-flux signs, MDA heat solution, and agreement of the public estimates with independently differentiated fields. `runStudy` returns measured errors without imposing scientific acceptance thresholds. `TestSeasonalResponseAssessment` exercises the public contract, including error decomposition, exact no-diffusion response, multimode scaling, optional tolerances, validation, state preservation, and snapshots.

Baseline: WVM `ac39308e5f044696cf8142d5e9b9cd80c7f9591c`; InternalModes `9e2edb3eda96191078e22f5d3a8bc785be38143d`; MATLAB R2025b Update 4. Other isolated runtime revisions: ClassAnnotations `ca212699516e30792bd3e584b7842289c49ca772`, NetCDF `17d00778fdc79284723139f57d3a88fef53f2247`, SplineCore `0ce6950e6328e931fe91797dfd707c24ceac8f6f`, Chebfun `1fe01297a74d9ee765a466c3068b7fb474bee053`, Distributions `cc0e9fa337de5e308978049c798d5fb6069e05a6`. ClassDocumentation 1.3.2 is an authoring-only dependency.

## Verification and limits

The public implementation passes 36 distinct focused tests: seven API tests, six independent qualification tests, 22 diffusion/integrator regressions, and the public forcing-documentation taxonomy test. The production Code Analyzer gate has no blocking findings; both new implementation helpers and all touched test/documentation-tool files have zero findings. Documentation generation and comparison pass with 2,353 files, 4,809 routes, and zero differences. A final provenance-only addition was followed by the affected API tests and targeted Code Analyzer checks. Package dependencies, released snapshots, experiment pins, and saved trajectories remain unchanged. Full/exhaustive and released-package suites are outside this focused change.

The earlier suggestion of a collocated production QGPV state is withdrawn. WVM transforms remain the resolved modal state. This assessment helps users choose resolution and tolerances for the observables they care about; it does not force a particular error threshold by replacing that state representation.

Complete #348's public MDA QGPV/endpoint reconstruction before relying on public diagnostics for nonzero-mean experiments. The present API covers the zero-MDA seasonal perturbation from rest, constant diffusivity, two active endpoints, and the compact Fourier layout without Nyquist modes. Arbitrary initial conditions, general temporal sources, variable diffusivity, inactive-endpoint diffusion, and nonlinear solution-error estimates need separate contracts and verification. Computational cost includes three modal generators, reconstructions, projections, and exact linear responses for the requested times.
