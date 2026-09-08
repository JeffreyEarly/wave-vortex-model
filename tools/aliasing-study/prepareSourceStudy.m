function data = prepareSourceStudy(config)
% Prepare fixed scientific modes and independent reference evidence for a case.
arguments
    config (1,1) struct
end
timer=tic;
D=config.Lz; f=config.f; g=config.g;
profile=studyProfile(config.profile,D); N2=profile.N2;
if min(chebfun(N2,[-D 0]))<=f^2, error('WVStudy:UnsupportedProfile','Require N2>f^2.'); end
g0=-integral(N2,-D,0); gd=abs(g0);
apvEVP=IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=g,g0=g0,gd=gd,surfaceBoundary="freeSurface");
grid=IMSolverSpectral(nEVP=config.Nz,coordinateKind="wkb").configuredForEVP(apvEVP);
[z,w]=grid.nativeQuadratureRule([-D 0]); w=w*(D/sum(w));
[zR,wR]=IMSolverSpectral(nEVP=config.referenceOrders(1)).configuredForEVP(apvEVP).nativeQuadratureRule([-D 0]);
[zQ,wQ]=IMSolverSpectral(nEVP=config.referenceOrders(2)).configuredForEVP(apvEVP).nativeQuadratureRule([-D 0]);
allZ=[z;zR;zQ;-D;0];
sets=struct(S=1:length(z),R=length(z)+(1:length(zR)),Q=length(z)+length(zR)+(1:length(zQ)),E=length(allZ)-1:length(allZ));
solver=IMSolverSpectral(nEVP=config.evpOrders(1),coordinateKind="wkb");
checkSolver=IMSolverSpectral(nEVP=config.evpOrders(2),coordinateKind="wkb");
inventory=enumerateStudyInteractions(config.Lxy,config.Nxy);
apv=family(apvEVP,config.apvCount);
mda=family(IMInternalModes.meanDensityAnomalyModes(N2=N2,zDomain=[-D 0],g=g,g0=g0,gd=gd),config.mdaCount);
[mda.transform,mda.assessment]=mda.basis.discreteTransform(z=z,weights=w,nModes=config.mdaCount,variables="G",gramTolerance=1e30);
[apv.transform,apv.assessment]=apv.basis.discreteTransform(z=z,weights=w,nModes=config.apvCount,variables=["F","G"],gramTolerance=1e30,quadraticAliasingTolerance=1e30);
wave=cell(length(inventory.magnitudes),1); boundary=wave;
waveGram=zeros(config.waveCount,length(wave));
for p=1:length(wave)
    kh=inventory.magnitudes(p);
    evp=IMInternalModes.waveModesAtWavenumber(N2=N2,zDomain=[-D 0],k=kh,f0=f,g=g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0));
    if kh==0, count=config.inertialCount; else, count=config.waveCount; end
    wave{p}=family(evp,count);
    if kh>0
        G=wave{p}.S.G;
        gram=G'*(w.*((N2(z)-f^2)/g).*G)+G(end,:)'*G(end,:);
        for n=1:count, waveGram(n,p)=norm(gram(1:n,1:n)-eye(n),2); end
    end
end
positive=find(inventory.magnitudes>0);
problem=IMGeostrophicZeroAPVModes.atWavenumber(N2=N2,zDomain=[-D 0],f0=f,g=g,k=inventory.magnitudes(positive),endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
zero=solver.solveGeostrophicZeroAPVModes(problem); zeroCheck=checkSolver.solveGeostrophicZeroAPVModes(problem);
for j=1:length(positive)
    % G's native coefficients are private. Adaptive physical-coordinate
    % interpolation of this same solved G supplies its derivative; compare
    % both independent EVP orders and interpolation residuals explicitly.
    Gfun=chebfun(@(zz)zeroPage(zero,zz,j,"G"),[-D 0]); dGfun=diff(Gfun);
    Gcheck=chebfun(@(zz)zeroPage(zeroCheck,zz,j,"G"),[-D 0]); dGcheck=diff(Gcheck);
    F=zeroPage(zero,allZ,j,"F"); G=zeroPage(zero,allZ,j,"G");
    values=struct(F=F,G=G,dF=-N2(allZ).*G/g,dG=dGfun(allZ));
    B=splitValues(values,sets); B.labels=[1 2]; B.positions=[1 2]; B.signs=[0 0];
    checkValues=struct(F=zeroPage(zeroCheck,zQ,j,"F"),G=zeroPage(zeroCheck,zQ,j,"G"),dF=-N2(zQ).*zeroPage(zeroCheck,zQ,j,"G")/g,dG=dGcheck(zQ));
    B.H=checkValues;
    B.J=struct(F=zeroPage(zeroCheck,[-D;0],j,"F"),G=zeroPage(zeroCheck,[-D;0],j,"G"),dF=-N2([-D;0]).*zeroPage(zeroCheck,[-D;0],j,"G")/g,dG=dGcheck([-D;0]));
    B.convergence=[0 fieldConvergence(B.Q,checkValues,wQ)];
    B.resolutionConvergence=[0 sobolevConvergence(B.Q,checkValues,wQ,D)];
    B.interpolationError=relativeError(Gfun(zQ),B.Q.G,wQ);
    B.tail=modeTails(B.S);
    boundary{positive(j)}=B;
end
meanPage=find(inventory.magnitudes==0);
inertial=wave{meanPage}; h=inertial.basis.h(:);
inertialGram=norm((inertial.S.F'.*w.')./h*inertial.S.F-eye(length(h)),2);
convergence=[apv.convergence;mda.convergence];
requiredConvergence=[apv.resolutionConvergence;mda.resolutionConvergence]; interpolationError=0;
for p=1:length(wave)
    convergence=[convergence;wave{p}.convergence]; %#ok<AGROW>
    required=wave{p}.resolutionConvergence;
    requiredConvergence=[requiredConvergence;required]; %#ok<AGROW>
    if ~isempty(boundary{p})
        convergence=[convergence;boundary{p}.convergence]; %#ok<AGROW>
        requiredConvergence=[requiredConvergence;boundary{p}.resolutionConvergence]; %#ok<AGROW>
        interpolationError=max(interpolationError,boundary{p}.interpolationError);
    end
end
pageDifficulty=zeros(length(wave),1);
for p=1:length(wave)
    pageDifficulty(p)=max([wave{p}.tail,apv.tail]);
    if ~isempty(boundary{p}), pageDifficulty(p)=max([pageDifficulty(p),boundary{p}.tail]); end
end
data=struct(pageDifficulty=pageDifficulty,config=config,profile=profile,z=z,w=w,zR=zR,wR=wR,zQ=zQ,wQ=wQ,allZ=allZ,sets=sets,inventory=inventory,apv=apv,mda=mda,wave={wave},boundary={boundary},waveGram=waveGram,inertialGram=inertialGram,convergence=convergence,requiredConvergence=requiredConvergence,boundaryInterpolationError=interpolationError,constructionSeconds=toc(timer));

    function B=family(evp,n)
        basis=solver.solveEVP(evp,nModes=n); check=checkSolver.solveEVP(evp,nModes=n);
        assert(isequal(basis.modeNumber,check.modeNumber),'Independent solves changed mode labels.');
        B=splitValues(evaluateStudyModes(basis,allZ,N2,profile.dLogN2),sets);
        B.basis=basis; B.checkh=check.h(:);
        B.H=evaluateStudyModes(check,zQ,N2,profile.dLogN2);
        B.J=evaluateStudyModes(check,[-D;0],N2,profile.dLogN2);
        orientation=sign(sum(wQ.*B.Q.F.*B.H.F,1)); orientation(orientation==0)=1;
        for variable=["F","G","dF","dG"]
            B.H.(variable)=B.H.(variable).*orientation;
            B.J.(variable)=B.J.(variable).*orientation;
        end
        B.labels=basis.modeNumber(:).'; B.positions=1:n; B.signs=zeros(1,n);
        finiteDepth=isfinite(basis.h(:)) & isfinite(check.h(:));
        depthError=max([0;abs(basis.h(finiteDepth).'-check.h(finiteDepth).')./abs(check.h(finiteDepth).')]);
        assert(isequal(isfinite(basis.h),isfinite(check.h)),'Independent solves disagree on finite equivalent depths.');
        B.convergence=[depthError,fieldConvergence(B.Q,evaluateStudyModes(check,zQ,N2,profile.dLogN2),wQ)];
        B.convergence=B.convergence(:).';
        B.resolutionConvergence=[depthError sobolevConvergence(B.Q,B.H,wQ,D)];
        B.tail=modeTails(B.S);
    end
end

function F=zeroPage(basis,z,page,variable)
if variable=="F", values=basis.F(z); else, values=basis.G(z); end
F=values(:,:,page);
end

function B=splitValues(values,sets)
B=struct();
for setName=string(fieldnames(sets)).'
    for variable=string(fieldnames(values)).'
        B.(setName).(variable)=values.(variable)(sets.(setName),:);
    end
end
end

function errors=fieldConvergence(A,B,w)
errors=zeros(1,4); fields=["F","G","dF","dG"];
for j=1:4, errors(j)=relativeError(A.(fields(j)),B.(fields(j)),w); end
end

function error=relativeError(A,B,w)
orientation=sign(real(sum(w.*conj(A).*B,1))); orientation(orientation==0)=1;
numerator=sum(w.*abs(A-B.*orientation).^2,1); denominator=sum(w.*abs(B).^2,1);
% A derivative can be identically zero (e.g. the constant inertial mode).
% Classify against the scale of the other columns rather than amplify
% a roundoff-only derivative into a relative error of order one.
scale=max(denominator); active=denominator>1e-24*scale;
error=max([0 sqrt(numerator(active)./denominator(active))]);
end

function tail=modeTails(fields)
tail=zeros(1,size(fields.F,2));
for variable=["F","G","dF","dG"]
    coefficients=chebcoeffs(chebfun(fields.(variable)));
    denominator=sum(abs(coefficients).^2,1); active=denominator>0;
    values=zeros(size(denominator));
    values(active)=sqrt(sum(abs(coefficients(max(1,end-3):end,active)).^2,1)./denominator(active));
    tail=max(tail,values);
end
end

function errors=sobolevConvergence(A,B,w,D)
% Joint positive H1 norms stay meaningful when a component's derivative is
% nearly zero. The separate product-level EVP check still guards products
% whose normalization amplifies a small derivative or localized overlap.
errors=zeros(1,2); variables=["F","G"];
for j=1:2
    v=variables(j); dv="d"+v;
    orientation=sign(sum(w.*A.(v).*B.(v),1)); orientation(orientation==0)=1;
    numerator=sum(w.*(abs(A.(v)-B.(v).*orientation).^2+D^2*abs(A.(dv)-B.(dv).*orientation).^2),1);
    denominator=sum(w.*(abs(B.(v)).^2+D^2*abs(B.(dv)).^2),1);
    active=denominator>0;
    if any(numerator(~active)>0), errors(j)=Inf; else, errors(j)=max([0 sqrt(numerator(active)./denominator(active))]); end
end
end
