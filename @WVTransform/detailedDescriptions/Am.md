`Am` stores the negative-frequency coefficients $$A_-^{k\ell j}$$ for internal gravity waves and inertial oscillations. The coefficients have units of velocity and use the transform's spectral layout.

The stored phase is referenced to `t0`. Linear evolution does not overwrite `Am`; use `Amt` for the coefficients evaluated at the current `t`. The wave and inertial primary-flow-component masks identify the active locations. Coefficients outside those masks must remain zero.

Together `Am` and `Ap` obey the transform's Hermitian and inertial conjugacy relationships so the reconstructed physical fields are real. In particular, the inertial coefficients satisfy `Am = conj(Ap)` on their masks. Quasigeostrophic transforms have no active `Am` content.

- Topic: Wave-vortex coefficients
