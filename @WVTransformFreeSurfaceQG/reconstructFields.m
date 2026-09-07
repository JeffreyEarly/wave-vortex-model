function fields = reconstructFields(self,variableNames,options)
% Reconstruct selected physical QG fields from one resolved spectral state.
%
% Displacement and QGPV include their MDA horizontal means. Surface height
% is in the zero-mean gauge. Selecting a component never mutates the state.
%
% - Topic: Evaluate physical fields
% - Declaration: fields = reconstructFields(variableNames,options)
% - Parameter variableNames: row of names from namesOfTransformVariables
% - Parameter options.flowComponent: one component of this transform; empty selects the full state
% - Returns fields: scalar structure of physical arrays keyed by requested name
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    variableNames (1,:) string {mustBeNonempty}
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    fields (1,1) struct
end
if any(~ismember(variableNames,string(self.namesOfTransformVariables())))
    error('WVTransform:UnknownVariable','Request QG fields listed by namesOfTransformVariables.')
end
[psiHat,etaHat,qHat] = self.reconstructSpectralState(flowComponent=options.flowComponent);
fields = struct();
if any(ismember(variableNames,["u" "ssu" "uvMax"]))
    u = self.transformToSpatialDomainWithFourier(-1i*reshape(self.l,1,[]).*psiHat);
end
if any(ismember(variableNames,["v" "ssv" "uvMax"]))
    v = self.transformToSpatialDomainWithFourier(1i*reshape(self.k,1,[]).*psiHat);
end
if any(ismember(variableNames,["psi" "ssh"]))
    psi = self.transformToSpatialDomainWithFourier(psiHat);
end
for name = variableNames
    switch name
        case "psi", value = psi;
        case "u", value = u;
        case "v", value = v;
        case "eta", value = self.transformToSpatialDomainWithFourier(etaHat);
        case "qgpv", value = self.transformToSpatialDomainWithFourier(qHat);
        case "ssh", value = (self.f/self.g)*psi(:,:,end);
        case "ssu", value = u(:,:,end);
        case "ssv", value = v(:,:,end);
        case "uvMax", value = max(hypot(u,v),[],"all");
    end
    fields.(name) = value;
end
end
