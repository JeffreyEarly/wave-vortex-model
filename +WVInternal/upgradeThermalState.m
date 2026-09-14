function s=upgradeThermalState(s)
% Migrate schema-1 arrays to an explicitly linear-only schema-2 inventory.
% - Topic: Developer utilities
if isfield(s,'schemaVersion') && isequal(s.schemaVersion,1)
    s.schemaVersion=2;
    s.shouldCheckQuadraticAliasing=false; s.nonlinearQuadratureCount=0;
    s.nonlinearQuadratureTolerance=1e-8;
    s.nonlinearQuadratureResidual=0; s.nonlinearReferenceResidual=0;
end
end
