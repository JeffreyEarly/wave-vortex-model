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
    name = string(metadata.name);
    [topicPath,isDeveloper] = topicForMember(className,name);
    setTopicPath(metadata,topicPath);
    metadata.isDeveloper = isDeveloper;
    if startsWith(className,"WVTransform")
        metadata.nav_order = transformMemberOrder(className,name,metadata.nav_order);
    elseif isForcingClass(className)
        metadata.nav_order = forcingMemberOrder(name,metadata.nav_order);
    end
end
end

function [topicPath,isDeveloper] = topicForMember(className,name)
if className == "WVFourierStorageLayout"
    [topicPath,isDeveloper] = fourierStorageLayoutTopic(name);
elseif className == "WVCompiledBackend"
    [topicPath,isDeveloper] = compiledBackendTopic(name);
elseif className == "WVCompiledConstantStratificationBackend"
    topicPath = "Compiled preview internals";
    isDeveloper = true;
elseif className == "WVDensityDiffusionIntegrator"
    topicPath = "Density diffusion integration";
    isDeveloper = true;
elseif startsWith(className,"WVTransform")
    [topicPath,isDeveloper] = transformTopic(className,name);
elseif className == "WVModel"
    [topicPath,isDeveloper] = modelTopic(name);
elseif isForcingClass(className)
    [topicPath,isDeveloper] = forcingTopic(className,name);
elseif ismember(className,["WVObservingSystem","WVEulerianFields", ...
        "WVLagrangianParticles","WVTracer","WVMooring","WVCoefficients"])
    [topicPath,isDeveloper] = observingTopic(className,name);
elseif startsWith(className,"WVModelOutput")
    [topicPath,isDeveloper] = outputTopic(className,name);
elseif ismember(className,["WVOperation","WVVariableAnnotation","WVCoefficientAnnotation"])
    [topicPath,isDeveloper] = operationTopic(className,name);
elseif contains(className,"FlowComponent") || endsWith(className,"Component")
    [topicPath,isDeveloper] = componentTopic(className,name);
else
    topicPath = "Class internals";
    isDeveloper = true;
end
end

function [topicPath,isDeveloper] = compiledBackendTopic(name)
isDeveloper = true;
if name == "capabilities"
    topicPath = "Inspect compiled support";
elseif name == "build"
    topicPath = "Build compiled support";
else
    topicPath = "Test compiled support";
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
    topicPath = "Legacy compatibility";
end
end

function [topicPath,isDeveloper] = transformTopic(className,name)
isDeveloper = false;

if ismember(name,["WVTransformConstantStratification", ...
        "WVTransformHydrostatic","WVTransformBoussinesq", ...
        "WVTransformStratifiedQG","WVTransformBarotropicQG", ...
        "WVTransformFreeSurfaceQG", ...
        "waveVortexTransformFromFile","assessVerticalResolution"])
    topicPath = "Create and restore a transform";
elseif ismember(name,["waveVortexTransformWithResolution", ...
        "waveVortexTransformWithDoubleResolution", ...
        "waveVortexTransformWithExplicitAntialiasing", ...
        "boussinesqTransform","hydrostaticTransform", ...
        "spectralVariableWithResolution"])
    topicPath = "Create a related transform";
elseif ismember(name,["Ap","Am","A0","Ag_q","Ag_0","Amda"])
    topicPath = "Inspect wave-vortex coefficients — Stored coefficients";
elseif className == "WVTransformFreeSurfaceQG" && ismember(name,["coefficientStateAnnotations", ...
        "coefficientStateVariableNamesForPersistence"])
    topicPath = "Inspect wave-vortex coefficients — Family contract";
elseif className == "WVTransformFreeSurfaceQG" && name == "coefficientTendency"
    topicPath = "Inspect wave-vortex coefficients — Coefficient evolution";
elseif ismember(name,["Apt","Amt","A0t","waveCoefficientsAtTimeT"])
    topicPath = "Inspect wave-vortex coefficients — Coefficients at the current time";
elseif ismember(name,["Omega","iOmega","phase","conjPhase","t","t0"])
    topicPath = "Inspect wave-vortex coefficients — Coefficient evolution";
elseif ismember(name,["addGMSpectrum","initWithAlternativeSpectrum", ...
        "initWavesWithFrequencySpectrum","initWithGMSpectrum", ...
        "addWavesWithFrequencySpectrum"])
    topicPath = "Initialize the flow — Waves — Wave spectra";
elseif startsWith(name,"initWithWave") || startsWith(name,"addWave") || ...
        startsWith(name,"setWave") || startsWith(name,"removeAllWave")
    topicPath = "Initialize the flow — Waves — Individual modes";
elseif contains(name,"InertialMotion")
    topicPath = "Initialize the flow — Inertial oscillations";
elseif contains(name,"Geostrophic") || ismember(name,["setSSH","removeAllGeostrophicMotions"])
    topicPath = "Initialize the flow — Geostrophic motions";
elseif contains(name,"MeanDensityAnomaly")
    topicPath = "Initialize the flow — Mean density anomalies";
elseif ismember(name,["initWithUVEta","initWithUVRho","addUVEta", ...
        "initFromNetCDFFile","initWithRandomFlow","initWithGaussianEddy", ...
        "addRandomFlow","removeAll"])
    topicPath = "Initialize the flow — General initialization";
elseif ismember(name,["u","v","w"])
    topicPath = "Evaluate physical fields — On the model grid — Velocity";
elseif name == "eta" && className == "WVTransformBarotropicQG"
    topicPath = "Evaluate physical fields — On the model grid — Pressure and surface fields";
elseif ismember(name,["eta","eta_true","rho","rho_bar","rho_e", ...
        "rho_nm","rho_nm0","rho_total"])
    topicPath = "Evaluate physical fields — On the model grid — Density and displacement";
elseif ismember(name,["p","pi","ssh","ssu","ssv"])
    topicPath = "Evaluate physical fields — On the model grid — Pressure and surface fields";
elseif ismember(name,["qgpv","psi","zeta_x","zeta_y","zeta_z"])
    topicPath = "Evaluate physical fields — On the model grid — Vorticity and geostrophic fields";
elseif name == "placeParticlesOnIsopycnal"
    topicPath = "Evaluate physical fields — Isopycnal utilities";
elseif ismember(name,["variableWithName","variableNames","hasVariableWithName", ...
        "summarizeVariables"])
    topicPath = "Evaluate physical fields — Registered variables";
elseif ismember(name,["variableAtPositionWithName","interpolatedFieldAtPosition"])
    topicPath = "Evaluate physical fields — At arbitrary positions";
elseif ismember(name,["latitude","f","f0","beta","rotationRate", ...
        "planetaryRadius","inertialPeriod"])
    topicPath = "Inspect the domain — Physical environment — Planetary rotation";
elseif ismember(name,["N0","N2","dLnN2","N2Function","rho0", ...
        "rhoFunction","shouldUseTrueNoMotionProfile","buoyancyPeriod"])
    topicPath = "Inspect the domain — Physical environment — Stratification and reference density";
elseif className == "WVTransformFreeSurfaceQG" && ( ...
        startsWith(name,"apv") || startsWith(name,"zeroAPV") || ...
        (startsWith(name,"mda") && name ~= "mdaComponent") || ...
        ismember(name,["g0","gd","activeEndpointCount","activeEndpoint", ...
        "sourceEndpoint","klNonzero","kNonzero","lNonzero","khNonzero", ...
        "khUnique","klNonzeroKhUniqueIndex","minimumRelativeMuSeparation", ...
        "verticalQuadratureWeights","verticalGridKind", ...
        "verticalGridCoordinate","modeSelectionMethod"]))
    topicPath = "Inspect the domain — Spectral grid — Free-surface modes and operators";
elseif name == "g"
    topicPath = "Inspect the domain — Physical environment — Gravity";
elseif ismember(name,["x","y","z"])
    topicPath = "Inspect the domain — Spatial grid — Coordinate axes";
elseif ismember(name,["X","Y","Z","xyGrid","xyzGrid"])
    topicPath = "Inspect the domain — Spatial grid — Coordinate arrays";
elseif ismember(name,["Lx","Ly","Lz"])
    topicPath = "Inspect the domain — Spatial grid — Domain dimensions";
elseif ismember(name,["Nx","Ny","Nz","spatialMatrixSize"])
    topicPath = "Inspect the domain — Spatial grid — Resolution and shape";
elseif ismember(name,["z_int","volumeIntegral"])
    topicPath = "Inspect the domain — Spatial grid — Quadrature and integration";
elseif ismember(name,["k","l","j"])
    topicPath = "Inspect the domain — Spectral grid — Compact grid vectors";
elseif ismember(name,["K","L","J","klGrid","kljGrid"])
    topicPath = "Inspect the domain — Spectral grid — Compact grid arrays";
elseif ismember(name,["dk","dl"])
    topicPath = "Inspect the domain — Spectral grid — Wavenumber spacing";
elseif ismember(name,["Kh","K2"])
    topicPath = "Inspect the domain — Spectral grid — Horizontal wavenumber geometry";
elseif ismember(name,["Nj","Nkl","spectralMatrixSize", ...
        "effectiveHorizontalGridResolution", ...
        "effectiveVerticalGridResolution","effectiveJMax", ...
        "summarizeDegreesOfFreedom"])
    topicPath = "Inspect the domain — Spectral grid — Resolution and shape";
elseif className == "WVTransformBarotropicQG" && ismember(name,["h","h_0","Lr2"])
    topicPath = "Inspect the domain — Spectral grid — Equivalent depth and deformation scale";
elseif ismember(name,["verticalModes","h","h_0","h_pm","Lr2", ...
        "waveModeVerticalStructureAtIndex"])
    topicPath = "Inspect the domain — Spectral grid — Vertical modes and scaling";
elseif ismember(name,["FMatrix","FinvMatrix","GMatrix","GinvMatrix"])
    topicPath = "Inspect the domain — Spectral grid — Vertical-mode transformation matrices";
elseif ismember(name,["isHydrostatic","shouldAntialias","computationalBackend","computationalBackendMetadata"])
    topicPath = "Inspect the domain — Transform configuration";
elseif ismember(name,["diffX","diffY","diffZF","diffZG","intZF","intZG"])
    topicPath = "Differentiate and integrate fields";
elseif ismember(name,["transformUVEtaToWaveVortex","transformUVWEtaToWaveVortex", ...
        "transformWaveVortexToUVWEta","transformQGPVToWaveVortex", ...
        "transformStateForward","transformStateBack", ...
        "transformMDAForward","transformMDABack","reconstructSpectralState"])
    topicPath = "Convert representations — Physical fields and coefficients";
elseif ismember(name,["geostrophicEnergy","waveEnergy","inertialEnergy", ...
        "mdaEnergy","meanDensityAnomalyEnergy", ...
        "geostrophicKineticEnergy","geostrophicPotentialEnergy", ...
        "totalEnergyOfFlowComponent"])
    topicPath = "Analyze energy — Component energy";
elseif ismember(name,["totalEnergy","totalEnergySpatiallyIntegrated", ...
        "exactTotalEnergy"])
    topicPath = "Analyze energy — Total energy";
elseif name == "quadraticDiagnostics"
    topicPath = "Analyze energy — Energy and enstrophy budgets";
elseif startsWith(name,"summarizeEnergy") || name == "summarizeModeEnergy"
    topicPath = "Analyze energy — Energy summaries";
elseif ismember(name,["uvMax","wMax","hasMeanPressureDifference"])
    topicPath = "Analyze the flow — Flow diagnostics";
elseif name == "isDensityInValidRange"
    topicPath = "Analyze the flow — Density validity";
elseif contains(lower(name),"enstrophy") && ~contains(lower(name),"flux")
    topicPath = "Analyze the flow — Potential vorticity and enstrophy";
elseif ismember(name,["spectrumWithFgTransform","spectrumWithGgTransform", ...
        "crossSpectrumWithFgTransform","crossSpectrumWithGgTransform", ...
        "transformToKLAxes","kAxis","lAxis"])
    topicPath = "Analyze the flow — Spectra — Spectral fields";
elseif name == "kRadial" || name == "transformToRadialWavenumber"
    topicPath = "Analyze the flow — Spectra — Radial wavenumber";
elseif name == "convertFromWavenumberToFrequency"
    topicPath = "Analyze the flow — Spectra — Frequency";
elseif ismember(name,["addForcing","setForcing","removeForcing","removeAllForcing"])
    topicPath = "Manage forcing and closures — Configure forcing";
elseif ismember(name,["forcingNames","forcingWithName", ...
        "hasForcingWithName","forcing","hasClosure"])
    topicPath = "Manage forcing and closures — Inspect forcing and closures";
elseif name == "summarizeForcing"
    topicPath = "Manage forcing and closures — Summarize forcing";
elseif ismember(name,["waveComponent","inertialComponent", ...
        "geostrophicComponent","mdaComponent", ...
        "primaryFlowComponentNames","primaryFlowComponentWithName", ...
        "primaryFlowComponents"])
    topicPath = "Inspect flow components — Primary flow components";
elseif ismember(name,["flowComponentNames","flowComponentWithName", ...
        "flowComponents","totalFlowComponent"])
    topicPath = "Inspect flow components — Registered and combined components";
elseif name == "summarizeFlowComponents"
    topicPath = "Inspect flow components — Summarize flow components";
elseif ismember(name,["addFlowComponent","addPrimaryFlowComponent"])
    topicPath = "Extend a transform — Flow components";
elseif ismember(name,["addOperation","removeOperation","operationWithName", ...
        "variableWithName","variableNames","hasVariableWithName"])
    topicPath = "Extend a transform — Operations and variables";
elseif name == "writeToFile"
    topicPath = "Save transform state";
elseif name == "version"
    topicPath = "Get package information";
else
    topicPath = transformDeveloperTopic(name);
    isDeveloper = true;
end
end

function navOrder = transformMemberOrder(className,name,currentOrder)
if ~startsWith(className,"WVTransform")
    navOrder = currentOrder;
    return
end

orderedGroups = {
    ["x","y","z"]
    ["X","Y","Z","xyGrid","xyzGrid"]
    ["Lx","Ly","Lz"]
    ["Nx","Ny","Nz","spatialMatrixSize"]
    ["z_int","volumeIntegral"]
    ["k","l","j"]
    ["K","L","J","klGrid","kljGrid"]
    ["dk","dl"]
    ["Kh","K2"]
    ["Nj","Nkl","spectralMatrixSize","effectiveHorizontalGridResolution", ...
        "effectiveVerticalGridResolution","effectiveJMax","summarizeDegreesOfFreedom"]
    ["verticalModes","h","h_0","h_pm","Lr2","waveModeVerticalStructureAtIndex"]
    ["FMatrix","FinvMatrix","GMatrix","GinvMatrix"]
    ["addForcing","setForcing","removeForcing","removeAllForcing"]
    ["forcing","forcingNames","forcingWithName","hasForcingWithName","hasClosure"]
    ["waveComponent","inertialComponent","geostrophicComponent","mdaComponent", ...
        "primaryFlowComponents","primaryFlowComponentNames","primaryFlowComponentWithName"]
    ["flowComponents","flowComponentNames","flowComponentWithName","totalFlowComponent"]
    ["Ap","Am","A0"]
    ["Apt","Amt","A0t","waveCoefficientsAtTimeT"]
    ["t0","t","Omega","iOmega","phase","conjPhase"]
    ["kAxis","lAxis","transformToKLAxes"]
    ["kRadial","transformToRadialWavenumber"]
    };

for group = orderedGroups'
    index = find(group{1} == name,1);
    if ~isempty(index)
        navOrder = index;
        return
    end
end
navOrder = currentOrder;
end

function topicPath = transformDeveloperTopic(name)
lowerName = lower(name);
if name == "WVTransform"
    topicPath = "Construction internals";
elseif ismember(name,["kMode_dft","lMode_dft","kMode_wv","lMode_wv", ...
        "isValidConjugateKLModeNumber","isValidConjugateModeNumber", ...
        "isValidKLModeNumber","isValidModeNumber", ...
        "isValidPrimaryKLModeNumber","isValidPrimaryModeNumber", ...
        "primaryKLModeNumberFromKLModeNumber"])
    topicPath = "Geometry and mode indexing — Mode numbers and validity";
elseif ismember(name,["indexFromKLModeNumber","indexFromModeNumber", ...
        "klModeNumberFromIndex","modeNumberFromIndex"])
    topicPath = "Geometry and mode indexing — Linear-index conversion";
elseif ismember(name,["conjugateDimension","Nk_dft","Nl_dft", ...
        "k_dft","l_dft","kl","dftConjugateIndices2D", ...
        "dftPrimaryIndices2D","indicesOfFourierConjugates", ...
        "shouldExcludeConjugates","shouldExcludeNyquist"])
    topicPath = "Geometry and mode indexing — DFT and WV layout metadata";
elseif ismember(name,["indicesFromDFTGridToWVGrid", ...
        "indicesFromWVGridToDFTGrid","transformFromDFTGridToWVGrid", ...
        "transformFromWVGridToDFTGrid", ...
        "transformFromSpatialDomainToDFTGrid", ...
        "transformToSpatialDomainFromDFTGrid", ...
        "transformToSpatialDomainFromDFTGridAtPosition"])
    topicPath = "Geometry and mode indexing — Layout conversion";
elseif ismember(name,["maskForAliasedModes", ...
        "maskForConjugateFourierCoefficients","maskForNyquistModes", ...
        "isHermitian","setConjugateToUnity"])
    topicPath = "Geometry and mode indexing — Masks and Hermitian bookkeeping";
elseif contains(lowerName,"cache") || contains(lowerName,"namemap") || ...
        contains(lowerName,"annotation") || contains(lowerName,"operation")
    topicPath = "Caches and registries";
elseif contains(lowerName,"group") || contains(lowerName,"requiredpropert") || ...
        contains(lowerName,"netcdf") || startsWith(name,"restore") || startsWith(name,"namesOf")
    topicPath = "Persistence internals";
elseif contains(lowerName,"flux") || contains(lowerName,"forcing") || ...
        startsWith(name,"rk4") || ismember(name,["Fu","Fv","Feta","F0","Fpv"])
    topicPath = "Nonlinear flux and forcing internals";
elseif contains(lowerName,"index") || contains(lowerName,"mode") || ...
        contains(lowerName,"grid") || contains(lowerName,"mask") || ...
        contains(lowerName,"axis") || contains(lowerName,"dimension") || ...
        contains(lowerName,"matrixsize") || startsWith(name,"isValid")
    topicPath = "Geometry and mode indexing — Additional geometry utilities";
elseif contains(lowerName,"transform") || contains(lowerName,"matrix") || ...
        contains(lowerName,"dct") || contains(lowerName,"dst") || ...
        startsWith(name,"PF") || startsWith(name,"QG") || ismember(name,["P0","Q0"])
    topicPath = "Spectral transforms and operators";
elseif contains(name,"Ap") || contains(name,"Am") || contains(name,"A0") || ...
        name == "PA0"
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
    topicPath = "Create the forcing";
elseif ismember(name,["wvt","name","priority","isClosure","forcingType", ...
        "r","k_r","k_f","j_f","u_rms","initialPV","modelSpectrum", ...
        "Cd","nu","kappa","kappa_z","shouldForceMeanDensityAnomaly","apvCutoffFraction", ...
        "alpha","Nj","pattern","amplitude","period","phase","A0_indices","Ap_indices","Am_indices", ...
        "A0bar","Apbar","Ambar","topographicHeight", ...
        "barotropicVelocityAmplitude","frequency","darwinSymbol", ...
        "rampDuration","startTime","shouldAvoidAdaptiveDamping", ...
        "maximumForcedHorizontalWavenumber","maximumForcedVerticalMode"])
    topicPath = "Inspect forcing configuration";
elseif ismember(name,["setWaveForcingCoefficients", ...
        "setGeostrophicForcingCoefficients","setNarrowBandGeostrophicForcing"])
    topicPath = "Configure forcing";
elseif ismember(name,["r_scaled","cd","alpha_scaled","damp", ...
        "k_damp","k_no_damp","j_damp","j_no_damp", ...
        "assumedEffectiveHorizontalGridResolution","dampingTimeScale", ...
        "effectiveHorizontalGridResolution","effectiveJMax"])
    topicPath = "Inspect forcing or damping scales";
elseif ismember(name,["barotropicVelocityAtTime","bottomVelocityAtTime", ...
        "spectralGenerationMask"])
    topicPath = "Evaluate prescribed forcing";
elseif name == "goffAbyssalHillTopography"
    topicPath = "Generate forcing inputs";
elseif name == "quasigeostrophicDampingContributions"
    topicPath = "Evaluate forcing budgets";
else
    isDeveloper = true;
    if ismember(name,["addHydrostaticSpatialForcing", ...
            "addNonhydrostaticSpatialForcing","addSpectralForcing", ...
            "setSpectralAmplitude","setSpectralForcing", ...
            "addPotentialVorticitySpatialForcing", ...
            "addPotentialVorticitySpectralForcing", ...
            "addQuasigeostrophicSpatialForcing", ...
            "addQuasigeostrophicSpectralForcing", ...
            "setPotentialVorticitySpectralAmplitude", ...
            "setPotentialVorticitySpectralForcing", ...
            "spatialFluxTypes","spectralFluxTypes","spectralAmplitudeTypes"])
        topicPath = "Implement forcing evaluation";
    elseif name == "forcingWithResolutionOfTransform"
        topicPath = "Convert forcing resolution";
    elseif ismember(name,["forcingFromGroup","writeToGroup", ...
            "classRequiredPropertyNames","classDefinedPropertyAnnotations"])
        topicPath = "Forcing persistence";
    else
        topicPath = "Forcing internals";
    end
end
end

function navOrder = forcingMemberOrder(name,currentOrder)
orderedGroups = {
    ["wvt","name","forcingType","isClosure","priority"]
    ["r","k_r","k_f","j_f","u_rms","initialPV","modelSpectrum", ...
        "Cd","nu","kappa","kappa_z","shouldForceMeanDensityAnomaly", ...
        "alpha","Nj","pattern","amplitude","period","phase"]
    ["A0_indices","A0bar","Ap_indices","Apbar","Am_indices","Ambar"]
    ["topographicHeight","barotropicVelocityAmplitude","frequency", ...
        "darwinSymbol","rampDuration","startTime", ...
        "shouldAvoidAdaptiveDamping","maximumForcedHorizontalWavenumber", ...
        "maximumForcedVerticalMode"]
    ["setWaveForcingCoefficients","setGeostrophicForcingCoefficients", ...
        "setNarrowBandGeostrophicForcing"]
    ["r_scaled","cd","alpha_scaled","k_no_damp","k_damp", ...
        "j_no_damp","j_damp","assumedEffectiveHorizontalGridResolution", ...
        "dampingTimeScale","effectiveHorizontalGridResolution","effectiveJMax", ...
        "damp"]
    ["barotropicVelocityAtTime","bottomVelocityAtTime","spectralGenerationMask"]
    };
for group = orderedGroups'
    index = find(group{1} == name,1);
    if ~isempty(index)
        navOrder = index;
        return
    end
end
navOrder = currentOrder;
end

function tf = isForcingClass(className)
tf = className == "WVForcing" || startsWith(className,"WVBottomFriction") || ...
    ismember(className,["WVNonlinearAdvection","WVFixedAmplitudeForcing", ...
    "WVNarrowBandGeostrophicForcing", ...
    "WVBetaPlanePVAdvection","WVSeasonalSurfaceBuoyancyFlux","WVSeasonalSurfaceAnomalyForcing","WVPseudoTopographicWaveGeneration", ...
    "WVAdaptiveDamping","WVVerticalDiffusivity","WVHorizontalDamping", ...
    "WVVerticalDamping","WVThermalDamping","WVAntialiasing"]);
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
elseif className == "WVCoefficientAnnotation" && ismember(name,[ ...
        "auxiliaryCoordinates","canonicalBasis","persistenceRole", ...
        "emptyFamilyPolicy","numericDomain","isPhysicallyPresent"])
    topicPath = "Inspect coefficient annotations";
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
