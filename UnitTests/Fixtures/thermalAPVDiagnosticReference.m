function reference = thermalAPVDiagnosticReference(w,apv,state,count)
% Independently differentiate pressure polynomials and integrate physical modes.
% Chebfun's Legendre-to-Chebyshev conversion and differentiation supply the
% thermal reference; no decomposition builder, thermal field worker or damping
% map is used. Stored diagnostic modes are interpolated in the analytic WKB
% coordinate and a weighted QR solve projects F. This independently tests the
% runtime's stored-coordinate map as well as its projection contraction.
[x,weights]=legpts(count); z=w.Lz*(x-1)/2; weights=weights(:)*w.Lz/2;
[s,sz]=coordinate(w,z); N2=w.N20*exp(2*w.inverseScale*z);
nc=numel(w.klNonzero); C=complex(zeros(w.thermalModeCount,nc));
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p;
    C(:,columns)=w.thermalToPolynomial(:,:,p)*state.Ath(:,columns);
end
pressure=chebfun(leg2cheb(C),'coeffs');
psi=feval(pressure,s); psiZ=sz.*feval(diff(pressure),s);
psiZZ=sz.^2.*feval(diff(pressure,2),s)+w.inverseScale*psiZ;
eta=-w.f./N2.*psiZ; ssh=w.f/w.g*feval(pressure,1);
eta_i=eta-(1+z/w.Lz).*ssh;
k=w.k(w.klNonzero).'; l=w.l(w.klNonzero).'; kh2=k.^2+l.^2;
q=-kh2.*psi+w.f^2./N2.*(psiZZ-2*w.inverseScale*psiZ);
[se,sze]=coordinate(w,[0;-w.Lz]); N2e=w.N20*exp(2*w.inverseScale*[0;-w.Lz]);
endpoint=-w.f./N2e.*sze.*feval(diff(pressure),se)-[1;0].*ssh;
source=pack(psi,eta,eta_i,q,ssh,endpoint,k,l,N2);
F=feval(chebfun(apv.apvF),s); G=feval(chebfun(apv.apvG),s);
Ag_q=(sqrt(weights).*F)\(sqrt(weights).*q); Ag_0=complex(zeros(2,nc));
apvPart=emptyFields(count,nc); zeroPart=apvPart;
for column=1:nc
    p=apv.klNonzeroKhUniqueIndex(column); mu=apv.apvMu(:,p);
    a=-Ag_q(:,column)./mu;
    phi=F*a; displacement=apv.f/apv.g*G*a;
    surface=apv.f/apv.g*apv.apvF(end,:)*a;
    trace=apv.f/apv.g*apv.apvG([end 1],:)*a-[1;0]*surface;
    Ag_0(:,column)=-(w.g/w.f)*kh2(column)*(endpoint(:,column)-trace);
    value=pack(phi,displacement,displacement-(1+z/w.Lz)*surface,F*Ag_q(:,column),surface,trace,k(column),l(column),N2);
    apvPart=assignColumn(apvPart,value,column);
    ZF=feval(chebfun(apv.zeroAPVF(:,:,p)),s);
    ZG=feval(chebfun(apv.zeroAPVG(:,:,p)),s);
    a=-Ag_0(:,column)/kh2(column); phi=ZF*a;
    displacement=apv.f/apv.g*ZG*a; surface=apv.f/apv.g*apv.zeroAPVF(end,:,p)*a;
    trace=apv.f/apv.g*apv.zeroAPVG([end 1],:,p)*a-[1;0]*surface;
    value=pack(phi,displacement,displacement-(1+z/w.Lz)*surface,zeros(count,1),surface,trace,k(column),l(column),N2);
    zeroPart=assignColumn(zeroPart,value,column);
end
meanPart=emptyFields(count,1);
meanFunction=chebfun(w.mdaG*state.Amda);
meanPart.eta=feval(meanFunction,s); meanPart.eta_i=meanPart.eta;
meanPart.buoyancy=-N2.*meanPart.eta;
meanPart.qgpv=-w.f*sz.*feval(diff(meanFunction),s);
meanPart.endpointAnomalies=feval(meanFunction,[1;-1]);
residual=source;
for name=string(fieldnames(source)).'
    residual.(name)=source.(name)-apvPart.(name)-zeroPart.(name);
end
components=struct(total=source,apv=apvPart,zeroAPV=zeroPart,mean=meanPart,residual=residual);
inventories=struct(); names=["kineticEnergy","interiorPotentialEnergy","surfacePotentialEnergy","totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"];
for name=names
    a=bilinear(apvPart,apvPart,name,weights,N2,w.g);
    b=bilinear(zeroPart,zeroPart,name,weights,N2,w.g);
    r=bilinear(residual,residual,name,weights,N2,w.g);
    m=bilinear(meanPart,meanPart,name,weights,N2,w.g)/2;
    inventories.(name)=struct(total=bilinear(source,source,name,weights,N2,w.g)+m,apv=a,zeroAPV=b,residual=r,mean=m,apvZeroAPV=2*bilinear(apvPart,zeroPart,name,weights,N2,w.g),apvResidual=2*bilinear(apvPart,residual,name,weights,N2,w.g),zeroAPVResidual=2*bilinear(zeroPart,residual,name,weights,N2,w.g));
end
residuals=struct();
for name=["qgpv","buoyancy","velocity","eta","eta_i","ssh","endpointAnomalies"]
    numerator=fieldSquare(residual,name,weights,w.Lz);
    denominator=fieldSquare(source,name,weights,w.Lz)+fieldSquare(meanPart,name,weights,w.Lz)/2;
    ratio=sqrt(numerator./denominator); ratio(denominator==0)=NaN;
    residuals.(name)=struct(absolute=sqrt(numerator),relative=ratio,reference=sqrt(denominator));
end
numerator=inventories.totalEnergy.residual; denominator=inventories.totalEnergy.total;
ratio=sqrt(numerator/denominator); if denominator==0,ratio=NaN;end
residuals.energyNorm=struct(absolute=sqrt(numerator),relative=ratio,reference=sqrt(denominator));
reference=struct(coefficients=struct(Ag_q=Ag_q,Ag_0=Ag_0),components=components,inventories=inventories,residuals=residuals,z=z,weights=weights,N2=N2);
end
function [s,sz]=coordinate(w,z)
if w.inverseScale==0
    s=1+2*z/w.Lz; sz=2/w.Lz*ones(size(z));
else
    denominator=-expm1(-w.inverseScale*w.Lz);
    s=1+2*expm1(w.inverseScale*z)/denominator;
    sz=2*w.inverseScale*exp(w.inverseScale*z)/denominator;
end
end
function fields=pack(psi,eta,eta_i,q,ssh,endpoint,k,l,N2)
fields=struct(u=-1i*l.*psi,v=1i*k.*psi,eta=eta,eta_i=eta_i,qgpv=q,buoyancy=-N2.*eta_i,ssh=ssh,endpointAnomalies=endpoint);
end
function fields=emptyFields(n,nc)
v=complex(zeros(n,nc)); fields=struct(u=v,v=v,eta=v,eta_i=v,qgpv=v,buoyancy=v,ssh=complex(zeros(1,nc)),endpointAnomalies=complex(zeros(2,nc)));
end
function target=assignColumn(target,value,column)
for name=string(fieldnames(value)).',target.(name)(:,column)=value.(name);end
end
function value=bilinear(a,b,name,weights,N2,g)
switch name
    case "kineticEnergy", terms=weights.*(conj(a.u).*b.u+conj(a.v).*b.v);
    case "interiorPotentialEnergy", terms=weights.*N2.*conj(a.eta).*b.eta;
    case "surfacePotentialEnergy", terms=g*conj(a.ssh).*b.ssh;
    case "potentialEnstrophy", terms=weights.*conj(a.qgpv).*b.qgpv;
    case "surfaceAnomalyVariance", terms=conj(a.endpointAnomalies(1,:)).*b.endpointAnomalies(1,:);
    case "bottomAnomalyVariance", terms=conj(a.endpointAnomalies(2,:)).*b.endpointAnomalies(2,:);
    case "totalEnergy"
        value=bilinear(a,b,"kineticEnergy",weights,N2,g)+bilinear(a,b,"interiorPotentialEnergy",weights,N2,g)+bilinear(a,b,"surfacePotentialEnergy",weights,N2,g); return
end
value=real(sum(terms,'all'));
end
function value=fieldSquare(fields,name,weights,depth)
switch name
    case "velocity", value=2*sum(weights.*(abs(fields.u).^2+abs(fields.v).^2),'all')/depth;
    case {"ssh","endpointAnomalies"}, value=2*sum(abs(fields.(name)).^2,2);
    otherwise, value=2*sum(weights.*abs(fields.(name)).^2,'all')/depth;
end
end
