function helper = freeSurfaceWeakStudyHelpers()
% Share study-local basis, geometry, energy, and weak-operator calculations.
% These helpers are diagnostic implementation details, not production APIs.
helper = struct();
helper.buildContext = @buildContext;
helper.sampledState = @sampledState;
helper.globalBasis = @globalBasis;
helper.seedState = @seedState;
helper.gram = @gram;
helper.physicalPair = @physicalPair;
helper.stateFromVector = @stateFromVector;
helper.fieldError = @fieldError;
helper.energyGeometry = @energyGeometry;
helper.verticalIntegral = @verticalIntegral;
helper.metricApply = @metricApply;
helper.constrainedSolve = @constrainedSolve;
helper.directionalGradientCheck = @directionalGradientCheck;
helper.pressureAdjointDefect = @pressureAdjointDefect;
helper.seedCheckpoints = @seedCheckpoints;
helper.fourierDerivative = @fourierDerivative;
helper.weakTendency = @weakTendency;
helper.labelBounds = @labelBounds;
helper.materialInvariants = @materialInvariants;
end

function context = buildContext(wvt,padding)
context.shape = [padding*wvt.Nx padding*wvt.Ny wvt.Nz];
context.nSurface = prod(context.shape(1:2));
context.bottom = (1:context.nSurface).';
context.top = ((wvt.Nz-1)*context.nSurface+(1:context.nSurface)).';
context.surfaceWeights = ones(context.nSurface,1)/context.nSurface;
context.weights = kron(wvt.verticalQuadratureWeights,context.surfaceWeights);
context.xi = wvt.z; context.D=wvt.Lz; context.g=wvt.g; context.N2=1e-4;
context.derivative.x = @(field) fourierDerivative(field,wvt.Lx,1);
context.derivative.y = @(field) fourierDerivative(field,wvt.Ly,2);
context.derivative.xi = @(field) reshape(reshape(field,[],wvt.Nz)*wvt.verticalDerivativeMatrix.',size(field));
context.verticalMatrix = wvt.verticalDerivativeMatrix;
context.f = wvt.f;
context.rho0 = wvt.rho0;
context.labelXi = linspace(-wvt.Lz,0,257).';
labelWeights = (-1).^(0:wvt.Nz-1).';
labelWeights([1 end]) = labelWeights([1 end])/2;
context.labelInterpolation = zeros(length(context.labelXi),wvt.Nz);
for j = 1:length(context.labelXi)
    [distance,index] = min(abs(context.labelXi(j)-wvt.z));
    if distance<1e-12*wvt.Lz
        context.labelInterpolation(j,index)=1;
    else
        row=labelWeights./(context.labelXi(j)-wvt.z);
        context.labelInterpolation(j,:)=row.'/sum(row);
    end
end
end

function fields = sampledState(wvt,state,context)
spectral = wvt.reconstructSpectralState(state=state);
for name = ["u","v","w","eta","ssh"]
    value = wvt.transformToSpatialDomainWithFourier(spectral.(name));
    value = real(interpft(interpft(value,context.shape(1),1),context.shape(2),2));
    if name=="ssh", value=value(:,:,end); end
    fields.(name)=value;
end
end

function [basis,linearBasis] = globalBasis(wvt,context)
template = wvt.coefficientState();
fields = sampledState(wvt,template,context);
for name = ["u","v","w","eta","ssh"]
    basis.(name)=zeros(numel(fields.(name)),0);
    linearBasis.(name)=basis.(name);
end
for family = ["Ag_q","Ag_0","Aw_p","Aw_m","Aio","Amda"]
    for entry = 1:numel(template.(family))
        phases = [1 1i];
        if family=="Amda", phases=1; end
        for phase = phases
            state = template; state.(family)(entry)=phase;
            rate = template;
            omega = 0;
            if family=="Aio", omega=wvt.f; end
            if ismember(family,["Aw_p","Aw_m"])
                [mode,column]=ind2sub(size(state.(family)),entry);
                omega=wvt.waveFrequency(mode,wvt.klNonzeroKhUniqueIndex(column));
                if family=="Aw_m", omega=-omega; end
            end
            if omega~=0, rate.(family)(entry)=1i*omega*phase; end
            fields=sampledState(wvt,state,context);
            rates=sampledState(wvt,rate,context);
            for name = ["u","v","w","eta","ssh"]
                basis.(name)(:,end+1)=fields.(name)(:);
                linearBasis.(name)(:,end+1)=rates.(name)(:);
            end
        end
    end
end
end

function state = seedState(wvt)
state = wvt.coefficientState();
column = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
index = wvt.klNonzero(column);
for mode = 1:2
    unit = wvt.coefficientState(); unit.Aw_p(mode,column)=1;
    fields=wvt.reconstructSpectralState(state=unit);
    height=[2 .15]; phase=[.37 1.1];
    state.Aw_p(mode,column)=height(mode)*exp(1i*phase(mode))/(2*fields.ssh(end,index));
end
state.Ag_q(1,column)=5e-9*exp(.83i);
state.Aio(1)=.02*exp(.33i)/(2*wvt.inertialF(end,1));
% Fix the nonzero-harmonic endpoint anomalies independently of the balanced
% APV contribution, so the same physical boundary targets survive refinement.
fields=wvt.reconstructSpectralState(state=state);
existing=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
response=zeros(2,2);
for mode=1:2
    unit=wvt.coefficientState(); unit.Ag_0(mode,column)=1;
    fields=wvt.reconstructSpectralState(state=unit);
    response(:,mode)=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
end
state.Ag_0(:,column)=response\([.2*exp(.7i);.1*exp(1.3i)]/2-existing);
state.Amda(1:2)=wvt.mdaG([end 1],1:2)\[2;-2];
end

function H = gram(basis,context)
H=basis.u'*(context.weights.*basis.u)+basis.v'*(context.weights.*basis.v)+basis.w'*(context.weights.*basis.w)+context.N2*basis.eta'*(context.weights.*basis.eta)+context.g*basis.ssh'*(context.surfaceWeights.*basis.ssh);
H=(H+H')/2;
end

function pair = physicalPair(basis,fields,context)
pair=basis.u'*(context.weights.*fields.u(:))+basis.v'*(context.weights.*fields.v(:))+basis.w'*(context.weights.*fields.w(:))+context.N2*basis.eta'*(context.weights.*fields.eta(:));
if isfield(fields,'ssh'), pair=pair+context.g*basis.ssh'*(context.surfaceWeights.*fields.ssh(:)); end
end

function fields = stateFromVector(basis,state,context)
for name=["u","v","w","eta"], fields.(name)=reshape(basis.(name)*state,context.shape); end
fields.ssh=reshape(basis.ssh*state,context.shape(1:2));
end

function errorValue = fieldError(actual,expected,context)
errorValue=0; scale=0;
for name=["u","v","w","eta"]
    weight=context.weights; if name=="eta", weight=weight*context.N2; end
    errorValue=errorValue+sum(weight.*(actual.(name)(:)-expected.(name)(:)).^2);
    scale=scale+sum(weight.*expected.(name)(:).^2);
end
errorValue=errorValue+context.g*sum(context.surfaceWeights.*(actual.ssh(:)-expected.ssh(:)).^2);
scale=scale+context.g*sum(context.surfaceWeights.*expected.ssh(:).^2);
errorValue=sqrt(errorValue/max(scale,realmin));
end

function [energy,gradient,H,Psi,physical,buoyancy] = energyGeometry(basis,state,context)
hatted=stateFromVector(basis,state,context);
physical=WVInternal.freeSurfacePhysicalFields(hatted,context.xi,context.D,context.derivative.x(hatted.ssh),context.derivative.y(hatted.ssh));
labels=physical.z-hatted.eta;
if min(labels,[],'all') < -context.D-1e-9 || max(labels,[],'all') > 1e-9
    error('WV:WeakStudyLabelDomain','Parcel labels [%.16g,%.16g] leave the specified [-D,0] domain.',min(labels,[],'all'),max(labels,[],'all'));
end
positiveHeight=max(physical.z,0);
APE=.5*context.N2*(hatted.eta.^2-positiveHeight.^2);
APE_z=-context.N2*positiveHeight;
buoyancy=-context.N2*(hatted.eta-positiveHeight);
gamma=repmat(physical.gamma,1,1,context.shape(3));
speedSquared=physical.u.^2+physical.v.^2+physical.w.^2;
energy=sum(context.weights.*gamma(:).*(.5*speedSquared(:)+APE(:)))+.5*context.g*sum(context.surfaceWeights.*hatted.ssh(:).^2);
if nargout==1, return; end
alpha=reshape(1+context.xi/context.D,1,1,[]);
geometry=(physical.w.*hatted.w-.5*speedSquared)/context.D+APE/context.D+gamma.*alpha.*APE_z;
Psi=verticalIntegral(geometry,context)-context.derivative.x(verticalIntegral(alpha.*physical.w.*hatted.u,context))-context.derivative.y(verticalIntegral(alpha.*physical.w.*hatted.v,context));
Psi=Psi(:);
betaX=alpha.*context.derivative.x(hatted.ssh)./physical.gamma;
betaY=alpha.*context.derivative.y(hatted.ssh)./physical.gamma;
R11=1./gamma+gamma.*betaX.^2; R22=1./gamma+gamma.*betaY.^2;
R12=gamma.*betaX.*betaY; R13=gamma.*betaX; R23=gamma.*betaY;
Ru=R11(:).*basis.u+R12(:).*basis.v+R13(:).*basis.w;
Rv=R12(:).*basis.u+R22(:).*basis.v+R23(:).*basis.w;
Rw=R13(:).*basis.u+R23(:).*basis.v+gamma(:).*basis.w;
H=basis.u'*(context.weights.*Ru)+basis.v'*(context.weights.*Rv)+basis.w'*(context.weights.*Rw)+context.N2*basis.eta'*(context.weights.*gamma(:).*basis.eta)+context.g*basis.ssh'*(context.surfaceWeights.*basis.ssh);
H=(H+H')/2;
gradient=H*state+basis.ssh'*(context.surfaceWeights.*Psi);
end

function value = verticalIntegral(field,context)
weights=reshape(context.weights,context.nSurface,[]);
value=reshape(sum(reshape(field,context.nSurface,[]).*weights,2)./context.surfaceWeights,context.shape(1:2));
end

function value = metricApply(physical,field,context)
gamma=physical.gamma;
alpha=reshape(1+context.xi/context.D,1,1,[]);
betaX=alpha.*context.derivative.x(physical.ssh)./gamma;
betaY=alpha.*context.derivative.y(physical.ssh)./gamma;
vertical=field.w+betaX.*field.u+betaY.*field.v;
value.u=field.u./gamma+gamma.*betaX.*vertical;
value.v=field.v./gamma+gamma.*betaY.*vertical;
value.w=gamma.*vertical;
end

function [rate,multiplier] = constrainedSolve(H,f,K,target)
unconstrained=H\f;
response=H\K';
multiplier=(K*response)\(K*unconstrained-target);
rate=unconstrained-response*multiplier;
end

function [relativeError,errors] = directionalGradientCheck(basis,state,gradient,context)
direction=cos((1:length(state)).'*.73);
direction=direction*(norm(state)/norm(direction));
errors=zeros(1,3);
for j=1:3
    step=10^(-j-3);
    plus=energyGeometry(basis,state+step*direction,context);
    minus=energyGeometry(basis,state-step*direction,context);
    errors(j)=abs((plus-minus)/(2*step)-gradient'*direction)/max(norm(gradient)*norm(direction),realmin);
end
relativeError=min(errors);
end

function [relativeError,smoothRelativeError] = pressureAdjointDefect(basis,context)
defect=zeros(size(basis.u,2),size(basis.u,1));
scale=0;
for j=1:size(basis.u,2)
    u=reshape(context.weights.*basis.u(:,j),context.shape);
    v=reshape(context.weights.*basis.v(:,j),context.shape);
    w=reshape(context.weights.*basis.w(:,j),context.shape);
    x=-context.derivative.x(u); y=-context.derivative.y(v);
    z=reshape(reshape(w,[],context.shape(3))*context.verticalMatrix,context.shape);
    value=x+y+z;
    value(context.top)=value(context.top)-context.surfaceWeights.*basis.w(context.top,j);
    defect(j,:)=value(:).';
    scale=scale+sum(x(:).^2+y(:).^2+z(:).^2);
end
relativeError=norm(defect,'fro')/max(sqrt(scale),realmin);
[X,Y,alpha]=ndgrid(2*pi*(0:context.shape(1)-1)/context.shape(1),2*pi*(0:context.shape(2)-1)/context.shape(2),1+context.xi/context.D);
horizontal=cat(4,ones(context.shape),cos(X),sin(X),cos(Y),sin(Y));
pressure=zeros(prod(context.shape),45);
for j=0:8
    for k=1:5
        value=alpha.^j.*horizontal(:,:,:,k);
        pressure(:,5*j+k)=value(:);
    end
end
surfacePair=basis.w(context.top,:)'*(context.surfaceWeights.*pressure(context.top,:));
smoothRelativeError=norm(defect*pressure,'fro')/max(norm(surfacePair,'fro'),realmin);
end

function [fingerprint,eta,ssh,xi] = seedCheckpoints(fields,context)
% Constant stratification gives a physical Chebyshev grid. Compare the same
% low-mode seed on one 24-by-24-by-257 grid using barycentric interpolation.
nz=length(context.xi);
expected=-context.D*(1+cos(pi*(0:nz-1).'/(nz-1)))/2;
if max(abs(context.xi-expected))>1e-9*context.D
    error('WV:WeakStudyCheckpointGrid','The constant-stratification checkpoint assumes the stated Chebyshev physical grid.');
end
xi=linspace(-context.D,0,257).';
weights=(-1).^(0:nz-1).'; weights([1 end])=weights([1 end])/2;
interpolation=zeros(length(xi),nz);
for j=1:length(xi)
    [distance,index]=min(abs(xi(j)-context.xi));
    if distance<1e-12*context.D
        interpolation(j,index)=1;
    else
        row=weights./(xi(j)-context.xi);
        interpolation(j,:)=row.'/sum(row);
    end
end
fingerprint=[];
for name=["u","v","w","eta"]
    value=real(interpft(interpft(fields.(name),24,1),24,2));
    value=reshape(reshape(value,[],nz)*interpolation.',24,24,length(xi));
    scale=sqrt(context.D/length(xi));
    if name=="eta", eta=value; scale=scale*sqrt(context.N2); end
    fingerprint=[fingerprint;scale*value(:)]; %#ok<AGROW>
end
ssh=real(interpft(interpft(fields.ssh,24,1),24,2));
fingerprint=[fingerprint;sqrt(context.g)*ssh(:)];
end

function value = fourierDerivative(field,L,dimension)
n=size(field,dimension);
k=(2*pi/L)*[0:n/2-1 0 -n/2+1:-1];
shape=ones(1,ndims(field)); shape(dimension)=n;
value=real(ifft(1i*reshape(k,shape).*fft(field,[],dimension),[],dimension));
end

function [rate,diagnostics] = weakTendency(study,state)
% Evaluate the same weak/KKT system used by the instantaneous budget study.
basis=study.basis; context=study.context;
hatted=stateFromVector(basis,state,context);
[energy,gradient,H,Psi,physical,buoyancy]=energyGeometry(basis,state,context);
rhs=WVInternal.freeSurfaceMappedTendency(hatted,zeros(context.shape),buoyancy,context.xi,context.D,context.f,context.rho0,context.derivative);
momentum=metricApply(physical,rhs,context);
scalarWeight=context.N2*repmat(physical.gamma,1,1,context.shape(3));
f=basis.u'*(context.weights.*momentum.u(:))+basis.v'*(context.weights.*momentum.v(:))+basis.w'*(context.weights.*momentum.w(:))+basis.eta'*(context.weights.*scalarWeight(:).*rhs.eta(:));
surfaceRate=hatted.w(context.top);
f=f-context.g*basis.w(context.top,:)'*(context.surfaceWeights.*hatted.ssh(:))+context.g*basis.ssh'*(context.surfaceWeights.*surfaceRate);
thetaSurface=hatted.eta(:,:,end)-hatted.ssh;
thetaBottom=hatted.eta(:,:,1);
targetSurface=-physical.u(:,:,end).*context.derivative.x(thetaSurface)-physical.v(:,:,end).*context.derivative.y(thetaSurface);
targetBottom=-physical.u(:,:,1).*context.derivative.x(thetaBottom)-physical.v(:,:,1).*context.derivative.y(thetaBottom);
target=[surfaceRate;targetSurface(:);targetBottom(:)];
[rate,multiplier]=constrainedSolve(H,f,study.K,study.left'*target);
retainedResidual=study.Kfull*rate-study.left*(study.left'*target);
solverResidual=H*rate+study.K'*multiplier-f;
gridWork=state'*f+Psi'*(context.surfaceWeights.*surfaceRate);
reactionWork=-(study.K*state)'*multiplier;
solverWork=state'*solverResidual;
sshWork=Psi'*(context.surfaceWeights.*(basis.ssh*rate-surfaceRate));
[minimumLabel,maximumLabel]=labelBounds(hatted,context);
divergence=context.derivative.x(hatted.u)+context.derivative.y(hatted.v)+context.derivative.xi(hatted.w);
diagnostics=struct(energy=energy,energyRate=gradient'*rate,workRates=[gridWork;reactionWork;solverWork;sshWork],minimumLabel=minimumLabel,maximumLabel=maximumLabel,maximumDivergence=max(abs(divergence),[],'all'),maximumSSHResidual=max(abs(basis.ssh*rate-surfaceRate)),maximumRetainedEndpointResidual=max(abs(retainedResidual(context.nSurface+1:end))),discardedBoundaryTargetRMS=norm(target-study.left*(study.left'*target))/sqrt(length(target)),budgetIdentityError=gradient'*rate-gridWork-reactionWork-solverWork-sshWork);
end

function [minimumLabel,maximumLabel] = labelBounds(hatted,context)
% Check the full evolving label field on the shared dense checkpoint grid.
eta=real(interpft(interpft(hatted.eta,24,1),24,2));
eta=reshape(reshape(eta,[],context.shape(3))*context.labelInterpolation.',24,24,length(context.labelXi));
ssh=real(interpft(interpft(hatted.ssh,24,1),24,2));
labels=reshape(context.labelXi,1,1,[])+reshape(1+context.labelXi/context.D,1,1,[]).*ssh-eta;
minimumLabel=min(labels,[],'all'); maximumLabel=max(labels,[],'all');
if minimumLabel < -context.D || maximumLabel > 0
    error('WV:WeakStudyStageLabelDomain','Stage labels [%.16g,%.16g] leave [-D,0] on the dense checkpoint grid.',minimumLabel,maximumLabel);
end
end

function [moments,scales,q] = materialInvariants(hatted,context)
% Physical APV and material moments; horizontal integrals are area averages.
sshX=context.derivative.x(hatted.ssh); sshY=context.derivative.y(hatted.ssh);
physical=WVInternal.freeSurfacePhysicalFields(hatted,context.xi,context.D,sshX,sshY);
alpha=reshape(1+context.xi/context.D,1,1,[]);
betaX=alpha.*sshX./physical.gamma; betaY=alpha.*sshY./physical.gamma;
dx=@(field)context.derivative.x(field)-betaX.*context.derivative.xi(field);
dy=@(field)context.derivative.y(field)-betaY.*context.derivative.xi(field);
dz=@(field)context.derivative.xi(field)./physical.gamma;
r=physical.z-hatted.eta;
omegaX=dy(physical.w)-dz(physical.v);
omegaY=dz(physical.u)-dx(physical.w);
omegaZ=dx(physical.v)-dy(physical.u);
q=omegaX.*dx(r)+omegaY.*dy(r)+(omegaZ+context.f).*dz(r)-context.f;
gamma=repmat(physical.gamma,1,1,context.shape(3));
weight=context.weights.*gamma(:);
moments=struct(volume=sum(weight),labelMoment1=sum(weight.*r(:)),labelMoment2=sum(weight.*r(:).^2),apvMoment1=sum(weight.*q(:)),apvMoment2=sum(weight.*q(:).^2));
scales=struct(volume=sum(weight),labelMoment1=sum(weight.*abs(r(:))),labelMoment2=sum(weight.*r(:).^2),apvMoment1=sum(weight.*abs(q(:))),apvMoment2=sum(weight.*q(:).^2));
end
