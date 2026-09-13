function evidence = evaluateBoussinesqRHSAssessment(prepared,Nxyz,options)
% Evaluate the complete nonlinear source and fixed modal dual on another grid.
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
problem=IMInternalModes.geostrophicAPVModes(N2=w.N2Function,zDomain=[-w.Lz 0],g=w.g,g0=w.g0,gd=w.gd,surfaceBoundary="freeSurface");
solver=IMSolverSpectral(nEVP=nz,coordinateKind="wkb").configuredForEVP(problem);
[z,q,Dz]=solver.nativeDifferentiationRule([-w.Lz 0]); q=q*(w.Lz/sum(q));
M=interpolation(w.Nz,nz);
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
rate=project(projectionSource); advection=project(advective);
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
    function matrix=pairing(part)
        basis=M*part.basis; density=basis.';
        if part.stratified, density=density.*N2.'; end
        matrix=(part.mix*density).*q.';
        matrix(:,[1 end])=matrix(:,[1 end])+part.endpoint;
    end
    function tendency=project(s)
        columns=w.klNonzero;
        curl=1i*w.kNonzero.'.*s.v(:,columns)-1i*w.lNonzero.'.*s.u(:,columns);
        tendency.Ag_q=pairing(prepared.pairings.apvF)*curl-(w.f/w.Lz)*pairing(prepared.pairings.apvG)*s.eta(:,columns);
        tendency.Ag_0=complex(zeros(size(w.Ag_0))); tendency.Aw_p=complex(zeros(size(w.Aw_p))); tendency.Aw_m=tendency.Aw_p;
        for p=1:numel(w.khUnique)
            c=find(w.klNonzeroKhUniqueIndex==p);
            tendency.Ag_0(:,c)=w.zeroAPVSourceSolve(:,:,p)*(pairing(prepared.pairings.zeroF{p})*curl(:,c)-(w.f/w.Lz)*pairing(prepared.pairings.zeroG{p})*s.eta(:,columns(c)));
            count=w.waveModeCountByKh(p); if count==0, continue; end
            modes=1:count; F=M*w.waveF(:,modes,p); G=M*w.waveG(:,modes,p);
            U=F'*(q.*s.u(:,columns(c))); V=F'*(q.*s.v(:,columns(c)));
            W=G'*(q.*s.w(:,columns(c))); E=G'*((q.*N2).*s.eta(:,columns(c)));
            k=w.kNonzero(c).'; l=w.lNonzero(c).'; kh=w.khUnique(p); depth=w.waveEquivalentDepth(modes,p); omega=w.waveFrequency(modes,p);
            common=(k.*U+l.*V)/kh+1i*kh*depth.*W;
            signed=(1i*w.f./(omega*kh)).*(l.*U-k.*V)-(kh*depth./omega).*E;
            phase=exp(1i*omega*(w.t-w.t0));
            tendency.Aw_p(modes,c)=((common+signed)./(2*depth))./phase;
            tendency.Aw_m(modes,c)=((common-signed)./(2*depth)).*phase;
        end
        meanIndex=find(w.k==0 & w.l==0,1);
        tendency.Aio=.5*exp(-1i*w.f*(w.t-w.t0))*pairing(prepared.pairings.inertial)*(s.u(:,meanIndex)-1i*s.v(:,meanIndex));
        tendency.Amda=real(pairing(prepared.pairings.mda)*s.eta(:,meanIndex));
    end
end
function M=interpolation(n,m)
x=-cos(pi*(0:n-1)'/(n-1)); y=-cos(pi*(0:m-1)'/(m-1));
b=(-1).^(0:n-1)'; b([1 end])=b([1 end])/2; M=zeros(m,n);
for j=1:m
    [distance,k]=min(abs(y(j)-x));
    if distance<32*eps, M(j,k)=1; else, row=b./(y(j)-x); M(j,:)=row.'/sum(row); end
end
end
