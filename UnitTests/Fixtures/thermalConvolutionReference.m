function tendency=thermalConvolutionReference(w,modes,count)
% Direct signed Fourier convolution of analytic monomial pressure fields.
% Neither the runtime FFT product kernel nor its quadrature map is used.
[x,weights]=legpts(count); z=w.Lz*(x-1)/2; weights=weights(:)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
fields=cell(size(modes)); endpoints=fields;
for i=1:numel(modes)
    fields{i}=physical(w,modes(i),z);
    endpoints{i}=physical(w,modes(i),[0;-w.Lz]);
end
moments=complex(zeros(size(w.Ath))); boundary=complex(zeros(2,size(w.Ath,2)));
for i=1:numel(modes)
    for j=1:numel(modes)
        k=modes(i).k+modes(j).k; l=modes(i).l+modes(j).l;
        column=find(abs(w.k(w.klNonzero)-k)<1e-14 & abs(w.l(w.klNonzero)-l)<1e-14);
        if isempty(column), continue; end
        cross=modes(i).k*modes(j).l-modes(i).l*modes(j).k;
        moments(:,column)=moments(:,column)+cross*(r.psi'*(weights.*fields{i}.psi.*fields{j}.q));
        boundary(:,column)=boundary(:,column)+cross*endpoints{i}.psi.*endpoints{j}.b;
    end
end
Ath=complex(zeros(size(w.Ath)));
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p;
    Ath(:,columns)=-w.sourceDual(:,:,p)*moments(:,columns)+w.sourceEndpoint(:,:,p)*boundary(:,columns);
end
tendency=struct(Ath=Ath,Amda=zeros(size(w.Amda)));
end
function field=physical(w,mode,z)
a=w.inverseScale; D=w.Lz;
if a==0
    s=1+2*z/D; J=2/D*ones(size(z));
else
    s=1+2*expm1(a*z)/(-expm1(-a*D)); J=2*a*exp(a*z)/(-expm1(-a*D));
end
p=mode.p; N2=w.N20*exp(2*a*z); psi=polyval(p,s);
first=polyval(polyder(p),s); second=polyval(polyder(polyder(p)),s);
eta=-w.f./N2.*J.*first;
q=-(mode.k^2+mode.l^2)*psi+w.f^2./N2.*(J.^2.*second-a*J.*first);
b=eta-(1+z/D)*(w.f/w.g)*polyval(p,1);
field=struct(psi=psi,q=q,b=b);
end
