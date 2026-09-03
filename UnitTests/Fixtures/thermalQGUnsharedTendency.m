function [tendency,speed,physical] = thermalQGUnsharedTendency(w,excludeSeasonal)
% Reference the original thermal RHS, including its redundant modal products.
% Keep reconstruction independent of the optimized shared-state path.
if nargin<2, excludeSeasonal=false; end
[phi,~,qHat,bHat]=ThermalUnsharedTransform.reconstruct(w,w.Ag_T);
[qHat(2:end-1,:),~]=ThermalUnsharedTransform.stateBack(w,w.Ag_T);
q=w.spatialField(qHat); b=w.spatialField(bHat);
u=w.spatialField(-1i*w.lNonzero.'.*phi); v=w.spatialField(1i*w.kNonzero.'.*phi);
speed=max(hypot(u,v),[],'all');
physical=struct(q=q,u=u,v=v,b=b,ub=u(:,:,end),vb=v(:,:,end),uvMax=speed);
Fq=zeros(w.spatialMatrixSize); Fb=zeros(w.Nx,w.Ny);
for force=w.spatialFluxForcing
    if excludeSeasonal && isa(force,'WVSeasonalSurfaceAnomalyForcing'), continue; end
    if w.shouldDealiasVertical && isa(force,'WVNonlinearAdvection')
        [aq,ab,fineSpeed]=w.dealiasedAdvection(physical);
        Fq=Fq+aq; Fb=Fb+ab; speed=max(speed,fineSpeed); physical.uvMax=speed;
    else
        [Fq,Fb]=force.addQuasigeostrophicSpatialForcing(w,Fq,Fb,physical);
    end
end
qHat=w.spectralField(Fq); bHat=w.spectralField(Fb);
tendency=struct(Ag_T=ThermalUnsharedTransform.stateForward(w,qHat(2:end-1,:),bHat));
for force=w.spectralFluxForcing
    if metaclass(force)==?WVAdaptiveDamping
        tendency.Ag_T=tendency.Ag_T+speed*force.damp(:,w.klNonzero).*w.Ag_T;
        if force.verticalDampingStrength>0
            [q,~]=ThermalUnsharedTransform.stateBack(w,w.Ag_T);
            tendency.Ag_T=tendency.Ag_T+ThermalUnsharedTransform.stateForward(w,speed*(force.verticalDamp*q),complex(zeros(1,length(w.klNonzero))));
        end
    else
        tendency=force.addQuasigeostrophicSpectralForcing(w,tendency,physical);
    end
end
end
