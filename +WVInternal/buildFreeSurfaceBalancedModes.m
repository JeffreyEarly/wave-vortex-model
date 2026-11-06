function vertical = buildFreeSurfaceBalancedModes(background,Nz,options)
% Build APV and MDA transforms on one fixed provider quadrature rule.
arguments
    background (1,1) IMBackground
    Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(Nz,4)}
    options struct
end

zDomain = background.zDomain;
Lz = background.D;
N2Function = background.N2;
nSolve = Nz+4;
initialNEVP = max(96,3*nSolve);
nEVP = initialNEVP;
apvProblem = IMInternalModes.geostrophicAPVModes(background,g0=options.g0,gd=options.gd);
mdaProblem = IMInternalModes.meanDensityAnomalyModes(background,g0=options.g0,gd=options.gd);

if isfield(options,"verticalGridRule") && options.verticalGridRule == "wkb"
    grid = IMVerticalGrid.wkb(background,Nz);
else
    grid = IMVerticalGrid.smoothedBandwidth(background,Nz);
end
z = grid.z;
weights = grid.weights;
Dz = grid.calculus.firstDerivativeMatrix();
if length(z) ~= Nz || any(diff(z) <= 0) || any(abs([z(1) z(end)]-zDomain) > sqrt(eps)*max(1,Lz))
    error('WVTransformFreeSurfaceQG:InvalidVerticalGrid','The vertical quadrature must contain Nz increasing points spanning the vertical domain.');
end
if any(~isfinite(weights)) || any(weights <= 0) || abs(sum(weights)-Lz) > 64*eps(max(1,Lz))
    error('WVTransformFreeSurfaceQG:InvalidVerticalQuadrature','The vertical quadrature must have finite positive weights that integrate the exact depth.');
end
N2Values = N2Function(z);
N2Values = N2Values(:);
if length(N2Values) ~= length(z) || any(~isfinite(N2Values)) || any(N2Values <= 0)
    error('WVTransformFreeSurfaceQG:InvalidStratification','N2Function must return one finite positive value per z point.');
end

apvCount = []; mdaCount = [];
if isfield(options,"apvModeCount"), apvCount = options.apvModeCount; end
if isfield(options,"mdaModeCount"), mdaCount = options.mdaModeCount; end
if apvCount>Nz
    error('WV:StrictAPVModeCountRejected','The explicit APV count %d exceeds the physical sample count Nz=%d.',apvCount,Nz)
end
if mdaCount>Nz
    error('WV:StrictMDAModeCountRejected','The explicit MDA count %d exceeds the physical sample count Nz=%d.',mdaCount,Nz)
end

for attempt=1:3
    referenceNEVP=ceil(1.5*nEVP);
    solver=IMSolverSpectral(nEVP=nEVP);
    referenceSolver=IMSolverSpectral(nEVP=referenceNEVP);
    [apvBasis,apvReference,apvTransform,apvAssessment,apv,apvPrepared]=assessFamily(apvProblem,apvCount,["F","G"],"APV");
    [mdaBasis,mdaReference,mdaTransform,mdaAssessment,mda]=assessFamily(mdaProblem,mdaCount,"G","MDA");
    % Retry only when independent convergence limits an assessed band. A
    % fixed-grid cutoff already measured at a smaller count needs no retry.
    if attempt==3 || (~convergenceLimits(apv) && ~convergenceLimits(mda))
        break
    end
    nEVP=referenceNEVP;
end
requireLinearCount(apv,apvCount,"APV");
requireLinearCount(mda,mdaCount,"MDA");

timer=tic;
linearCount=apv.linearCount;
F=apvPrepared.values.F;
G=apvPrepared.values.G;
if grid.kind ~= "wkb" && options.quadraticDealiasing == "effectiveBandwidth"
    zFilter=grid.calculus.lobattoRule(size(F,1));
    F=apvBasis.F(zFilter);
    G=apvBasis.G(zFilter);
end
apvDealiasing=WVInternal.quadraticDealiasingPrefix(F(:,1:linearCount),G(:,1:linearCount),Nz-1,options,grid.kind);
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
    apvTransform=apvTransform.prefixTransform(selectedCount);
end
if apvTransform.hasNegativeWeights || mdaTransform.hasNegativeWeights ...
        || max(abs(apvTransform.weights-weights)) > 0 || max(abs(mdaTransform.weights-weights)) > 0
    error('WVTransformFreeSurfaceQG:InvalidVerticalQuadrature','InternalModes did not preserve the shared positive physical quadrature rule.');
end
if ~isempty(apvAssessment.weightFit) || ~isempty(mdaAssessment.weightFit)
    error('WVTransformFreeSurfaceQG:ModeSelectionInconsistency','InternalModesEVP did not use the supplied fixed quadrature rule.');
end
apv.filteringCount=apvDealiasing.filteringCount;
apv.filteringStatus="applied";
apv.dealiasing=apvDealiasing;
apv=selectedRecord(apv,apvTransform,["F","G"]);
mda.filteringCount=NaN;
mda.filteringStatus="not-applicable";
mda=selectedRecord(mda,mdaTransform,"G");

vertical = struct(grid=grid,z=z,weights=weights,Dz=Dz,N2Values=N2Values,nEVP=nEVP,initialNEVP=initialNEVP,solver=solver, ...
    apvProblem=apvProblem,mdaProblem=mdaProblem,apvBasis=apvBasis,mdaBasis=mdaBasis,apvReference=apvReference,mdaReference=mdaReference, ...
    referenceNEVP=referenceNEVP,apvTransform=apvTransform,mdaTransform=mdaTransform,apvAssessment=apvAssessment,mdaAssessment=mdaAssessment, ...
    apv=apv,mda=mda,apvDealiasing=apvDealiasing,quadraticDealiasingSeconds=quadraticDealiasingSeconds);

    function [basis,reference,transform,assessment,result,prepared]=assessFamily(problem,requested,variables,family)
        count=nSolve;
        if family=="MDA" && ~isempty(requested), count=requested; end
        [basis,reference,construction]=solveBand(problem,count,family,isempty(requested));
        candidateCount=numel(basis.modeNumber);
        [convergence,~,prepared]=WVInternal.compareResolvedModes(basis,reference,2*referenceNEVP+1,candidateCount);
        summary=WVInternal.summarizeModeConvergence(convergence,candidateCount,options.modeConvergenceTolerance);
        convergedCount=summary.acceptedCount;

        % The fixed rule only sees modes qualified by the independent solves.
        gridCandidateCount=min(convergedCount,Nz);
        transform=[]; assessment=[];
        fixedGridCount=0;
        diagnostics=table();
        channelDiagnostics=struct();
        fixedGridReason="";
        if gridCandidateCount>0
            try
                [transform,assessment]=basis.discreteTransform(z=z,weights=weights,variables=variables, ...
                    nModes=gridCandidateCount,allowRetainedPrefix=true,gramTolerance=options.gramTolerance);
                fixedGridCount=numel(transform.modeNumber);
                diagnostics=assessment.prefixDiagnostics;
                for variable=variables
                    channelDiagnostics.(variable)=assessment.variablePrefixDiagnostics(variable=variable);
                end
                fixedGridReason=string(assessment.retentionReason);
            catch exception
                if exception.identifier~="IMBasisSet:NoAcceptableDiscreteTransformPrefix"
                    rethrow(exception)
                end
                fixedGridReason=string(exception.message);
            end
        end

        limitingLabel=NaN;
        limitingMetric="candidate-count";
        coverage="candidate-ceiling";
        firstUnassessedCount=candidateCount+1;
        if fixedGridCount<gridCandidateCount
            firstUnassessedCount=NaN;
            limitingLabel=basis.modeNumber(fixedGridCount+1);
            limitingMetric="fixed-grid";
            coverage="measured-cutoff";
        elseif convergedCount<min(candidateCount,Nz)
            limitingLabel=basis.modeNumber(convergedCount+1);
            limitingMetric="independent-convergence";
            coverage="measured-cutoff";
            firstUnassessedCount=NaN;
            if ~summary.measured(convergedCount+1)
                coverage="reference-inconclusive";
                firstUnassessedCount=convergedCount+1;
            end
        elseif candidateCount>Nz
            limitingLabel=basis.modeNumber(Nz+1);
            limitingMetric="physical-sample-count";
            coverage="sample-ceiling";
            firstUnassessedCount=Nz+1;
        elseif ~isempty(construction.rejectedNormalizationCounts)
            limitingMetric="mode-normalization";
            coverage="normalization-inconclusive";
            firstUnassessedCount=NaN;
        end
        requestKind="strict";
        if isempty(requested)
            requestKind="automatic";
            requested=NaN;
        end
        result=struct(requestKind=requestKind,requestedCount=requested,initialNEVP=initialNEVP,candidateNEVP=nEVP,referenceNEVP=referenceNEVP, ...
            candidateCount=candidateCount,convergedCount=convergedCount,convergenceAssessedCount=nnz(summary.measured),gridAssessedCount=gridCandidateCount, ...
            fixedGridCount=fixedGridCount,linearCount=fixedGridCount,linearCoverage=coverage,linearLimitingMetric=limitingMetric, ...
            candidateLimitReached=coverage=="candidate-ceiling",firstUnassessedCount=firstUnassessedCount, ...
            limitingLabel=limitingLabel,fixedGridReason=fixedGridReason,prefixDiagnostics=diagnostics, ...
            channelDiagnostics=channelDiagnostics,convergence=convergence, ...
            candidateConstruction=construction);
    end

    function [basis,reference,construction]=solveBand(problem,limit,family,isAutomatic)
        % MDA normalization can fail in a high tail. Find the largest band
        % returned by both independent solvers, and record the search ceiling.
        lower=0; upper=limit; count=limit;
        attemptedCounts=[]; rejectedCounts=[];
        while count>lower
            attemptedCounts(end+1)=count; %#ok<AGROW>
            try
                candidate=solver.solveEVP(problem,nModes=count);
                refined=referenceSolver.solveEVP(problem,nModes=count);
                basis=candidate;
                reference=refined;
                lower=count;
            catch exception
                if family~="MDA" || exception.identifier~="IMMeanDensityAnomalyModesBasis:ZeroNormMode"
                    rethrow(exception)
                end
                if ~isAutomatic
                    error('WV:StrictMDAModeCountRejected', ...
                        'The explicit MDA count %d includes a mode with unresolved normalization at nEVP=%d or referenceNEVP=%d.', ...
                        count,nEVP,referenceNEVP)
                end
                rejectedCounts(end+1)=count; %#ok<AGROW>
                upper=count-1;
            end
            count=ceil((lower+upper)/2);
        end
        if lower==0
            error('WV:UnqualifiedMDACandidateBand','No candidate MDA mode normalized in both solves. Increase Nz to raise the balanced EVP resolution.')
        end
        construction=struct(attemptedCounts=attemptedCounts,rejectedNormalizationCounts=rejectedCounts, ...
            candidateCount=numel(basis.modeNumber),candidateBudget=limit);
    end
end

function doesLimit=convergenceLimits(record)
doesLimit=record.linearLimitingMetric=="independent-convergence";
end

function requireLinearCount(record,requested,family)
if ~isempty(requested) && requested>record.linearCount
    if convergenceLimits(record)
        error('WV:UnconvergedBalancedModes', ...
            'The explicit %s count %d exceeds the independently converged prefix %d at label %g (%s). Increase Nz to raise the balanced EVP resolution, or reduce the requested count.', ...
            family,requested,record.linearCount,record.limitingLabel,record.linearCoverage)
    end
    error("WV:Strict"+family+"ModeCountRejected", ...
        'The explicit %s count %d exceeds the qualified prefix %d (%s at label %g). %s', ...
        family,requested,record.linearCount,record.linearLimitingMetric,record.limitingLabel,record.fixedGridReason)
end
if record.linearCount==0
    if convergenceLimits(record)
        error('WV:UnconvergedBalancedModes','No %s mode passes independent convergence (%s). Increase Nz to raise the balanced EVP resolution.',family,record.linearCoverage)
    end
    error("WV:NoResolved"+family+"Modes",'No %s mode passes the fixed-grid assessment. Increase Nz.',family)
end
end

function record=selectedRecord(record,transform,variables)
record.status="accepted";
record.selectedCount=numel(transform.modeNumber);
record.selectedLabels=transform.modeNumber(:);
record.sampledInversionSpan="selected";
record.sampledInversionSpanCount=record.selectedCount;
for variable=variables
    mask=transform.activeModeMask(variable=variable);
    record.selectedActive.(variable)=mask(:);
end
end
