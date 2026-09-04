function page = weakThermalMDA(buoyancy,buoyancyZ,weights,kappaT)
% Assemble heat-conserving weak MDA diffusion on every original MDA column.
% The first orthogonal direction represents the heat functional. Its
% derivative is zero by construction, not by clipping an eigenvalue.
% - Topic: Developer utilities
field=sqrt(weights).*buoyancy;
columnScale=vecnorm(field);
[~,R]=qr(field./columnScale,0);
fromVariance=diag(1./columnScale)/R;
heat=(buoyancy*fromVariance)'*weights;
rotation=[heat/norm(heat),null(heat')];
fromVariance=fromVariance*rotation;
toVariance=rotation'*(R.*columnScale);
derivative=buoyancyZ*fromVariance;
derivative(:,1)=0;
weakMatrix=derivative'*(kappaT*weights.*derivative);
generator=-(weakMatrix+weakMatrix')/2;
[V,values]=eig(generator(2:end,2:end),'vector');
V=blkdiag(1,V); values=[0;values];
page=struct(generator=fromVariance*generator*toVariance,energy=field'*field, ...
    fromModes=fromVariance*V,toModes=V'*toVariance,rates=values, ...
    energyGenerator=generator,fromEnergy=fromVariance,toEnergy=toVariance, ...
    heat=buoyancy'*weights);
page.diagnostics=struct(eigenResidual=norm(generator*V-V.*values.','fro')/max(norm(generator,'fro')*norm(V,'fro'),realmin), ...
    eigenvectorCondition=1,coordinateCondition=cond(R), ...
    heatResidual=norm(page.heat'*page.generator)/max(norm(page.heat)*norm(page.generator,2),realmin), ...
    maximumGrowthRate=max(values),growthUncertainty=1e3*eps*norm(generator,2));
end
