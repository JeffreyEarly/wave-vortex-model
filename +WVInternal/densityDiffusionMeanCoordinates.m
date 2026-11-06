function [field,fromVariance,toVariance,R,buoyancyIntegral] = densityDiffusionMeanCoordinates(buoyancy,weights)
% Factor the buoyancy-variance metric and put the column inventory first.
field = sqrt(weights).*buoyancy;
columnScale = vecnorm(field);
[~,R] = qr(field./columnScale,0);
fromVariance = diag(1./columnScale)/R;
inventory = (buoyancy*fromVariance)'*weights;
inventoryNorm = norm(inventory);
if ~(isfinite(inventoryNorm) && inventoryNorm>0)
    error('WV:MissingMeanBuoyancyInventory','The retained MDA modes must represent a finite nonzero column buoyancy inventory.');
end
rotation = [inventory/inventoryNorm,null(inventory')];
fromVariance = fromVariance*rotation;
toVariance = rotation'*(R.*columnScale);
buoyancyIntegral = buoyancy'*weights;
end
