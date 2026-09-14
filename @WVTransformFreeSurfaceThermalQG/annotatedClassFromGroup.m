function w=annotatedClassFromGroup(group)
% Restore flat canonical thermal arrays through the annotated group interface.
% - Topic: Create and restore a transform
% - Parameter group: NetCDF group with the complete scientific state
% - Returns w: restored transform without a scientific eigenproblem
arguments
    group NetCDFGroup
end
CAAnnotatedClass.throwErrorIfMissingProperties(group,WVTransformFreeSurfaceThermalQG.classRequiredPropertyNames());
schema=WVInternal.thermalStateSchema();
s=CAAnnotatedClass.propertyValuesFromGroup(group,schema(:,1).');
coefficients=CAAnnotatedClass.propertyValuesFromGroup(group,{'Ath','Amda'});
time=CAAnnotatedClass.propertyValuesFromGroup(group,{'t'});
w=WVTransformFreeSurfaceThermalQG(scientificState=s,coefficientState=coefficients,t=time.t);
end
