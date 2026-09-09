function [report,reference] = assessFreeSurfaceBoundaryGrid(zero,problem,vertical,inputs,options)
% Qualify fixed endpoint responses without using a scalar-family Gram test.
z=vertical.z; w=vertical.weights; Dz=vertical.Dz;
reference=IMSolverSpectral(nEVP=vertical.referenceNEVP).solveGeostrophicZeroAPVModes(problem);
rule=IMSolverSpectral(nEVP=2*vertical.referenceNEVP+1,coordinateKind="wkb").configuredForEVP(vertical.apvProblem);
[zq,wq]=rule.nativeQuadratureRule(inputs.zDomain);
F=zero.F(z); G=zero.G(z); Fr=reference.F(z); Gr=reference.G(z);
Fq=zero.F(zq); Gq=zero.G(zq); N2=inputs.N2Function(z); N2q=inputs.N2Function(zq);
f=inputs.f0; g=options.g; kappa=problem.k(:);
records=cell(numel(kappa),1);
for p=1:numel(kappa)
    kh=kappa(p); A=F(:,:,p); B=G(:,:,p);
    dF=-N2.*B/g; dG=-(g*kh^2/f^2)*A;
    derivativeFError=columnError(Dz*A,dF,w);
    derivativeGError=columnError(Dz*B,dG,w);
    referenceError=max(columnError(A,Fr(:,:,p),w),columnError(B,Gr(:,:,p),w));
    endpointNames=string(zero.endpoints(:)); expected=eye(2); active=ismember(["surface","bottom"],endpointNames);
    expected=expected(:,active); actual=[B(end,:)-A(end,:);B(1,:)];
    endpointIdentityError=max(abs(actual-expected),[],1).';
    [Ks,Hs,Ms]=forms(A,B,w,N2,kh);
    [Kq,Hq,Mq]=forms(Fq(:,:,p),Gq(:,:,p),wq,N2q,kh);
    R=chol(Mq);
    physicalEnergyError=norm(R'\(Ks-Kq)/R,2);
    generalizedEnergyError=norm(R'\(Hs-Hq)/R,2);
    majorantError=norm(R'\(Ms-Mq)/R,2);
    gridError=max([derivativeFError,derivativeGError,endpointIdentityError,repmat(max([physicalEnergyError,generalizedEnergyError,majorantError]),numel(endpointNames),1)],[],2);
    records{p}=table(repmat(kh,numel(endpointNames),1),endpointNames,derivativeFError,derivativeGError,endpointIdentityError,repmat(physicalEnergyError,numel(endpointNames),1),repmat(generalizedEnergyError,numel(endpointNames),1),referenceError,gridError,VariableNames=["kappa","endpoint","derivativeFError","derivativeGError","endpointIdentityError","physicalEnergyError","generalizedEnergyError","modeConvergenceError","gridError"]);
end
rows=vertcat(records{:});
report=struct(status="accepted",nEVP=vertical.nEVP,referenceNEVP=vertical.referenceNEVP,coordinateKind=string(vertical.solver.coordinateKind),pages=rows,tolerance=options.boundaryResolutionTolerance,modeConvergenceTolerance=options.modeConvergenceTolerance,coverage="Every configured endpoint at every retained positive kappa; physical differentiation, endpoint identity, coupled physical and signed energy. No endpoint is removed to pass.");
if any(rows.modeConvergenceError>options.modeConvergenceTolerance)
    report.status="reference-inconclusive";
    if isfield(options,"boundaryReportOnly") && options.boundaryReportOnly, return; end
    error('WV:UnconvergedBoundaryModes','Independent zero-APV solves disagree by %.3g; increase the balanced EVP resolution before assessing the physical grid.',max(rows.modeConvergenceError))
end
[worst,index]=max(rows.gridError);
if worst>options.boundaryResolutionTolerance
    report.status="rejected";
    if isfield(options,"boundaryReportOnly") && options.boundaryReportOnly, return; end
    error('WV:UnderresolvedBoundaryGrid','The %s zero-APV response at kappa %.6g has physical grid error %.3g > boundaryResolutionTolerance %.3g. Increase Nz or reduce the horizontal bandwidth. Reducing wave/APV counts cannot remove this fixed boundary requirement.',rows.endpoint(index),rows.kappa(index),worst,options.boundaryResolutionTolerance)
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
value=(numerator./denominator).'; value(numerator==0 & denominator==0)=0;
end
