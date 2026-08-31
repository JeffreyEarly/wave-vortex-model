function names = coefficientStateVariableNamesForPersistence(self)
% Return physically present canonical coefficient variable names.
%
% - Topic: Persistence internals
% - Declaration: names = coefficientStateVariableNamesForPersistence(self)
% - Returns names: coefficient names that have a physical NetCDF variable
arguments
    self (1,1) WVTransform
end

annotations = self.coefficientStateAnnotations();
isCanonicalState = arrayfun(@(annotation)annotation.persistenceRole == "canonicalState",annotations);
isPresent = arrayfun(@(annotation)annotation.isPhysicallyPresent(self),annotations);
names = {annotations(isCanonicalState & isPresent).name};
end
