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
a.eta=e+alpha.*a.ssh;
converted=projectHatted(w,a);
if nargout<2, return; end
assert(~isempty(fieldnames(rate)),'Supply a coefficient rate for the tangent.');
phase=phaseRate(w,state);
for name=string(fieldnames(rate)).', rate.(name)=rate.(name)+phase.(name); end
velocity=sample(w,rate);
velocity.eta=alpha.*velocity.ssh+exp(-lambda*interior).*(velocity.eta-alpha.*velocity.ssh);
% projectHatted is linear in its hatted input, including SSH. Applying it
% to one second of field change, then dividing by one second, projects rates.
tangent=projectHatted(w,velocity);
phase=phaseRate(w,converted);
for name=string(fieldnames(tangent)).', tangent.(name)=tangent.(name)-phase.(name); end
end

function fields=sample(w,state)
spectral=w.reconstructSpectralState(state=state);
fields=struct();
for name=["u","v","w","eta","ssh"]
    fields.(name)=w.transformToSpatialDomainWithFourier(spectral.(name));
end
fields.ssh=fields.ssh(:,:,end);
end

function state=projectHatted(w,fields)
% Encode hatted fields through the public physical-input state projector.
alpha=reshape(1+w.z/w.Lz,1,1,[]); gamma=1+fields.ssh/w.Lz;
fields.u=fields.u./gamma; fields.v=fields.v./gamma;
fields.w=fields.w+alpha.*(fields.u.*w.diffX(fields.ssh)+fields.v.*w.diffY(fields.ssh));
state=w.projectFields(fields);
end

function rate=phaseRate(w,state)
rate=structfun(@(a)zeros(size(a)),state,UniformOutput=false);
omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex); omega(~w.activeWaveModes)=0;
rate.Aw_p=1i*omega.*state.Aw_p; rate.Aw_m=-1i*omega.*state.Aw_m;
rate.Aio=1i*w.f*state.Aio;
end
