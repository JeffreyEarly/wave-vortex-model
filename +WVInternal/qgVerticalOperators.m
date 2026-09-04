function operators = qgVerticalOperators(z,quadratureCount)
% Build quadrature and interpolation on the stored WKB vertical grid.
% The input nodes are the bottom-to-surface WKB Chebyshev-Lobatto grid.
% Interpolation uses every stored node; no coefficient family is reduced.
% - Topic: Developer utilities
arguments (Input)
    z (:,1) double {mustBeFinite}
    quadratureCount (1,1) double {mustBeInteger,mustBePositive}
end
arguments (Output)
    operators (1,1) struct
end
nz=length(z);
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
operators=struct(zQuadrature=fine*zCoefficients,quadratureWeights=weights,phiToQuadrature=fine/native);
end
