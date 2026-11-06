function report = assessFreeSurfaceJointResolution(w,vertical,options)
% Measure the selected coupled state on the actual observations.
% The shared provider inverse supplies numerical diagnostics only. Measure
% the manuscript projection with its existing signed forms and traces.
% Each positive kappa uses one actual Fourier column. Rotation in the
% horizontal plane preserves the observation norm for its modal synthesis.
arguments (Input)
    w (1,1) WVTransform
    vertical (1,1) struct = struct()
    options.waveReference = []
    options.failureMode (1,1) string {mustBeMember(options.failureMode,["diagnostic","error"])} = "diagnostic"
end
isBoussinesq = isa(w,"WVTransformFreeSurfaceBoussinesq");
native = struct(z=w.z,weights=w.verticalQuadratureWeights,N2=w.N2,P=eye(w.Nz));
reference = referenceQuadrature(w,vertical,options.waveReference);
omittedAPV = omittedAPVMode(w,vertical);
pages = cell(numel(w.khUnique),1);
for p = 1:numel(w.khUnique)
    column = find(w.klNonzeroKhUniqueIndex==p,1);
    pages{p} = assessPage(w,column,p,isBoussinesq,native,reference,vertical,options.waveReference,omittedAPV);
end
meanReport = assessPage(w,0,0,isBoussinesq,native,reference,vertical,options.waveReference,omittedAPV);
pages = vertcat(pages{:});
if isempty(pages), pages = repmat(meanReport,0,1); end
report = struct(status="measured",limitingKappa=NaN,pages=pages,mean=meanReport, ...
    coefficientNorm="one unit of positive observation norm per synthesis column", ...
    rankTolerance=meanReport.recovery.observation.relativeTolerance,policy="diagnostic sampled least squares on the selected span", ...
    sourceReference="one smooth off-span probe of independent volume source components and applicable traces");
records = [pages;meanReport];
rejected = find(~[records.recoverySuccess],1);
if isempty(rejected), return; end
limiting = records(rejected);
report.limitingKappa = limiting.kappa;
if ismember(limiting.recoveryStatus,["sampleRankDeficient","fitRankDeficient"])
    report.status = "rank-deficient";
else
    report.status = "recovery-unavailable";
end
if options.failureMode=="error"
    error('WV:UnresolvedJointSynthesis', ...
        'Selected joint synthesis at kappa %.17g failed (%s, observation rank %g of %d). Increase Nz or request a smaller supported inventory.', ...
        limiting.kappa,limiting.recoveryStatus,limiting.recovery.observation.rank,limiting.columnCount)
end
end

function page = assessPage(w,column,p,isBoussinesq,native,reference,vertical,waveReference,omittedAPV)
isMean = p==0;
kappa = 0; k = 0; l = 0;
if ~isMean
    kappa = w.khUnique(p);
    k = w.kNonzero(column); l = w.lNonzero(column);
end
[A,labels] = observationMatrix(w,native.P,column,p,isBoussinesq);
[D,observationNorm] = observationFactor(w,native,isMean,isBoussinesq);
columnNorms = vecnorm(D.*A,2,1).';
scale = ones(size(columnNorms));
scale(columnNorms>0) = 1./columnNorms(columnNorms>0);
probe = IMDiscreteTransform.fromObservationMatrices(A,columnLabels=labels,coefficientScale=scale, ...
    observationFactor=D,failureMode="diagnostic");
B = physicalProjection(w,A,column,p,isBoussinesq,native);
overlap = B*A;
page = struct(kappa=kappa,k=k,l=l,columnLabels=labels,columnCount=size(A,2),observationNorm=observationNorm, ...
    coefficientScale=scale,recoverySuccess=probe.success,recoveryStatus=probe.status,recovery=probe.diagnostics, ...
    physicalProjectionOverlapError=norm((overlap-eye(size(overlap))).*scale.'./scale,"fro"), ...
    productionInversion=productionInversion(w,A,scale,D,p,isBoussinesq), ...
    reference=assessReference(w,reference,vertical,waveReference,column,p,isBoussinesq,native,overlap,scale), ...
    omittedContent=assessOmittedAPV(w,omittedAPV,column,p,isBoussinesq,B,probe,D,scale));
end

function [A,labels] = observationMatrix(w,P,column,p,isBoussinesq)
if isBoussinesq
    if p==0
        [I,inertial] = WVInternal.freeSurfaceTransferModes(w,"Aio",0,P,w.t0);
        [G,mda] = WVInternal.freeSurfaceTransferModes(w,"Amda",0,P,w.t0);
        A = [2*real(I),-2*imag(I),G];
        labels = ["Aio.real:"+string(inertial.'),"Aio.imag:"+string(inertial.'),"Amda:"+string(mda.')];
    else
        families = ["Ag_q","Ag_0","Aw_p","Aw_m"];
        A = zeros(4*size(P,1)+1,0);
        labels = strings(1,0);
        for family = families
            [M,ids] = WVInternal.freeSurfaceTransferModes(w,family,column,P,w.t0);
            A = [A,M]; %#ok<AGROW>
            labels = [labels,family+":"+string(ids.')]; %#ok<AGROW>
        end
    end
elseif p==0
    A = P*w.mdaG;
    labels = "Amda:"+string(w.mdaModeNumber(:).');
else
    A = [P*w.apvF,zeros(size(P,1),numel(w.activeEndpoint)); ...
        w.apvEndpointResponse(:,:,p),-(w.f/w.g)*eye(numel(w.activeEndpoint))/w.khUnique(p)^2];
    labels = ["Ag_q:"+string(w.apvModeNumber(:).'),"Ag_0:"+string(w.activeEndpoint(:).')];
end
end

function [D,name] = observationFactor(w,grid,isMean,isBoussinesq)
if isBoussinesq
    D = sqrt([repmat(grid.weights,3,1);grid.weights.*grid.N2;w.g]);
    name = "positive hatted energy of u, v, w, total displacement, and SSH";
elseif isMean
    D = sqrt(grid.weights.*grid.N2);
    name = "positive interior potential energy of mean displacement";
else
    D = [sqrt(grid.weights/w.Lz)/abs(w.f);ones(numel(w.activeEndpoint),1)/w.Lz];
    name = "depth RMS of q/abs(f) and Euclidean norm of active endpoint displacement/Lz";
end
end

function B = physicalProjection(w,A,column,p,isBoussinesq,grid)
n = numel(grid.z);
if ~isBoussinesq
    if p==0, B=w.mdaGProjection; else, B=qgProjection(w,w.apvFProjection,p); end
elseif p==0
    F = w.inertialFProjection/2;
    M = w.mdaGProjection;
    B = [F,zeros(size(F,1),3*n+1);zeros(size(F)), -F,zeros(size(F,1),2*n+1);zeros(size(M,1),3*n),M,zeros(size(M,1),1)];
else
    k = w.kNonzero(column); l = w.lNonzero(column); kh = w.khUnique(p);
    F = w.apvFProjection; G = w.apvGProjection; fD = w.f/w.Lz;
    alpha = 1+w.z/w.Lz;
    apv = [-1i*l*F,1i*k*F,zeros(size(F)),-fD*G,fD*(G*alpha-w.apvStretchingMoment)];
    traces = [zeros(2,3*n),full(sparse(1:2,[n,1],[1,1],2,n)),[-1;0]];
    buoyancy = -(w.g/w.f)*kh^2*(traces(w.activeEndpoint,:)-w.apvEndpointResponse(:,:,p)*apv);
    wave = waveProjection(w,A,grid,true);
    B = [apv;buoyancy;wave];
end
end

function B = qgProjection(w,F,p)
ne = numel(w.activeEndpoint);
B = [F,zeros(size(F,1),ne); ...
    -(w.g/w.f)*w.khUnique(p)^2*[-w.apvEndpointResponse(:,:,p)*F,eye(ne)]];
end

function B = waveProjection(w,A,grid,includeSurface)
firstWave = size(w.apvF,2)+numel(w.activeEndpoint)+1;
metric = [repmat(grid.weights,3,1);grid.weights.*grid.N2;w.g*includeSurface];
B = A(:,firstWave:end)'.*(metric.'/(2*w.Lz));
end

function result = productionInversion(w,A,scale,D,p,isBoussinesq)
result = struct(status="not-applicable",spanCount=NaN,roundTripError=NaN,observationNoiseGain=NaN);
if isBoussinesq, return; end
if p==0, R=w.mdaGForward; else, R=qgProjection(w,w.apvFForward,p); end
result = struct(status="measured",spanCount=size(A,2), ...
    roundTripError=norm((R*A-eye(size(A,2))).*scale.'./scale,"fro"), ...
    observationNoiseGain=norm(R./scale./D.',2));
end

function reference = referenceQuadrature(w,vertical,waveReference)
reference = struct();
if ~all(isfield(vertical,["apvReference","mdaReference"])) || isempty(vertical.apvReference) || isempty(vertical.mdaReference), return; end
count = max([129,2*w.Nz+1,2*vertical.referenceNEVP+1]);
if ~isempty(waveReference)
    inertial = waveReference.bases{waveReference.basisIndex(1)};
    count = max(count,2*inertial.solver.nEVP+1);
end
calculus = w.verticalGrid.calculus;
[z,weights] = calculus.quadratureRule(count);
z = [w.z(1);z;w.z(end)];
reference = struct(z=z,weights=[0;weights;0],N2=w.N2Function(z),P=calculus.interpolationMatrix(z));
[reference.apvF,reference.apvG,reference.apvH,reference.apvAvailable] = alignedReference( ...
    vertical.apvReference,w.apvModeNumber,w.apvF,w.z,z,"F");
[~,reference.mdaG,~,reference.mdaAvailable] = alignedReference(vertical.mdaReference,w.mdaModeNumber,w.mdaG,w.z,z,"G");
reference.zeroGram = [];
if ~isempty(w.activeEndpoint) && isfield(vertical,"zeroReference") && ~isempty(vertical.zeroReference)
    g0 = w.g0; gd = w.gd;
    if ~isfinite(g0), g0=0; end
    if ~isfinite(gd), gd=0; end
    reference.zeroGram = vertical.zeroReference.generalizedEnergyMatrix(g0=g0,gd=gd);
end
end

function report = assessReference(w,grid,vertical,waveReference,column,p,isBoussinesq,native,overlap,scale)
sourceStatus = "unassessed";
if ~isBoussinesq && p==0, sourceStatus = "not-applicable"; end
report = struct(status="unassessed",quadratureCount=0,modeInterpolationError=NaN,retainedFieldError=NaN, ...
    maximumRetainedModeFieldError=NaN,sourceStatus=sourceStatus,sourceQuadratureError=NaN,sourceError=NaN);
if isempty(fieldnames(grid)), return; end
fine = modalStateOnGrid(w,grid.P,column,p,isBoussinesq);
[ref,available] = referenceState(w,fine,vertical,waveReference,grid,p,isBoussinesq);
if ~available, return; end
if p>0
    % Even QG reconstructs hatted velocity, total displacement and SSH.
    [Ainterp,Aref] = deal(hattedFields(fine,~isBoussinesq),hattedFields(ref,~isBoussinesq));
    D = observationFactor(w,grid,false,true);
else
    Ainterp = observationMatrix(fine,eye(numel(grid.z)),0,0,isBoussinesq);
    Aref = observationMatrix(ref,eye(numel(grid.z)),0,0,isBoussinesq);
    D = observationFactor(w,grid,true,isBoussinesq);
end
denom = max(norm((D.*Aref).*scale.',"fro"),realmin);
report.status = "measured";
report.quadratureCount = numel(grid.z)-2;
report.modeInterpolationError = norm((D.*(Ainterp-Aref)).*scale.',"fro")/denom;
residual = D.*(Ainterp*overlap-Aref);
report.retainedFieldError = norm(residual.*scale.',"fro")/denom;
report.maximumRetainedModeFieldError = max(vecnorm(residual)./max(vecnorm(D.*Aref),realmin));
if ~isBoussinesq && p==0, return; end
a = sourceProbe(w,w,native,[],column,p,isBoussinesq,true);
b = sourceProbe(w,fine,grid,Ainterp,1,double(p>0),isBoussinesq,false);
c = sourceProbe(w,ref,grid,Aref,1,double(p>0),isBoussinesq,false);
report.sourceStatus = "measured";
report.sourceQuadratureError = norm((a-b)./scale)/max(norm(b./scale),realmin);
report.sourceError = norm((a-c)./scale)/max(norm(c./scale),realmin);
end

function A = hattedFields(state,isQG)
if isQG
    state.waveModeCountByKh = 0;
    state.waveModeNumber = zeros(0,1);
end
A = observationMatrix(state,eye(size(state.apvF,1)),1,1,true);
end

function s = modalStateOnGrid(w,P,column,p,isBoussinesq)
s = struct(Lz=w.Lz,g=w.g,rho0=w.rho0,f=w.f,g0=w.g0,gd=w.gd,t0=w.t0, ...
    activeEndpoint=w.activeEndpoint,apvModeNumber=w.apvModeNumber,mdaModeNumber=w.mdaModeNumber, ...
    khUnique=0,kNonzero=0,lNonzero=0,klNonzeroKhUniqueIndex=1, ...
    mdaG=P*w.mdaG,apvProjectionNormalization=w.apvProjectionNormalization, ...
    mdaProjectionNormalization=w.mdaProjectionNormalization);
if p==0
    if isBoussinesq
        s.inertialF = P*w.inertialF;
        s.inertialModeNumber = w.inertialModeNumber;
    end
    return
end
s.khUnique = w.khUnique(p);
s.kNonzero = w.kNonzero(column); s.lNonzero = w.lNonzero(column);
s.apvF = P*w.apvF; s.apvG = P*w.apvG; s.apvMu = w.apvMu(:,p);
s.zeroAPVF = P*w.zeroAPVF(:,:,p); s.zeroAPVG = P*w.zeroAPVG(:,:,p);
s.apvEndpointResponse = w.apvEndpointResponse(:,:,p);
s.zeroAPVSourceSolve = w.zeroAPVSourceSolve(:,:,p);
if isBoussinesq
    s.waveModeCountByKh = w.waveModeCountByKh(p);
    rows = 1:s.waveModeCountByKh;
    s.waveF = P*w.waveF(:,rows,p); s.waveG = P*w.waveG(:,rows,p);
    s.waveEquivalentDepth = w.waveEquivalentDepth(rows,p); s.waveFrequency = w.waveFrequency(rows,p);
    s.waveModeNumber = w.waveModeNumber(rows);
end
end

function [s,available] = referenceState(w,s,vertical,waves,grid,p,isBoussinesq)
z = grid.z;
if p==0
    s.mdaG = grid.mdaG;
    available = grid.mdaAvailable;
    if ~available || ~isBoussinesq, return; end
    if isempty(waves), available=false; return; end
    basis = waves.bases{waves.basisIndex(1)};
    [s.inertialF,~,~,available] = alignedReference(basis,w.inertialModeNumber,w.inertialF,w.z,z,"F");
    return
end
available = grid.apvAvailable;
if ~available, return; end
s.apvF = grid.apvF; s.apvG = grid.apvG;
s.apvMu = s.khUnique^2+(w.f^2/w.g)./grid.apvH;
response = [s.apvG(end,:)-s.apvF(end,:);s.apvG(1,:)];
s.apvEndpointResponse = -(w.f/w.g)*response(w.activeEndpoint,:)./s.apvMu.';
if ~isempty(w.activeEndpoint)
    if isempty(grid.zeroGram), available=false; return; end
    s.zeroAPVF = vertical.zeroReference.F(z,pages=p);
    s.zeroAPVG = vertical.zeroReference.G(z,pages=p);
    s.zeroAPVSourceSolve = ((2*s.khUnique^2/w.Lz)*grid.zeroGram(:,:,p))\eye(numel(w.activeEndpoint));
end
if ~isBoussinesq || s.waveModeCountByKh==0, return; end
if isempty(waves), available=false; return; end
page = find(waves.kappa==s.khUnique,1);
if isempty(page), available=false; return; end
basis = waves.bases{waves.basisIndex(page)};
rows = 1:s.waveModeCountByKh;
[s.waveF,s.waveG,s.waveEquivalentDepth,available] = alignedReference(basis,s.waveModeNumber,w.waveF(:,rows,p),w.z,z,"F");
s.waveFrequency = sqrt(w.f^2+w.g*s.waveEquivalentDepth*s.khUnique^2);
end

function [F,G,h,available] = alignedReference(basis,labels,values,nodes,z,variable)
[matched,rows] = ismember(labels(:),basis.modeNumber(:));
F = []; G = []; h = [];
available = all(matched);
if ~available, return; end
if variable=="F", anchor=basis.F(nodes); else, anchor=basis.G(nodes); end
phase = sign(real(sum(conj(anchor(:,rows)).*values,1)));
available = all(phase~=0);
if ~available, return; end
F = basis.F(z); G = basis.G(z);
F = F(:,rows).*phase; G = G(:,rows).*phase;
h = reshape(basis.h(rows),[],1);
end

function a = sourceProbe(w,s,grid,A,column,p,isBoussinesq,isNative)
x = 1+grid.z/w.Lz;
if ~isBoussinesq
    q = abs(w.f)*(1+.3i*x+.2*sin(7*x));
    ends = w.Lz*[.013+.002i;-.009+.004i];
    if isNative
        F = w.apvFProjection;
    else
        F = s.apvProjectionNormalization*(s.apvF'.*(grid.weights.'/w.Lz));
    end
    a = qgProjection(s,F,p)*[q;ends(w.activeEndpoint)];
    return
end
u = .01*(1+.2i*x+.3*cos(5*x));
v = .02*(.5+x.^2+.1i*x);
vSpeed = .002*(.1+x+.4i*sin(3*x));
eta = .5+.2*x+.1i*cos(7*x);
if p==0
    if isNative
        I = w.inertialFProjection;
        M = w.mdaGProjection;
    else
        I = s.inertialF'.*(grid.weights.'/w.Lz);
        accelerations = [s.gd;s.g0]; accelerations(~isfinite(accelerations))=0;
        measure = grid.weights.*grid.N2/s.g;
        measure([1,end]) = measure([1,end])+accelerations/s.g;
        M = s.mdaProjectionNormalization*(s.mdaG'.*measure.');
    end
    io = .5*I*(real(u)-1i*real(v));
    a = [real(io);imag(io);M*real(eta)];
    return
end
curl = 1i*s.kNonzero(column)*v-1i*s.lNonzero(column)*u;
if isNative
    F = w.apvFProjection; G = w.apvGProjection;
    F0 = w.zeroAPVFProjection(:,:,p); G0 = w.zeroAPVGProjection(:,:,p);
    S0 = w.zeroAPVSourceSolve(:,:,p);
    modes = 1:w.waveModeCountByKh(p);
    waves = zeros(0,1);
    if ~isempty(modes)
        waveState = struct(klNonzero=1,kNonzero=w.kNonzero(column),lNonzero=w.lNonzero(column),khUnique=w.khUnique(p), ...
            Lz=w.Lz,f=w.f,g=w.g,t=w.t0,t0=w.t0,waveFrequency=w.waveFrequency(modes,p));
        sources = struct(u=u,v=v,w=vSpeed,eta=eta);
        [plus,minus] = WVInternal.projectFreeSurfaceWaves(waveState,1,1,sources, ...
            w.waveF(:,modes,p),w.waveG(:,modes,p),grid.weights,grid.N2);
        waves = [plus;minus];
    end
else
    F = s.apvProjectionNormalization*(s.apvF'.*(grid.weights.'/w.Lz));
    G = WVInternal.freeSurfaceAPVDisplacementProjection(s.apvF,s.apvG,grid.weights,grid.N2,s.g,s.apvProjectionNormalization);
    [F0,G0] = WVInternal.freeSurfaceBoundarySourceProjections(s.zeroAPVF,s.zeroAPVG,grid.weights,grid.N2,s.Lz,s.g,s.g0,s.gd);
    S0 = s.zeroAPVSourceSolve;
    W = waveProjection(s,A,grid,false);
    waves = W*[u;v;vSpeed;eta;0];
end
a = [F*curl-(s.f/s.Lz)*G*eta;S0*(F0*curl-(s.f/s.Lz)*G0*eta);waves];
end

function mode = omittedAPVMode(w,vertical)
mode = struct();
if isempty(w.khUnique) || ~isfield(vertical,"apvReference") || isempty(vertical.apvReference), return; end
basis = vertical.apvReference;
row = find(~ismember(basis.modeNumber(:),w.apvModeNumber),1);
if isempty(row), return; end
F = basis.F(w.z); G = basis.G(w.z);
mode = struct(F=F(:,row),G=G(:,row),h=basis.h(row),label="Ag_q:"+string(basis.modeNumber(row)));
end

function result = assessOmittedAPV(w,mode,column,p,isBoussinesq,B,probe,D,scale)
result = struct(status="unassessed",label="",physicalProjectionLeakage=NaN,sampledInversionLeakage=NaN);
if p==0 || isempty(fieldnames(mode)), return; end
F = mode.F; G = mode.G;
kh = w.khUnique(p); mu = kh^2+(w.f^2/w.g)/mode.h;
if isBoussinesq
    A = -[-1i*w.lNonzero(column)*F;1i*w.kNonzero(column)*F;zeros(size(F));(w.f/w.g)*G;(w.f/w.g)*F(end)]/mu;
else
    ends = [G(end)-F(end);G(1)];
    A = [F;-(w.f/w.g)*ends(w.activeEndpoint)/mu];
end
denom = norm(D.*A);
if ~isfinite(denom) || denom==0, return; end
result.status = "measured";
result.label = mode.label;
result.physicalProjectionLeakage = norm((B*A)./scale)/denom;
if probe.success, result.sampledInversionLeakage=norm((probe.forwardMatrix*A)./scale)/denom; end
end
