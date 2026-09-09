function rows = qgBoundaryGridAssessment(data)
% Check each fixed endpoint and its coupled physical/signed energy forms.
arguments (Input)
    data (1,1) struct
end
solver=IMSolverSpectral(nEVP=numel(data.z),coordinateKind="wkb").configuredForEVP(data.apv.basis.evp);
[z,~,Dz]=solver.nativeDifferentiationRule([-data.config.Lz 0]);
if norm(z-data.z,Inf)>1e-10*data.config.Lz, error('WVStudy:GridMismatch','The prepared physical grid must match the native WKB differentiation rule.'); end
c=data.config; N2=data.profile.N2(z); records=cell(nnz(data.inventory.magnitudes>0),1); j=0;
g0=-integral(data.profile.N2,-c.Lz,0); gd=abs(g0);
for p=find(data.inventory.magnitudes>0).'
    B=data.boundary{p}; k=data.inventory.magnitudes(p);
    derivativeF=columnError(Dz*B.S.F,B.S.dF,data.w);
    derivativeG=columnError(Dz*B.S.G,B.S.dG,data.w);
    expected=[1 0;0 1]; actual=[B.S.G(end,:)-B.S.F(end,:);B.S.G(1,:)];
    endpointError=max(abs(actual-expected),[],1);
    zeroAPV=columnError(Dz*B.S.G,-(c.g*k^2/c.f^2)*B.S.F,data.w);
    [Ks,Hs,Ms]=forms(B.S,data.w,N2,k,c,g0,gd);
    [Kr,Hr,Mr]=forms(B.Q,data.wQ,data.profile.N2(data.zQ),k,c,g0,gd);
    R=chol(Mr); energyError=norm(R'\(Ks-Kr)/R,2); signedError=norm(R'\(Hs-Hr)/R,2);
    majorantError=norm(R'\(Ms-Mr)/R,2);
    gate=max([derivativeF;derivativeG;endpointError;zeroAPV;repmat(max([energyError signedError majorantError]),1,2)],[],1);
    j=j+1;
    records{j}=table(repmat(p,2,1),repmat(k,2,1),["surface";"bottom"],derivativeF.',derivativeG.',zeroAPV.',endpointError.',repmat(energyError,2,1),repmat(signedError,2,1),gate.',VariableNames={'page','kappa','endpoint','derivativeFError','derivativeGError','zeroAPVError','endpointIdentityError','physicalEnergyError','generalizedEnergyError','gridError'});
end
rows=vertcat(records{:});
end
function value=columnError(A,B,w)
numerator=sqrt(sum(w.*abs(A-B).^2,1)); denominator=sqrt(sum(w.*abs(B).^2,1));
value=numerator./denominator; value(numerator==0 & denominator==0)=0;
end
function [K,H,M]=forms(V,w,N2,k,c,g0,gd)
F=V.F; G=V.G; b=[G(end,:)-F(end,:);G(1,:)];
K=k^2*(F'*(w.*F))+(c.f/c.g)^2*(G'*(w.*N2.*G))+(c.f^2/c.g)*(F(end,:)'*F(end,:));
H=K+(c.f/c.g)^2*(b'*([g0;gd].*b));
M=K+(c.f/c.g)^2*(b'*([abs(g0);abs(gd)].*b));
end
