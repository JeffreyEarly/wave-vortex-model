function [result,details]=evaluateProjectedThermodynamics(w,profile,state,time)
% Compare total density displacement and exact displacement before adoption.
% Prescribed retained state; current source projector and pressure functional.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
    profile (1,1) string {mustBeMember(profile,["constant","exponential"])}
    state (1,1) struct
    time (1,1) double
end
w.t=time;
spectral=w.reconstructSpectralState(state=state);
a=struct();
for name=["u","v","w","eta","p","ssh"]
    a.(name)=w.transformToSpatialDomainWithFourier(spectral.(name));
end
a.ssh=a.ssh(:,:,end);
xi=reshape(w.z,1,1,[]); alpha=1+xi/w.Lz; q=reshape(w.N2,1,1,[]);
gamma=1+a.ssh/w.Lz; z=xi+alpha.*a.ssh; r=z-a.eta;
assert(min(r,[],'all')>=-w.Lz-32*eps(w.Lz) && max(r,[],'all')<=32*eps(w.Lz),'Study parcel labels must be admissible.');
if profile=="constant", lambda=0; else, lambda=1/650; end
nr=1e-4*exp(lambda*r);
% Stable profile-specific conversion independent of production thermodynamics.
interior=a.eta-alpha.*a.ssh;
if lambda==0
    e=interior; B=-1e-4*(a.eta-max(z,0));
else
    e=-expm1(-lambda*interior)/lambda;
    B=-nr.*expm1(lambda*(a.eta-max(z,0)))/lambda;
end
h=e+alpha.*a.ssh;
derivative=struct(x=@(f)w.diffX(f),y=@(f)w.diffY(f),xi=@(f)w.diffZ(f));
etaTerms=WVInternal.freeSurfaceNonlinearTerms(a,a.p,w.z,w.Lz,w.f,w.rho0,w.N2,-B-q.*a.eta,derivative);
b=a.w(:,:,end); zt=alpha.*b;
u=a.u./gamma; v=a.v./gamma; wi=(a.w-alpha.*b)./gamma;
physicalW=a.w+alpha.*(u.*w.diffX(a.ssh)+v.*w.diffY(a.ssh));
hRate=physicalW-e.*wi*lambda-u.*w.diffX(h)-v.*w.diffY(h)-wi.*w.diffZ(h);
% Compare the same physical rate, not the two different coordinate rates.
etaRateFromH=zt+(q./nr).*(hRate-zt);
pulledSource=etaTerms.source;
pulledSource.eta=etaRateFromH-a.w;
reference=w.projectSources(etaTerms.source);
pulled=w.projectSources(pulledSource);
% Native h coefficients are allowed to differ quadratically.
hSource=etaTerms.source;
hSource.w=hSource.w+q.*(h-a.eta);
hSource.eta=hRate-a.w;
native=w.projectSources(hSource);
% Project the same velocities/SSH twice, changing only the scalar variable.
physical=struct(u=u,v=v,w=physicalW,eta=a.eta,ssh=a.ssh);
baseState=w.projectFields(physical);
physical.eta=h;
hState=w.projectFields(physical);
baseSpectral=w.reconstructSpectralState(state=baseState);
hSpectral=w.reconstructSpectralState(state=hState);
deltaP=w.transformToSpatialDomainWithFourier(hSpectral.p-baseSpectral.p);
baseP=w.transformToSpatialDomainWithFourier(baseSpectral.p);
% Isolate the conversion-induced pressure change from baseline projection error.
closureTerms=WVInternal.freeSurfaceNonlinearTerms(a,a.p+deltaP,w.z,w.Lz,w.f,w.rho0,w.N2,-B-q.*a.eta,derivative);
closureSource=etaTerms.source;
for name=["u","v","w","eta"]
    closureSource.(name)=closureSource.(name)+(closureTerms.total.(name)-etaTerms.total.(name));
end
closure=w.projectSources(closureSource);
% Pull the density state back before asking the displacement pressure closure.
recoveredInterior=h-alpha.*a.ssh;
if lambda==0, inverseEta=alpha.*a.ssh+recoveredInterior; else, inverseEta=alpha.*a.ssh-log1p(-lambda*recoveredInterior)/lambda; end
physical.eta=inverseEta;
inverseState=w.projectFields(physical);
inverseSpectral=w.reconstructSpectralState(state=inverseState);
inverseP=w.transformToSpatialDomainWithFourier(inverseSpectral.p-baseSpectral.p);
rows=struct([]);
for name=string(fieldnames(reference)).'
    row=struct(family=name,referenceMax=max(abs(reference.(name)),[],'all'), ...
        pulledError=max(abs(pulled.(name)-reference.(name)),[],'all'), ...
        nativeDifference=max(abs(native.(name)-reference.(name)),[],'all'), ...
        closureDifference=max(abs(closure.(name)-reference.(name)),[],'all'));
    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
end
baseEta=w.transformToSpatialDomainWithFourier(baseSpectral.eta);
hProjected=w.transformToSpatialDomainWithFourier(hSpectral.eta);
result=struct(families=rows,reference=reference,pulled=pulled, ...
    inversePressureError=max(abs(inverseP),[],'all'), ...
    hDifference=max(abs(h-a.eta),[],'all'), ...
    scalarPullbackError=max(abs(etaRateFromH-etaTerms.total.eta),[],'all'), ...
    pressureDifference=max(abs(deltaP),[],'all'), ...
    pressureBaselineError=max(abs(baseP-a.p),[],'all'), ...
    etaBaselineError=max(abs(baseEta-a.eta),[],'all'), ...
    conversionProjectionError=max(abs((hProjected-baseEta)-(h-a.eta)),[],'all'), ...
    surfacePressureDifference=max(abs(deltaP(:,:,end)),[],'all'));
if nargout>1
    details=struct(native=native,hatted=a,hState=hState);
end

end
