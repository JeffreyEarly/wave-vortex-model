function [report,reference] = assessFreeSurfaceBoundaryGrid(zero,problem,vertical,inputs,options)
% Qualify fixed endpoint responses without using a scalar-family Gram test.
background=inputs.background;
z=vertical.z; w=vertical.weights; Dz=vertical.Dz;
reference=IMSolverSpectral(nEVP=vertical.referenceNEVP).solveGeostrophicZeroAPVModes(problem);
rule=IMSolverSpectral(nEVP=2*vertical.referenceNEVP+1,coordinateKind="wkb").configuredForEVP(vertical.apvProblem);
[zq,wq]=rule.nativeQuadratureRule(background.zDomain);
Fq=zero.F(zq); Gq=zero.G(zq);
referenceError=max(columnError(Fq,reference.F(zq),wq),columnError(Gq,reference.G(zq),wq));
hasReference=isfinite(referenceError) & referenceError<=options.modeConvergenceTolerance;
endpointNames=string(zero.endpoints(:));
kappa=problem.k(:);
reportOnly=isfield(options,"boundaryReportOnly") && options.boundaryReportOnly;
if ~all(hasReference,"all") && ~reportOnly
    [endpoint,page]=find(~hasReference,1);
    error('WV:UnconvergedBoundaryModes', ...
        'The independent %s zero-APV reference at kappa %.6g is inconclusive (relative error %.3g). Increase Nz to raise the balanced EVP resolution, or reduce the horizontal bandwidth.', ...
        endpointNames(endpoint),kappa(page),referenceError(endpoint,page))
end
F=zero.F(z); G=zero.G(z);
N2=background.N2(z); N2q=background.N2(zq);
f=background.f0; g=background.g;
expected=eye(2);
expected=expected(:,ismember(["surface","bottom"],endpointNames));
nEndpoints=numel(endpointNames);
records=cell(numel(kappa),1);
for p=1:numel(kappa)
    kh=kappa(p);
    derivativeFError=nan(nEndpoints,1);
    derivativeGError=derivativeFError;
    endpointIdentityError=derivativeFError;
    physicalEnergyError=NaN;
    generalizedEnergyError=NaN;
    gridError=derivativeFError;
    if all(hasReference(:,p))
        A=F(:,:,p); B=G(:,:,p);
        dF=-N2.*B/g; dG=-(g*kh^2/f^2)*A;
        derivativeFError=columnError(Dz*A,dF,w);
        derivativeGError=columnError(Dz*B,dG,w);
        endpointIdentityError=max(abs([B(end,:)-A(end,:);B(1,:)]-expected),[],1).';
        [Ks,Hs,Ms]=forms(A,B,w,N2,kh);
        [Kq,Hq,Mq]=forms(Fq(:,:,p),Gq(:,:,p),wq,N2q,kh);
        R=chol(Mq);
        physicalEnergyError=norm(R'\(Ks-Kq)/R,2);
        generalizedEnergyError=norm(R'\(Hs-Hq)/R,2);
        majorantError=norm(R'\(Ms-Mq)/R,2);
        energyError=max([physicalEnergyError,generalizedEnergyError,majorantError]);
        gridError=max([derivativeFError,derivativeGError,endpointIdentityError,repmat(energyError,nEndpoints,1)],[],2);
    end
    records{p}=table(repmat(kh,nEndpoints,1),endpointNames,derivativeFError,derivativeGError,endpointIdentityError, ...
        repmat(physicalEnergyError,nEndpoints,1),repmat(generalizedEnergyError,nEndpoints,1),referenceError(:,p),gridError, ...
        VariableNames=["kappa","endpoint","derivativeFError","derivativeGError","endpointIdentityError", ...
        "physicalEnergyError","generalizedEnergyError","modeConvergenceError","gridError"]);
end
rows=vertcat(records{:});
report=struct(status="accepted",nEVP=vertical.nEVP,referenceNEVP=vertical.referenceNEVP, ...
    coordinateKind=string(vertical.solver.coordinateKind),pages=rows,tolerance=options.boundaryResolutionTolerance, ...
    modeConvergenceTolerance=options.modeConvergenceTolerance, ...
    coverage="Every configured endpoint at every retained positive kappa. Independent zero-APV convergence precedes checks of physical differentiation, endpoint identity and coupled energy.");
if ~all(hasReference,"all")
    report.status="reference-inconclusive";
    return
end
[worst,index]=max(rows.gridError);
if worst>options.boundaryResolutionTolerance
    report.status="rejected";
    if reportOnly, return; end
    error('WV:UnderresolvedBoundaryGrid', ...
        'The %s zero-APV response at kappa %.6g has physical grid error %.3g > boundaryResolutionTolerance %.3g. Increase Nz or reduce the horizontal bandwidth.', ...
        rows.endpoint(index),rows.kappa(index),worst,options.boundaryResolutionTolerance)
end
    function [K,H,M]=forms(A,B,weights,N2Values,kh)
        boundary=[B(end,:)-A(end,:);B(1,:)]; accelerations=[inputs.g0;inputs.gd]; accelerations(~isfinite(accelerations))=0;
        K=kh^2*(A'*(weights.*A))+(f/g)^2*(B'*(weights.*N2Values.*B))+(f^2/g)*(A(end,:)'*A(end,:));
        H=K+(f/g)^2*(boundary'*(accelerations.*boundary));
        M=K+(f/g)^2*(boundary'*(abs(accelerations).*boundary));
    end
end
function value=columnError(A,B,w)
numerator=sqrt(sum(w.*abs(A-B).^2,1)); denominator=sqrt(sum(w.*abs(B).^2,1));
value=reshape(numerator./denominator,size(B,2),size(B,3));
value(numerator==0 & denominator==0)=0;
end
