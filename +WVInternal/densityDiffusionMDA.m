function page = densityDiffusionMDA(buoyancy,buoyancyZ,weights,kappa_z)
% Assemble conservative MDA density diffusion on every original MDA column.
% The first orthogonal direction represents the column-integrated buoyancy functional. Its
% derivative is zero by construction, not by clipping an eigenvalue.
% - Topic: Developer utilities
field=sqrt(weights).*buoyancy;
columnScale=vecnorm(field);
[~,R]=qr(field./columnScale,0);
fromVariance=diag(1./columnScale)/R;
buoyancyIntegral=(buoyancy*fromVariance)'*weights;
rotation=[buoyancyIntegral/norm(buoyancyIntegral),null(buoyancyIntegral')];
fromVariance=fromVariance*rotation;
toVariance=rotation'*(R.*columnScale);
derivative=buoyancyZ*fromVariance;
derivative(:,1)=0;
weakMatrix=derivative'*(kappa_z*weights.*derivative);
generator=-(weakMatrix+weakMatrix')/2;
page=struct(generator=fromVariance*generator*toVariance,energy=field'*field, ...
    energyGenerator=generator,fromEnergy=fromVariance,toEnergy=toVariance, ...
    coordinateMatrix=R,buoyancyIntegral=buoyancy'*weights);
page.diagnostics=struct(integralResidual=norm(page.buoyancyIntegral'*page.generator)/max(norm(page.buoyancyIntegral)*norm(page.generator,'fro'),realmin));
end
