function [converted,tangent] = thermodynamicCoefficientMap(w,profile,state,time,rate)
% T_t and its derivative along state+timestep*rate in reference-time modes.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
    profile (1,1) string {mustBeMember(profile,["constant","exponential"])}
    state (1,1) struct
    time (1,1) double
    rate (1,1) struct = struct()
end
w.t=time;
a=sample(w,state);
alpha=reshape(1+w.z/w.Lz,1,1,[]);
interior=a.eta-alpha.*a.ssh;
if profile=="constant", lambda=0; else, lambda=1/650; end
if lambda==0, e=interior; else, e=-expm1(-lambda*interior)/lambda; end
% Only the scalar displacement changes. Preserve the authoritative state
% and project that change, avoiding round-trip error in unchanged fields.
correction=projectScalarCorrection(w,e-interior);
converted=state;
for name=string(fieldnames(state)).', converted.(name)=state.(name)+correction.(name); end
if nargout<2, return; end
assert(~isempty(fieldnames(rate)),'Supply a coefficient rate for the tangent.');
tangent=rate;
phase=phaseRate(w,state);
for name=string(fieldnames(rate)).', rate.(name)=rate.(name)+phase.(name); end
velocity=sample(w,rate);
correctionRate=projectScalarCorrection(w,expm1(-lambda*interior).*(velocity.eta-alpha.*velocity.ssh));
phase=phaseRate(w,correction);
for name=string(fieldnames(tangent)).', tangent.(name)=tangent.(name)+correctionRate.(name)-phase.(name); end
end

function fields=sample(w,state)
spectral=w.reconstructSpectralState(state=state);
fields=struct();
for name=["u","v","w","eta","ssh"]
    fields.(name)=w.transformToSpatialDomainWithFourier(spectral.(name));
end
fields.ssh=fields.ssh(:,:,end);
end

function state=projectScalarCorrection(w,eta)
% With zero SSH and velocity changes, physical and hatted fields coincide.
zero=zeros(size(eta));
fields=struct(u=zero,v=zero,w=zero,eta=eta,ssh=zeros(w.Nx,w.Ny));
state=w.projectFields(fields);
end

function rate=phaseRate(w,state)
rate=structfun(@(a)zeros(size(a)),state,UniformOutput=false);
omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex); omega(~w.activeWaveModes)=0;
rate.Aw_p=1i*omega.*state.Aw_p; rate.Aw_m=-1i*omega.*state.Aw_m;
rate.Aio=1i*w.f*state.Aio;
end
