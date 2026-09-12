function results = runDerivativeComparison(outputFolder)
% Measure warmed derivative kernels and complete unforced coefficient RHSs.
% Configure runtime dependencies before calling. Does not change production.
arguments
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath = path; cleanup = onCleanup(@()path(originalPath));
addpath(fullfile(root,'tools','nonlinear-study'));
addpath(fullfile(fileparts(root),'OceanKit','tools','profiling'));
rows = zeros(24,9); row = 0;
for Hside = [8 32]
    for Z = [33 129 513]
        x = -cos(pi*(0:Z-1)'/(Z-1));
        weights = (-1).^(0:Z-1)'; weights([1 end])=weights([1 end])/2;
        distance = x-x'; distance(1:Z+1:end)=1;
        D = (weights'./weights)./distance; D(1:Z+1:end)=0; D(1:Z+1:end)=-sum(D,2);
        metric = (1+0.2*x)/500; D=metric.*D;
        for complexInput = [false true]
            u = repmat(reshape(exp(x),1,1,[]),Hside,Hside,1);
            if complexInput, u=u*(1+2i); end
            for n = [1 4]
                dense = @()denseWKBDerivative(u,D,n);
                fast = @()fftWKBDerivative(u,metric,n);
                expected = dense(); actual = fast();
                error = norm(actual(:)-expected(:))/norm(expected(:));
                [denseSeconds,fftSeconds] = pairedTiming(dense,fast);
                polynomial = 1;
                for order = 1:n
                    differentiated = polyder(polynomial);
                    differentiated = [zeros(1,numel(polynomial)-numel(differentiated)),differentiated];
                    polynomial = conv([0.2 1]/500,polynomial+differentiated);
                end
                oracle = u.*reshape(polyval(polynomial,x),1,1,[]);
                denseError = max(abs(expected-oracle),[],'all')/max(abs(oracle),[],'all');
                fftError = max(abs(actual-oracle),[],'all')/max(abs(oracle),[],'all');
                row=row+1; rows(row,:) = [Hside,Z,complexInput,n,denseSeconds,fftSeconds,error,denseError,fftError];
                fprintf('Kernel %dx%d x %d complex=%d order=%d: dense %.4g FFT %.4g s\n',Hside,Hside,Z,complexInput,n,denseSeconds,fftSeconds);
            end
        end
    end
end
results.kernels = array2table(rows,VariableNames={'horizontalSide','Z','complexInput','order','denseSeconds','fftSeconds','relativeDifference','denseAnalyticError','fftAnalyticError'});
writetable(results.kernels,fullfile(outputFolder,'kernels.csv'));
rows = zeros(3,10); row = 0;
for Z = [33 65 129]
    base = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 Z],N2Function=@(z)1e-4*exp(z/650),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    setupStart = tic;
    wvt = DerivativeStudyBoussinesq(base.scientificState());
    setupSeconds = toc(setupStart);
    assert(isempty(wvt.verticalModes),'Study restoration unexpectedly constructed modes.');
    wvt.t0 = -17;
    study = manuscriptEvolutionOperators(wvt,"exponential",padding=1);
    state = study.seed("mixed",1);
    for family = string(fieldnames(state)).', wvt.(family)=state.(family); end
    wvt.addForcing(WVNonlinearAdvection(wvt));
    wvt.useFFT = false; denseRate = wvt.coefficientTendency();

    denseProfile = profileCodeHotspots(@()wvt.coefficientTendency(),projectRoots=root);
    wvt.useFFT = true; fftRate = wvt.coefficientTendency();
    [denseSeconds,fftSeconds] = pairedTiming(@()switchedRHS(wvt,false),@()switchedRHS(wvt,true));
    fftProfile = profileCodeHotspots(@()wvt.coefficientTendency(),projectRoots=root);
    familyErrors = zeros(1,6); index = 0;
    for family = string(fieldnames(state)).'
        index=index+1;
        difference=fftRate.(family)-denseRate.(family);
        familyErrors(index)=norm(difference(:))/max(norm(denseRate.(family)(:)),realmin);
    end
    assert(max(familyErrors)<1e-8,'Candidate coefficient tendencies failed the relative agreement gate.');
    row=row+1; rows(row,:) = [Z,setupSeconds,denseSeconds,fftSeconds,familyErrors];
    save(fullfile(outputFolder,sprintf('rhs-profile-%d.mat',Z)),'denseProfile','fftProfile');
    fprintf('Full RHS Z=%d: dense %.4g FFT %.4g s; maximum family difference %.3g\n',Z,denseSeconds,fftSeconds,max(familyErrors));
end
results.rhs = array2table(rows,VariableNames=[{'Z','restorationAndMetricSeconds','denseSeconds','fftSeconds'},fieldnames(state)']);
writetable(results.rhs,fullfile(outputFolder,'rhs.csv'));
qg = WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(z/650),g0=.02,gd=.03,gramTolerance=.1);
qg.initWithGaussianEddy(maximumSpeed=.05,horizontalRadius=20e3,verticalScale=250,zCenter=75);
qgSeconds = timeit(@()qg.coefficientTendency());
qgProfile = profileCodeHotspots(@()qg.coefficientTendency(),projectRoots=root);
save(fullfile(outputFolder,'qg-profile.mat'),'qgProfile','qgSeconds');
results.matlab = version; results.computer=computer; results.qgSeconds=qgSeconds;
save(fullfile(outputFolder,'comparison.mat'),'results');
end

function rate = switchedRHS(wvt,useFFT)
wvt.useFFT = useFFT;
rate = wvt.coefficientTendency();
end

function [denseSeconds,fftSeconds] = pairedTiming(dense,fast)
% Warm both paths, alternate measurement order, and report three-pair medians.
for warmup = 1:3, dense(); fast(); end
samples = zeros(3,2);
for repeat = 1:3
    if mod(repeat,2)
        samples(repeat,1)=timeit(dense); samples(repeat,2)=timeit(fast);
    else
        samples(repeat,2)=timeit(fast); samples(repeat,1)=timeit(dense);
    end
end
denseSeconds = median(samples(:,1)); fftSeconds = median(samples(:,2));
end
