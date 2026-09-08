function [tendency,speed] = coefficientTendency(self)
% Accumulate registered volume sources and project their resolved tendencies.
%
% Linear modal phases are handled by reconstruction. This RHS integrates
% source-driven reference-time amplitudes through the ordinary WVModel path.
% No nonlinear advection is installed by this experimental transform.
%
% - Topic: Project physical sources
% - Declaration: [tendency,speed] = coefficientTendency()
% - Returns tendency: structure following coefficientStateAnnotations
% - Returns speed: maximum reconstructed horizontal speed, when requested
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    tendency (1,1) struct
    speed (1,1) double
end
zero = zeros(self.Nx,self.Ny,self.Nz);
u=zero; v=zero; w=zero; eta=zero;
for forcing = self.spatialFluxForcing
    [u,v,w,eta] = forcing.addNonhydrostaticSpatialForcing(self,u,v,w,eta);
end
tendency = self.projectSources(struct(u=u,v=v,w=w,eta=eta));
if nargout>1
    fields = self.reconstructFields(["u","v"]);
    speed = max(hypot(fields.u,fields.v),[],'all');
end
end
