function page = weakThermalPage(phi,eta,etaZ,buoyancyZ,phiSurface,weights,N2,kh,f,g,kappaT)
% Assemble weak thermal diffusion without changing the balanced state space.
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
weakMatrix=-etaZEnergy'*(kappaT*weights.*buoyancyZEnergy);
generator=-(energyMetric\weakMatrix);
[V,values,W]=eig(generator,'vector');
[growth,index]=max(real(values));
rateCondition=norm(V(:,index))*norm(W(:,index))/abs(W(:,index)'*V(:,index));
rateResidual=norm(generator*V(:,index)-values(index)*V(:,index))/norm(V(:,index));
% Normalize the left projection against the actual right eigenvectors.
projection=(W'*V)\W';
page=struct(generator=fromEnergy*generator*toEnergy,energy=field'*field, ...
    weakMatrix=-etaZ'*(kappaT*weights.*buoyancyZ),fromModes=fromEnergy*V, ...
    toModes=projection*toEnergy,rates=values,energyGenerator=generator, ...
    fromEnergy=fromEnergy,toEnergy=toEnergy);
page.diagnostics=struct(eigenResidual=norm(generator*V-V.*values.','fro')/max(norm(generator,'fro')*norm(V,'fro'),realmin), ...
    eigenvectorCondition=cond(V),coordinateCondition=cond(R), ...
    biorthogonalityError=norm(projection*V-eye(size(V)),2), ...
    maximumGrowthRate=growth,growthUncertainty=rateCondition*max(rateResidual,eps*norm(generator,2)), ...
    growthTolerance=1e3*eps*norm(generator,2), ...
    energyWeakResidual=norm(energyMetric*generator+weakMatrix,'fro')/max(norm(weakMatrix,'fro'),realmin), ...
    weakResidual=norm(page.energy*page.generator+page.weakMatrix,'fro')/max(norm(page.energy,'fro')*norm(page.generator,'fro')+norm(page.weakMatrix,'fro'),realmin));
end
