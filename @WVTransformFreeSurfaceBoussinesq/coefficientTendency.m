function [tendency,speed,diagnostics] = coefficientTendency(self)
% Evaluate registered forcing in the reference-time coefficient families.
%
% With explicit WVNonlinearAdvection, solve the full mapped weak equations
% and retained kinematic constraints. Linear phases are carried by field
% reconstruction and subtracted once from the full coefficient rate.
% Without advection, preserve the linear projection of reference sources.
% Prescribed work plus constraint-reaction work is not the complete energy
% rate: spatial, solver and SSH residual work also enter the discrete budget.
% Nonlinear activation requires the stored inventory's quadratic qualification.
%
% - Topic: Project physical sources
% - Declaration: [tendency,speed,diagnostics] = coefficientTendency()
% - Returns tendency: structure following coefficientStateAnnotations
% - Returns speed: maximum physical horizontal speed, when requested
% - Returns diagnostics: nonlinear solver, label, energy and work diagnostics; empty for linear source projection
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    tendency (1,1) struct
    speed (1,1) double
    diagnostics (1,1) struct
end
hasAdvection=any(arrayfun(@(forcing)isa(forcing,'WVNonlinearAdvection'),self.spatialFluxForcing));
if hasAdvection
    context=self.nonlinearContext();
    [tendency,diagnostics,stage]=context.evaluate(self.coefficientState(),includeForcing=true);
    if nargout>1, speed=max(hypot(stage.physical.u,stage.physical.v),[],'all'); end
else
    zero = zeros(self.Nx,self.Ny,self.Nz);
    u=zero; v=zero; w=zero; eta=zero;
    for forcing = self.spatialFluxForcing
        [u,v,w,eta] = forcing.addNonhydrostaticSpatialForcing(self,u,v,w,eta);
    end
    tendency = self.projectSources(struct(u=u,v=v,w=w,eta=eta));
    diagnostics=struct();
    if nargout>1
        fields = self.reconstructFields(["u","v"]);
        speed = max(hypot(fields.u,fields.v),[],'all');
    end
end
end
