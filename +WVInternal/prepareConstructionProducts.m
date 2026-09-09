function data = prepareConstructionProducts(state,bases,reference,vertical,counts,inertialCount,assessment,options)
% Adapt actual construction bases to the shared physical-product measurement.
% No wave/APV/MDA eigensolve is performed here.
timer=tic; D=state.Lxyz(3); N2=state.N2Function; f=2*state.rotationRate*sind(state.latitude);
inventory=WVInternal.constructionInteractionInventory(state);
% Reserve the bounded inventory before allocating reference fields.
nBoundary=state.activeEndpointCount; nAPV=numel(WVInternal.constructionModeLevels(numel(state.apvMode)));
waveStress=[0;arrayfun(@(n)2*numel(WVInternal.constructionModeLevels(n)),counts)];
reserved=0;
for index=1:height(inventory.interactions)
    row=inventory.interactions(index,:); a=waveStress(row.page1); b=waveStress(row.page2);
    pairs=a*b+(a+b)*(nAPV+nBoundary)+2*nAPV*nBoundary+nBoundary^2;
    channels=13; if row.page3==1, channels=10; elseif counts(row.page3-1)==0, channels=0; end
    reserved=reserved+pairs*channels;
end
if reserved>500000
    error('WV:QuadraticConstructionBudget','The requested construction reserves %d sampled products, exceeding the 500000-product budget. Reduce the horizontal band or explicit candidate counts. No unmeasured map has been accepted.',reserved)
end
referenceFieldBytes=48*numel(state.z)*8*(sum(counts)+inertialCount+numel(state.apvMode)+numel(state.mdaMode)+nBoundary*numel(counts));
if referenceFieldBytes>512*1024^2
    error('WV:QuadraticConstructionBudget','Reference field storage would exceed 512 MiB. Reduce the horizontal band or explicit candidate counts.')
end
profile=chebfun(N2,[-D 0]); logarithmicDerivative=diff(log(profile)); dLogN2=@(z)logarithmicDerivative(z);
nz=numel(state.z); nr=max(65,3*nz); nq=max(97,4*nz);
rule=IMSolverSpectral(nEVP=nr,coordinateKind="wkb").configuredForEVP(vertical.apvProblem);
[zR,wR]=rule.nativeQuadratureRule([-D 0]);
rule=IMSolverSpectral(nEVP=nq,coordinateKind="wkb").configuredForEVP(vertical.apvProblem);
[zQ,wQ]=rule.nativeQuadratureRule([-D 0]);
z=state.z; w=state.verticalQuadratureWeights; allZ=[z;zR;zQ;-D;0];
sets=struct(S=1:nz,R=nz+(1:nr),Q=nz+nr+(1:nq),E=numel(allZ)-1:numel(allZ));
config=struct(selectInertial=true,constructionPolicy=true,boundaryCount=state.activeEndpointCount,Lxy=state.Lxyz(1:2),Nxy=state.Nxyz(1:2),Lz=D,Nz=nz,f=f,g=state.g,waveCount=max([counts;1]),apvCount=numel(state.apvMode),mdaCount=numel(state.mdaMode),inertialCount=inertialCount,gramTolerance=options.gramTolerance,eigenAllowance=options.modeConvergenceTolerance,referenceAllowance=min(1e-4,options.quadraticAliasingTolerance/100),referenceAbsoluteAllowance=min(1e-10,options.quadraticAliasingTolerance/100));
apv=family(vertical.apvBasis,vertical.apvReference,config.apvCount);
mda=family(vertical.mdaBasis,vertical.mdaReference,config.mdaCount);
apv.transform=vertical.apvTransform; apv.assessment=vertical.apvAssessment;
mda.transform=vertical.mdaTransform; mda.assessment=vertical.mdaAssessment;
wave=cell(numel(inventory.magnitudes),1); boundary=wave;
wave{1}=family(bases.bases{bases.basisIndex(1)},reference.bases{reference.basisIndex(1)},inertialCount);
active=find(state.waveModeCountByKh>0);
waveGram=zeros(config.waveCount,numel(wave));
for p=1:numel(counts)
    collectionPage=find(active==p)+1;
    if isempty(collectionPage), collectionPage=1; end
    wave{p+1}=family(bases.bases{bases.basisIndex(collectionPage)},reference.bases{reference.basisIndex(collectionPage)},counts(p));
    errors=assessment.prefixGramError{p};
    if counts(p)>0, waveGram(1:counts(p),p+1)=errors(1:counts(p)); end
end
zero=vertical.zeroModes;
if ~isempty(zero)
    zeroCheck=vertical.zeroReference;
    Fs=zero.F(allZ); Gs=zero.G(allZ); Fr=zeroCheck.F([zQ;-D;0]); Gr=zeroCheck.G([zQ;-D;0]);
end
for p=1:numel(counts)
    if isempty(zero)
        B=wave{p+1}; B.labels=[]; B.positions=[]; B.signs=[]; B.tail=[];
        for boundarySet=["S","R","Q","E","H","J"]
            for boundaryField=["F","G","dF","dG"], B.(boundarySet).(boundaryField)=zeros(size(B.(boundarySet).(boundaryField),1),0); end
        end
    else
        kh=state.khUnique(p);
        boundaryValues=struct(F=Fs(:,:,p),G=Gs(:,:,p),dF=-N2(allZ).*Gs(:,:,p)/state.g,dG=-(state.g*kh^2/f^2)*Fs(:,:,p));
        B=split(boundaryValues); B.labels=state.activeEndpoint.'; B.positions=1:numel(B.labels); B.signs=zeros(size(B.labels)); B.tail=zeros(size(B.labels));
        boundaryValues=struct(F=Fr(:,:,p),G=Gr(:,:,p),dF=-N2([zQ;-D;0]).*Gr(:,:,p)/state.g,dG=-(state.g*kh^2/f^2)*Fr(:,:,p));
        for boundaryField=["F","G","dF","dG"]
            B.H.(boundaryField)=boundaryValues.(boundaryField)(1:nq,:); B.J.(boundaryField)=boundaryValues.(boundaryField)(nq+1:end,:);
        end
    end
    boundary{p+1}=B;
end
inertialF=state.inertialF(:,1:inertialCount); inertialForward=state.inertialFForward(1:inertialCount,:);
inertialGram=norm(inertialForward*inertialF-eye(inertialCount),2);
% All prepared candidate columns have already passed independent H1 agreement.
requiredConvergence=max([assessment.pages.modeConvergenceError;assessment.inertial.modeConvergenceError]);
data=struct(config=config,profile=struct(N2=N2,dLogN2=dLogN2),z=z,w=w,zR=zR,wR=wR,zQ=zQ,wQ=wQ,allZ=allZ,sets=sets,inventory=inventory,apv=apv,mda=mda,wave={wave},boundary={boundary},waveGram=waveGram,inertialGram=inertialGram,convergence=requiredConvergence,requiredConvergence=requiredConvergence,boundaryInterpolationError=0,pageDifficulty=zeros(numel(wave),1),constructionSeconds=toc(timer));
    function B=family(basis,check,n)
        familyValues=WVInternal.evaluateResolvedModes(basis,allZ,N2,dLogN2);
        for familyField=["F","G","dF","dG"], familyValues.(familyField)=familyValues.(familyField)(:,1:n); end
        B=split(familyValues); B.basis=basis; B.checkh=check.h(1:n); B.checkh=B.checkh(:);
        familyValues=WVInternal.evaluateResolvedModes(check,[zQ;-D;0],N2,dLogN2);
        orientation=sign(sum(wQ.*B.Q.F.*familyValues.F(1:nq,1:n),1)); orientation(orientation==0)=1;
        for familyField=["F","G","dF","dG"]
            B.H.(familyField)=familyValues.(familyField)(1:nq,1:n).*orientation;
            B.J.(familyField)=familyValues.(familyField)(nq+1:end,1:n).*orientation;
        end
        B.labels=reshape(basis.modeNumber(1:n),1,[]); B.positions=1:n; B.signs=zeros(1,n); B.tail=zeros(1,n);
        % The immutable comparison contains the candidate ceiling; map assessment selects labels.
        if basis.evp.modeFamily=="meanDensityAnomaly", B.modeConvergence=vertical.mdaConvergence;
        elseif basis.evp.name=="geostrophicAPVModes", B.modeConvergence=vertical.apvConvergence;
        else
            familyKappa=basis.evp.parameters.k;
            if familyKappa==0, B.modeConvergence=assessment.inertial.convergence;
            else, [~,page]=min(abs(state.khUnique-familyKappa)); B.modeConvergence=assessment.modeConvergence{page}; end
        end
    end
    function B=split(values)
        B=struct();
        for splitSet=string(fieldnames(sets)).'
            for splitField=["F","G","dF","dG"], B.(splitSet).(splitField)=values.(splitField)(sets.(splitSet),:); end
        end
    end
end
