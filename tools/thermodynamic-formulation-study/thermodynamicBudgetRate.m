function budget=thermodynamicBudgetRate(w,profile,variant,state,time,rate)
% Analytic derivative of the physical inventory along the discrete RHS.
% External work is zero; nonzero power is the model's invariant defect.
op=thermodynamicComparisonOperators(w,profile,variant);
f=op.fields(time,state);
if variant=="equivalent"
    state=w.coefficientState();
    base=thermodynamicComparisonOperators(w,profile,"displacement");
    rate=base.rhs(time,state);
end
omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex); omega(~w.activeWaveModes)=0;
rate.Aw_p=rate.Aw_p+1i*omega.*state.Aw_p;
rate.Aw_m=rate.Aw_m-1i*omega.*state.Aw_m;
rate.Aio=rate.Aio+1i*w.f*state.Aio;
spectral=w.reconstructSpectralState(state=rate); v=struct();
for name=["u","v","w","eta","ssh"], v.(name)=w.transformToSpatialDomainWithFourier(spectral.(name)); end
v.ssh=v.ssh(:,:,end);
alpha=reshape(1+w.z/w.Lz,1,1,[]); gammaT=v.ssh/w.Lz;
etaT=v.eta;
if profile=="constant", lambda=0; else, lambda=1/650; end
if variant=="density"
    factor=exp(lambda*(f.eta-alpha.*f.ssh));
    etaT=alpha.*v.ssh+factor.*(v.eta-alpha.*v.ssh);
end
ut=(v.u-f.u.*gammaT)./f.gamma; vt=(v.v-f.v.*gammaT)./f.gamma;
wt=v.w+alpha.*(ut.*w.diffX(f.ssh)+vt.*w.diffY(f.ssh)+f.u.*w.diffX(v.ssh)+f.v.*w.diffY(v.ssh));
context=WVInternal.freeSurfaceThermodynamics(w);
thermal=context.evaluate(f.z,f.eta,f.ssh);
weights=reshape(w.verticalQuadratureWeights,1,1,[])/(w.Nx*w.Ny);
kinetic=.5*(f.u.^2+f.v.^2+f.w.^2);
power=sum(weights.*(gammaT.*(kinetic+thermal.ape)+f.gamma.*(f.u.*ut+f.v.*vt+f.w.*wt+thermal.apeEta.*etaT+thermal.apeZ.*alpha.*v.ssh)),'all')+w.g*mean(f.ssh.*v.ssh,'all');
rhoT=-w.rho0/w.g*1e-4*exp(lambda*f.label).*(alpha.*v.ssh-etaT);
anomaly=f.density-w.rho0;
momentRate=sum(weights.*(gammaT.*anomaly+f.gamma.*rhoT),'all');
secondRate=sum(weights.*(gammaT.*anomaly.^2+2*f.gamma.*anomaly.*rhoT),'all');
budget=[power;momentRate;secondRate];
end
