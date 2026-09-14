function w=annotatedClassFromGroup(group)
% Restore authoritative scientific arrays and an optional local snapshot.
% Coefficients in an observer stream are selected by the concrete file reader.
% - Topic: Create and restore a transform
% - Parameter group: NetCDF group with the complete scientific state
% - Returns w: restored transform without a scientific eigenproblem
arguments (Input)
    group (1,1) NetCDFGroup
end
arguments (Output)
    w (1,1) WVTransformFreeSurfaceThermalQG
end
version=CAAnnotatedClass.propertyValuesFromGroup(group,{'schemaVersion'});
schema=WVInternal.thermalStateSchema(); names=schema(:,1).';
if version.schemaVersion==1
    names=names(~ismember(names,{'shouldCheckQuadraticAliasing','nonlinearQuadratureCount','nonlinearQuadratureTolerance','nonlinearQuadratureResidual','nonlinearReferenceResidual'}));
end
CAAnnotatedClass.throwErrorIfMissingProperties(group,names);
s=CAAnnotatedClass.propertyValuesFromGroup(group,names);
w=WVTransformFreeSurfaceThermalQG(scientificState=s);
% hasVariableWithName searches descendants: only adopt a local scalar snapshot.
localNames=string([{group.realVariables.name},{group.complexVariables.name}]);
if all(ismember(["Ath","Amda","t"],localNames)) && ~group.hasDimensionWithName('t')
    values=CAAnnotatedClass.propertyValuesFromGroup(group,{'Ath','Amda','t'});
    w.Ath=values.Ath; w.Amda=values.Amda; w.t=values.t;
end
if ismember("t0",localNames), w.t0=group.readVariables('t0'); end
end
