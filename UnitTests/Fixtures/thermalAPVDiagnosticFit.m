function [state,expected,relativeFitError,physicalFit] = thermalAPVDiagnosticFit(w,apv,kind)
% Fit known physical APV/boundary pressure, recording thermal source-fit error.
% This is fixture setup only. The diagnostic projection is independently
% checked after representing the known field in the finite thermal space.
nc=numel(w.klNonzero); expected=struct(Ag_q=complex(zeros(apv.apvModeCount,nc)),Ag_0=complex(zeros(2,nc)));
column=find(w.k(w.klNonzero)>0 & w.l(w.klNonzero)==0,1); p=apv.klNonzeroKhUniqueIndex(column);
if any(kind==["apv","mixed"]),expected.Ag_q(2,column)=1e-7*(1+.3i);end
if any(kind==["surface","mixed"]),expected.Ag_0(1,column)=3e-8*(1-.2i);end
if any(kind==["bottom","mixed"]),expected.Ag_0(2,column)=-2e-8*(1+.1i);end
phi=-apv.apvF*(expected.Ag_q(:,column)./apv.apvMu(:,p))-apv.zeroAPVF(:,:,p)*expected.Ag_0(:,column)/apv.khNonzero(column)^2;
functionPressure=chebfun(phi);
[x,weights]=legpts(max(257,2*w.thermalModeCount+1));
legendre=legpoly(0:w.thermalModeCount-1); values=feval(legendre,x);
c=((2*(0:w.thermalModeCount-1)'+1)/2).*(values'*(weights(:).*feval(functionPressure,x)));
state=w.coefficientState();state.Ath=0*state.Ath;state.Amda=0*state.Amda;
state.Ath(:,column)=w.polynomialToThermal(:,:,w.klNonzeroKhUniqueIndex(column))*c;
actual=chebfun(leg2cheb(w.thermalToPolynomial(:,:,w.klNonzeroKhUniqueIndex(column))*state.Ath(:,column)),'coeffs');
relativeFitError=norm(actual-functionPressure)/norm(functionPressure);
[x,weights]=legpts(1025); z=w.Lz*(x-1)/2; weights=weights(:)*w.Lz/2;
if w.inverseScale==0
    s=1+2*z/w.Lz; sz=2/w.Lz*ones(size(z));
else
    denominator=-expm1(-w.inverseScale*w.Lz); s=1+2*expm1(w.inverseScale*z)/denominator; sz=2*w.inverseScale*exp(w.inverseScale*z)/denominator;
end
N2=w.N20*exp(2*w.inverseScale*z); derivative=sz.*feval(diff(actual),s);
second=sz.^2.*feval(diff(actual,2),s)+w.inverseScale*derivative;
q=-apv.khNonzero(column)^2*feval(actual,s)+w.f^2./N2.*(second-2*w.inverseScale*derivative);
knownQ=feval(chebfun(apv.apvF),s)*expected.Ag_q(:,column);
qAbsolute=sqrt(sum(weights.*abs(q-knownQ).^2)/w.Lz); qScale=sqrt(sum(weights.*abs(knownQ).^2)/w.Lz);
if qScale==0,qRelative=NaN;else,qRelative=qAbsolute/qScale;end
trace=apv.apvEndpointResponse(:,:,p)*expected.Ag_q(:,column)-(w.f/w.g)*expected.Ag_0(:,column)/apv.khNonzero(column)^2;
if w.inverseScale==0,szEnd=2/w.Lz*ones(2,1);else,szEnd=2*w.inverseScale*exp(w.inverseScale*[0;-w.Lz])/(-expm1(-w.inverseScale*w.Lz));end
actualTrace=-w.f./(w.N20*exp(2*w.inverseScale*[0;-w.Lz])).*szEnd.*feval(diff(actual),[1;-1])-[1;0]*(w.f/w.g)*feval(actual,1);
physicalFit=struct(qgpvAbsolute=qAbsolute,qgpvRelative=qRelative,endpointAbsolute=abs(actualTrace-trace));
end
