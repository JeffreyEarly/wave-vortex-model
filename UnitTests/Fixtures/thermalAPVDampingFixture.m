function force=thermalAPVDampingFixture(w)
% Freeze six APV coordinates using the shared default signed endpoint weights.
apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny 129],N2Function=@(z)w.N20*exp(2*w.inverseScale*z),latitude=w.latitude,g=w.g,apvModeCount=6,mdaModeCount=4,gramTolerance=.1);
force=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5);
end
