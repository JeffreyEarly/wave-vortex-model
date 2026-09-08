function summary = runPilot(outputDirectory)
% Measure bounded scalar-channel pilot cost and independent reference quality.
arguments (Input)
    outputDirectory (1,1) string
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
constructionTimer = tic;
D=1000; f=1e-4; g=9.81; nWave=8; nAPV=4; nMDA=3; nInertial=6; Nz=17;
N2 = @(z) 1e-4*ones(size(z));
apvEVP = IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=g,g0=-.1,gd=.1,surfaceBoundary="freeSurface");
gridSolver = IMSolverSpectral(nEVP=Nz,coordinateKind="wkb").configuredForEVP(apvEVP);
[z,w] = gridSolver.nativeQuadratureRule([-D 0]); w=w*(D/sum(w));
referenceSolver = IMSolverSpectral(nEVP=257).configuredForEVP(apvEVP);
[z1,w1] = referenceSolver.nativeQuadratureRule([-D 0]);
referenceSolver = IMSolverSpectral(nEVP=513).configuredForEVP(apvEVP);
[z2,w2] = referenceSolver.nativeQuadratureRule([-D 0]);
inventory = enumerateStudyInteractions([1e4 1e4],[8 8]);
writetable(inventory.interactions,fullfile(outputDirectory,'interactions.csv'));
solver = IMSolverSpectral(nEVP=128,coordinateKind="wkb");
checkSolver = IMSolverSpectral(nEVP=192,coordinateKind="wkb");
allZ = [z;z1;z2;-D;0];
sets = struct(S=1:Nz,R=Nz+(1:length(z1)),Q=Nz+length(z1)+(1:length(z2)),E=length(allZ)-1:length(allZ));
apv = buildFamily(apvEVP,nAPV,["F","G"]);
mdaEVP = IMInternalModes.meanDensityAnomalyModes(N2=N2,zDomain=[-D 0],g=g,g0=-.1,gd=.1);
mda = buildFamily(mdaEVP,nMDA,"G");
wave = cell(length(inventory.magnitudes),1);
for page = 1:length(wave)
    kh=inventory.magnitudes(page);
    evp = IMInternalModes.waveModesAtWavenumber(N2=N2,zDomain=[-D 0],k=kh,f0=f,g=g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0));
    if kh==0, wave{page}=buildFamily(evp,nInertial,"F"); else, wave{page}=buildFamily(evp,nWave,"G"); end
end
positivePages = find(inventory.magnitudes>0);
zeroProblem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2,zDomain=[-D 0],f0=f,g=g,k=inventory.magnitudes(positivePages),endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
zeroModes = solver.solveGeostrophicZeroAPVModes(zeroProblem);
zeroCheck = checkSolver.solveGeostrophicZeroAPVModes(zeroProblem);
zeroF=zeroModes.F(allZ); zeroG=zeroModes.G(allZ);
zeroFCheck=zeroCheck.F(z2); zeroGCheck=zeroCheck.G(z2);
boundary = cell(length(wave),1);
for j = 1:length(positivePages)
    page=positivePages(j); kh=inventory.magnitudes(page);
    values = struct(F=zeroF(:,:,j),G=zeroG(:,:,j),dF=-N2(allZ).*zeroG(:,:,j)/g,dG=-g*kh^2*zeroF(:,:,j)/f^2);
    family=splitValues(values,sets); family.labels=[1 2];
    family.eigenError=max(relativeColumns(family.Q.F,zeroFCheck(:,:,j),w2),relativeColumns(family.Q.G,zeroGCheck(:,:,j),w2));
    boundary{page}=family;
end
[~,control] = apv.basis.discreteTransform(z=z,weights=w,nModes=nAPV,variables=["F","G"],gramTolerance=1e30,quadraticAliasingTolerance=1e30);
constructionSeconds=toc(constructionTimer);
fprintf('Pilot construction %.3f s; %d vector interactions, %d magnitude triples.\n',constructionSeconds,height(inventory.interactions),size(inventory.pageTriples,1));
% This pilot qualifies the scalar adapter only. Full energy-source projection
% channels must be added before policy scoring and physical recommendations.
channels = ["F" "G" "G";"G" "dG" "G";"G" "dF" "F";"F" "F" "F";"G" "G" "F"];
familyPairs = ["wave" "wave";"wave" "apv";"apv" "wave";"wave" "boundary";"boundary" "wave";"apv" "boundary"];
records=cell(0,1); raw=cell(0,1); productCount=0; assessmentTimer=tic; r=0;
for t = 1:size(inventory.pageTriples,1)
    pages=inventory.pageTriples(t,:);
    for pair=1:size(familyPairs,1)
        aName=familyPairs(pair,1); bName=familyPairs(pair,2);
        a=getFamily(aName,pages(1)); b=getFamily(bName,pages(2));
        for c=1:size(channels,1)
            targetVariable=channels(c,3);
            if inventory.magnitudes(pages(3))==0
                if targetVariable=="F", target=wave{pages(3)}; targetName="inertial"; else, target=mda; targetName="mda"; end
            else
                if targetVariable=="F", target=apv; targetName="apv"; else, target=wave{pages(3)}; targetName="wave"; end
            end
            [i,j]=ndgrid(1:length(a.labels),1:length(b.labels)); i=i(:).'; j=j(:).';
            av=channels(c,1); bv=channels(c,2);
            context1=prepareContext(target,targetVariable,z1,w1);
            context2=prepareContext(target,targetVariable,z2,w2);
            S=a.S.(av)(:,i).*b.S.(bv)(:,j); R=a.R.(av)(:,i).*b.R.(bv)(:,j); Q=a.Q.(av)(:,i).*b.Q.(bv)(:,j); E=a.E.(av)(:,i).*b.E.(bv)(:,j);
            counts=1:length(target.labels);
            low=measureProductProjection(context1,S,R,E,counts);
            high=measureProductProjection(context2,S,Q,E,counts);
            stability=referenceStability(context2,low,high,counts);
            r=r+1; productCount=productCount+length(i);
            [worst,index]=max(high.error(end,:));
            records{r}=struct(triple=t,inputA=aName,inputB=bName,output=targetName,channel=av+"*"+bv+"->"+targetVariable,error=worst,modeA=a.labels(i(index)),modeB=b.labels(j(index)),referenceStability=stability,eigenConvergence=max([a.eigenError,b.eigenError,target.eigenError]),gramError=target.gramError,productCount=length(i));
            raw{r}=struct(i=i,j=j,error=high.error,referenceStability=stability);
        end
    end
    if mod(t,10)==0, fprintf('Pilot triples %d/%d, products %d, %.2f s.\n',t,size(inventory.pageTriples,1),productCount,toc(assessmentTimer)); end
end
assessmentSeconds=toc(assessmentTimer);
rows=struct2table(vertcat(records{:})); writetable(rows,fullfile(outputDirectory,'pilot-channels.csv'));
summary=struct(status="pilot-only",constructionSeconds=constructionSeconds,assessmentSeconds=assessmentSeconds,vectorInteractions=height(inventory.interactions),magnitudeTriples=size(inventory.pageTriples,1),productEvaluations=productCount,maximumReferenceStability=max(rows.referenceStability),maximumEigenConvergence=max(rows.eigenConvergence),referenceAllowance=1e-4,eigenAllowance=1e-6,apvControl=control.prefixDiagnostics,scope="scalar adapter; full physical source inventory and policy comparison pending");
summary.referencesStable=summary.maximumReferenceStability<=summary.referenceAllowance && summary.maximumEigenConvergence<=summary.eigenAllowance;
fid=fopen(fullfile(outputDirectory,'pilot-summary.json'),'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true)); clear cleanup
save(fullfile(outputDirectory,'pilot-products.mat'),'raw','inventory','summary','-v7');
disp(summary)

    function family=buildFamily(evp,n,variables)
        basis=solver.solveEVP(evp,nModes=n); check=checkSolver.solveEVP(evp,nModes=n);
        F=basis.F(allZ); G=basis.G(allZ); h=basis.h(:).';
        dG=F./h;
        if isfield(evp.parameters,'k'), k=evp.parameters.k; dF=(k^2*h-(N2(allZ)-f^2)/g).*G; else, dF=-N2(allZ).*G/g; end
        family=splitValues(struct(F=F,G=G,dF=dF,dG=dG),sets);
        family.labels=basis.modeNumber;
        family.eigenError=max([max(abs(basis.h(:)-check.h(:))./abs(check.h(:))),relativeColumns(family.Q.F,check.F(z2),w2),relativeColumns(family.Q.G,check.G(z2),w2)]);
        family.basis=basis;
        if isfield(evp.parameters,'k') && evp.parameters.k==0
            family.transform=[];
            family.gramError=norm((family.S.F'.*w.')./basis.h(:)*family.S.F-eye(n),2);
        else
            [family.transform,assessment]=basis.discreteTransform(z=z,weights=w,nModes=n,variables=variables,gramTolerance=1e30);
            family.gramError=assessment.prefixDiagnostics.gramError(end);
        end
    end

    function context=prepareContext(target,variable,zReference,weightsReference)
        if ~isempty(target.transform)
            context=prepareProductProjection(target.basis,target.transform,variable,zReference,weightsReference);
            return
        end
        % Match fromStratification's fixed inertial F dual, including its
        % sampled Gram error. Do not substitute a sampled least-squares fit.
        h=target.basis.h(:); n=length(h);
        context=struct(sampleValues=target.S.F,sampleMetric=diag(w),sampleGram=diag(h),targetGram=diag(h),majorantGram=diag(h),active=true(n,1),referenceValues=target.basis.F(zReference),volumeWeights=weightsReference,endpointValues=target.E.F,endpointMetric=[0;0],variable="F");
    end

    function family=getFamily(name,page)
        switch name
            case "wave", family=wave{page};
            case "apv", family=apv;
            case "boundary", family=boundary{page};
        end
    end
end

function family=splitValues(values,sets)
family=struct();
for setName=string(fieldnames(sets)).'
    for variable=string(fieldnames(values)).'
        family.(setName).(variable)=values.(variable)(sets.(setName),:);
    end
end
end

function error=relativeColumns(A,B,w)
orientation=sign(sum(w.*A.*B,1)); orientation(orientation==0)=1;
denominator=sum(w.*abs(B).^2,1); numerator=sum(w.*abs(A-B.*orientation).^2,1);
active=denominator>0; error=max([0 sqrt(numerator(active)./denominator(active))]);
end

function stability=referenceStability(context,low,high,counts)
stability=0;
usable=~high.isZero;
for j=1:length(counts)
    active=find(context.active(1:counts(j)));
    delta=low.referenceCoefficients{j}-high.referenceCoefficients{j};
    numerator=real(sum(conj(delta).*(context.majorantGram(active,active)*delta),1));
    values=sqrt(max(0,numerator(usable))./high.productNormSquared(usable));
    stability=max([stability values]);
end
normDifference=abs(sqrt(low.productNormSquared(usable)./high.productNormSquared(usable))-1);
stability=max([stability normDifference]);
end
