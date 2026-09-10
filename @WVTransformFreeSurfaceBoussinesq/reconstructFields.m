function fields = reconstructFields(self,variableNames,options)
% Reconstruct selected fields on the reference samples and moving mesh.
%
% u/v/w are physical velocities; u_hat/v_hat/w_hat are the modal variables.
% The existing z axis remains the fixed reference coordinate, while
% z_physical is the moving mesh. eta is total displacement and
% eta_i=eta-(1+z/Lz)*ssh. p is reconstructed modal pressure,
% including hydrostatic MDA. It supplies the quadratic-order pressure
% approximation in the manuscript nonlinear terms.
%
% Component velocities use the total state's geometry, so disjoint component
% contributions add to the full velocity. z_physical has no
% component partition. Mean SSH retains the existing zero-mean gauge.
%
% - Topic: Reconstruct and project fields
% - Declaration: fields = reconstructFields(variableNames,options)
% - Parameter variableNames: row of supported field names
% - Parameter options.flowComponent: component of this transform; empty selects all
% - Returns fields: named Nx by Ny by Nz arrays; surface fields are Nx by Ny
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    variableNames (1,:) string {mustBeNonempty}
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    fields (1,1) struct
end
if any(~ismember(variableNames,string(self.namesOfTransformVariables())))
    error('WVTransform:UnknownVariable','Request fields listed by namesOfTransformVariables.')
end
if ~isempty(options.flowComponent) && any(ismember(variableNames,"z_physical"))
    error('WVTransform:TotalStateVariable','z_physical describes the total state and has no component partition.')
end
spectral = self.reconstructSpectralState(flowComponent=options.flowComponent);
sampled = struct();
for name = ["u","v","w","eta","ssh"]
    sampled.(name) = self.transformToSpatialDomainWithFourier(spectral.(name));
end
sampled.ssh = sampled.ssh(:,:,end);
if any(ismember(variableNames,["u","v","w","ssu","ssv","w_i","z_physical"]))
    mapped = sampled;
    if ~isempty(options.flowComponent)
        total = self.reconstructSpectralState();
        totalSSH = self.transformToSpatialDomainWithFourier(total.ssh);
        mapped.ssh = totalSSH(:,:,end);
    end
    physical = WVInternal.freeSurfacePhysicalFields(mapped,self.z,self.Lz,self.diffX(mapped.ssh),self.diffY(mapped.ssh));
end
fields = struct();
for name = variableNames
    switch name
        case {"u","v","w","w_i"}, value = physical.(name);
        case "z_physical", value = physical.z;
        case {"u_hat","v_hat","w_hat"}, value = sampled.(extractBefore(name,"_hat"));
        case "eta", value = sampled.eta;
        case "eta_i", value = sampled.eta-reshape(1+self.z/self.Lz,1,1,[]).*sampled.ssh;
        case "ssu", value = physical.u(:,:,end);
        case "ssv", value = physical.v(:,:,end);
        case "ssh", value = sampled.ssh;
        case "p", value = self.transformToSpatialDomainWithFourier(spectral.p);
        otherwise, value = self.transformToSpatialDomainWithFourier(spectral.(name));
    end
    fields.(name) = value;
end
end
