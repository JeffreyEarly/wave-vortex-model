function results = runFreeSurfaceWeakBudgetStudy(outputFolder)
% Diagnose mapped weak evolution, boundary reactions, and physical energy.
%
% This dense experiment uses the existing global real modal span, not a
% production pressure closure. Density labels must remain in [-D,0]. Only
% physical height uses the manuscript's constant-density extension above
% zero. Constant interior N2 then gives A=N2*(eta^2-max(z,0)^2)/2.
% Suitable MDA mean offsets keep both active boundary labels admissible.
% A fixed low-mode seed is retained while counts and quadrature increase;
% amplitude multiplies every seed coefficient, including the mean offsets.
%
% Source physics is WVM 81987767 plus mapping 43ed50ef and tendency 74569724,
% with configureCIEnvironment's InternalModes@2.0.0-beta.4 snapshots.
arguments (Input)
    outputFolder (1,1) string
end
arguments (Output)
    results table
end
helper = freeSurfaceWeakStudyHelpers();
if ~isfolder(outputFolder), mkdir(outputFolder); end
configurations = [65 2 3 2 2 2;129 4 6 4 4 2;129 4 6 4 4 3];
rows = cell(0,1);
referenceSeed = [];
for configuration = 1:size(configurations,1)
    config = configurations(configuration,:);
    constructionClock = tic;
    wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[4 4 config(1)],N2Function=@(z)1e-4+0*z,apvModeCount=config(2),waveModeCount=config(3),mdaModeCount=config(4),inertialModeCount=config(5),nEVP=128);
    constructorSeconds = toc(constructionClock);
    setupClock = tic;
    wvt.t=0; wvt.t0=0;
    context = helper.buildContext(wvt,config(6));
    [basis,linearBasis] = helper.globalBasis(wvt,context);
    H0 = helper.gram(basis,context);
    diagonalScale = sqrt(diag(H0));
    R0 = chol(H0./(diagonalScale*diagonalScale.'));
    T = diag(1./diagonalScale)/R0;
    for name = ["u","v","w","eta","ssh"]
        basis.(name)=basis.(name)*T;
        linearBasis.(name)=linearBasis.(name)*T;
    end
    whiteningError = norm(helper.gram(basis,context)-eye(size(T)),2);
    seedFields = helper.sampledState(wvt,helper.seedState(wvt),context);
    [seedFingerprint,denseSeedEta,denseSeedSSH,denseXi] = helper.seedCheckpoints(seedFields,context);
    if isempty(referenceSeed), referenceSeed=seedFingerprint; end
    seedRefinementDifference = norm(seedFingerprint-referenceSeed)/norm(referenceSeed);
    seed = helper.physicalPair(basis,seedFields,context);
    representationError = helper.fieldError(helper.stateFromVector(basis,seed,context),seedFields,context);
    [pressureAdjointError,smoothPressureAdjointError] = helper.pressureAdjointDefect(basis,context);
    Kfull = [basis.ssh;basis.eta(context.top,:)-basis.ssh;basis.eta(context.bottom,:)];
    [left,singular,~] = svd(Kfull,'econ');
    values = diag(singular);
    constraintRank = sum(values>1e-10*max(values));
    left = left(:,1:constraintRank);
    K = left'*Kfull;
    expectedLinear = helper.physicalPair(basis,helper.stateFromVector(linearBasis,seed,context),context);
    seedStateFields = helper.stateFromVector(basis,seed,context);
    linearF = struct(u=wvt.f*seedStateFields.v,v=-wvt.f*seedStateFields.u,w=-context.N2*seedStateFields.eta,eta=seedStateFields.w);
    linearRhs = helper.physicalPair(basis,linearF,context)-wvt.g*basis.w(context.top,:)'*(context.surfaceWeights.*seedStateFields.ssh(:))+wvt.g*basis.ssh'*(context.surfaceWeights.*seedStateFields.w(context.top));
    linearTarget = [seedStateFields.w(context.top);zeros(2*context.nSurface,1)];
    [linearRate,linearMultiplier] = helper.constrainedSolve(eye(size(T)),linearRhs,K,left'*linearTarget);
    linearError = norm(linearRate-expectedLinear)/max(norm(expectedLinear),realmin);
    basisSetupSeconds = toc(setupClock);
    fprintf('weak configuration %d: %d real coefficients, %d constraints, linear error %.3g\n',configuration,size(T,1),constraintRank,linearError);
    for amplitude = [.25 1]
        state = amplitude*seed;
        hatted = helper.stateFromVector(basis,state,context);
        assemblyClock = tic;
        [energy,gradient,H,Psi,physical,buoyancy] = helper.energyGeometry(basis,state,context);
        rhsClock = tic;
        rhs = WVInternal.freeSurfaceMappedTendency(hatted,zeros(context.shape),buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,context.derivative);
        rhsSeconds = toc(rhsClock);
        momentum = helper.metricApply(physical,rhs,context);
        % Flatten gamma explicitly: implicit expansion must not create an
        % Nx-by-Ny-by-Nz-by-Ngrid thermodynamic pairing.
        scalarWeight = context.N2*repmat(physical.gamma,1,1,wvt.Nz);
        f = basis.u'*(context.weights.*momentum.u(:))+basis.v'*(context.weights.*momentum.v(:))+basis.w'*(context.weights.*momentum.w(:))+basis.eta'*(context.weights.*scalarWeight(:).*rhs.eta(:));
        surfaceRate = hatted.w(context.top);
        f = f-wvt.g*basis.w(context.top,:)'*(context.surfaceWeights.*hatted.ssh(:))+wvt.g*basis.ssh'*(context.surfaceWeights.*surfaceRate);
        thetaSurface = hatted.eta(:,:,end)-hatted.ssh;
        thetaBottom = hatted.eta(:,:,1);
        targetSurface = -physical.u(:,:,end).*context.derivative.x(thetaSurface)-physical.v(:,:,end).*context.derivative.y(thetaSurface);
        targetBottom = -physical.u(:,:,1).*context.derivative.x(thetaBottom)-physical.v(:,:,1).*context.derivative.y(thetaBottom);
        target = [surfaceRate;targetSurface(:);targetBottom(:)];
        assemblySeconds = toc(assemblyClock);
        solveClock = tic;
        v0 = H\f;
        [v,multiplier] = helper.constrainedSolve(H,f,K,left'*target);
        solveSeconds = toc(solveClock);
        rate0 = gradient'*v0;
        rate = gradient'*v;
        gridDefect = state'*f+Psi'*(context.surfaceWeights.*surfaceRate);
        mismatch0 = Psi'*(context.surfaceWeights.*(basis.ssh*v0-surfaceRate));
        mismatch = Psi'*(context.surfaceWeights.*(basis.ssh*v-surfaceRate));
        reaction = -(K*state)'*multiplier;
        solverResidual = H*v+K'*multiplier-f;
        solverWork = state'*solverResidual;
        [gradientError,gradientErrors] = helper.directionalGradientCheck(basis,state,gradient,context);
        residual = Kfull*v-target;
        retainedResidual = Kfull*v-left*(left'*target);
        divergence = context.derivative.x(hatted.u)+context.derivative.y(hatted.v)+context.derivative.xi(hatted.w);
        labels = physical.z-hatted.eta;
        denseLabels = reshape(denseXi,1,1,[])+amplitude*(reshape(1+denseXi/context.D,1,1,[]).*denseSeedSSH-denseSeedEta);
        if min(denseLabels,[],'all') < -context.D || max(denseLabels,[],'all') > 0
            error('WV:WeakStudyOversampledLabels','The fixed seed leaves the reference-label domain on the checkpoint grid.');
        end
        row = struct(configuration=configuration,nz=wvt.Nz,apvModeCount=config(2),waveModeCount=config(3),mdaModeCount=config(4),inertialModeCount=config(5),horizontalQuadratureCount=context.shape(1),amplitude=amplitude,realCoefficientCount=length(state),constraintRank=constraintRank,minimumRetainedConstraintSingularValue=min(values(1:constraintRank)),whiteningError=whiteningError,seedRepresentationError=representationError,pressureAdjointRelativeError=pressureAdjointError,linearCoefficientRelativeError=linearError,linearReactionNorm=norm(linearMultiplier),energy=energy,minimumLabel=min(labels,[],'all'),maximumLabel=max(labels,[],'all'),maximumStateDivergence=max(abs(divergence),[],'all'),gradientFiniteDifferenceRelativeError=gradientError,gridEnergyDefect=gridDefect,unconstrainedSSHGeometryWork=mismatch0,constrainedSSHGeometryWork=mismatch,constraintReactionWork=reaction,solverResidualWork=solverWork,unconstrainedEnergyRate=rate0,constrainedEnergyRate=rate,unconstrainedBudgetIdentityError=rate0-gridDefect-mismatch0,constrainedBudgetIdentityError=rate-gridDefect-mismatch-reaction-solverWork,maximumSSHRateResidual=max(abs(residual(1:context.nSurface))),maximumSurfaceDensityRateResidual=max(abs(residual(context.nSurface+(1:context.nSurface)))),maximumBottomDensityRateResidual=max(abs(residual(2*context.nSurface+(1:context.nSurface)))),discardedBoundaryTargetNorm=norm(target-left*(left'*target)),relativeConstraintCorrection=norm(v-v0)/max(norm(v0),realmin),massRcond=rcond(H),matlabRelease=string(version('-release')));
        row.seedRefinementRelativeDifference = seedRefinementDifference;
        row.oversampledMinimumLabel = min(denseLabels,[],'all');
        row.oversampledMaximumLabel = max(denseLabels,[],'all');
        row.maximumRetainedSurfaceDensityRateResidual = max(abs(retainedResidual(context.nSurface+(1:context.nSurface))));
        row.maximumRetainedBottomDensityRateResidual = max(abs(retainedResidual(2*context.nSurface+(1:context.nSurface))));
        row.discardedBoundaryTargetRMS = norm(target-left*(left'*target))/sqrt(length(target));
        row.smoothPressureAdjointRelativeError = smoothPressureAdjointError;
        row.gradientRelativeErrorStep1eMinus4 = gradientErrors(1);
        row.gradientRelativeErrorStep1eMinus5 = gradientErrors(2);
        row.gradientRelativeErrorStep1eMinus6 = gradientErrors(3);
        % Single observations include warm-up and diagnostic overhead; these
        % are not a timing benchmark or production throughput claim.
        row.constructorSeconds = constructorSeconds;
        row.basisSetupSeconds = basisSetupSeconds;
        row.massAndRHSAssemblySeconds = assemblySeconds;
        row.mappedRHSEvaluationSeconds = rhsSeconds;
        row.twoWeakSolvesSeconds = solveSeconds;
        rows{end+1}=row; %#ok<AGROW>
        fprintf('amplitude %.2f: D %.4g, SSH work %.4g, reaction %.4g, rate %.4g, gradient %.3g\n',amplitude,gridDefect,mismatch0,reaction,rate,gradientError);
    end
end
results = struct2table(vertcat(rows{:}));
writetable(results,fullfile(outputFolder,'mapped-weak-budget-study.csv'));
end
