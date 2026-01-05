function build_website_documentation(options)
arguments
    options.rootDir = ".."
end
buildFolder = fullfile(options.rootDir,"docs");
sourceFolder = fullfile(options.rootDir,"Documentation","WebsiteDocumentation");

copyfile(sourceFolder,buildFolder);

changelogPath = fullfile(options.rootDir, "CHANGELOG.md");
if isfile(changelogPath)
    header = "---" + newline + ...
             "layout: default" + newline + ...
             "title: Version History" + newline + ...
             "nav_order: 100" + newline + ...
             "---" + newline + newline;
    versionHistoryText = header + fileread(changelogPath);
    versionHistoryFilePath = fullfile(options.rootDir,"docs","version-history.md");
    fid = fopen(versionHistoryFilePath, "w");
    assert(fid ~= -1, "Could not open CHANGELOG.md for writing");
    fwrite(fid, versionHistoryText);
    fclose(fid);
end

classFolderName = 'Class documentation';

%%
parentName = 'Transforms';
websiteFolder = 'classes/transforms';

classDoc = ClassDocumentation('WVTransform',buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,nav_order=1,excludedSuperclasses = {'CAAnnotatedClass'});
classDoc.writeToFile();

classes = {'WVTransformBoussinesq','WVTransformHydrostatic','WVTransformConstantStratification','WVTransformBarotropicQG','WVTransformStratifiedQG'}; % 'WVTransformSingleMode'
excludedSuperclasses = {'handle','WVTransform','CAAnnotatedClass'};
classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName+1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,excludedSuperclasses=excludedSuperclasses);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)

%%
websiteFolder = 'classes';
classDoc = ClassDocumentation('WVModel',buildFolder=buildFolder,websiteFolder=websiteFolder,parent=classFolderName,nav_order=2);
classDoc.writeToFile();

%%
parentName = 'Forcing';
websiteFolder = 'classes/forcing';

excludedSuperclasses = {'handle','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classDoc = ClassDocumentation('WVForcing',nav_order=1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,excludedSuperclasses=excludedSuperclasses);
classDoc.writeToFile();

excludedSuperclasses = {'handle','WVForcing','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classes = {'WVNonlinearAdvection','WVBottomFrictionLinear','WVBottomFrictionQuadratic','WVFixedAmplitudeForcing','WVBetaPlanePVAdvection'};
classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName+1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,excludedSuperclasses=excludedSuperclasses);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)

%%
websiteFolder = 'classes/forcing/closures';

excludedSuperclasses = {'handle','WVForcing','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classes = {'WVAdaptiveDamping','WVVerticalDiffusivity','WVHorizontalDamping','WVVerticalDamping','WVThermalDamping','WVAntialiasing'};
classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName+1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent='Closures',grandparent='Forcing',excludedSuperclasses=excludedSuperclasses);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)

%%
parentName = 'Model output';
websiteFolder = 'classes/model-output';
classes = {'WVModelOutputFile','WVModelOutputGroup'};

excludedSuperclasses = {'handle','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,excludedSuperclasses=excludedSuperclasses);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)

excludedSuperclasses = {'handle','WVModelOutputGroup','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classDoc = ClassDocumentation('WVModelOutputGroupEvenlySpaced',buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,nav_order=3,excludedSuperclasses=excludedSuperclasses);
classDoc.writeToFile();

%%
parentName = 'Observing systems';
websiteFolder = 'classes/observing-systems';

excludedSuperclasses = {'handle','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classDoc = ClassDocumentation('WVObservingSystem',buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,nav_order=1,excludedSuperclasses=excludedSuperclasses);
classDoc.writeToFile();

excludedSuperclasses = {'handle','WVObservingSystem','CAAnnotatedClass','matlab.mixin.Heterogeneous'};
classes = {'WVEulerianFields','WVLagrangianParticles','WVTracer','WVMooring','WVCoefficients'};
classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName+1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,excludedSuperclasses=excludedSuperclasses);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)



%%
parentName = 'Operations & annotations';
websiteFolder = 'classes/operations-and-annotations';
classes = {'WVOperation','WVVariableAnnotation'};

classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)


parentName = 'Flow components';
websiteFolder = 'classes/flow-components';

classDoc = ClassDocumentation('WVFlowComponent',nav_order=1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName);
classDoc.writeToFile();

excludedSuperclasses = {'handle','WVFlowComponent'};
classes = {'WVPrimaryFlowComponent','WVTotalFlowComponent','WVGeostrophicComponent','WVInternalGravityWaveComponent','WVInertialOscillationComponent','WVMeanDensityAnomalyComponent'};
classDocumentation = ClassDocumentation.empty(length(classes),0);
for iName=1:length(classes)
    classDocumentation(iName) = ClassDocumentation(classes{iName},nav_order=iName+1,buildFolder=buildFolder,websiteFolder=websiteFolder,parent=parentName,grandparent=classFolderName,excludedSuperclasses=excludedSuperclasses);
end
arrayfun(@(a) a.writeToFile(),classDocumentation)

end