function [tendency,speed]=coefficientTendency(self,options)
% Evaluate selected thermal dynamics and registered sources.
% - Topic: Density diffusion integration
% - Parameter options.linearDynamics: true selects linear dynamics; false requires qualified nonlinear advection
% - Parameter options.excludingHomogeneousEvolution: omit diffusion for exponential stages
% - Parameter options.excludingForcing: names of analytically handled forcings
arguments
    self WVTransformFreeSurfaceThermalQG
    options.linearDynamics (1,1) logical = false
    options.excludingHomogeneousEvolution (1,1) logical = false
    options.excludingForcing (1,:) string = strings(1,0)
end
hasAdvection=self.hasForcingWithName('nonlinear advection');
if options.linearDynamics && hasAdvection
    error('WV:ThermalLinearConflict','Remove nonlinear advection before selecting linearDynamics=true.');
elseif ~options.linearDynamics && ~hasAdvection
    error('WV:ThermalEvolutionUnavailable','Register qualified nonlinear advection or explicitly select linearDynamics=true.');
end
needsNative=~hasAdvection;
for force=self.forcing
    needsNative=needsNative || (~isa(force,'WVNonlinearAdvection') && ~isa(force,'WVSeasonalSurfaceAnomalyForcing'));
end
if needsNative
    [q,u,v,b,ub,vb,phiHat]=self.quasigeostrophicSpatialState();
    speed=max(hypot(u,v),[],'all');
    physical=struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb,phiHat=phiHat,uvMax=speed);
else
    physical=struct(); speed=0;
end
if hasAdvection
    [physical.thermalNonlinearTendency,nonlinearSpeed]=self.nonlinearCoefficientTendency();
    speed=max(speed,nonlinearSpeed); physical.uvMax=speed;
end
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
