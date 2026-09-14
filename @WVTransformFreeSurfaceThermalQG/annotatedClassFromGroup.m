function w=annotatedClassFromGroup(group)
% Restore flat canonical thermal arrays through the annotated group interface.
% - Topic: Create and restore a transform
% - Parameter group: NetCDF group with the complete scientific state
% - Returns w: restored transform without a scientific eigenproblem
arguments
    group NetCDFGroup
end
version=CAAnnotatedClass.propertyValuesFromGroup(group,{'schemaVersion'});
schema=WVInternal.thermalStateSchema();
names=schema(:,1).';
if version.schemaVersion==1
    names=names(~ismember(names,{'shouldCheckQuadraticAliasing','nonlinearQuadratureCount','nonlinearQuadratureTolerance','nonlinearQuadratureResidual','nonlinearReferenceResidual'}));
end
CAAnnotatedClass.throwErrorIfMissingProperties(group,[names,{'Ath','Amda','t'}]);
s=CAAnnotatedClass.propertyValuesFromGroup(group,names);
coefficients=CAAnnotatedClass.propertyValuesFromGroup(group,{'Ath','Amda'});
time=CAAnnotatedClass.propertyValuesFromGroup(group,{'t'});
w=WVTransformFreeSurfaceThermalQG(scientificState=s,coefficientState=coefficients,t=time.t);
end
