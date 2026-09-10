# Instantaneous matrix-free pressure diagnostic

> Historical evidence. This report describes the retired weak/pressure implementation or its comparison studies. The executable solvers have been removed; see the [direct runtime qualification](../../Documentation/Validation/NonlinearFreeSurface/direct-runtime-qualification.md) for the current implementation. Historical source links refer to revision `7b9ccda7`.

`WVInternal.freeSurfacePressureSolver(wvt)` snapshots the reference grid and stored vertical derivative. Its `solve(ssh,force,piSurface)` returns pressure per reference density and a diagnostic report containing the complete mapped pressure gradient, pressure-corrected hatted acceleration, GMRES residuals, and separate interior, bottom, and surface divergence defects. No runtime evolution path calls this helper.

The equation matches the dense authoring oracle: $\nabla_\xi\cdot(M\nabla_\xi\pi)=\nabla_\xi\cdot F$ at interior vertical nodes, $(M\nabla_\xi\pi)_w=F_w$ at the bottom, and $\pi=\pi_s$ at the surface. Both surface slopes and all metric cross terms are included. Boundary rows replace the PDE; endpoint divergence is deliberately reported separately. This instantaneous collocation pressure is not a modal constraint multiplier, and it does not establish that a projected modal trajectory obeys the unprojected pointwise momentum equations without projection and constraint reaction forces.

The right preconditioner reuses LU factorizations of small row-equilibrated flat Fourier blocks. It uses the squared **first-derivative** horizontal operator: real even-grid Nyquist derivatives are zero, so the corresponding preconditioner wavenumbers are also zero. Horizontal derivatives reuse the existing `WVGeometryDoublyPeriodic.diffX/diffY` implementation on a separate geometry snapshot. All column unknowns are real grid values; only block solves use complex Fourier coordinates. No global pressure matrix, reconstruction basis, EVP, modes, or new scientific state are constructed. GMRES restarts bound its Krylov storage; exhaustion or stagnation leaving an unacceptable independently recomputed residual raises `WV:PressureSolverConvergence`.

## Verification ledger

The focused tests use a supported $6\times6\times17$ transform grid over an $80\times60$ km horizontal domain and 100 m depth. The first attempted 800 by 600 m domain failed the transform's existing boundary-resolution qualification before exercising the solver. The test domain was widened and the vertical grid increased; no tolerance or qualification policy was weakened.

- Analytic nonflat manufactured pressure includes both slopes, a horizontal mean, and a prescribed divergence-free acceleration. The solver agrees with the independent dense oracle to $1.77\times10^{-10}$ m$^2$ s$^{-2}$, using 9 iterations at scaled relative residual $6.52\times10^{-13}$.
- A flat control includes horizontal mean, x and y Nyquist, and cross-Nyquist pressure. It converges in one iteration at residual $7.05\times10^{-16}$. Reusing the context across nonflat and flat stages reproduces the pressure exactly; changes to the source transform's clock do not affect the diagnostic or its factors.
- Deliberately unresolved vertical forcing demonstrates the boundary-row distinction: interior divergence is $2.89\times10^{-15}$ s$^{-2}$ while bottom and surface divergence are approximately $0.0758$ s$^{-2}$. Both match the dense oracle; bottom acceleration and prescribed surface pressure still close.
- An imposed one-iteration budget raises the convergence error. Invalid geometry, array shape, and force fields are rejected; zero forcing returns zero pressure without iteration.
- All four test methods passed after correcting only the two test-control configurations above. The added three-vector restart control also passed against the dense oracle.
- Code Analyzer: zero active or blocking findings in both new MATLAB files; one declared performance suppression for appending the bounded GMRES residual history.
- Package manifest and generated website unchanged. No missing assets; dependencies are the pinned `../oceankit-beta-publish` snapshots. One `docs:check` passed: 2,362 files, 4,827 routes, zero failures and zero differences. Whitespace and authored-file scope checks passed.

This is a diagnostic implementation and a small-grid qualification. Large-grid memory/performance, steep-surface conditioning, and all momentum residuals of an evolved reduced trajectory remain unqualified.
