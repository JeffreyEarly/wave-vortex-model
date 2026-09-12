function result=evaluateThermodynamicCoefficientTangent(w,profile,state,time,steps)
% Finite coefficient-map derivative and separately identified RHS changes.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
    profile (1,1) string {mustBeMember(profile,["constant","exponential"])}
    state (1,1) struct
    time (1,1) double
    steps (1,:) double {mustBePositive} = [4 2 1 .5 .25 .125]
end
[base,details]=evaluateProjectedThermodynamics(w,profile,state,time);
[converted,tangent]=thermodynamicCoefficientMap(w,profile,state,time,base.reference);
rows=struct([]);
for step=steps
    plus=state; minus=state;
    for name=string(fieldnames(state)).'
        plus.(name)=state.(name)+step*base.reference.(name);
        minus.(name)=state.(name)-step*base.reference.(name);
    end
    forward=thermodynamicCoefficientMap(w,profile,plus,time+step);
    backward=thermodynamicCoefficientMap(w,profile,minus,time-step);
    % Deliberately omit explicit time dependence as a negative control.
    fixedForward=thermodynamicCoefficientMap(w,profile,plus,time);
    fixedBackward=thermodynamicCoefficientMap(w,profile,minus,time);
    for name=string(fieldnames(state)).'
        difference=(forward.(name)-backward.(name))/(2*step);
        fixed=(fixedForward.(name)-fixedBackward.(name))/(2*step);
        row=struct(family=name,step=step,rateMax=max(abs(tangent.(name)),[],'all'), ...
            error=max(abs(difference-tangent.(name)),[],'all'), ...
            omittedTimeError=max(abs(fixed-tangent.(name)),[],'all'));
        if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
    end
end
w.t=time;
[shared,surfaceMismatch]=densityCandidate(w,profile,converted,details.hatted.p);
naive=densityCandidate(w,profile,converted,[]);
comparison=struct([]);
for name=string(fieldnames(state)).'
    row=struct(family=name,rateMax=max(abs(tangent.(name)),[],'all'), ...
        beforeRetentionDifference=max(abs(details.native.(name)-tangent.(name)),[],'all'), ...
        retentionDifference=max(abs(shared.(name)-details.native.(name)),[],'all'), ...
        closureDifference=max(abs(naive.(name)-shared.(name)),[],'all'), ...
        candidateDifference=max(abs(naive.(name)-tangent.(name)),[],'all'));
    if isempty(comparison), comparison=row; else, comparison(end+1)=row; end %#ok<AGROW>
end
result=struct(finiteDifferences=rows,comparison=comparison,tangent=tangent, ...
    reference=base.reference,surfacePressureMismatch=surfaceMismatch);
end

function [rate,surfaceMismatch]=densityCandidate(w,profile,state,pressure)
spectral=w.reconstructSpectralState(state=state); a=struct();
for name=["u","v","w","eta","ssh","p"]
    a.(name)=w.transformToSpatialDomainWithFourier(spectral.(name));
end
a.ssh=a.ssh(:,:,end);
if isempty(pressure), pressure=a.p; end
surfaceMismatch=max(abs(pressure(:,:,end)-w.rho0*w.g*a.ssh),[],'all');
alpha=reshape(1+w.z/w.Lz,1,1,[]); xi=reshape(w.z,1,1,[]);
e=a.eta-alpha.*a.ssh;
if profile=="constant", lambda=0; interior=e; else, lambda=1/650; interior=-log1p(-lambda*e)/lambda; end
eta=interior+alpha.*a.ssh; z=xi+alpha.*a.ssh; r=xi-interior;
assert(isreal(interior) && min(r,[],'all')>=-w.Lz && max(r,[],'all')<=0,'Retained density candidate must have admissible labels.');
if lambda==0, B=-1e-4*(eta-max(z,0)); else, B=-1e-4*exp(lambda*r).*expm1(lambda*(eta-max(z,0)))/lambda; end
q=reshape(w.N2,1,1,[]);
derivative=struct(x=@(f)w.diffX(f),y=@(f)w.diffY(f),xi=@(f)w.diffZ(f));
terms=WVInternal.freeSurfaceNonlinearTerms(a,pressure,w.z,w.Lz,w.f,w.rho0,w.N2,-B-q.*a.eta,derivative);
gamma=1+a.ssh/w.Lz; u=a.u./gamma; v=a.v./gamma;
wi=(a.w-alpha.*a.w(:,:,end))./gamma;
physicalW=a.w+alpha.*(u.*w.diffX(a.ssh)+v.*w.diffY(a.ssh));
source=terms.source;
source.eta=physicalW-e.*wi*lambda-u.*w.diffX(a.eta)-v.*w.diffY(a.eta)-wi.*w.diffZ(a.eta)-a.w;
% The retained state has its own modal pressure in the cancelling linear
% operator. A prescribed shared pressure changes the total acceleration.
source.u=source.u-w.diffX(pressure-a.p)/w.rho0;
source.v=source.v-w.diffY(pressure-a.p)/w.rho0;
source.w=source.w-w.diffZ(pressure-a.p)/w.rho0;
rate=w.projectSources(source);
end
