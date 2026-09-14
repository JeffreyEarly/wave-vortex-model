function [tendency,speed]=coefficientTendency(self,options)
% Evaluate explicitly selected linear thermal dynamics and registered sources.
% - Topic: Density diffusion integration
% - Parameter options.linearDynamics: must be true until nonlinear T4 is qualified
% - Parameter options.excludingHomogeneousEvolution: omit diffusion for exponential stages
% - Parameter options.excludingForcing: names of analytically handled forcings
arguments
    self WVTransformFreeSurfaceThermalQG
    options.linearDynamics (1,1) logical = false
    options.excludingHomogeneousEvolution (1,1) logical = false
    options.excludingForcing (1,:) string = strings(1,0)
end
if ~options.linearDynamics, error('WV:ThermalEvolutionUnavailable','Select linearDynamics=true explicitly; nonlinear thermal dynamics require T4.'); end
[q,u,v,b,ub,vb,phiHat]=self.quasigeostrophicSpatialState();
speed=max(hypot(u,v),[],'all');
physical=struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb,phiHat=phiHat,uvMax=speed);
tendency=struct(Ath=complex(zeros(size(self.Ath))),Amda=zeros(size(self.Amda)));
if ~options.excludingHomogeneousEvolution
    tendency.Ath=self.kappa_z*self.thermalRatesPerDiffusivity(:,self.klNonzeroKhUniqueIndex).*self.Ath;
    tendency.Amda=self.kappa_z*self.mdaGeneratorPerDiffusivity*self.Amda;
end
Fq=zeros(self.spatialMatrixSize); Fb=zeros(self.Nx,self.Ny,2); hasSpatial=false;
for force=self.spatialFluxForcing
    if any(options.excludingForcing==string(force.name)), continue; end
    [Fq,Fb]=force.addQuasigeostrophicSpatialForcing(self,Fq,Fb,physical); hasSpatial=true;
end
if hasSpatial
    source=self.projectQuasigeostrophicSpatialTendency(Fq,Fb);
    tendency.Ath=tendency.Ath+source.Ath; tendency.Amda=tendency.Amda+source.Amda;
end
for force=self.spectralFluxForcing
    if any(options.excludingForcing==string(force.name)), continue; end
    tendency=force.addQuasigeostrophicSpectralForcing(self,tendency,physical);
end
end
