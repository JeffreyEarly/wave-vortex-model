function inventory = portableVariableAnnotations()
% Enumerate built-in annotations without evaluating diagnostic fields.
% The small transforms exercise registration and metadata, including both
% antialias settings. No numerical results from these fixtures are exported.
families = ["constant-hydrostatic","constant-nonhydrostatic","barotropic", ...
    "stratified-qg","hydrostatic","boussinesq"];
inventory = struct(configuration={},family={},transformClass={},annotation={},authority={},component={});
for family = families
    for antialias = [false true]
        switch family
            case "barotropic"
                wvt = WVTransformBarotropicQG([17000 11000],[8 6],j=1,shouldAntialias=antialias);
            case "stratified-qg"
                wvt = WVTransformStratifiedQG([17000 11000 1000],[8 6 9],Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
            case "hydrostatic"
                wvt = WVTransformHydrostatic([17000 11000 1000],[8 6 9],Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
            case "boussinesq"
                wvt = WVTransformBoussinesq([17000 11000 1000],[8 6 9],Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
            otherwise
                wvt = WVTransformConstantStratification([17000 11000 1000],[8 6 9],N0=5.2e-3,isHydrostatic=family=="constant-hydrostatic",shouldAntialias=antialias);
        end
        configuration = family + "-aa" + double(antialias);
        names = sort(reshape(string(wvt.annotatedPropertyNames),1,[]));
        for name = names
            a = wvt.propertyAnnotationWithName(name);
            if isa(a,"WVVariableAnnotation")
                append(a,"registered",componentForName(name));
            end
        end
        % Factories expose stable variables that are not registered by default.
        op = wvt.operationForKnownVariable('energy');
        append(op.outputVariables,"known-variable-factory","");
        for componentName = sort(reshape(string(wvt.flowComponentNames),1,[]))
            component = wvt.flowComponentWithName(componentName);
            op = wvt.operationForKnownVariable('energy',flowComponent=component);
            if string(op.outputVariables.name) ~= "energy"
                append(op.outputVariables,"known-variable-factory",componentName);
            end
        end
        % Bind a reserved exemplar name through the real forcing operation.
        % Templates retain its exact annotation; arbitrary instance names must
        % be bound and collision-checked at construction, never in hot loops.
        wvt.addForcing(WVFixedAmplitudeForcing(wvt,name="portable_catalog_forcing"));
        wvt.addForcing(WVFixedAmplitudeForcing(wvt,name="portable_catalog_second"));
        op = SpatialForcingOperation(wvt);
        for a = op.outputVariables
            if endsWith(string(a.name),"_portable_catalog_forcing")
                append(a,"forcing-instance-template","");
            end
        end
    end
end

    function append(annotation,authority,component)
        inventory(end+1) = struct(configuration=configuration,family=family,transformClass=string(class(wvt)), ...
            annotation=annotation,authority=authority,component=component);
    end
end

function component = componentForName(name)
component = "";
for pair = ["_g","_w","_io","_mda";"geostrophic","wave","inertial","mda"]
    if endsWith(name,pair(1)), component=pair(2); return; end
end
end
