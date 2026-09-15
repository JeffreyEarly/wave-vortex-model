function summary = calibrateQuadraticDealiasing(outputFolder,options)
% Compare bounded product samples for common-coordinate filtering policies.
arguments (Input)
    outputFolder (1,1) string
    options.wvmRoot (1,1) string
    options.internalModesRoot (1,1) string
    options.dependencyRoot (1,1) string
    options.chebfunRoot (1,1) string
    options.profiles (1,:) string = ["constant","exponential","sharp"]
    options.verticalCounts (1,:) double = [33 65 129]
    options.sourceRevision (1,1) string = "uncommitted study candidate"
    options.providerRevision (1,1) string = "uncommitted study candidate"
end
environment = setupDealiasingStudy(options.wvmRoot,options.internalModesRoot,options.dependencyRoot,options.chebfunRoot);
maxNumCompThreads(1);
if ~isfolder(outputFolder), mkdir(outputFolder); end
policies = policyCandidates();
records = struct([]);
productRecords = struct([]);
cases = calibrationCases(options.profiles,options.verticalCounts);
for studyCase = cases
        profile = studyCase.profile;
        nz = studyCase.Nz;
        N2 = stratification(profile);
        nEVP = max(104,ceil(1.6*nz));
        started = tic;
        wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([studyCase.Lxy studyCase.Lxy 1000],[16 16 nz],N2Function=N2,nEVP=nEVP,shouldAntialias=true,quadraticDealiasing="none");
        constructionSeconds = toc(started);
        pages = unique(round(linspace(1,numel(wvt.khUnique),5)));
        apvProblem = IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-1000 0],g=wvt.g,g0=wvt.g0,gd=wvt.gd,surfaceBoundary="freeSurface");
        rule = IMSolverSpectral(nEVP=nz,coordinateKind="wkb").configuredForEVP(apvProblem);
        n = nz-1;
        fineCount = max(4*n+1,2*max(wvt.nEVP,wvt.balancedNEVP)+1);
        referenceCount = 2*(fineCount-1)+1;
        xDomain = reshape(rule.xReference([1 end]),1,2);
        fineZ = rule.zOfX(chebpts(fineCount,xDomain));
        referenceZ = rule.zOfX(chebpts(referenceCount,xDomain));
        apvBasis = IMSolverSpectral(nEVP=wvt.balancedNEVP).solveEVP(apvProblem,nModes=numel(wvt.apvMode));
        apv = sampleBasis(apvBasis,wvt.z,fineZ,referenceZ);
        apv.coarseAgreement = relativeShapeError(apv.coarseF,wvt.apvF,apv.coarseG,wvt.apvG);
        assert(apv.coarseAgreement<1e-9,'Reconstructed APV modes do not match the constructor inventory.');
        waves = IMSolverSpectral(nEVP=wvt.nEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers(wvt.khUnique(pages).',N2=N2,zDomain=[-1000 0],f0=wvt.f,g=wvt.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=wvt.waveModeCountByKh(pages).');
        for pageIndex = 0:numel(pages)
            if pageIndex==0
                family = "apv"; kappa = 0; samples = apv;
            else
                family = "wave"; page = pages(pageIndex); kappa = wvt.khUnique(page);
                basis = waves.bases{waves.basisIndex(pageIndex)};
                samples = sampleBasis(basis,wvt.z,fineZ,referenceZ);
                m = wvt.waveModeCountByKh(page);
                samples.coarseAgreement = relativeShapeError(samples.coarseF,wvt.waveF(:,1:m,page),samples.coarseG,wvt.waveG(:,1:m,page));
                assert(samples.coarseAgreement<1e-9,'Reconstructed wave modes do not match the constructor inventory.');
            end
            products = sampledProducts(samples,samples,n,false);
            if family=="wave"
                mixedProducts = sampledProducts(samples,apv,n,true);
            else
                mixedProducts = struct([]);
            end
            for policyIndex = 1:numel(policies)
                parameters = policies(policyIndex);
                policyArguments = namedargs2cell(parameters);
                started = tic;
                report = assessQuadraticDealiasing(samples.fineF,samples.fineG,n,policyArguments{:});
                apvReport = assessQuadraticDealiasing(apv.fineF,apv.fineG,n,policyArguments{:});
                scoreSeconds = toc(started);
                count = leadingCount(report.accepted);
                apvCount = leadingCount(apvReport.accepted);
                selected = products([products.i]<=count & [products.j]<=count);
                if ~isempty(mixedProducts)
                    selected = [selected,mixedProducts([mixedProducts.i]<=count & [mixedProducts.j]<=apvCount)]; %#ok<AGROW>
                end
                errors = [selected.aliasError];
                referenceErrors = [selected.referenceError];
                fullReferenceErrors = [selected.fullReferenceError];
                record = struct(profile=profile,Nz=nz,Lxy=studyCase.Lxy,family=family,kappa=kappa,policy=parameters.quadraticDealiasing,retainedFraction=parameters.retainedFraction,energyFraction=parameters.energyFraction,bandwidthFraction=parameters.bandwidthFraction,linearCount=size(samples.coarseF,2),retainedCount=count,apvCount=apvCount,sampleCount=numel(errors),maximumAliasError=maximumOrNaN(errors),p95AliasError=percentile95(errors),maximumReferenceError=maximumOrNaN(referenceErrors),maximumFullReferenceError=maximumOrNaN(fullReferenceErrors),scoreSeconds=scoreSeconds,linearConstructionSeconds=constructionSeconds,fineCount=fineCount,referenceCount=referenceCount,coarseAgreement=samples.coarseAgreement);
                records = [records;record]; %#ok<AGROW>
            end
            for product = [products,mixedProducts]
                row = struct(profile=profile,Nz=nz,Lxy=studyCase.Lxy,family=family,kappa=kappa,i=product.i,j=product.j,channel=product.channel,mixed=product.mixed,aliasError=product.aliasError,referenceError=product.referenceError,fullReferenceError=product.fullReferenceError);
                productRecords = [productRecords;row]; %#ok<AGROW>
            end
        end
        writetable(struct2table(records),fullfile(outputFolder,'calibration.csv'));
        writetable(struct2table(productRecords),fullfile(outputFolder,'products.csv'));
        fprintf('Calibrated %s Nz=%d Lxy=%g, construction %.3f s, fine/reference %d/%d samples\n',profile,nz,studyCase.Lxy,constructionSeconds,fineCount,referenceCount);
end
summary = struct(environment=environment,sourceRevision=options.sourceRevision,providerRevision=options.providerRevision,threads=1,recordCount=numel(records),productCount=numel(productRecords),metric="Chebyshev-weighted coefficient error through floor(2*(Nz-1)/3), divided by full reference product norm; low-band and full-spectrum reference convergence are recorded separately",sampling="Self-products, neighboring-mode products, reflected-index products, and wave/APV products; O(M) pairs, three F/G channel products per pair",cases=cases);
writelines(jsonencode(summary,PrettyPrint=true),fullfile(outputFolder,'summary.json'));
end

function cases = calibrationCases(profiles,verticalCounts)
cases = struct(profile={},Nz={},Lxy={});
for profile = profiles
    for nz = verticalCounts
        if profile=="sharp" && nz~=65, continue; end
        cases(end+1) = struct(profile=profile,Nz=nz,Lxy=1e5); %#ok<AGROW>
    end
    if profile=="exponential" && any(verticalCounts==65)
        % Match the large benchmark's horizontal spacing and upper k band.
        cases(end+1) = struct(profile=profile,Nz=65,Lxy=12500); %#ok<AGROW>
    elseif profile=="constant" && any(verticalCounts==129)
        % Strong constant stratification needs this finer vertical grid to
        % resolve the independent boundary response at the upper k band.
        cases(end+1) = struct(profile=profile,Nz=129,Lxy=12500); %#ok<AGROW>
    end
end
end

function candidates = policyCandidates()
base = struct(quadraticDealiasing="none",retainedFraction=2/3,energyFraction=.99,bandwidthFraction=2/3);
candidates = base;
for fraction = [.5 2/3 .75]
    entry = base; entry.quadraticDealiasing="fixedFraction"; entry.retainedFraction=fraction;
    candidates(end+1) = entry; %#ok<AGROW>
end
for coverage = [.95 .99 .999]
    for fraction = [.5 2/3 .75]
        entry = base; entry.quadraticDealiasing="effectiveBandwidth"; entry.energyFraction=coverage; entry.bandwidthFraction=fraction;
        candidates(end+1) = entry; %#ok<AGROW>
    end
end
end

function N2 = stratification(profile)
switch profile
    case "constant", N2=@(z)1e-4+zeros(size(z));
    case "exponential", N2=@(z)1e-4*exp(2*z/700);
    case "sharp", N2=@(z)1e-5+9e-5*exp(-((z+200)/100).^2);
    otherwise, error('DealiasingStudy:UnknownProfile','Unknown study profile %s.',profile)
end
end

function samples = sampleBasis(basis,z,fineZ,referenceZ)
samples = struct(coarseF=basis.F(z),coarseG=basis.G(z),fineF=basis.F(fineZ),fineG=basis.G(fineZ),referenceF=basis.F(referenceZ),referenceG=basis.G(referenceZ));
end

function value = relativeShapeError(F,expectedF,G,expectedG)
value = max(norm(F-expectedF,'fro')/max(norm(expectedF,'fro'),realmin),norm(G-expectedG,'fro')/max(norm(expectedG,'fro'),realmin));
end

function count = leadingCount(mask)
first = find(~mask,1);
if isempty(first), count=numel(mask); else, count=first-1; end
end

function products = sampledProducts(left,right,gridDegree,mixed)
nLeft = size(left.coarseF,2); nRight = size(right.coarseF,2);
i = (1:nLeft).';
if mixed
    pairs = unique([i,max(1,ceil(i*nRight/nLeft));i,min(i,nRight);i,nRight+1-max(1,ceil(i*nRight/nLeft))],'rows');
else
    pairs = unique([i,i;i(1:end-1),i(2:end);i,nLeft+1-i],'rows');
end
products = repmat(struct(i=0,j=0,channel="",mixed=mixed,aliasError=0,referenceError=0,fullReferenceError=0),1,3*size(pairs,1));
channelIndex = 0;
for channels = ["FF","FG","GG"]
    channelIndex = channelIndex+1;
    names = char(channels);
    a = string(names(1)); b = string(names(2));
    leftScale = max(abs(left.("reference"+a)),[],1); leftScale(leftScale==0)=1;
    rightScale = max(abs(right.("reference"+b)),[],1); rightScale(rightScale==0)=1;
    coarse = (left.("coarse"+a)(:,pairs(:,1))./leftScale(pairs(:,1))).*(right.("coarse"+b)(:,pairs(:,2))./rightScale(pairs(:,2)));
    fine = (left.("fine"+a)(:,pairs(:,1))./leftScale(pairs(:,1))).*(right.("fine"+b)(:,pairs(:,2))./rightScale(pairs(:,2)));
    reference = (left.("reference"+a)(:,pairs(:,1))./leftScale(pairs(:,1))).*(right.("reference"+b)(:,pairs(:,2))./rightScale(pairs(:,2)));
    c = chebyshevCoefficients(coarse); f = chebyshevCoefficients(fine); r = chebyshevCoefficients(reference);
    rows = 1:floor(2*gridDegree/3)+1;
    denominator = coefficientNorm(r); denominator(denominator==0)=1;
    aliasError = coefficientNorm(c(rows,:)-r(rows,:))./denominator;
    referenceError = coefficientNorm(f(rows,:)-r(rows,:))./denominator;
    paddedFine = [f;zeros(size(r,1)-size(f,1),size(f,2))];
    fullReferenceError = coefficientNorm(paddedFine-r)./denominator;
    for p = 1:size(pairs,1)
        products((channelIndex-1)*size(pairs,1)+p) = struct(i=pairs(p,1),j=pairs(p,2),channel=channels,mixed=mixed,aliasError=aliasError(p),referenceError=referenceError(p),fullReferenceError=fullReferenceError(p));
    end
end
end

function coefficients = chebyshevCoefficients(values)
n = size(values,1)-1;
values = flipud(values);
coefficients = real(fft([values;values(end-1:-1:2,:)],[],1))/n;
coefficients = coefficients(1:n+1,:);
coefficients([1 end],:) = coefficients([1 end],:)/2;
end

function value = coefficientNorm(coefficients)
coefficients(1,:) = sqrt(2)*coefficients(1,:);
value = sqrt(sum(coefficients.^2,1));
end

function value = maximumOrNaN(values)
if isempty(values), value=NaN; else, value=max(values); end
end

function value = percentile95(values)
if isempty(values), value=NaN; else, values=sort(values); value=values(ceil(.95*numel(values))); end
end
