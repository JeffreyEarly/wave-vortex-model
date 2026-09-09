function [assessment,reference] = assessWaveModeConstruction(state,bases,activePages,referenceNEVP,tolerance)
% Compare the actual constructed wave bases with an explicitly requested solve.
% Zero-count pages contain no tested waves. A full passing prefix reaches
% the candidate ceiling; it is not a measured maximum available mode count.
arguments (Input)
    state (1,1) struct
    bases (1,1) IMBasisCollection
    activePages (:,1) double
    referenceNEVP (:,1) double
    tolerance (1,1) double
end
np=length(state.khUnique);
kappa=state.khUnique;
requestedCount=state.waveModeCountByKh;
convergedCount=nan(np,1); gridSupportedCount=zeros(np,1); usableCount=nan(np,1);
status=repmat("reference-not-requested",np,1);
candidateLimitReached=false(np,1);
modeConvergence=cell(np,1); prefixGramError=cell(np,1);
reference=[];
if ~isempty(referenceNEVP)
    f=2*state.rotationRate*sind(state.latitude);
    reference=IMSolverSpectral(nEVP=referenceNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers([0 state.khUnique(activePages).'],N2=state.N2Function,zDomain=[-state.Lxyz(3) 0],f0=f,g=state.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=requestedCount(activePages).',nInertialModes=length(state.inertialMode));
end
for p=1:np
    count=requestedCount(p);
    if count==0
        convergedCount(p)=0; usableCount(p)=0; status(p)="not-requested";
        prefixGramError{p}=zeros(0,1);
        continue
    end
    G=state.waveG(:,1:count,p);
    gram=state.waveGForward(1:count,:,p)*G;
    errors=zeros(count,1);
    for n=1:count, errors(n)=norm(gram(1:n,1:n)-eye(n),2); end
    prefixGramError{p}=errors;
    gridSupportedCount(p)=sum(cumprod(errors<=state.gramTolerance));
    if isempty(reference), continue; end
    page=find(activePages==p)+1;
    basis=bases.bases{bases.basisIndex(page)};
    check=reference.bases{reference.basisIndex(page)};
    report=compare(basis,check,kappa(p)); modeConvergence{p}=report;
    [convergedCount(p),complete]=acceptedPrefix(report,count,tolerance);
    usableCount(p)=min(convergedCount(p),gridSupportedCount(p));
    if ~complete
        status(p)="reference-inconclusive"; usableCount(p)=NaN;
    elseif usableCount(p)==count
        status(p)="accepted"; candidateLimitReached(p)=true;
    else
        status(p)="rejected";
    end
end
count=length(state.inertialMode);
gram=state.inertialFForward*state.inertialF;
errors=zeros(count,1);
for n=1:count, errors(n)=norm(gram(1:n,1:n)-eye(n),2); end
inertial=struct(requestedCount=count,gramError=state.inertialGramError,prefixGramError=errors,gridSupportedCount=sum(cumprod(errors<=state.gramTolerance)),convergence=[],convergedCount=NaN,usableCount=NaN);
if ~isempty(reference)
    inertial.convergence=compare(bases.bases{bases.basisIndex(1)},reference.bases{reference.basisIndex(1)},0);
    [inertial.convergedCount,complete]=acceptedPrefix(inertial.convergence,count,tolerance);
    if complete, inertial.usableCount=min(inertial.convergedCount,inertial.gridSupportedCount); end
end
assessment=struct(pages=table(kappa,requestedCount,convergedCount,gridSupportedCount,usableCount,status,candidateLimitReached),modeConvergence={modeConvergence},prefixGramError={prefixGramError},inertial=inertial,modeConvergenceTolerance=tolerance,gramTolerance=state.gramTolerance,nEVP=state.nEVP,referenceNEVP=referenceNEVP,coverage="Actual constructed modes at every supported kappa; linear convergence and fixed-grid Gram evidence only. Quadratic products are assessed separately. Two-resolution agreement is not a rigorous error bound.");

    function report=compare(basis,check,kh)
        nQuadrature=2*max(state.nEVP,referenceNEVP)+1;
        rule=IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(basis.evp);
        [z,w]=rule.nativeQuadratureRule(basis.zDomain);
        candidate=prepare(basis,z,kh,state.nEVP,nQuadrature);
        refined=prepare(check,z,kh,referenceNEVP,nQuadrature);
        report=assessModeConvergence(candidate,refined,z,w);
    end
end

function prepared=prepare(basis,z,kappa,nEVP,nQuadrature)
factors=basis.normalizationFactors(basis.normalization);
dG=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,1)./factors;
dF=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,2)./factors.*basis.h(:).';
identity=struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber),normalization=string(basis.normalization),zDomain=basis.zDomain,kappa=kappa);
prepared=struct(identity=identity,values=struct(F=basis.F(z),G=basis.G(z)),derivatives=struct(F=dF,G=dG),equivalentDepths=basis.h,provenance=struct(solverClass="IMSolverSpectral",coordinateKind="wkb",nEVP=nEVP,quadratureCount=nQuadrature,source="explicit construction basis"));
end

function [count,complete]=acceptedPrefix(report,n,tolerance)
passed=false(n,1); complete=true;
for j=1:n
    rows=report.measurements.columnLabel==report.identity.columnLabels(j) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
    if any(report.measurements.status(rows)~="measured")
        complete=false;
    else
        passed(j)=all(report.measurements.value(rows)<=tolerance);
    end
end
count=sum(cumprod(passed));
end
