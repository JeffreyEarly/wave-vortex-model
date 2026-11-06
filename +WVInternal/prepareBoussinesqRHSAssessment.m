function prepared = prepareBoussinesqRHSAssessment(w)
% Freeze one modal state and its continuous volume/endpoint source functionals.
% This offline snapshot neither changes the runtime activation gate nor caches
% data on the caller. Its sampled modal representation must be resolved first.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
end
snapshot=WVTransformFreeSurfaceBoussinesq(w.scientificState());
state=w.coefficientState();
for name=string(fieldnames(state)).', snapshot.(name)=state.(name); end
snapshot.t=w.t; snapshot.t0=w.t0;
prepared=struct(kind="boussinesqRHSSnapshot-v1",transform=snapshot,spectral=snapshot.reconstructSpectralState(),thermodynamics=WVInternal.freeSurfaceThermodynamics(snapshot));
end
