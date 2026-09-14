function result = compareThermalReadinessFields(a,b,count,criteria)
% Compare thermal states on common physical-depth quadrature and Fourier keys.
% Full differences include all resolved horizontal content, with common-band
% error and each lost tail reported separately. Near-zero relative errors are
% undefined; absolute errors and their units remain available.
% - Topic: Developer utilities
% - Parameter a: candidate thermal state
% - Parameter b: reference thermal state
% - Parameter count: independent physical-depth Gauss count
% - Parameter criteria: declared observable allowances, used only for reporting
% - Returns result: physical norms, tails and dimensional reporting allowances
arguments (Input)
    a (1,1) WVTransformFreeSurfaceThermalQG
    b (1,1) WVTransformFreeSurfaceThermalQG
    count (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(count,65)}
    criteria (1,1) struct = thermalReadinessCriteria()
end
arguments (Output)
    result table
end
if ~isequal(a.domainSize,b.domainSize) || a.N20~=b.N20 || a.inverseScale~=b.inverseScale || a.f~=b.f || a.g~=b.g
    error('WV:ReadinessComparisonPhysics','Field comparisons require common physical geometry and stratification.');
end
[x,weights]=legpts(count); z=(x-1)*a.Lz/2; weights=weights(:)/2;
upperDepth=min(200,a.Lz); upperZ=(x-1)*upperDepth/2;
A=commonFields(a,z,upperZ); B=commonFields(b,z,upperZ);
keys=union(A.keys,B.keys,'rows'); [hasA,ia]=ismember(keys,A.keys,'rows'); [hasB,ib]=ismember(keys,B.keys,'rows');
common=hasA & hasB; factor=2*ones(1,size(keys,1)); factor(all(keys==0,2))=1;
kh2=(2*pi*keys(:,1)'/a.Lx).^2+(2*pi*keys(:,2)'/a.Ly).^2;
observables=criteria.observable; relative=criteria.relativeAllowance; floors=criteria.absoluteFloor;
errorValue=zeros(9,1); commonError=errorValue; referenceNorm=errorValue; referenceTail=errorValue; candidateTail=errorValue;
for j=1:numel(observables)
    field=observables(j); fa=A.(field); fb=B.(field);
    av=complex(zeros(size(fa,1),size(keys,1))); bv=av; av(:,hasA)=fa(:,ia(hasA)); bv(:,hasB)=fb(:,ib(hasB));
    metric=factor;
    if ismember(field,["qgpv","buoyancy","velocity","upperBuoyancyGradient"]), metric=weights.*factor; end
    if ismember(field,["velocity","surfaceBuoyancyGradient"]), metric=metric.*kh2; end
    if field=="energyNorm"
        metric=[a.Lz*weights.*factor.*kh2;a.Lz*weights.*a.N2Function(z).*factor;a.g*factor];
    end
    normOf=@(v,mask)sqrt(sum(metric(:,mask).*abs(v(:,mask)).^2,'all'));
    errorValue(j)=normOf(av-bv,true(size(common))); commonError(j)=normOf(av-bv,common);
    referenceNorm(j)=normOf(bv,true(size(common))); referenceTail(j)=normOf(bv,~common); candidateTail(j)=normOf(av,~common);
end
if any(~isfinite([errorValue;commonError;referenceNorm;referenceTail;candidateTail]))
    error('WV:ReadinessFiniteComparison','An independent physical field norm is nonfinite.');
end
units=criteria.units.';
relativeError=NaN(9,1); resolved=referenceNorm>floors.'; relativeError(resolved)=errorValue(resolved)./referenceNorm(resolved);
result=table(observables.',units,errorValue,relativeError,commonError,referenceNorm,referenceTail,candidateTail,relative.',floors.',VariableNames={'observable','units','error','relativeError','commonError','referenceNorm','referenceTail','candidateTail','relativeAllowance','absoluteFloor'});
end
function fields=commonFields(w,z,upperZ)
C=complex(zeros(w.thermalModeCount,numel(w.klNonzero)));
for page=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==page; C(:,columns)=w.thermalToPolynomial(:,:,page)*w.Ath(:,columns);
end
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
e=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
u=WVInternal.thermalPolynomialFields(upperZ,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
P=WVInternal.thermalVerticalInterpolation(w.z,z,w.Lz,w.inverseScale); U=WVInternal.thermalVerticalInterpolation(w.z,upperZ,w.Lz,w.inverseScale);
meanEta=P*w.mdaG*w.Amda; meanQ=-w.f*P*w.mdaGZ*w.Amda; endpoints=w.mdaG([end 1],:)*w.Amda;
meanUpper=-w.N2Function(upperZ).*(2*w.inverseScale*U*w.mdaG+U*w.mdaGZ)*w.Amda;
kh2=hypot(w.k(w.klNonzero),w.l(w.klNonzero)).'.^2;
fields=struct(keys=[[w.kMode_wv(w.klNonzero),w.lMode_wv(w.klNonzero)];0 0],qgpv=[r.qgpv*C-kh2.*(r.psi*C),meanQ],buoyancy=[r.buoyancy*C,-w.N2Function(z).*meanEta],velocity=[r.psi*C,zeros(numel(z),1)],ssh=[e.ssh*C,0],surfaceAnomaly=[e.eta_i(1,:)*C,endpoints(1)],bottomAnomaly=[e.eta_i(2,:)*C,endpoints(2)],upperBuoyancyGradient=[u.buoyancyZ*C,meanUpper],surfaceBuoyancyGradient=[e.buoyancy(1,:)*C,-w.N20*endpoints(1)]);
fields.energyNorm=[fields.velocity;[r.eta*C,meanEta];fields.ssh];
end
