function data = thermalAPVDecompositionData(w,apv,count)
% Prepare independent physical projection and synthesis from authoritative arrays.
% The F-channel pairing is the physical L2 integral. Its weighted QR solves
% the sampled Gram system; signed G-channel and forcing duals are unrelated.
% Only small coefficient maps are built per radius. Thermal polynomial fields
% and APV F/G interpolation are shared; no complete thermal-to-field matrices
% are duplicated for every component and radius.
% - Topic: Developer utilities
for name=["Lx","Ly","Lz","g","f","rho0"]
    if ~isequal(w.(name),apv.(name))
        error('WV:APVDiagnosticGeometry','Thermal and APV diagnostics require identical %s.',name);
    end
end
if ~isequal(w.activeEndpoint,[1;2]) || ~isequal(apv.activeEndpoint,[1;2])
    error('WV:APVDiagnosticEndpoints','Both surface and bottom endpoints must be active.');
end
for name=["Nx","Ny","shouldAntialias","shouldExcludeNyquist","shouldExcludeConjugates","conjugateDimension"]
    if ~isequal(w.(name),apv.(name))
        error('WV:APVDiagnosticFourierSupport','Keep identical horizontal support and %s.',name);
    end
end
sourceKeys=[w.kMode_wv(w.klNonzero),w.lMode_wv(w.klNonzero)];
targetKeys=[apv.kMode_wv(apv.klNonzero),apv.lMode_wv(apv.klNonzero)];
[found,targetColumn]=ismember(sourceKeys,targetKeys,'rows');
if ~all(found) || numel(unique(targetColumn))~=size(targetKeys,1)
    error('WV:APVDiagnosticFourierSupport','Diagnostic Fourier integer pairs must match the complete source support.');
end
if count<max([w.Nz,apv.Nz,w.thermalModeCount,apv.apvModeCount])
    error('WV:APVDiagnosticQuadrature','Use at least the larger stored grid, thermal count and APV count.');
end
[x,weights]=legpts(count); z=(x-1)*w.Lz/2; weights=weights(:)*w.Lz/2;
N2=w.N2Function(z); diagnosticN2=apv.N2Function(z);
if any(~isfinite(diagnosticN2) | diagnosticN2<=0) || max(abs(diagnosticN2./N2-1))>1e-9
    error('WV:APVDiagnosticStratification','Stratification must agree on the physical diagnostic quadrature.');
end
P=WVInternal.qgVerticalInterpolation(apv.z,z);
F=P*apv.apvF; G=P*apv.apvG;
[Q,R]=qr(sqrt(weights).*F,0); condition=rcond(R);
if ~isfinite(condition) || condition<1e-12
    error('WV:APVDiagnosticCondition','The independently sampled diagnostic APV basis is rank deficient or poorly conditioned.');
end
gramError=norm((F'*(weights.*F))/w.Lz-eye(apv.apvModeCount),2);
if gramError>max(apv.gramTolerance,100*eps)
    error('WV:APVDiagnosticCondition','The refined APV Gram error %.3g exceeds the stored allowance %.3g. Refine diagnostic modes or sampling.',gramError,apv.gramTolerance);
end
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
endpoint=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
pages=cell(numel(w.khUnique),1);
for p=1:numel(pages)
    columns=find(w.klNonzeroKhUniqueIndex==p); kh=w.khUnique(p);
    targetPage=apv.klNonzeroKhUniqueIndex(targetColumn(columns(1)));
    mu=apv.apvMu(:,targetPage).';
    if any(~isfinite(mu)) || any(abs(mu)./(kh^2+abs(mu-kh^2))<=apv.muTolerance)
        error('WV:APVDiagnosticCondition','The diagnostic inversion is singular or insufficiently separated.');
    end
    C=w.thermalToPolynomial(:,:,p);
    Aq=R\(Q'*(sqrt(weights).*((r.qgpv-kh^2*r.psi)*C)));
    E=apv.apvEndpointResponse(:,:,targetPage);
    A0=-(w.g/w.f)*kh^2*(endpoint.eta_i*C-E*Aq);
    pages{p}=struct(columns=columns,targetColumns=targetColumn(columns),kh=kh,Aq=Aq,A0=A0, ...
        mu=mu,apvEndpoint=E, ...
        zeroPsi=-(P*apv.zeroAPVF(:,:,targetPage))/kh^2,zeroEta=-(w.f/w.g)*(P*apv.zeroAPVG(:,:,targetPage))/kh^2, ...
        zeroSSH=-(w.f/w.g)*apv.zeroAPVF(end,:,targetPage)/kh^2,zeroEndpoint=-(w.f/w.g)*eye(2)/kh^2);
end
M=WVInternal.thermalVerticalInterpolation(w.z,z,w.Lz,w.inverseScale);
meanFields=struct(psi=zeros(count,w.mdaModeCount),eta=M*w.mdaG,eta_i=M*w.mdaG, ...
    qgpv=-w.f*(M*w.mdaGZ),buoyancy=-N2.*(M*w.mdaG),ssh=zeros(1,w.mdaModeCount),endpointAnomalies=w.mdaG([end 1],:));
metadata=struct(apvModeNumber=apv.apvModeNumber,activeEndpoint=apv.activeEndpoint,g0=apv.g0,gd=apv.gd, ...
    apvModeCount=apv.apvModeCount,diagnosticNz=apv.Nz,thermalModeCount=w.thermalModeCount,sourceNz=w.Nz, ...
    quadratureCount=count,quadratureKind="physical-depth Gauss-Legendre",projection="F-channel physical Galerkin with weighted QR", ...
    normalization="generalized-energy APV; boundary-normalized zero-APV",gramError=gramError,reciprocalQRCondition=condition, ...
    gramTolerance=apv.gramTolerance,modeConvergenceTolerance=apv.modeConvergenceTolerance,boundaryResolutionTolerance=apv.boundaryResolutionTolerance, ...
    muTolerance=apv.muTolerance,shouldAntialias=apv.shouldAntialias,quadraticDealiasing=apv.quadraticDealiasing, ...
    retainedFraction=apv.retainedFraction,energyFraction=apv.energyFraction,bandwidthFraction=apv.bandwidthFraction, ...
    kNonzero=apv.kNonzero,lNonzero=apv.lNonzero,accountingKNonzero=w.k(w.klNonzero),accountingLNonzero=w.l(w.klNonzero), ...
    meanConvention="original thermal MDA; zero mean SSH and horizontal velocity", ...
    inventoryUnits="energy m3/s2; enstrophy m/s2; endpoint half second moments m2",modalPowerUnits="s-2", ...
    requestedAPVModeCount=NaN,requestedCountProvenance="not retained by the existing transform; use construction provenance", ...
    isConstructionAssessmentAvailable=~isempty(fieldnames(apv.constructionAssessment)),modeSelectionMethod=apv.modeSelectionMethod);
data=struct(apv=apv,quadratureCount=count,z=z,weights=weights,N2=N2,depth=w.Lz,g=w.g, ...
    f=w.f,sourcePhysics=[w.g,w.f,w.rho0,w.latitude,w.rotationRate],targetPhysics=[apv.g,apv.f,apv.rho0,apv.latitude,apv.rotationRate], ...
    polynomial=r,endpoint=endpoint,thermalToPolynomial=w.thermalToPolynomial,apvF=F,apvG=G,apvFSurface=apv.apvF(end,:),pages={pages},meanFields=meanFields, ...
    metadata=metadata,k=w.k(w.klNonzero),l=w.l(w.klNonzero),klNonzero=w.klNonzero,Nkl=w.Nkl,meanIndex=find(hypot(w.k,w.l)==0,1), ...
    targetColumn=targetColumn,kRadial=w.kRadial,radialBinning=w.transformToRadialWavenumber(speye(w.Nkl)), ...
    domain=[w.Lx w.Ly],grid=[w.Nx w.Ny],shouldAntialias=w.shouldAntialias,conjugateDimension=w.conjugateDimension);
end
