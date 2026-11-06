function [FProjection,GProjection] = freeSurfaceBoundarySourceProjections(F,G,weights,N2,D,g,g0,gd)
% Evaluate the boundary-buoyancy source functionals in endpoint coordinates.
% The caller applies the signed generalized-energy normalization by page.
FProjection = F'.*(weights.'/D);
GProjection = G'.*(weights.*N2/g).';
if isfinite(g0)
    GProjection(:,end) = GProjection(:,end)+(g0/g)*(G(end,:)-F(end,:))';
end
if isfinite(gd)
    GProjection(:,1) = GProjection(:,1)+(gd/g)*G(1,:)';
end
end
