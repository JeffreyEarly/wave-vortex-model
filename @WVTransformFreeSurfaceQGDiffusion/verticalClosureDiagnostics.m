function diagnostics=verticalClosureDiagnostics(self)
% Separate physical energy and over-integrated enstrophy source budgets.
% The historical potentialEnstrophy property is not redefined. These budgets
% use the physical-depth polynomial quadrature for independent QGPV.
% - Topic: Evaluate physical fields
if isempty(self.verticalNumerics)
    error('WVTransformFreeSurfaceQGDiffusion:MissingVerticalOperators','Configure vertical operators before requesting polynomial budget diagnostics.');
end
o=self.verticalNumerics;
[q,b]=self.transformStateBack(self.Ag_T); c=o.qToPolynomial*q;
[phi,eta,~,~]=self.reconstructSpectralState();
[qSpatial,u,v,bSpatial,ub,vb]=self.quasigeostrophicSpatialState();
physical=struct(q=qSpatial,u=u,v=v,b=bSpatial,ub=ub,vb=vb);
speed=max(hypot(u,v),[],'all');
if self.shouldDealiasVertical
    [Fq,Fb,fineSpeed]=self.dealiasedAdvection(physical); speed=max(speed,fineSpeed);
else
    nonlinear=WVNonlinearAdvection(self);
    [Fq,Fb]=nonlinear.addQuasigeostrophicSpatialForcing(self,zeros(self.spatialMatrixSize),zeros(self.Nx,self.Ny,self.activeEndpointCount),physical);
end
advection=self.projectQuasigeostrophicSpatialTendency(Fq,Fb);
horizontal=complex(zeros(size(self.Ag_T))); vertical=horizontal; source=horizontal;
for force=self.spectralFluxForcing
    if isa(force,'WVAdaptiveDamping')
        horizontal=horizontal+speed*force.damp(:,self.klNonzero).*self.Ag_T;
        if force.verticalDampingStrength>0
            vertical=vertical+self.transformStateForward(speed*(force.verticalDamp*q),complex(zeros(size(b))));
        end
    end
end
for force=self.spatialFluxForcing
    if isa(force,'WVSeasonalSurfaceAnomalyForcing')
        [Fq,Fb]=force.addQuasigeostrophicSpatialForcing(self,zeros(self.spatialMatrixSize),zeros(self.Nx,self.Ny,self.activeEndpointCount),physical);
        tendency=self.projectQuasigeostrophicSpatialTendency(Fq,Fb); source=source+tendency.Ag_T;
    end
end
tail=o.polynomialDegree>=.8*max(o.polynomialDegree);
diagnostics=struct(overintegratedPotentialEnstrophy=sum(abs(c).^2,'all'),verticalTailFraction=sum(abs(c(tail,:)).^2,'all')/max(sum(abs(c).^2,'all'),realmin),advection=power(advection.Ag_T),thermal=power(self.coefficientLinearRates().*self.Ag_T),horizontalDamping=power(horizontal),verticalDamping=power(vertical),surfaceForcing=power(source));
    function result=power(amplitudes)
        [dq,db]=self.transformStateBack(amplitudes);
        [dphi,deta,~,~]=self.reconstructSpectralState(amplitudes);
        enstrophy=2*real(sum(conj(c).*(o.qToPolynomial*dq),'all'));
        energy=2*real(sum(self.verticalQuadratureWeights.*(self.khNonzero.'.^2.*conj(phi).*dphi+self.N2.*conj(eta).*deta),'all'));
        endpointVariance=2*real(sum(conj(b).*db,'all'));
        result=struct(enstrophy=enstrophy,physicalEnergy=energy,endpointVariance=endpointVariance);
    end
end
