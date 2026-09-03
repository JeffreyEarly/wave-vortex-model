function operators = qgVerticalOperators(z,quadratureCount)
% Build WKB-polynomial over-integration and physical-norm QGPV coordinates.
% The input nodes are the bottom-to-surface WKB Chebyshev-Lobatto grid.
% QGPV uses only its independent interior nodes (degree Nz-3); phi uses
% all nodes (degree Nz-1). No endpoint QGPV or thermal eigenvectors enter.
% - Topic: Developer utilities
arguments (Input)
    z (:,1) double {mustBeFinite}
    quadratureCount (1,1) double {mustBeInteger,mustBePositive}
end
arguments (Output)
    operators (1,1) struct
end
nz=length(z); nq=nz-2;
if nz<5 || any(diff(z)<=0) || quadratureCount<nz
    error('WV:VerticalGrid','Use increasing Chebyshev-mapped z and at least Nz quadrature points.');
end
s=-cos(pi*(0:nz-1)'/(nz-1));
offDiagonal=(1:quadratureCount-1)'./sqrt(4*(1:quadratureCount-1)'.^2-1);
[vectors,values]=eig(diag(offDiagonal,1)+diag(offDiagonal,-1),'vector');
[sFine,order]=sort(values); weights=2*vectors(1,order)'.^2;
native=cos(acos(s)*(0:nz-1)); fine=cos(acos(sFine)*(0:nz-1));
zCoefficients=native\z;
derivative=sin(acos(sFine)*(0:nz-1)).*(0:nz-1)./sqrt(1-sFine.^2);
jacobian=derivative*zCoefficients;
if any(jacobian<=0)
    error('WV:VerticalMapping','The interpolated WKB coordinate must have positive dz/ds.');
end
weights=weights.*jacobian;
qNative=native(2:end-1,1:nq); qFine=fine(:,1:nq);
% Weighted QR keeps the physical-depth metric without normal equations.
[orthogonal,triangular]=qr(sqrt(weights).*qFine,0);
qFromPolynomial=qNative/triangular;
qToPolynomial=triangular/qNative;
operators=struct(nativeZ=z,zQuadrature=fine*zCoefficients,quadratureWeights=weights,qToQuadrature=qFine/qNative,phiToQuadrature=fine/native,qFromQuadrature=qFromPolynomial*(orthogonal'.*sqrt(weights).'),qFromPolynomial=qFromPolynomial,qToPolynomial=qToPolynomial);
end
