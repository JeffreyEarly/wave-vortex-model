function state = scientificState(self)
% Copy the complete immutable scientific representation for direct construction.
%
% The structure contains flat geometry, profile, quadrature, and resolved
% modal arrays. It excludes coefficients, time, registered operations, and
% state-dependent caches. It is an in-memory construction contract; annotated
% file continuation is qualified in the subsequent architecture increment.
%
% - Topic: Create a transform
% - Declaration: state = scientificState()
% - Returns state: scalar structure accepted by the primary constructor
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    state (1,1) struct
end
state = struct();
for name = string(self.scientificPropertyNames()), state.(name) = self.(name); end
for name = string(self.geometryStateNames())
    switch name
        case "Lxyz", state.Lxyz = [self.Lx self.Ly self.Lz];
        case "Nxyz", state.Nxyz = [self.Nx self.Ny self.Nz];
        otherwise, state.(name) = self.(name);
    end
end
end
