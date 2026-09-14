function maps=thermalNonlinearMaps(w,count)
% Build immutable product-grid maps without constructing scientific modes.
% - Topic: Developer utilities
[x,weights]=legpts(count); z=w.Lz*(x-1)/2; weights=weights(:)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
e=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
geometry=WVGeometryDoublyPeriodic([w.Lx w.Ly],[w.Nx w.Ny],Nz=count,shouldAntialias=true,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
endpointGeometry=WVGeometryDoublyPeriodic([w.Lx w.Ly],[w.Nx w.Ny],Nz=2,shouldAntialias=true,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
maps=struct(psi=r.psi,qZero=r.qgpv,endpointPsi=e.psi,endpointAnomaly=e.eta_i,pairing=r.psi'.*weights.',geometry=geometry,endpointGeometry=endpointGeometry,count=count);
end
