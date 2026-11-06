function page = densityDiffusionMDA(buoyancy,buoyancyZ,weights,kappa_z)
% Assemble conservative MDA density diffusion on every original MDA column.
% The first orthogonal direction represents the column-integrated buoyancy functional. Its
% derivative is zero by construction, not by clipping an eigenvalue.
% - Topic: Developer utilities
[field,fromVariance,toVariance,R,buoyancyIntegral]=WVInternal.densityDiffusionMeanCoordinates(buoyancy,weights);
derivative=buoyancyZ*fromVariance;
derivative(:,1)=0;
weakMatrix=derivative'*(kappa_z*weights.*derivative);
generator=-(weakMatrix+weakMatrix')/2;
page=struct(generator=fromVariance*generator*toVariance,energy=field'*field, ...
    energyGenerator=generator,fromEnergy=fromVariance,toEnergy=toVariance, ...
    coordinateMatrix=R,buoyancyIntegral=buoyancyIntegral);
page.diagnostics=struct(integralResidual=norm(page.buoyancyIntegral'*page.generator)/max(norm(page.buoyancyIntegral)*norm(page.generator,'fro'),realmin));
end
