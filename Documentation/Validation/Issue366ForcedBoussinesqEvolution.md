# Forced linear free-surface Boussinesq evolution and restart

This increment completes the bounded source, model-integration, and stored-continuation demonstration in #366. `WVTransformFreeSurfaceBoussinesq` projects volume sources into its six resolved coefficient families, evaluates registered forcing through `coefficientTendency`, and uses the existing `WVModel` fixed-step and annotated output paths. It preserves QG behavior, resolved modes, independent family counts, both active boundaries, and the existing class hierarchy.

## Public use

```matlab
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(2*z/700));
[X,~,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
force = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*cos(2*pi*X/wvt.Lx).*(1+Z/wvt.Lz),frequency=3e-4,referenceTime=17,phase=.4);
wvt.addForcing(force);
model = WVModel(wvt);
model.setupIntegrator(integratorType="fixed",deltaT=20);
model.createNetCDFFileForModelOutput('forced-linear.nc',outputInterval=400);
model.integrateToTime(800);
model.closeNetCDFFile();
resumed = WVModel.modelFromFile('forced-linear.nc');
resumed.setupIntegrator(integratorType="fixed",deltaT=20);
resumed.integrateToTime(1600);
resumed.closeNetCDFFile();
```

`WVModel(wvt)` integrates registered coefficient tendencies. Its existing `shouldUseLinearDynamics=true` option means analytical phase-only evolution with frozen reference-time coefficients and does not evaluate these sources. The new transform installs no nonlinear advection. Thus the ordinary tendency path advances a forced linear system without changing that legacy option's behavior. The existing no-closure warning still uses the term “nonlinear flux.”

Use an explicit `deltaT` for this qualified fixed-step path. Adaptive coefficient tolerances and automatic timestep selection are not qualified here; `coefficientAbsoluteTolerances` explicitly rejects adaptive stepping rather than assigning one dimensionally inconsistent tolerance to all families. Nonlinear flux, resolution transfer, independent surface mass flux, boundary sheet forcing, and legacy rigid-lid coefficient initialization remain unsupported by this increment. Generic volume-source projection is supported, but its truncation error is source- and resolution-dependent; the example above does not claim exact pointwise satisfaction of the unprojected forced equations at any chosen retained band.

## State projection and source projection

`projectFields(fields)` remains the observable-state projector. `projectSources(sources)` accepts exactly four real finite arrays `u`, `v`, `w`, `eta`, each `Nx × Ny × Nz`. The first three are prescribed momentum accelerations in m/s²; `eta` is a source of **total displacement** in m/s. These are volume fields including their endpoint values, not independent boundary sheets. Applied surface pressure may enter through its horizontal acceleration, as in the manuscript's `source-vector-definition`; no fifth pressure or independent SSH source is accepted.

Sources need not satisfy continuity or diagnostic ocean-state relations. Projection implements the defining generalized-energy pairing in `projection-coefficient-and-projector` of `literature/ape-apv-free-surface/main.tex`, inspected at `0a2edf4199aed1a195778c2ae66dea41118c9265`.

The APV source is

$$\dot A_{g,q}=\mathcal F_g[ikS_v-ilS_u]-\frac{f}{D}\mathcal G_g[S_\eta].$$

The existing shared balanced builder already supplies these source pairings, the zero-APV volume/endpoint pairings, and the small signed solve that expresses the result in the stored boundary-normalized coordinates. The new peer stores and reuses those operators; it neither assumes mutually orthogonal boundary responses nor changes the basis. MDA uses its existing signed G projection. Inactive endpoint dimensions and variables remain physically omitted from files.

For a wave polarization $(U_\sigma,V_\sigma,W_\sigma,E_\sigma)$ at reference phase, the continuous norm without the conventional factor one half is $2h$. Wave endpoint interior-displacement anomalies vanish, so its source pairing is

$$\dot A_{w,\sigma}(t)=\frac{e^{-i\sigma\omega(t-t_0)}}{2h}\int_{-D}^{0}\left(U_\sigma^*S_u+V_\sigma^*S_v+W_\sigma^*S_w+N^2E_\sigma^*S_\eta\right)\,dz.$$

This applies the stored F/G polarizations with the fixed positive physical quadrature and continuous normalization. There is no fitted basis or wave Gram correction. The equivalent manuscript G formula includes source divergence, its vertical derivative, and a surface correction. A divergent, curl-free momentum source is checked against that independent formula, including the surface term. The direct energy form also avoids subtracting a truncated balanced reconstruction of a generic source: the residual-G expression must not assume that the retained balanced band reconstructs the entire balanced source response.

Inertial forcing applies $e^{-if(t-t_0)}\mathcal F_{io}[\bar S_u-i\bar S_v]/2$. Real MDA amplitudes and independent shapes survive the ordinary family-keyed tendency packing. Changing coefficients at each integrator stage uses the existing cache invalidation; no new transform cache is introduced.

## Controlled source and independent checks

`WVPrescribedBoussinesqSource` stores four fixed spatial rate arrays and multiplies them by $\cos[\nu(t-t_s)+\phi]$. The source clock is absolute time and is persisted separately from the transform's `t0`. It uses the existing `NonhydrostaticSpatial` forcing interface and registration order, with no new forcing category.

The manufactured control includes wave, APV, two boundary, inertial, and MDA families. Equal instantaneous wave signs make its wave displacement and SSH vanish; one boundary coefficient is chosen to cancel the balanced surface pressure. Consequently the complete source is a resolved field with zero SSH source, providing an exact reference for the homogeneous surface-kinematic condition. Its known modal source amplitudes give a closed-form time integral of the cosine times the inverse modal phase. A mixed initial ocean state supplies nontrivial pressure, vertical velocity, endpoint anomalies, and means.

This control checks the full forced horizontal/vertical momentum and displacement equations, bottom impermeability, surface kinematics, and positive physical work. It includes physical-energy cross terms. A separate generic source, which need not be an admissible state, is checked against independent full-polarization generalized-energy matrices, including both endpoint terms and the nonorthogonal zero-APV solve. These checks do not reuse `projectFields` as a source reference.

Temporal error uses the analytic integral of the **numerically projected** fixed source, isolating RK4 error from the fixed spatial projection floor. Total coefficient error instead compares with the independently manufactured modal source. Both errors sum each family's positive physical error energy separately before taking the square root, preventing inter-family cancellation. The source projection error uses the same norm applied to rates.

## Quantitative evidence

Domain and representation match the preceding mixed-transform qualification: 100 km × 100 km × 1000 m; 8 × 8 Fourier grid, 65 WKB-Chebyshev samples; four wave modes per sign, three APV modes, two active endpoints, three inertial modes, and two MDA modes. Both constant $N^2=10^{-4}$ and exponential $N^2=10^{-4}\exp(2z/700)$ profiles are used. Latitude is 30°, $f=7.2921\times10^{-5}$ s⁻¹, $g=9.81$ m/s², and $\rho_0=1025$ kg/m³. Defaults use $g_0=-\int N^2dz$ and $g_d=+\int N^2dz$. Wave/inertial EVP resolution is 64; balanced EVP resolution is 207. No retained count changes during a run or restart.

The source has $\nu=3\times10^{-4}$ rad/s, $t_s=17$ s, and $\phi=0.4$ rad. Runs start at 127 s with `t0=31` s and finish at 1727 s. Checkpoints are at 927 s while forcing and modal phases are nontrivial. Output spacing is 400 s.

| Profile | Source projection error | RK4 error, 80 s | RK4 error, 40 s | RK4 error, 20 s | Restart error, 20 s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Constant | 1.18e-11 | 1.21e-10 | 7.57e-12 | 4.73e-13 | 0 |
| Exponential | 1.06e-10 | 2.00e-7 | 1.23e-8 | 7.62e-10 | 0 |

At 20 s, total coefficient errors are `1.18e-11` and `7.69e-10`, respectively. Each halving of the step reduces temporal error by approximately sixteen, consistent with RK4. Zero restart error means identical coefficient values in these runs with the same step alignment, not a universal bitwise restart guarantee.

Tests require generic energy-pairing agreement below `2e-7`, divergence-G wave agreement within `1e-14` absolute coefficient rate, forced momentum/displacement termwise residuals below `3e-6`, surface-kinematic residual below `2e-7`, and relative physical-work residual below `2e-6`. These are explicit bounded-case regression tolerances. Source truncation for arbitrary unrepresented profiles remains separate from these manufactured resolved-source bounds.

The CSV is `Documentation/Validation/issue-366-forced-evolution.csv`. Reproduce it and the restart checkpoint/reference files with `TestFreeSurfaceBoussinesqEvolution.runStudy(outputFolder)`. Use a fresh MATLAB process with InternalModes absent from every path entry, then call `TestFreeSurfaceBoussinesqEvolution.verifyRestartWithoutProvider(outputFolder)`; it verifies solver unavailability before restoring and continuing both checkpoints. This operation advances the checkpoint files; rerun the study to recreate them.

## Persistence and retained architecture

The canonical constructor still consumes flat stored scientific state. New source-pairing arrays join the existing modes, quadrature, derivative, and geometry annotations. `transformFromGroup` adapts those arrays into the constructor without eigenproblem construction. The file reader delegates committed coefficient/time selection and forcing reconstruction to the existing transform lifecycle. Model files retain a single complete, flat annotated coefficient stream; independent families are not packed into `Ap/Am/A0` or a shared `Nj`.

The continuation tests compare coefficients, pressure, selected physical-energy inventories, immutable operator arrays, `t`, `t0`, and the source clock. Separate transform round trips cover zero, surface-only, bottom-only, and two active boundaries. Empty endpoint coefficient shape is preserved; because that family is physically omitted, the storage complexity flag of an empty MATLAB array is not serialized. Runtime integrator objects are reconstructed with explicit settings, as in existing `WVModel.modelFromFile` behavior.

No shared class hierarchy, forcing registry, integrator, observer topology, or persistence format was replaced. No released snapshots or package metadata changed. The new experimental APIs remain documented in source and this report; supported website-catalog adoption and released-provider CI qualification remain in #354. #352 owns broader cross-model output/resolution transfer. This demonstrates the bounded linear architecture gate; adaptive stepping, arbitrary-source resolution surveys, nonlinear Boussinesq dynamics, and broad optional forcing/observer combinations remain future qualification.

## Verification and dependency scope

Five new evolution/source/restart test methods and 164 affected existing regressions passed on MATLAB R2025b Update 4. The fresh-process provider-free continuation passed for both profiles. Production Code Analyzer covered 231 files; the sole deliberate-error stub finding was corrected and its focused recheck has zero findings, leaving no blocking production findings. Setup-time annotation growth advisories remain nonblocking. The new test file has no Code Analyzer findings. Documentation build/check passed with 2357 files, 4817 routes, and zero generated drift. No task assets were missing.

The WVM integration baseline was `2e3e987f767799a407e7b4e9dc75af02f5192df1`; scientific construction used corrected InternalModes authoring commit `e7ea60dadc4e947769cda89f7c1116f22ffa404b`. These local scientific results do not qualify the older provider snapshot used by current hosted smoke CI. Released graph adoption and the full scientific CI gate remain #354.
