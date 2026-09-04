function operators = densityDiffusionModes(operators)
% Add complete diffusion eigencoordinates only when exact evolution needs them.
%
% The input generators remain unchanged. Eigenvalue residuals, conditioning,
% and possible growth are reported without clipping computed rates.
% - Topic: Developer utilities
for p = 1:length(operators.pages)
    page = operators.pages{p};
    generator = page.energyGenerator;
    [V,values,W] = eig(generator,'vector');
    [growth,index] = max(real(values));
    rateCondition = norm(V(:,index))*norm(W(:,index))/abs(W(:,index)'*V(:,index));
    rateResidual = norm(generator*V(:,index)-values(index)*V(:,index))/norm(V(:,index));
    projection = (W'*V)\W';
    page.fromModes = page.fromEnergy*V;
    page.toModes = projection*page.toEnergy;
    page.rates = values;
    page.diagnostics.eigenResidual = norm(generator*V-V.*values.','fro')/max(norm(generator,'fro')*norm(V,'fro'),realmin);
    page.diagnostics.eigenvectorCondition = cond(V);
    page.diagnostics.coordinateCondition = cond(page.coordinateMatrix);
    page.diagnostics.biorthogonalityError = norm(projection*V-eye(size(V)),2);
    page.diagnostics.maximumGrowthRate = growth;
    page.diagnostics.growthUncertainty = rateCondition*max(rateResidual,eps*norm(generator,2));
    page.diagnostics.growthTolerance = 1e3*eps*norm(generator,2);
    operators.pages{p} = page;
end
page = operators.mda;
generator = page.energyGenerator;
[V,values] = eig(generator(2:end,2:end),'vector');
V = blkdiag(1,V);
values = [0;values];
page.fromModes = page.fromEnergy*V;
page.toModes = V'*page.toEnergy;
page.rates = values;
page.diagnostics.eigenResidual = norm(generator*V-V.*values.','fro')/max(norm(generator,'fro')*norm(V,'fro'),realmin);
page.diagnostics.eigenvectorCondition = 1;
page.diagnostics.coordinateCondition = cond(page.coordinateMatrix);
page.diagnostics.maximumGrowthRate = max(values);
page.diagnostics.growthUncertainty = 1e3*eps*norm(generator,2);
operators.mda = page;
end
