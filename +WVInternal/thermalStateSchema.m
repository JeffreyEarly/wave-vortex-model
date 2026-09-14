function schema = thermalStateSchema()
% Named flat-array persistence contract for the optional thermal peer.
% - Topic: Developer utilities
schema = {
    'domainAxis', {}, '1', 'Domain coordinate indices', true, false;
    'domainSize', {'domainAxis'}, 'm', 'Domain lengths', false, false;
    'gridSize', {'domainAxis'}, '1', 'Physical grid counts', false, false;
    'z', {}, 'm', 'Increasing WKB Lobatto depth', true, false;
    'latitude', {}, 'degrees', 'Latitude', false, false;
    'g', {}, 'm s-2', 'Gravity', false, false;
    'rho0', {}, 'kg m-3', 'Reference density', false, false;
    'N20', {}, 's-2', 'Surface squared buoyancy frequency', false, false;
    'inverseScale', {}, 'm-1', 'Half logarithmic stratification gradient', false, false;
    'kappa_z', {}, 'm2 s-1', 'Immutable buoyancy diffusivity', false, false;
    'shouldAntialias', {}, '1', 'Horizontal antialiasing policy', false, false;
    'schemaVersion', {}, '1', 'Thermal scientific state schema', false, false;
    'shouldCheckQuadraticAliasing', {}, '1', 'Qualified nonlinear quadrature policy', false, false;
    'nonlinearQuadratureCount', {}, '1', 'Physical-depth nonlinear quadrature count', false, false;
    'nonlinearQuadratureTolerance', {}, '1', 'Nonlinear moment Gram tolerance', false, false;
    'nonlinearQuadratureResidual', {}, '1', 'Nonlinear quadrature residual', false, false;
    'nonlinearReferenceResidual', {}, '1', 'Nonlinear reference quadrature residual', false, false;
    'thermalDirection', {}, '1', 'Ordinal complete thermal directions', true, false;
    'polynomialDegree', {}, '1', 'Complete Legendre polynomial degrees', true, false;
    'mdaMode', {}, '1', 'Independent MDA directions', true, false;
    'activeEndpoint', {}, '1', 'Surface then bottom endpoint codes', true, false;
    'klNonzero', {}, '1', 'Compact nonzero Fourier indices', true, false;
    'khUnique', {}, 'm-1', 'Distinct horizontal radii', true, false;
    'klNonzeroKhUniqueIndex', {'klNonzero'}, '1', 'Radius page for each column', false, false;
    'verticalQuadratureWeights', {'z'}, 'm', 'Physical-depth sampling weights', false, false;
    'thermalToPolynomial', {'polynomialDegree','thermalDirection','khUnique'}, 'm', 'Streamfunction polynomial map for unit velocity amplitudes', false, true;
    'polynomialToThermal', {'thermalDirection','polynomialDegree','khUnique'}, 'm-1', 'Inverse polynomial map', false, true;
    'sourceDual', {'thermalDirection','polynomialDegree','khUnique'}, '1', 'Weak source dual in polynomial trial coordinates', false, true;
    'sourceEndpoint', {'thermalDirection','activeEndpoint','khUnique'}, 's-1', 'Strict displacement-source projection', false, true;
    'thermalRatesPerDiffusivity', {'thermalDirection','khUnique'}, 'm-2', 'Unit-diffusivity eigenvalues, including null directions', false, true;
    'conjugateDirection', {'thermalDirection','khUnique'}, '1', 'Conjugate eigenvector permutation', false, false;
    'thermalEnergyGram', {'thermalDirection','thermalDirection','khUnique'}, '1', 'Positive physical energy metric including cross terms', false, true;
    'assemblyQuadratureCount', {}, '1', 'Physical-depth assembly quadrature count', false, false;
    'gramTolerance', {}, '1', 'MDA sampling Gram allowance', false, false;
    'modeConvergenceTolerance', {}, '1', 'MDA mode convergence allowance', false, false;
    'boundaryResolutionTolerance', {}, '1', 'Boundary sampling allowance', false, false;
    'mdaSurfaceWeight', {}, 'm s-2', 'MDA basis surface weight', false, false;
    'mdaBottomWeight', {}, 'm s-2', 'MDA basis bottom weight', false, false;
    'mdaG', {'z','mdaMode'}, '1', 'MDA displacement reconstruction', false, false;
    'mdaGForward', {'mdaMode','z'}, '1', 'MDA displacement projector', false, false;
    'mdaGZ', {'z','mdaMode'}, 'm-1', 'MDA displacement derivative', false, false;
    'mdaGeneratorPerDiffusivity', {'mdaMode','mdaMode'}, 'm-2', 'Conservative mean diffusivity operator', false, false;
    'mdaEnergyGram', {'mdaMode','mdaMode'}, 's-2', 'Mean physical energy metric', false, false;
};
end
