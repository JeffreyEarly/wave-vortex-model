function fields = reconstructFields(self,variableNames,options)
% Reconstruct selected real physical fields from one stored modal state.
%
% Eta denotes total displacement. The density-anomaly displacement is
% eta_i=eta-(1+z/Lz)*ssh. Pressure includes the horizontally averaged
% hydrostatic anomaly; mean SSH is fixed to zero.
%
% - Topic: Reconstruct and project fields
% - Declaration: fields = reconstructFields(variableNames,options)
% - Parameter variableNames: row of supported physical field names
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
spectral = self.reconstructSpectralState(flowComponent=options.flowComponent);
fields = struct();
for name = variableNames
    switch name
        case "eta_i", value = self.transformToSpatialDomainWithFourier(spectral.eta-(1+self.z/self.Lz).*spectral.ssh);
        case "ssu", volume = self.transformToSpatialDomainWithFourier(spectral.u); value = volume(:,:,end);
        case "ssv", volume = self.transformToSpatialDomainWithFourier(spectral.v); value = volume(:,:,end);
        case "ssh", volume = self.transformToSpatialDomainWithFourier(spectral.ssh); value = volume(:,:,end);
        otherwise, value = self.transformToSpatialDomainWithFourier(spectral.(name));
    end
    fields.(name) = value;
end
end
