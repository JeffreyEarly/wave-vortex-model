function validateForcingInventory(self,forcing)
% Require horizontal antialiasing for nonlinear QG advection.
hasAdvection=any(arrayfun(@(force)isa(force,'WVNonlinearAdvection'),forcing));
if hasAdvection && ~self.shouldAntialias
    error('WVTransformFreeSurfaceQG:NonlinearInventoryUnqualified', ...
        'Nonlinear advection requires shouldAntialias=true. Vertical quadraticDealiasing is an independent retained-mode policy and may be none.')
end
end
