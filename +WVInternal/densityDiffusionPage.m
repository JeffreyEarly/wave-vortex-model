function page = densityDiffusionPage(phi,eta,etaZ,buoyancyZ,phiSurface,weights,N2,kh,f,g,kappa_z)
% Assemble density diffusion without changing the balanced state space.
% Columns are original APV followed by boundary-normalized zero-APV modes.
% QR changes coordinates in the positive physical-energy metric; it does
% not replace the signed normalization of the public coefficients.
% - Topic: Developer utilities
field=[sqrt(weights)*kh.*phi; sqrt(weights.*N2).*eta; (f/sqrt(g))*phiSurface];
columnScale=vecnorm(field);
[~,R]=qr(field./columnScale,0);
fromEnergy=diag(1./columnScale)/R;
toEnergy=R.*columnScale;
etaZEnergy=(etaZ./columnScale)/R;
buoyancyZEnergy=(buoyancyZ./columnScale)/R;
energyField=(field./columnScale)/R;
energyMetric=energyField'*energyField;
weakMatrix=-etaZEnergy'*(kappa_z*weights.*buoyancyZEnergy);
generator=-(energyMetric\weakMatrix);
page=struct(generator=fromEnergy*generator*toEnergy,energy=field'*field, ...
    weakMatrix=-etaZ'*(kappa_z*weights.*buoyancyZ),energyGenerator=generator, ...
    fromEnergy=fromEnergy,toEnergy=toEnergy,coordinateMatrix=R);
page.diagnostics=struct(energyWeakResidual=norm(energyMetric*generator+weakMatrix,'fro')/max(norm(weakMatrix,'fro'),realmin), ...
    weakResidual=norm(page.energy*page.generator+page.weakMatrix,'fro')/max(norm(page.energy,'fro')*norm(page.generator,'fro')+norm(page.weakMatrix,'fro'),realmin));
end
