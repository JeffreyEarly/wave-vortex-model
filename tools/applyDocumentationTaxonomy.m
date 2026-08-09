function applyDocumentationTaxonomy(documentation)
% Apply the WaveVortexModel information architecture to generated API pages.
%
% ClassDocumentation reflects every public MATLAB member, including public
% implementation machinery inherited from mixins. This policy keeps the
% user-facing reference organized around tasks and routes the remaining
% implementation surface into intentional Developer Topics.

arguments
    documentation (1,1) ClassDocumentation
end

className = string(documentation.name);
for iMetadata = 1:numel(documentation.allMethodDocumentation)
    metadata = documentation.allMethodDocumentation(iMetadata);
    [topicPath,isDeveloper] = topicForMember(className,string(metadata.name));
    setTopicPath(metadata,topicPath);
    metadata.isDeveloper = isDeveloper;
end
end

function [topicPath,isDeveloper] = topicForMember(className,name)
if className == "WVFourierStorageLayout"
    [topicPath,isDeveloper] = fourierStorageLayoutTopic(name);
elseif className == "WVFastTransformDoublyPeriodic"
    topicPath = "Select a horizontal-transform backend";
    isDeveloper = true;
elseif className == "WVFastTransformDoublyPeriodicFFTW"
    [topicPath,isDeveloper] = fftwAdapterTopic(name);
elseif className == "WVVerticalTransformConstantStratification"
    [topicPath,isDeveloper] = verticalTransformTopic(name);
elseif startsWith(className,"WVTransform")
    [topicPath,isDeveloper] = transformTopic(name);
elseif className == "WVModel"
    [topicPath,isDeveloper] = modelTopic(name);
elseif className == "WVForcing" || startsWith(className,"WVBottomFriction") || ...
        ismember(className,["WVNonlinearAdvection","WVFixedAmplitudeForcing", ...
        "WVBetaPlanePVAdvection","WVPseudoTopographicWaveGeneration", ...
        "WVAdaptiveDamping","WVVerticalDiffusivity","WVHorizontalDamping", ...
        "WVVerticalDamping","WVThermalDamping","WVAntialiasing"])
    [topicPath,isDeveloper] = forcingTopic(className,name);
elseif ismember(className,["WVObservingSystem","WVEulerianFields", ...
        "WVLagrangianParticles","WVTracer","WVMooring","WVCoefficients"])
    [topicPath,isDeveloper] = observingTopic(className,name);
elseif startsWith(className,"WVModelOutput")
    [topicPath,isDeveloper] = outputTopic(className,name);
elseif ismember(className,["WVOperation","WVVariableAnnotation"])
    [topicPath,isDeveloper] = operationTopic(className,name);
elseif contains(className,"FlowComponent") || endsWith(className,"Component")
    [topicPath,isDeveloper] = componentTopic(className,name);
else
    topicPath = "Class internals";
    isDeveloper = true;
end
end

function [topicPath,isDeveloper] = verticalTransformTopic(name)
isDeveloper = true;
if ismember(name,["WVVerticalTransformConstantStratification","create","Nz","Nj","backendIdentifier"])
    topicPath = "Create a vertical-transform strategy";
elseif ismember(name,["transformForward","transformBack"])
    topicPath = "Apply vertical transforms";
elseif name == "dispatchRecords"
    topicPath = "Inspect vertical dispatch";
else
    topicPath = "Class internals";
end
end

function [topicPath,isDeveloper] = fftwAdapterTopic(name)
isDeveloper = true;
if ismember(name,["WVFastTransformDoublyPeriodicFFTW","wvg","Nz","backendIdentifier","fourierStorageLayout"])
    topicPath = "Create an FFTW adapter";
elseif ismember(name,["transformFromSpatialDomainWithFourier","transformToSpatialDomainWithFourier"])
    topicPath = "Apply horizontal transforms";
elseif ismember(name,["diffX","diffY"])
    topicPath = "Apply spatial derivatives";
else
    topicPath = "Class internals";
end
end

function [topicPath,isDeveloper] = fourierStorageLayoutTopic(name)
isDeveloper = true;
if ismember(name,["WVFourierStorageLayout","horizontalGridSize", ...
        "fourierStorageSize","nFourierStorageRows","Nkl", ...
        "fourierStorageType","compressedDimension","mappingMethod"])
    topicPath = "Describe Fourier storage";
elseif ismember(name,["fourierRowsForDirectWVIndices","directWVIndices", ...
        "fourierRowsForConjugatedWVIndices","conjugatedWVIndices", ...
        "hermitianCompletionRows","hermitianSourceRows", ...
        "hermitianSourceWVIndices","selfConjugateFourierRows", ...
        "transformFromFourierStorageToWVGrid", ...
        "transformFromWVGridToFourierStorage"])
    topicPath = "Map Fourier storage and WV grid";
elseif ismember(name,["allocateFourierStorage", ...
        "reshapeFourierStorageToRows","reshapeFourierRowsToStorage"])
    topicPath = "Manage Fourier storage";
elseif ismember(name,["mappingMemoryBytes","mappingMemoryUsage"])
    topicPath = "Inspect Fourier storage";
else
    topicPath = "Class internals";
end
end

function [topicPath,isDeveloper] = transformTopic(name)
isDeveloper = false;

if ismember(name,["WVTransformConstantStratification", ...
        "WVTransformHydrostatic","WVTransformBoussinesq", ...
        "WVTransformStratifiedQG","WVTransformBarotropicQG", ...
        "waveVortexTransformFromFile","waveVortexTransformWithResolution", ...
        "waveVortexTransformWithDoubleResolution", ...
        "waveVortexTransformWithExplicitAntialiasing"])
    topicPath = "Create and restore a transform";
elseif ismember(name,["Ap","Am","A0"])
    topicPath = "Inspect wave-vortex coefficients — Stored coefficients";
elseif ismember(name,["Apt","Amt","A0t","waveCoefficientsAtTimeT"])
    topicPath = "Inspect wave-vortex coefficients — Coefficients at the current time";
elseif ismember(name,["t","t0"])
    topicPath = "Set and inspect time";
elseif startsWith(name,"initWithWave") || startsWith(name,"addWave") || ...
        startsWith(name,"setWave") || startsWith(name,"removeAllWave")
    topicPath = "Initialize the flow — Waves";
elseif contains(name,"InertialMotion")
    topicPath = "Initialize the flow — Inertial oscillations";
elseif contains(name,"Geostrophic") || ismember(name,["setSSH","removeAllGeostrophicMotions"])
    topicPath = "Initialize the flow — Geostrophic motions";
elseif contains(name,"MeanDensityAnomaly")
    topicPath = "Initialize the flow — Mean density anomalies";
elseif ismember(name,["initWithUVEta","initWithUVRho","addUVEta", ...
        "initFromNetCDFFile","initWithRandomFlow","addRandomFlow","removeAll"])
    topicPath = "Initialize the flow";
elseif ismember(name,physicalFieldNames())
    topicPath = "Evaluate physical fields — On the model grid";
elseif ismember(name,["variableWithName","variableNames","hasVariableWithName", ...
        "summarizeVariables"])
    topicPath = "Evaluate physical fields — Registered variables";
elseif ismember(name,["variableAtPositionWithName","interpolatedFieldAtPosition"])
    topicPath = "Evaluate physical fields — At arbitrary positions";
elseif ismember(name,spatialDomainNames())
    topicPath = "Inspect the domain — Spatial grid";
elseif ismember(name,spectralDomainNames())
    topicPath = "Inspect the domain — Spectral grid";
elseif ismember(name,stratificationNames())
    topicPath = "Inspect the domain — Rotation and stratification";
elseif ismember(name,["diffX","diffY","diffZF","diffZG","intZF","intZG"])
    topicPath = "Differentiate and integrate fields";
elseif ismember(name,["transformUVEtaToWaveVortex","transformUVWEtaToWaveVortex", ...
        "transformWaveVortexToUVWEta","transformQGPVToWaveVortex"])
    topicPath = "Convert representations — Physical fields and coefficients";
elseif name == "hasMeanPressureDifference" || startsWith(name,"summarizeEnergy") || ...
        name == "summarizeModeEnergy" || name == "summarizeDegreesOfFreedom" || ...
        ismember(name,energyNames())
    topicPath = "Analyze the flow — Energy and summaries";
elseif contains(lower(name),"enstrophy") || name == "qgpv"
    topicPath = "Analyze the flow — Potential vorticity and enstrophy";
elseif contains(name,"Spectrum") || startsWith(name,"transformToRadial") || ...
        startsWith(name,"transformToPseudoRadial") || name == "convertFromWavenumberToFrequency"
    topicPath = "Analyze the flow — Spectra";
elseif ismember(name,["addForcing","setForcing","removeForcing", ...
        "removeAllForcing","forcingNames","forcingWithName", ...
        "hasForcingWithName","summarizeForcing","forcing","hasClosure"])
    topicPath = "Manage forcing and closures";
elseif ismember(name,["addFlowComponent","addPrimaryFlowComponent", ...
        "flowComponentNames","flowComponentWithName","flowComponents", ...
        "primaryFlowComponentNames","primaryFlowComponentWithName", ...
        "primaryFlowComponents","totalFlowComponent","summarizeFlowComponents"])
    topicPath = "Extend a transform — Flow components";
elseif ismember(name,["addOperation","removeOperation","operationWithName", ...
        "variableWithName","variableNames","hasVariableWithName"])
    topicPath = "Extend a transform — Operations and variables";
elseif name == "writeToFile"
    topicPath = "Save transform state";
elseif name == "version"
    topicPath = "Get package information";
elseif name == "spectralVariableWithResolution"
    topicPath = "Create and restore a transform";
else
    topicPath = transformDeveloperTopic(name);
    isDeveloper = true;
end
end

function topicPath = transformDeveloperTopic(name)
lowerName = lower(name);
if name == "WVTransform"
    topicPath = "Construction internals";
elseif contains(lowerName,"cache") || contains(lowerName,"namemap") || ...
        contains(lowerName,"annotation") || contains(lowerName,"operation")
    topicPath = "Caches and registries";
elseif contains(lowerName,"group") || contains(lowerName,"requiredpropert") || ...
        contains(lowerName,"netcdf") || startsWith(name,"restore") || startsWith(name,"namesOf")
    topicPath = "Persistence internals";
elseif contains(lowerName,"flux") || contains(lowerName,"forcing") || startsWith(name,"rk4")
    topicPath = "Nonlinear flux and forcing internals";
elseif contains(lowerName,"index") || contains(lowerName,"mode") || ...
        contains(lowerName,"grid") || contains(lowerName,"mask") || ...
        contains(lowerName,"axis") || contains(lowerName,"dimension") || ...
        contains(lowerName,"matrixsize") || startsWith(name,"isValid")
    topicPath = "Geometry and mode indexing";
elseif contains(lowerName,"transform") || contains(lowerName,"matrix") || ...
        contains(lowerName,"dct") || contains(lowerName,"dst") || ...
        startsWith(name,"PF") || startsWith(name,"QG")
    topicPath = "Spectral transforms and operators";
elseif contains(name,"Ap") || contains(name,"Am") || contains(name,"A0") || ...
        ismember(name,["Fu","Fv","Feta","F0","Fpv","PA0","P0","Q0"])
    topicPath = "Projection and reconstruction coefficients";
else
    topicPath = "Class internals";
end
end

function [topicPath,isDeveloper] = modelTopic(name)
isDeveloper = false;
if ismember(name,["WVModel","modelFromFile"])
    topicPath = "Create and restore a model";
elseif ismember(name,["wvt","t","initialTime","isDynamicsLinear","summarize"])
    topicPath = "Inspect model state";
elseif ismember(name,["setupIntegrator","integrateToTime"])
    topicPath = "Configure and run integration";
elseif contains(lower(name),"particle") || contains(lower(name),"float") || contains(lower(name),"drifter")
    topicPath = "Track particles";
elseif contains(name,"Tracer") || name == "tracer"
    topicPath = "Advect tracers";
elseif contains(name,"ObservingSystem") || contains(name,"FluxedCoefficients")
    topicPath = "Manage observing systems";
elseif ismember(name,["addNetCDFOutputVariables","removeNetCDFOutputVariables", ...
        "setNetCDFOutputVariables","addNewOutputFile","addOutputFile", ...
        "createNetCDFFileForModelOutput","closeNetCDFFile","ncfile", ...
        "outputFileNames","outputFileWithName","outputFiles"])
    topicPath = "Write model output";
else
    isDeveloper = true;
    if contains(lower(name),"integrat") || contains(lower(name),"tolerance") || ...
            contains(lower(name),"blowup") || contains(lower(name),"diagnostic")
        topicPath = "Integrator state";
    elseif contains(lower(name),"flux") || contains(lower(name),"indices")
        topicPath = "Flux assembly";
    elseif contains(lower(name),"output") || contains(lower(name),"netcdf") || ...
            contains(lower(name),"history")
        topicPath = "Output scheduling and persistence";
    else
        topicPath = "Model internals";
    end
end
end

function [topicPath,isDeveloper] = forcingTopic(className,name)
isDeveloper = false;
if name == className
    topicPath = "Create forcing and closures";
elseif ismember(name,["name","description","priority","isClosure","forcingType", ...
        "shouldAntialias"])
    topicPath = "Inspect forcing configuration";
elseif contains(lower(name),"resolutionoftransform")
    topicPath = "Convert forcing resolution";
elseif startsWith(name,"set") && ~contains(lower(name),"flux")
    topicPath = "Configure forcing";
else
    isDeveloper = true;
    if contains(lower(name),"group") || contains(lower(name),"requiredpropert")
        topicPath = "Forcing persistence";
    elseif contains(lower(name),"flux") || contains(lower(name),"amplitude") || ...
            contains(lower(name),"forcing")
        topicPath = "Forcing evaluation";
    else
        topicPath = "Forcing internals";
    end
end
end

function [topicPath,isDeveloper] = observingTopic(className,name)
isDeveloper = false;
if name == className
    topicPath = "Create an observing system";
elseif ismember(name,["name","description","wvt","model","fieldNames", ...
        "trackedFieldNames","trackedFields","x","y","z","x_index","y_index", ...
        "nParticles","absTolerance","absToleranceXY","absToleranceZ"])
    topicPath = "Inspect observed state";
elseif contains(name,"NetCDFOutputVariables")
    topicPath = "Configure sampled variables";
elseif ismember(name,["initialConditions","updateWithIncrements","fluxAtTime", ...
        "particlePositions","updateParticleTrackedFields"])
    topicPath = "Advance the observing system";
else
    isDeveloper = true;
    if contains(lower(name),"group") || contains(lower(name),"file") || ...
            contains(lower(name),"storage") || contains(lower(name),"netcdf")
        topicPath = "Observing-system persistence";
    elseif contains(lower(name),"flux") || contains(lower(name),"initialcondition")
        topicPath = "Observer integration";
    else
        topicPath = "Observing-system internals";
    end
end
end

function [topicPath,isDeveloper] = outputTopic(className,name)
isDeveloper = false;
if name == className
    topicPath = "Create model output";
elseif contains(lower(name),"interval") || ismember(name,["initialTime","finalTime"])
    topicPath = "Configure output schedules";
elseif contains(name,"ObservingSystem")
    topicPath = "Manage output observers";
elseif ismember(name,["closeNetCDFFile","initializeOutputFile","initializeOutputGroup", ...
        "writeTimeStepToOutputFile","writeTimeStepToNetCDFFile"])
    topicPath = "Write and close output";
else
    isDeveloper = true;
    if contains(lower(name),"group") || contains(lower(name),"file") || ...
            contains(lower(name),"storage") || contains(lower(name),"outputtime")
        topicPath = "Output persistence and scheduling";
    else
        topicPath = "Output internals";
    end
end
end

function [topicPath,isDeveloper] = operationTopic(className,name)
isDeveloper = false;
if name == className
    topicPath = "Create operations and annotations";
elseif ismember(name,["name","description","detailedDescription","outputVariables", ...
        "isDependentOnApAmA0","isVariableWithLinearTimeStep", ...
        "isVariableWithNonlinearTimeStep"])
    topicPath = "Inspect dependencies and outputs";
elseif name == "compute"
    topicPath = "Evaluate an operation";
else
    topicPath = "Operation internals";
    isDeveloper = true;
end
end

function [topicPath,isDeveloper] = componentTopic(className,name)
isDeveloper = false;
if name == className
    topicPath = "Create a flow component";
elseif ismember(name,["name","shortName","abbreviatedName","description","wvt", ...
        "nModes","degreesOfFreedomPerMode"])
    topicPath = "Inspect a flow component";
elseif contains(lower(name),"mask") || startsWith(name,"isValid")
    topicPath = "Inspect component modes — Masks and validity";
elseif contains(lower(name),"solution") || contains(lower(name),"modenumber") || ...
        contains(lower(name),"modeproperties")
    topicPath = "Work with component modes";
elseif contains(lower(name),"energy")
    topicPath = "Compute component energy";
else
    topicPath = "Flow-component internals";
    isDeveloper = true;
end
end

function setTopicPath(metadata,topicPath)
parts = split(topicPath," — ");
metadata.topic = parts(1);
metadata.subtopic = [];
metadata.subsubtopic = [];
if numel(parts) >= 2
    metadata.subtopic = parts(2);
end
if numel(parts) >= 3
    metadata.subsubtopic = parts(3);
end
end

function names = physicalFieldNames()
names = ["u","v","w","eta","eta_true","p","pi","ssh","ssu","ssv", ...
    "rho","rho_bar","rho_e","rho_nm","rho_nm0","rho_total", ...
    "qgpv","zeta_x","zeta_y","zeta_z","uvMax","wMax"];
end

function names = spatialDomainNames()
names = ["Lx","Ly","Lz","Nx","Ny","Nz","x","y","z","z_int", ...
    "xyGrid","xyzGrid","spatialMatrixSize","volumeIntegral"];
end

function names = spectralDomainNames()
names = ["k","l","j","kAxis","lAxis","klGrid","kljGrid","Nj", ...
    "spectralMatrixSize","effectiveHorizontalGridResolution", ...
    "effectiveVerticalGridResolution","effectiveJMax"];
end

function names = stratificationNames()
names = ["latitude","f0","beta","N0","N2","N2Function","rhoFunction", ...
    "buoyancyPeriod","inertialPeriod","isHydrostatic", ...
    "shouldUseTrueNoMotionProfile","verticalModes"];
end

function names = energyNames()
names = ["totalEnergy","totalEnergySpatiallyIntegrated","exactTotalEnergy", ...
    "geostrophicEnergy","waveEnergy","inertialEnergy", ...
    "meanDensityAnomalyEnergy","totalEnergyOfFlowComponent"];
end
