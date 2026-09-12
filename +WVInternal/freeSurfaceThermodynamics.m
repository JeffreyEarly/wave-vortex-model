function context = freeSurfaceThermodynamics(wvt)
% Evaluate parcel buoyancy and APE with upper-constant reference density.
%
% Parcel labels remain in [-Lz,0], allowing 32 ulps of endpoint roundoff.
% The hydrostatic no-motion density is constant above zero, so N_+^2=0
% there. Parcel density is never extended beyond its reference domain.
% For I(z)=integral_0^z N_+^2, J'=I, r=z-eta, buoyancy is I(r)-I(z)
% and APE is -eta*I(r)-J(r)+J(z). The manuscript surface-pressure
% approximation uses g*ssh and drops the corresponding cubic surface-energy
% correction, leaving g*ssh^2/2. This is not an all-orders pressure closure.
%
% The factory snapshots the profile and constants without computing modes.
% Derived antiderivatives are rebuilt, not persisted as prognostic state.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
context = WVInternal.freeSurfaceThermodynamicContext(wvt.N2Function,wvt.Lz,wvt.g,wvt.rho0);
end
