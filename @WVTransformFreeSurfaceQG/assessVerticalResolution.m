function assessment = assessVerticalResolution(Lz,Nz,options)
% Assess vertical-mode accuracy and the active-endpoint horizontal limit.
%
% This method performs the scientific vertical solve without constructing a
% complete horizontal transform. For active endpoint families it returns a
% conservative maximum horizontal wavenumber whose APV/zero-APV product
% error satisfies `quadraticAliasingTolerance`.
%
% - Topic: Create and restore a transform
% - Declaration: assessment = WVTransformFreeSurfaceQG.assessVerticalResolution(Lz,Nz,options)
% - Parameter Lz: vertical domain depth in meters
% - Parameter Nz: number of physical vertical quadrature points
% - Parameter options.N2Function: squared buoyancy-frequency function
% - Parameter options.rhoFunction: no-motion density function
% - Parameter options.g0: surface acceleration; default stratification integral
% - Parameter options.gd: bottom acceleration; default `Inf`
% - Parameter options.apvGramTolerance: APV normalized-Gram tolerance
% - Parameter options.mdaGramTolerance: MDA normalized-Gram tolerance
% - Parameter options.quadraticAliasingTolerance: APV quadratic-product tolerance
% - Returns assessment: data-only vertical-resolution diagnostics
arguments
    Lz (1,1) double {mustBePositive}
    Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(Nz,4)}
    options.N2Function function_handle = @isempty
    options.rhoFunction function_handle = @isempty
    options.rho0 (1,1) double {mustBePositive} = 1025
    options.rotationRate (1,1) double {mustBePositive} = 7.2921e-5
    options.latitude (1,1) double {mustBeSupportedLatitude} = 33
    options.g (1,1) double {mustBePositive} = 9.81
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = Inf
    options.apvGramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 1e-2
    options.mdaGramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 1e-2
    options.quadraticAliasingTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 0.1
end

inputs = WVTransformFreeSurfaceQG.resolveScientificInputs(Lz,options);
verticalOptions = options;
verticalOptions.g0 = inputs.g0;
verticalOptions.gd = inputs.gd;
vertical = WVTransformFreeSurfaceQG.buildVerticalModes(Lz,Nz,inputs.N2Function,verticalOptions);
activeMask = [isfinite(inputs.g0),isfinite(inputs.gd)];
endpointNames = ["surface","bottom"];
integratedN = integral(@(z) sqrt(inputs.N2Function(z)),-Lz,0);
horizontalWavenumberScale = abs(inputs.f0)*(Nz-1)^2/integratedN;
limit = WVTransformFreeSurfaceQG.supportedHorizontalWavenumber(vertical.apvBasis,vertical.apvTransform,inputs.N2Function, ...
    inputs.f0,options.g,endpointNames(activeMask),vertical.nEVP,options.quadraticAliasingTolerance,seedKh=horizontalWavenumberScale);

apvModeCount = length(vertical.apvTransform.modeNumber);
mdaModeCount = length(vertical.mdaTransform.modeNumber);
apvDiagnostics = vertical.apvAssessment.prefixDiagnostics(apvModeCount,:);
mdaDiagnostics = vertical.mdaAssessment.prefixDiagnostics(mdaModeCount,:);
assessment = struct(z=vertical.z,weights=vertical.weights,apvModeCount=apvModeCount,mdaModeCount=mdaModeCount, ...
    apvGramError=apvDiagnostics.gramError,mdaGramError=mdaDiagnostics.gramError, ...
    quadraticAliasingError=apvDiagnostics.quadraticAliasingError,apvGramTolerance=options.apvGramTolerance, ...
    mdaGramTolerance=options.mdaGramTolerance,quadraticAliasingTolerance=options.quadraticAliasingTolerance, ...
    horizontalWavenumberScale=horizontalWavenumberScale,isHorizontalLimitApplicable=limit.isApplicable, ...
    maximumSupportedKh=limit.maximumSupportedKh,firstRejectedKh=limit.firstRejectedKh, ...
    maximumSupportedError=limit.maximumSupportedError,firstRejectedError=limit.firstRejectedError, ...
    minimumHorizontalWavelength=limit.minimumHorizontalWavelength,limitingEndpoint=limit.limitingEndpoint, ...
    limitingAPVModeNumber=limit.limitingModeNumber);
end
