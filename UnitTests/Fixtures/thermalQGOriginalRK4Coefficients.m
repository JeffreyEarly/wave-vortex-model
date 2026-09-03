function c=thermalQGOriginalRK4Coefficients(lambda,h)
% Frozen pre-optimization formulas, evaluated on every coefficient column.
z=h*lambda;
[p1,p2,p3]=phiFunctions(z);
[half,~,~]=phiFunctions(z/2);
c=struct(E=exp(z),E2=exp(z/2),Q=(h/2)*half,f1=h*(p1-3*p2+4*p3),f2=h*(p2-2*p3),f3=h*(-p2+4*p3));
end

function [p1,p2,p3]=phiFunctions(z)
p1=zeros(size(z)); p2=p1; p3=p1;
small=abs(z)<1;
for j=1:3
    term=ones(nnz(small),1)/factorial(j); value=term;
    for k=1:24, term=term.*z(small)/(k+j); value=value+term; end
    switch j
        case 1, p1(small)=value;
        case 2, p2(small)=value;
        case 3, p3(small)=value;
    end
end
p1(~small)=expm1(z(~small))./z(~small);
p2(~small)=(p1(~small)-1)./z(~small);
p3(~small)=(p2(~small)-0.5)./z(~small);
end
