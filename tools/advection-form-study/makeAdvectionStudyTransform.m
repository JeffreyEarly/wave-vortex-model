function w=makeAdvectionStudyTransform(profile,spec)
% Fixed domain and provider resolution; spec=[Nx Nz APV wave MDA inertial].
if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[spec(1) spec(1) spec(2)],N2Function=N2,apvModeCount=spec(3),waveModeCount=spec(4),mdaModeCount=spec(5),inertialModeCount=spec(6),nEVP=256,shouldAntialias=false);
end
