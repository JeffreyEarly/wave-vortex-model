function coefficients=thermalConstrainedFit(A,values,B,constraints,weights)
% Fit physical samples in a positive metric with exact boundary/inventory loads.
% Row scaling avoids mixing units in the constraint rank decision. The null
% space contains only unconstrained directions; no penalty or regularization
% relaxes the loads. Native state fitting and resolution transfer share this
% worker, but supply their own authoritative physical maps and quadrature.
% - Topic: Developer utilities
rowScale=max(vecnorm(B,2,2),realmin); B=B./rowScale; constraints=constraints./rowScale;
baseline=pinv(B)*constraints; Z=null(B);
if norm(B*baseline-constraints,'fro')>1e-11*max(1,norm(constraints,'fro'))
    error('WV:ThermalConstraintFit','The target space cannot retain the requested endpoint and inventory constraints. Increase its retained dimension.');
end
coefficients=baseline+Z*((sqrt(weights).*(A*Z))\(sqrt(weights).*(values-A*baseline)));
end
