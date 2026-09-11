function validateForcingInventory(self,forcing)
% Validate the complete effective forcing inventory before its atomic commit.
% Construction-time quadratic qualification belongs to the stored inventory;
% registration neither changes retained counts nor reconstructs modes.
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    forcing WVForcing
end
hasAdvection = any(arrayfun(@(force)isa(force,'WVNonlinearAdvection'),forcing));
for force = forcing
    if ~isa(force,'WVNonlinearAdvection') && ~isa(force,'WVPrescribedBoussinesqSource')
        error('WVTransformFreeSurfaceBoussinesq:UnsupportedForcing','Free-surface Boussinesq evolution supports WVNonlinearAdvection and WVPrescribedBoussinesqSource only; %s is not qualified.',class(force));
    end
    if isa(force,'WVPrescribedBoussinesqSource') && force.sourceCoordinates=="physical" && ~hasAdvection
        error('WVTransformFreeSurfaceBoussinesq:PhysicalSourceRequiresAdvection','Physical-coordinate sources require registered WVNonlinearAdvection. Add both together, or use a reference-coordinate source for linear evolution.');
    end
end
if hasAdvection && (~self.shouldAntialias || ~self.shouldCheckQuadraticAliasing)
    error('WVTransformFreeSurfaceBoussinesq:NonlinearInventoryUnqualified','Nonlinear advection requires shouldAntialias=true and an inventory constructed with shouldCheckQuadraticAliasing=true. Reconstruct a qualified transform explicitly; registration does not change retained modes.');
end
end
