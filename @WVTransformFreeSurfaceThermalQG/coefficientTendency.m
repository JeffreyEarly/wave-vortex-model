function [tendency,speed,processes]=coefficientTendency(self,options)
% Evaluate selected thermal dynamics and registered sources.
% Native spatial sources share one projection unless process budgets are
% requested. Each diagnostic increment is the actual callback before/after
% difference, preserving order-dependent accumulation and exclusions.
% - Topic: Density diffusion integration
% - Parameter options.linearDynamics: true selects linear dynamics; false requires qualified nonlinear advection
% - Parameter options.excludingHomogeneousEvolution: omit diffusion for exponential stages
% - Parameter options.excludingForcing: names of analytically handled forcings
% - Returns tendency: complete family-keyed coefficient rates
% - Returns speed: maximum horizontal speed from required dynamics reconstruction
% - Returns processes: ordered labels and row of family-keyed tendency increments
arguments
    self WVTransformFreeSurfaceThermalQG
    options.linearDynamics (1,1) logical = false
    options.excludingHomogeneousEvolution (1,1) logical = false
    options.excludingForcing (1,:) string = strings(1,0)
end
hasAdvection=any(arrayfun(@(force)isa(force,'WVNonlinearAdvection'),self.forcing));
if options.linearDynamics && hasAdvection
    error('WV:ThermalLinearConflict','Remove nonlinear advection before selecting linearDynamics=true.');
elseif ~options.linearDynamics && ~hasAdvection
    error('WV:ThermalEvolutionUnavailable','Register qualified nonlinear advection or explicitly select linearDynamics=true.');
end
blank=struct(Ath=complex(zeros(size(self.Ath))),Amda=zeros(size(self.Amda)));
tendency=blank; speed=0; hasNonlinearSpeed=false; physical=struct();
processes=struct(labels=strings(1,0),tendencies=repmat(blank,1,0));
if ~options.excludingHomogeneousEvolution
    tendency.Ath=self.kappa_z*self.thermalRatesPerDiffusivity(:,self.klNonzeroKhUniqueIndex).*self.Ath;
    tendency.Amda=self.kappa_z*self.mdaGeneratorPerDiffusivity*self.Amda;
    if nargout>2, processes=append(processes,"density diffusion",tendency); end
end
Fq=[]; Fb=[]; hasSpatial=false;
for force=self.spatialFluxForcing
    if any(options.excludingForcing==string(force.name)), continue; end
    if ~hasSpatial, Fq=zeros(self.spatialMatrixSize); Fb=zeros(self.Nx,self.Ny,2); end
    if ~isa(force,'WVSeasonalSurfaceAnomalyForcing') && ~isfield(physical,'q')
        [physical,speed]=nativeState(self);
    end
    if nargout>2, beforeQ=Fq; beforeB=Fb; end
    [Fq,Fb]=force.addQuasigeostrophicSpatialForcing(self,Fq,Fb,physical); hasSpatial=true;
    if nargout>2
        increment=self.projectQuasigeostrophicSpatialTendency(Fq-beforeQ,Fb-beforeB);
        processes=append(processes,string(force.name),increment);
    end
end
if hasSpatial
    source=self.projectQuasigeostrophicSpatialTendency(Fq,Fb);
    tendency.Ath=tendency.Ath+source.Ath; tendency.Amda=tendency.Amda+source.Amda;
end
for force=self.spectralFluxForcing
    if any(options.excludingForcing==string(force.name)), continue; end
    if nargout>2, before=tendency; end
    if isa(force,'WVNonlinearAdvection')
        [tendency,nonlinearSpeed]=force.addQuasigeostrophicSpectralForcing(self,tendency,physical);
        speed=nonlinearSpeed; hasNonlinearSpeed=true; physical.uvMax=speed;
    else
        if force.isClosure && ~isfield(physical,'uvMax')
            speed=self.uvMax; physical.uvMax=speed;
        end
        if ~isa(force,'WVBottomFrictionQuadratic') && ~force.isClosure && ~isfield(physical,'q')
            [physical,nativeSpeed]=nativeState(self);
            if ~hasNonlinearSpeed, speed=nativeSpeed; end
            physical.uvMax=speed;
        end
        if nargout>2 && (isa(force,'WVThermalAPVDamping') || isa(force,'WVAdaptiveDamping'))
            [tendency,horizontal,~]=force.addQuasigeostrophicSpectralForcing(self,tendency,physical);
        else
            tendency=force.addQuasigeostrophicSpectralForcing(self,tendency,physical);
        end
    end
    validateTendency(tendency,blank,string(force.name));
    if nargout>2
        increment=struct(Ath=tendency.Ath-before.Ath,Amda=tendency.Amda-before.Amda);
        if isa(force,'WVThermalAPVDamping')
            vertical=struct(Ath=increment.Ath-horizontal.Ath,Amda=increment.Amda-horizontal.Amda);
            processes=append(processes,string(force.name)+": horizontal",horizontal);
            processes=append(processes,string(force.name)+": vertical",vertical);
        elseif isa(force,'WVAdaptiveDamping')
            selective=struct(Ath=increment.Ath-horizontal.Ath,Amda=increment.Amda-horizontal.Amda);
            processes=append(processes,string(force.name)+": horizontal",horizontal);
            processes=append(processes,string(force.name)+": generalized enstrophy",selective);
        else
            processes=append(processes,string(force.name),increment);
        end
    end
end
end
function [physical,speed]=nativeState(w)
[q,u,v,b,ub,vb,phiHat]=w.quasigeostrophicSpatialState();
speed=max(hypot(u,v),[],'all');
physical=struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb,phiHat=phiHat,uvMax=speed);
end
function processes=append(processes,label,tendency)
processes.labels(end+1)=label;
processes.tendencies(end+1)=tendency;
end
function validateTendency(value,blank,name)
if ~isstruct(value) || ~isscalar(value) || ~isequal(sort(fieldnames(value)),sort(fieldnames(blank)))
    error('WV:ThermalForcingTendency','Forcing %s must return exactly the Ath and Amda families.',name);
end
for family=string(fieldnames(blank)).'
    if ~isnumeric(value.(family)) || ~isequal(size(value.(family)),size(blank.(family))) || any(~isfinite(value.(family)),'all')
        error('WV:ThermalForcingTendency','Forcing %s returned an invalid %s size or nonfinite values.',name,family);
    end
end
if ~isreal(value.Amda)
    error('WV:ThermalForcingTendency','Forcing %s returned a complex horizontal-mean tendency.',name);
end
end
