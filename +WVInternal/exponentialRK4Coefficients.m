function c = exponentialRK4Coefficients(lambda,h,columnIndices)
% Forward Cox-Matthews ETDRK4 weights, including null modes.
% lambda has one column per distinct kh (s^-1); h is in seconds. Optional
% columnIndices expands the completed weights to coefficient columns. With
% two inputs, preserve the supplied rate-array shape as before.
z=h*lambda;
[p1,p2,p3]=phiFunctions(z);
half=phiFunctions(z/2);
c=struct(E=exp(z),E2=exp(z/2),Q=(h/2)*half,f1=h*(p1-3*p2+4*p3),f2=h*(p2-2*p3),f3=h*(-p2+4*p3));
if nargin>2
    for name=string(fieldnames(c)).'
        c.(name)=c.(name)(:,columnIndices);
    end
end
end

function [p1,p2,p3] = phiFunctions(z)
p1=zeros(size(z)); p2=p1; p3=p1;
small=abs(z)<1;
smallZ=z(small); largeZ=z(~small);
for j=1:nargout
    term=ones(size(smallZ))/factorial(j); value=term;
    for k=1:24, term=term.*smallZ/(k+j); value=value+term; end
    switch j
        case 1, p1(small)=value;
        case 2, p2(small)=value;
        case 3, p3(small)=value;
    end
end
p1(~small)=expm1(largeZ)./largeZ;
if nargout>1, p2(~small)=(p1(~small)-1)./largeZ; end
if nargout>2, p3(~small)=(p2(~small)-0.5)./largeZ; end
end
