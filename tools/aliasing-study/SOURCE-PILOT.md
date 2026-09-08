# Physical-source pilot decisions before calibration

The 13 source terms are the individual x, y, and z advection terms for u, v, w, and eta, plus w*eta*d(log N2)/dz. Each source component projects into both wave frequency signs with the actual WVM generalized-energy dual. At zero output, u/v project into inertial modes and eta into MDA; the mean w source has no retained incompressible family. Individual channels have a real vertical shape times a constant phase, so zero-output products are phase-aligned to represent real conjugate-pair forcing. No sums of different channels or arbitrary superpositions are scored.

Inputs are wave-wave, wave-APV in both orders, wave-boundary in both orders, APV-boundary in both orders, and boundary-boundary. APV and boundary amplitudes use the streamfunction normalization; their nonzero canonical coefficient conversion cancels in the normalized individual-product error. The existing signed APV same-family assessment remains a separate control. Boundary and APV output source coefficients, boundary sheet evolution, and qualification of the complete nonlinear operator are outside this bounded channel inventory.

## Additional reference check

The scalar pilot checked eigenfunctions globally and integrated the same solved products twice. The physical pilot additionally compares retained reference coefficients and positive product norms between the independent EVP solutions. This is essential when modes are localized: a globally small eigenfunction perturbation can dominate the overlap of two opposite-boundary tails. The reference allowance remains 1e-4 for both integration and EVP-product discrepancies.

The initial 10 km square physical pilot failed this new check (maximum 2.552 on the diagnostic interaction subset). Those results are inconclusive and preserved. No sparse policy may be scored from them. A 100 km square domain still contains localized boundary modes but avoids the extreme opposite-boundary tail overlap: its full-survey EVP-product discrepancy was 2.089e-6 and reference-quadrature discrepancy 6.278e-13.

## Mode/derivative convergence norm

The pilot exposed another conditioning issue: a nearly constant F mode can have an extremely small nonzero derivative, so normalizing derivative roundoff by that derivative alone is poorly conditioned. The maximum componentwise relative derivative discrepancy was 2.580e-5 in the 100 km pilot, while its product-level discrepancy passed the stricter product-stability allowance. The original componentwise diagnostics remain in every summary.

For the calibration and withheld matrices, the eigenfunction/derivative gate uses the dimensionally scaled positive H1 norm for each mode: integral(|F|^2+D^2|dF/dz|^2), and separately the corresponding G norm, where D is the physical depth. Differences use the same norm and the fixed physical reference weights. The tolerance remains 1e-6; equivalent-depth convergence is checked separately at the same tolerance. This choice is made before policy scoring. The independent product-level EVP check remains mandatory, so a small H1 difference alone cannot certify a tiny derivative product or localized overlap. Direct spectral derivatives remain unchanged; no eigenfunctions, grids, or quadrature weights are fitted.

MDA F is the provider's surface-referenced pressure integral, so its derivative is -N2*G/g, not h*d2G/dz2. All other solved-form derivatives come from differentiation of the actual native spectral representation. The zero-APV G derivative uses a converged adaptive interpolant of that same solved G; its interpolation discrepancy is also reported.

## Independent fixed counts

The initial Nz=17 pilot's explicit APV=4 and inertial=6 bands fail their linear Gram gates. The pilot reports that failure rather than shrinking them. The next declared pilot uses APV=3, MDA=3, and inertial=3 explicitly, to measure wave-count decisions on a linearly acceptable fixed-family background. Higher-Nz calibration cases may declare different independent counts before running; each will remain strict.

## Cost accounting

Construction includes modes, both EVP orders, reference grids, physical polarizations, and source projection contexts. Assessment includes model-grid products and all reference evaluations. A nonzero product count denotes unique physical products; each undergoes two quadrature references and an independent-EVP reference. Structural zeros are recorded separately. Process peak RSS is measured with `/usr/bin/time -l`, including MATLAB and result serialization. The full physical pilot is small enough to use as the bounded dense-survey instrument.
