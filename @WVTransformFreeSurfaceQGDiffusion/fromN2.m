function self = fromN2(Lxyz,Nxyz,options)
% Build complete balanced diffusion modes on a WKB Chebyshev grid.
%
% No APV eigensolve is performed. The APV descriptor supplies only the
% physical domain and stratification to the native spectral grid builder.
% The matrix acts on [q(z(2:end-1)); b0], with b0 in meters.
%
% - Topic: Create and restore a transform
% - Parameter Lxyz: domain lengths in meters
% - Parameter Nxyz: horizontal and vertical grid counts
% - Parameter verticalDealiasingFactor: nonlinear quadrature count divided by Nz; default 2, independent of the thermal mode count
% - Parameter options.N2Function: positive stratification function
% - Parameter options.kappaT: fixed buoyancy diffusivity, default 1e-5 m2/s
% - Returns self: complete thermal-mode transform
arguments
    Lxyz (1,3) double {mustBePositive,mustBeFinite}
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    options.N2Function (1,1) function_handle
    options.kappaT (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-5
    options.latitude (1,1) double {mustBeSupportedLatitude} = 24
    options.rotationRate (1,1) double {mustBePositive,mustBeFinite} = 7.2921e-5
    options.planetaryRadius (1,1) double {mustBePositive,mustBeFinite} = 6.371e6
    options.g (1,1) double {mustBePositive,mustBeFinite} = 9.81
    options.shouldAntialias (1,1) logical = true
    options.verticalDealiasingFactor (1,1) double {mustBeGreaterThanOrEqual(options.verticalDealiasingFactor,1),mustBeFinite} = 2
end
if Nxyz(3)<5 || min(Nxyz(1:2))<4
    error('WVTransformFreeSurfaceQGDiffusion:InvalidGrid','Use Nz >= 5 and Nx, Ny >= 4.');
end
D=Lxyz(3); nz=Nxyz(3); n=nz-1;
f=2*options.rotationRate*sind(options.latitude);
problem=IMInternalModes.geostrophicAPVModes(N2=options.N2Function,zDomain=[-D 0],g=options.g,g0=0,gd=Inf,surfaceBoundary="freeSurface");
grid=IMSolverSpectral(nEVP=nz,coordinateKind="wkb").configuredForEVP(problem);
[z,w,Dz]=grid.nativeDifferentiationRule([-D 0]); w=w*(D/sum(w));
N2=reshape(options.N2Function(z),[],1);
if numel(N2)~=nz || any(~isfinite(N2) | N2<=0)
    error('WVTransformFreeSurfaceQGDiffusion:InvalidStratification','N2Function must return a finite positive value at every node.');
end
geometry=WVGeometryDoublyPeriodic(Lxyz(1:2),Nxyz(1:2),shouldAntialias=options.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
kh=hypot(geometry.k,geometry.l); kh=kh(kh>0);
[khUnique,~,pageMap]=uniquetol(kh,100*eps,DataScale=max(kh)); np=length(khUnique);
state=rmfield(options,{'N2Function','verticalDealiasingFactor'});
state.verticalNumerics=WVQGVerticalOperators.fromGrid(z,options.verticalDealiasingFactor);
state.shouldDealiasVertical=true;
state.Lx=Lxyz(1); state.Ly=Lxyz(2); state.x=geometry.x; state.y=geometry.y;
state.z=z; state.N2=N2; state.khUnique=khUnique; state.klNonzeroKhUniqueIndex=pageMap;
state.verticalQuadratureWeights=w; state.verticalDerivativeMatrix=Dz;
state.scaledStateFromModes=complex(zeros(n,n,np)); state.modesFromScaledState=state.scaledStateFromModes;
state.phiModes=complex(zeros(nz,n,np)); state.etaModes=state.phiModes; state.qModes=state.phiModes;
state.thermalDecayRate=complex(zeros(n,np)); state.eigenResidual=zeros(np,1); state.eigenvectorCondition=zeros(np,1);
scale=[(D/abs(f))*sqrt(w(2:end-1)/D);1];
% Homogeneous weak diffusion, expressed on interior displacement.
vertical=-(Dz.'*(w.*(Dz.*N2.')))./(w.*N2); vertical(1,:)=0;
projection=[-f*Dz(2:end-1,:);zeros(1,nz)]; projection(end,end)=1;
rhs=zeros(nz,n); rhs(2:end-1,1:end-1)=eye(nz-2); rhs(end,end)=1;
% At zero diffusivity use the unit-diffusivity basis with zero rates.
solveDiffusivity=options.kappaT;
if solveDiffusivity==0, solveDiffusivity=1; end
for ip=1:np
    Q=-khUnique(ip)^2*eye(nz)+Dz*((f^2./N2).*Dz);
    inversion=Q;
    inversion(1,:)=-(f/N2(1))*Dz(1,:);
    inversion(end,:)=-(f/N2(end))*Dz(end,:);
    inversion(end,end)=inversion(end,end)-f/options.g;
    phi=inversion\rhs;
    eta=-(f./N2).*(Dz*phi);
    etaInterior=eta-(f/options.g)*(1+z/D)*phi(end,:);
    L=solveDiffusivity*projection*vertical*etaInterior;
    Lscaled=scale.*L./scale.';
    [right,lambda,left]=eig(Lscaled); lambda=diag(lambda);
    [~,order]=sortrows([real(lambda),imag(lambda)],[-1 2]);
    lambda=lambda(order); right=right(:,order); left=left(:,order);
    % Fix each eigenvector phase using its largest scaled-state entry.
    [~,pivot]=max(abs(right),[],1);
    phase=exp(-1i*angle(right(sub2ind([n n],pivot,1:n))));
    right=right.*phase; left=left.*phase;
    left=left./conj(diag(left'*right).');
    residual=norm(Lscaled*right-right.*lambda.','fro')/max(norm(Lscaled,'fro'),realmin);
    inverseResidual=norm(left'*right-eye(n),'fro')/sqrt(n);
    growthTolerance=1e3*eps*norm(Lscaled,2);
    if residual>1e-11 || inverseResidual>1e-9 || any(real(lambda)>growthTolerance)
        error('WVTransformFreeSurfaceQGDiffusion:UnreliableModes','Page kh=%.8g: eigen residual %.3g, inverse residual %.3g, maximum growth %.3g.',khUnique(ip),residual,inverseResidual,max(real(lambda)));
    end
    state.scaledStateFromModes(:,:,ip)=right;
    state.modesFromScaledState(:,:,ip)=left';
    R=right./scale;
    state.phiModes(:,:,ip)=phi*R; state.etaModes(:,:,ip)=eta*R; state.qModes(:,:,ip)=(Q*phi)*R;
    state.thermalDecayRate(:,ip)=-lambda*(options.kappaT/solveDiffusivity);
    state.eigenResidual(ip)=residual; state.eigenvectorCondition(ip)=cond(right);
end
args=namedargs2cell(state);
self=WVTransformFreeSurfaceQGDiffusion(args{:});
end
