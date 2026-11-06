function grid = restoreFreeSurfaceVerticalGrid(state)
% Restore the provider map and check that it belongs to the saved operators.
grid = IMVerticalGrid.fromSnapshot(jsondecode(state.verticalGridSnapshot));
if ~any(grid.kind == ["wkb","smoothedBandwidth"]) || isempty(grid.calculus) || ~isequal(grid.z,state.z(:)) || ...
        ~isequal(grid.weights,state.verticalQuadratureWeights(:))
    error('WV:InconsistentVerticalGrid','The saved vertical calculus and quadrature must match the saved grid.');
end
Dz = grid.calculus.firstDerivativeMatrix();
stored = state.verticalDerivativeMatrix;
if ~isequal(size(Dz),size(stored)) || ~isreal(stored) || any(~isfinite(stored),"all") || ...
        any(abs(Dz-stored) > 128*eps(max(1,abs(Dz))),"all")
    error('WV:InconsistentVerticalGrid','The saved vertical derivative must match the provider calculus.');
end
end
