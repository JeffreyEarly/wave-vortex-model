function report=assessThermalQuadrature(n,D,N20,a,f,g,count,tolerance)
% Compare mapped polynomial moment Grams using two independently finer rules.
% Products P_i P_j P_k and P_i P'_j P_k/J use the dz and dz/J measures.
% This is quadrature evidence; assembled-state interaction tests remain separate.
% - Topic: Developer utilities
order=ceil(3*(n-1)/2)+1;
counts=[count 2*count+1 4*count+3]; grams=cell(3,2);
for i=1:3
    [x,w]=legpts(counts(i)); z=D*(x-1)/2; w=w(:)*D/2;
    r=WVInternal.thermalPolynomialFields(z,order,D,N20,a,0,f,g);
    if a==0, J=2/D*ones(size(z)); else, J=2*a*exp(a*z)/(-expm1(-a*D)); end
    grams{i,1}=r.psi'*(w.*r.psi);
    grams{i,2}=r.psi'*((w./J).*r.psi);
end
errors=zeros(1,2); reference=zeros(1,2);
for measure=1:2
    R=chol(grams{3,measure});
    errors(measure)=norm(R'\(grams{1,measure}-grams{2,measure})/R,2);
    reference(measure)=norm(R'\(grams{2,measure}-grams{3,measure})/R,2);
end
report=struct(counts=counts,testPolynomialCount=order,measureNames=["dz","dz/J"],residuals=errors,referenceResiduals=reference,tolerance=tolerance);
if max(errors)>tolerance || max(reference)>.2*tolerance
    error('WV:ThermalNonlinearQuadrature','Product quadrature residual %.3g or reference %.3g failed %.3g; increase nonlinearQuadratureCount.',max(errors),max(reference),tolerance);
end
end
