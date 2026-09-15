function vertical = buildFreeSurfaceBalancedModes(Lz,Nz,N2Function,options)
% Build APV and MDA transforms on one fixed WKB quadrature rule.
arguments
    Lz (1,1) double {mustBePositive}
    Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(Nz,4)}
    N2Function function_handle
    options struct
end

zDomain = [-Lz 0];
nSolve = Nz+4;
nEVP = max(96,3*nSolve);
if isfield(options,"balancedNEVP"), nEVP=options.balancedNEVP; end
solver = IMSolverSpectral(nEVP=nEVP);
apvProblem = IMInternalModes.geostrophicAPVModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=options.g0,gd=options.gd,surfaceBoundary="freeSurface");
mdaProblem = IMInternalModes.meanDensityAnomalyModes(N2=N2Function,zDomain=zDomain,g=options.g,g0=options.g0,gd=options.gd);

gridSolver = IMSolverSpectral(nEVP=Nz,coordinateKind="wkb").configuredForEVP(apvProblem);
[z,weights,Dz] = gridSolver.nativeDifferentiationRule(zDomain);
weights = weights*(Lz/sum(weights));
if length(z) ~= Nz || any(diff(z) <= 0) || abs(z(1)+Lz) > sqrt(eps)*max(1,Lz) || abs(z(end)) > sqrt(eps)*max(1,Lz)
    error('WVTransformFreeSurfaceQG:InvalidVerticalGrid','The WKB quadrature must contain Nz increasing points spanning exactly [-Lz,0].');
end
if any(~isfinite(weights)) || any(weights <= 0) || abs(sum(weights)-Lz) > 64*eps(max(1,Lz))
    error('WVTransformFreeSurfaceQG:InvalidVerticalQuadrature','The WKB quadrature must have finite positive weights that integrate the exact depth.');
end
N2Values = N2Function(z);
N2Values = N2Values(:);
if length(N2Values) ~= length(z) || any(~isfinite(N2Values)) || any(N2Values <= 0)
    error('WVTransformFreeSurfaceQG:InvalidStratification','N2Function must return one finite positive value per z point.');
end

apvCount = []; mdaCount = [];
if isfield(options,"apvModeCount"), apvCount = options.apvModeCount; end
if isfield(options,"mdaModeCount"), mdaCount = options.mdaModeCount; end
[apvBasis,apvTransform,apvAssessment,apvCandidateConstruction] = buildAPV();
[mdaBasis,mdaTransform,mdaAssessment,mdaCandidateConstruction] = buildMDA();
referenceNEVP=ceil(1.5*nEVP);
referenceSolver=IMSolverSpectral(nEVP=referenceNEVP);
apvReference=referenceSolver.solveEVP(apvProblem,nModes=numel(apvTransform.h));
mdaReference=referenceSolver.solveEVP(mdaProblem,nModes=numel(mdaTransform.h));
[apvConvergence,apvErrors,apvPrepared]=WVInternal.compareResolvedModes(apvBasis,apvReference,N2Function,2*referenceNEVP+1,numel(apvTransform.h));
[mdaConvergence,mdaErrors]=WVInternal.compareResolvedModes(mdaBasis,mdaReference,N2Function,2*referenceNEVP+1,numel(mdaTransform.h));
if any(apvErrors(1:numel(apvTransform.h))>options.modeConvergenceTolerance) || any(mdaErrors(1:numel(mdaTransform.h))>options.modeConvergenceTolerance)
    attempt=1; if isfield(options,'balancedAttempt'), attempt=options.balancedAttempt; end
    if attempt<3
        options.balancedAttempt=attempt+1; options.balancedNEVP=referenceNEVP;
        vertical=WVInternal.buildFreeSurfaceBalancedModes(Lz,Nz,N2Function,options);
        return
    end
    % Automatic linear counts retain the converged leading prefix. Explicit
    % requests remain strict even when the bounded solve budget is exhausted.
    apvLimit=qualifiedPrefix(apvErrors,numel(apvTransform.h),apvCount,options.modeConvergenceTolerance,"APV");
    mdaLimit=qualifiedPrefix(mdaErrors,numel(mdaTransform.h),mdaCount,options.modeConvergenceTolerance,"MDA");
    apvTransform=apvBasis.discreteTransform(z=z,weights=weights,variables=["F","G"],gramTolerance=options.gramTolerance,nModes=apvLimit);
    mdaTransform=mdaBasis.discreteTransform(z=z,weights=weights,variables="G",gramTolerance=options.gramTolerance,nModes=mdaLimit);
end

linearCount=numel(apvTransform.h);
if ~isempty(apvCount) && apvCount>linearCount
    error('WV:StrictAPVModeCountRejected', ...
        'The explicit APV count %d exceeds the converged or fixed-grid Gram prefix %d.',apvCount,linearCount)
end
timer=tic;
apvDealiasing=WVInternal.quadraticDealiasingPrefix(apvPrepared.values.F(:,1:linearCount), ...
    apvPrepared.values.G(:,1:linearCount),Nz-1,options);
quadraticDealiasingSeconds=toc(timer);
if ~isempty(apvCount) && apvCount>apvDealiasing.filteringCount
    error('WV:QuadraticDealiasingAPVCountRejected', ...
        'The explicit APV count %d exceeds the quadratic-dealiasing limit %d under policy %s.', ...
        apvCount,apvDealiasing.filteringCount,options.quadraticDealiasing)
end
selectedCount=apvDealiasing.filteringCount;
if ~isempty(apvCount), selectedCount=apvCount; end
if selectedCount<1
    error('WV:NoResolvedAPVModes', ...
        'No APV mode passes the linear and quadratic-dealiasing limits. Increase Nz or change quadraticDealiasing.')
end
apvDealiasing.selectedCount=selectedCount;
if selectedCount~=linearCount
    apvTransform=apvBasis.discreteTransform(z=z,weights=weights,variables=["F","G"], ...
        gramTolerance=options.gramTolerance,nModes=selectedCount);
end
if apvTransform.hasNegativeWeights || mdaTransform.hasNegativeWeights ...
        || max(abs(apvTransform.weights-weights)) > 0 || max(abs(mdaTransform.weights-weights)) > 0
    error('WVTransformFreeSurfaceQG:InvalidVerticalQuadrature','InternalModes did not preserve the shared positive physical quadrature rule.');
end
if ~isempty(apvAssessment.weightFit) || ~isempty(mdaAssessment.weightFit)
    error('WVTransformFreeSurfaceQG:ModeSelectionInconsistency','InternalModesEVP did not use the supplied fixed quadrature rule.');
end

vertical = struct(z=z,weights=weights,Dz=Dz,N2Values=N2Values,nEVP=nEVP,solver=solver,apvProblem=apvProblem,mdaProblem=mdaProblem, ...
    apvBasis=apvBasis,apvCandidateConstruction=apvCandidateConstruction,mdaBasis=mdaBasis,mdaCandidateConstruction=mdaCandidateConstruction,apvConvergence=apvConvergence,mdaConvergence=mdaConvergence,apvReference=apvReference,mdaReference=mdaReference,referenceNEVP=referenceNEVP,apvTransform=apvTransform,mdaTransform=mdaTransform,apvAssessment=apvAssessment,mdaAssessment=mdaAssessment,apvDealiasing=apvDealiasing,quadraticDealiasingSeconds=quadraticDealiasingSeconds);
    function [basis,transform,assessment,candidateConstruction]=buildAPV()
        % The complete candidate establishes the independent linear limit
        % before filtering.
        count=nSolve;
        attemptedCounts=[];
        while true
            attemptedCounts(end+1)=count; %#ok<AGROW>
            basis=solver.solveEVP(apvProblem,nModes=count);
            [transform,assessment]=basis.discreteTransform(z=z,weights=weights,variables=["F","G"],gramTolerance=options.gramTolerance);
            if count==nSolve || numel(transform.h)<numel(basis.h)
                candidateConstruction=struct(attemptedCounts=attemptedCounts,candidateCount=numel(basis.h));
                return
            end
            count=min(2*count,nSolve);
        end
    end

    function [basis,transform,assessment,candidateConstruction]=buildMDA()
        % A failed normalization in an unused candidate tail must not prevent
        % selection of a shorter, grid-qualified prefix. Bracket a valid
        % candidate band until its Gram cutoff lies strictly inside the band.
        % Never accept a truncated search ceiling as a measured Gram cutoff.
        count=nSolve;
        if ~isempty(mdaCount), count=mdaCount; end
        lower=0; upper=count; attemptedCounts=[]; rejectedCounts=[];
        while true
            attemptedCounts(end+1)=count; %#ok<AGROW>
            try
                basis=solver.solveEVP(mdaProblem,nModes=count);
            catch exception
                if ~isempty(mdaCount) || ~strcmp(exception.identifier,'IMMeanDensityAnomalyModesBasis:ZeroNormMode')
                    rethrow(exception)
                end
                rejectedCounts(end+1)=count; %#ok<AGROW>
                upper=count-1;
                count=ceil((lower+upper)/2);
                if count<=lower
                    error('WV:UnqualifiedMDACandidateBand','MDA normalization failed before a physical-grid Gram cutoff could be established. Increase the balanced EVP resolution.')
                end
                continue
            end
            [transform,assessment]=basis.discreteTransform(z=z,weights=weights,variables="G",gramTolerance=options.gramTolerance,nModes=mdaCount);
            if ~isempty(mdaCount) || isempty(rejectedCounts) || numel(transform.h)<numel(basis.h)
                candidateConstruction=struct(attemptedCounts=attemptedCounts,rejectedNormalizationCounts=rejectedCounts,candidateCount=numel(basis.h));
                return
            end
            lower=count;
            count=ceil((lower+upper)/2);
            if count<=lower
                error('WV:UnqualifiedMDACandidateBand','The valid MDA candidate band ends before a physical-grid Gram cutoff was measured. Increase the balanced EVP resolution.')
            end
        end
    end
end

function count=qualifiedPrefix(errors,count,requested,tolerance,family)
firstRejected=find(~isfinite(errors(1:count)) | errors(1:count)>tolerance,1);
if isempty(firstRejected), return; end
linearLimit=firstRejected-1;
if ~isempty(requested) && requested>linearLimit
    error('WV:UnconvergedBalancedModes','The explicit %s count %d exceeds the independently converged prefix %d. Increase the EVP resolution or reduce the requested count.',family,requested,firstRejected-1)
end
count=linearLimit;
if count<1
    error('WV:UnconvergedBalancedModes','No %s mode passes independent convergence at tolerance %.3g.',family,tolerance)
end
end
