function du = denseWKBDerivative(u,D,n)
% Match the production diffZ layout and repeated matrix applications.
arguments
    u double
    D (:,:) double
    n (1,1) double {mustBeMember(n,1:4)} = 1
end
Z = size(u,3);
v = reshape(permute(u,[3 1 2]),Z,[]);
for order = 1:n, v=D*v; end
du = permute(reshape(v,Z,size(u,1),size(u,2)),[2 3 1]);
end
