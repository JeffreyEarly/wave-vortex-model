function operation = operationForKnownVariable(self,variableName,options)
% Create one operation sharing reconstruction across requested Boussinesq fields.
%
% Component output names use the ordinary abbreviated-name suffix.
% All outputs participate in the existing annotation-based field cache.
%
% - Topic: Evaluate physical fields
% - Declaration: operation = operationForKnownVariable(variableName,options)
% - Parameter variableName: requested Boussinesq field names, supplied as separate arguments
% - Parameter options.flowComponent: one component of this transform; empty selects the full state
% - Returns operation: operation with outputs in requested order
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Input,Repeating)
    variableName char
end
arguments (Input)
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    operation (1,1) WVOperation
end
names = string(variableName);
if isempty(names) || length(unique(names)) ~= length(names) || any(~ismember(names,string(self.namesOfTransformVariables())))
    error('WVTransform:UnknownVariable','Request distinct Boussinesq fields listed by namesOfTransformVariables.')
end
component = options.flowComponent;
if ~isempty(component) && any(ismember(names,["z_physical","p_full"]))
    error('WVTransform:TotalStateVariable','z_physical and p_full describe the total state and have no component partition.')
end
suffix = "";
if ~isempty(component)
    if ~isscalar(component) || component.wvt ~= self
        error('WVTransform:InvalidComponent','Select one component belonging to this transform.')
    end
    suffix = "_"+string(component.abbreviatedName);
end
isTimeDependent = true;
if ~isempty(component)
    masks = component.coefficientMasks;
    isTimeDependent = any(masks.Aw_p,'all') || any(masks.Aw_m,'all') || any(masks.Aio,'all');
end
annotations = WVVariableAnnotation.empty(1,0);
for name = names
    dimensions = {'x','y','z'};
    switch name
        case "psi", units = 'm2 s-1'; description = 'geostrophic streamfunction';
        case "eta", units = 'm'; description = 'total material displacement including the MDA mean';
        case "eta_i", units = 'm'; description = 'parcel-label displacement relative to the fixed reference column';
        case "z_physical", units = 'm'; description = 'physical height of the moving mesh';
        case "p_linear", units = 'Pa'; description = 'linear modal pressure anomaly including hydrostatic MDA';
        case "p_full", units = 'Pa'; description = 'full collocation pressure anomaly relative to the C1 hydrostatic reference';
        case {"u_hat","v_hat","w_hat"}, units = 'm s-1'; description = 'hatted modal velocity on the fixed reference column';
        case "w_i", units = 'm s-1'; description = 'material reference-coordinate velocity';
        case "qgpv", units = 's-1'; description = 'full QGPV including the MDA mean';
        case "ssh", units = 'm'; description = 'sea-surface height in the zero-mean gauge'; dimensions = {'x','y'};
        case {"ssu","ssv"}, units = 'm s-1'; description = 'surface horizontal velocity'; dimensions = {'x','y'};
        case "uvMax", units = 'm s-1'; description = 'maximum horizontal speed'; dimensions = {};
        otherwise, units = 'm s-1'; description = 'physical velocity on the moving mesh';
    end
    annotation = WVVariableAnnotation(char(name+suffix),dimensions,units,description);
    annotation.isVariableWithLinearTimeStep = isTimeDependent || ismember(name,["u","v","w","ssu","ssv","w_i","z_physical","p_full"]);
    annotation.isVariableWithNonlinearTimeStep = true;
    annotation.isDependentOnApAmA0 = true;
    annotations(end+1) = annotation;
end
operationName = "boussinesqFields"+suffix;
if isscalar(names), operationName = names+suffix; end
operation = WVOperation(char(operationName),annotations,@compute);

    function varargout = compute(wvt)
        fields = wvt.reconstructFields(names,flowComponent=component);
        varargout = cell(1,length(names));
        for iName = 1:length(names), varargout{iName} = fields.(names(iName)); end
    end
end
