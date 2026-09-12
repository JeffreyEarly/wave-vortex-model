function value=advectionTransport(field,u,v,w,c,derivative,form)
% Approximate u.grad(field), with prescribed continuum divergence c.
% adjointXi = W^(-1)*(B-Dxi'*W); B has oriented endpoint entries -1,+1.
if form=="advective"
    value=u.*derivative.x(field)+v.*derivative.y(field)+w.*derivative.xi(field);
    return
end
conservative=derivative.x(u.*field)+derivative.y(v.*field)+derivative.xi(w.*field);
if form=="divergence"
    value=conservative-c.*field;
else
    if form=="compatible", dz=derivative.adjointXi(field); else, dz=derivative.xi(field); end
    advective=u.*derivative.x(field)+v.*derivative.y(field)+w.*dz;
    value=.5*(conservative+advective-c.*field);
end
end
