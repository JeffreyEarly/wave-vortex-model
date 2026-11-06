function evidence = evaluateBoussinesqRHSAssessment(prepared,Nxyz,options)
% Evaluate the complete nonlinear source and fixed modal projection on another grid.
% No eigensolve, modal fit, closure change, or source filtering is performed.
% crossingOrder=0 keeps native quadrature; a positive order integrates the
% buoyancy crossing layer separately. evidence.source always retains the
% pointwise physical source; only its volume projection receives the load.
arguments
    prepared (1,1) struct
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.crossingOrder (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end
if ~isfield(prepared,'kind') || prepared.kind~="boussinesqRHSSnapshot-v1"
    error('WV:InvalidRHSAssessment','Supply a prepared Boussinesq RHS snapshot.')
end
w=prepared.transform; nz=Nxyz(3);
if any(Nxyz(1:2)<[w.Nx w.Ny]) || nz<5
    error('WV:InvalidAssessmentGrid','Use at least the original horizontal grid and five vertical samples.')
end
if options.crossingOrder>0 && w.verticalGrid.kind~="wkb"
    error('WV:CrossingProjectionGrid','Crossing projection requires a WKB grid. Use crossingOrder=0 for this evolution grid.')
end
if nz == w.Nz
    z = w.z;
    q = w.verticalQuadratureWeights;
    Dz = w.verticalDerivativeMatrix;
    M = eye(nz);
else
    calculus = w.verticalGrid.calculus;
    % Vary the sampling without rebuilding the map or its smoothing.
    [z,q,Dz] = calculus.lobattoRule(nz);
    M = calculus.interpolationMatrix(z);
end
geometry=WVGeometryDoublyPeriodic([w.Lx w.Ly],Nxyz(1:2),Nz=nz,shouldAntialias=false,shouldExcludeNyquist=true,shouldExcludeConjugates=w.shouldExcludeConjugates,conjugateDimension=w.conjugateDimension);
keys=round([w.k(:)*w.Lx,w.l(:)*w.Ly]/(2*pi));
otherKeys=round([geometry.k(:)*w.Lx,geometry.l(:)*w.Ly]/(2*pi));
[found,indices]=ismember(keys,otherKeys,'rows');
if ~all(found), error('WV:MissingAssessmentWavenumber','The evaluation grid omits a retained wavenumber.'); end
if options.crossingOrder>0
    crossing=WVInternal.prepareBuoyancyCrossingProjection(w.N2Function,z,q,w.Lz,options.crossingOrder);
end
h=struct();
for name=["u","v","w","eta","p"]
    value=zeros(nz,numel(geometry.k)); value(:,indices)=M*prepared.spectral.(name);
    h.(name)=geometry.transformToSpatialDomainWithFourier(value);
end
h.ssh=h.p(:,:,end)/(w.rho0*w.g);
physicalZ=reshape(z,1,1,[])+reshape(1+z/w.Lz,1,1,[]).*h.ssh;
N2=w.N2Function(z); N2=N2(:);
if options.crossingOrder>0
    thermal=prepared.thermodynamics.evaluateCrossingSplit(physicalZ,h.eta,h.ssh,N2);
else
    thermal=prepared.thermodynamics.evaluateNonlinear(physicalZ,h.eta,h.ssh,N2);
end
derivative=struct(x=@(a)geometry.diffX(a),y=@(a)geometry.diffY(a),xi=@verticalDerivative);
terms=WVInternal.freeSurfaceNonlinearTerms(h,h.p,z,w.Lz,w.f,w.rho0,N2,thermal.buoyancyRemainder,derivative);
source=terms.source;
for name=["u","v","w","eta"]
    values=geometry.transformFromSpatialDomainWithFourier(source.(name)); spectral.(name)=values(:,indices);
    values=geometry.transformFromSpatialDomainWithFourier(-terms.N.(name)); advective.(name)=values(:,indices);
end
projectionSource=spectral;
if options.crossingOrder>0
    load=crossing.load(h.ssh);
    splitBuoyancy=-thermal.smoothBuoyancyRemainder+load;
    splitW=-terms.N.w+(h.ssh./(w.Lz+h.ssh)).*verticalDerivative(h.p)/w.rho0+splitBuoyancy;
    values=geometry.transformFromSpatialDomainWithFourier(splitW);
    projectionSource.w=values(:,indices);
end
if nz == w.Nz
    projection = w;
    waveF = w.waveF;
    waveG = w.waveG;
else
    projection = projectionOnRule(w,M,q,N2);
    waveF = pagemtimes(M,w.waveF);
    waveG = pagemtimes(M,w.waveG);
end
rate = project(projectionSource);
advection = project(advective);
zero=zeros(size(spectral.u)); buoyancy=struct(u=zero,v=zero,w=zero,eta=zero);
values=geometry.transformFromSpatialDomainWithFourier(-thermal.buoyancyRemainder); buoyancy.w=values(:,indices);
if options.crossingOrder>0
    values=geometry.transformFromSpatialDomainWithFourier(splitBuoyancy); buoyancy.w=values(:,indices);
end
buoyancy=project(buoyancy);
evidence=struct(crossingOrder=options.crossingOrder,snapshot=w,grid=Nxyz,z=z,source=spectral,tendency=rate,advection=advection,buoyancy=buoyancy,minimumGamma=min(1+h.ssh/w.Lz,[],'all'),maximumSSHOverDepth=max(abs(h.ssh),[],'all')/w.Lz,minimumLabel=min(physicalZ-h.eta,[],'all'),maximumLabel=max(physicalZ-h.eta,[],'all'));
    function value=verticalDerivative(a)
        value=reshape(reshape(a,[],nz)*Dz.',size(a));
    end
    function tendency = project(s)
        tendency = WVInternal.projectBoussinesqSpectralSources(w,s,projection,q,N2,waveF,waveG);
    end
end

function projection = projectionOnRule(w,M,weights,N2)
% Resample mode values before applying the continuous normalization.
% Endpoint values contribute directly to the first and last columns.
F = M*w.apvF;
G = M*w.apvG;
projection.apvFProjection = w.apvProjectionNormalization*(F'.*(weights.'/w.Lz));
projection.apvGProjection = WVInternal.freeSurfaceAPVDisplacementProjection(F,G,weights,N2,w.g,w.apvProjectionNormalization);
projection.inertialFProjection = (M*w.inertialF)'.*(weights.'/w.Lz);

measure = weights.*N2/w.g;
if isfinite(w.g0), measure(end) = measure(end)+w.g0/w.g; end
if isfinite(w.gd), measure(1) = measure(1)+w.gd/w.g; end
projection.mdaGProjection = w.mdaProjectionNormalization*((M*w.mdaG)'.*measure.');

nEndpoint = numel(w.activeEndpoint);
projection.zeroAPVFProjection = zeros(nEndpoint,numel(weights),numel(w.khUnique));
projection.zeroAPVGProjection = zeros(size(projection.zeroAPVFProjection));
for p = 1:numel(w.khUnique)
    [projection.zeroAPVFProjection(:,:,p),projection.zeroAPVGProjection(:,:,p)] = ...
        WVInternal.freeSurfaceBoundarySourceProjections(M*w.zeroAPVF(:,:,p),M*w.zeroAPVG(:,:,p), ...
        weights,N2,w.Lz,w.g,w.g0,w.gd);
end
end
