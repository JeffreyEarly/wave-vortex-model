`Ap` stores the positive-frequency coefficients $$A_+^{k\ell j}$$ for internal gravity waves and the positive-frequency member of the paired inertial representation. The coefficients have units of velocity and use the transform's spectral layout.

The stored phase is referenced to `t0`. Linear evolution does not overwrite `Ap`; use `Apt` for the coefficients evaluated at the current `t`. The wave and inertial primary-flow-component masks identify the active locations. Coefficients outside those masks must remain zero.

Together `Ap` and `Am` obey the transform's Hermitian and inertial conjugacy relationships so the reconstructed physical fields are real. Quasigeostrophic transforms have no active `Ap` content.

- Topic: Wave-vortex coefficients
