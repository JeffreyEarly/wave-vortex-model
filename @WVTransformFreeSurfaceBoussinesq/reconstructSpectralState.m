function fields = reconstructSpectralState(self,options)
% Reconstruct current-time physical fields on the compact Fourier grid.
%
% Each nonzero column represents the half-complex amplitude plus its
% conjugate. The horizontal mean is already real, including both signs of
% each inertial oscillation. Pressure includes the MDA hydrostatic gauge.
%
% - Topic: Reconstruct and project fields
% - Declaration: fields = reconstructSpectralState(options)
% - Parameter options.flowComponent: component of this transform; empty selects all
% - Parameter options.state: complete reference-time family structure; default current state
% - Returns fields: u,v,w,eta,p,ssh,qgpv arrays of shape Nz by Nkl; ssh is vertically repeated
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
    options.state (1,1) struct = struct()
end
arguments (Output)
    fields (1,1) struct
end
state = options.state;
if isempty(fieldnames(state))
    state = self.coefficientState(flowComponent=options.flowComponent);
elseif ~isempty(options.flowComponent)
    error('WVTransformFreeSurfaceBoussinesq:AmbiguousState','Supply either explicit state or a component selector.')
else
    for annotation = self.coefficientStateAnnotations()
        if ~isfield(state,annotation.name), error('WVTransformFreeSurfaceBoussinesq:InvalidCoefficient','Supply every canonical coefficient family.'); end
        self.validateCoefficient(state.(annotation.name),string(annotation.name));
    end
end
fields = WVInternal.freeSurfaceSelectedSpectralFields(self,state,["u","v","w","eta","p","qgpv"],1:self.Nz);
fields.ssh = repmat(fields.p(end,:)/(self.rho0*self.g),self.Nz,1);
end
