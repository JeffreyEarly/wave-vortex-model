function annotations = classDefinedPropertyAnnotations()
% Describe the flat scientific representation and independent coefficient streams.
% - Topic: Save transform state
% - Declaration: annotations = classDefinedPropertyAnnotations()
% - Returns annotations: geometry, transform, scientific and coefficient metadata
annotations = WVGeometryDoublyPeriodicStratified.propertyAnnotationsForGeometry();
annotations = cat(2,annotations,WVTransform.propertyAnnotationsForTransform());
for name = ["waveMode","inertialMode","apvMode","mdaMode","activeEndpoint","klNonzero","khUnique"]
    annotations(end+1) = CADimensionProperty(char(name),'1',char(name));
end
annotations = cat(2,annotations,WVTransformFreeSurfaceBoussinesq.coefficientAnnotations());
% The same balanced scientific arrays have the same persistence vocabulary.
shared = WVTransformFreeSurfaceQG.classDefinedPropertyAnnotations();
wanted = setdiff([WVTransformFreeSurfaceBoussinesq.scientificPropertyNames(),{'activeEndpointCount'}],{annotations.name});
for annotation = shared
    if any(strcmp(annotation.name,wanted)) && ~strcmp(annotation.name,'zeroAPVSourceSolve')
        annotations(end+1) = annotation;
    end
end
annotations(end+1) = CANumericProperty('zeroAPVSourceSolve',{'activeEndpoint','activeEndpoint','khUnique'},'1','boundary-normalized signed source solve');
annotations(end+1) = CANumericProperty('waveModeCountByKh',{'khUnique'},'1','retained wave prefix on each exact positive wavenumber page');
names = {'waveModeNumber','inertialModeNumber','mdaPressureMode','waveF','waveG','waveGForward','waveEquivalentDepth','waveFrequency','inertialF','inertialFForward','inertialEquivalentDepth','waveGramError','inertialGramError','balancedNEVP','nEVP','projectionTolerance'};
dims = {{'waveMode'},{'inertialMode'},{'z','mdaMode'},{'z','waveMode','khUnique'},{'z','waveMode','khUnique'},{'waveMode','z','khUnique'},{'waveMode','khUnique'},{'waveMode','khUnique'},{'z','inertialMode'},{'inertialMode','z'},{'inertialMode'},{'khUnique'},{},{},{},{}};
units = {'1','1','m s-2','1','1','1','m','rad s-1','1','1','m','1','1','1','1','1'};
for j = 1:length(names)
    annotations(end+1) = CANumericProperty(names{j},dims{j},units{j},names{j});
end
end
