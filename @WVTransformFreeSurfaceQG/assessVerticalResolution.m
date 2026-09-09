function assessment = assessVerticalResolution(Lz,Nz,options)
% Assess vertical-mode accuracy and the active-endpoint horizontal limit.
%
% This method performs the scientific vertical solve without constructing a
% complete horizontal transform. For active endpoint families it returns a
% conservative maximum horizontal wavenumber whose APV/zero-APV product
% error satisfies `quadraticAliasingTolerance` and whose fixed boundary
% responses satisfy `boundaryResolutionTolerance`. The two errors retain
% their separate units of relative error and separate tolerances.
%
% - Topic: Create and restore a transform
% - Declaration: assessment = WVTransformFreeSurfaceQG.assessVerticalResolution(Lz,Nz,options)
% - Parameter Lz: vertical domain depth in meters
% - Parameter Nz: number of physical vertical quadrature points
% - Parameter options.N2Function: squared buoyancy-frequency function
% - Parameter options.rhoFunction: no-motion density function
% - Parameter options.g0: surface acceleration; default negative stratification integral
% - Parameter options.gd: bottom acceleration; default positive stratification integral; use Inf to omit the bottom endpoint
% - Parameter options.latitude: latitude in degrees; default 24
% - Parameter options.gramTolerance: shared normalized-Gram tolerance; default 1e-2
% - Parameter options.modeConvergenceTolerance: independent physical H1 and equivalent-depth agreement; default 1e-6
% - Parameter options.boundaryResolutionTolerance: fixed zero-APV physical derivative and energy tolerance; default 1e-2
% - Parameter options.quadraticAliasingTolerance: APV quadratic-product tolerance
% - Returns assessment: data-only vertical-resolution diagnostics
arguments
    Lz (1,1) double {mustBePositive}
    Nz (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(Nz,4)}
    options.N2Function function_handle = @isempty
    options.rhoFunction function_handle = @isempty
    options.rho0 (1,1) double {mustBePositive} = 1025
    options.rotationRate (1,1) double {mustBePositive} = 7.2921e-5
    options.latitude (1,1) double {mustBeSupportedLatitude} = 24
    options.g (1,1) double {mustBePositive} = 9.81
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
    options.gramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 1e-2
    options.modeConvergenceTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
    options.boundaryResolutionTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-2
    options.quadraticAliasingTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 0.1
end

inputs = WVInternal.resolveFreeSurfaceInputs(Lz,options);
verticalOptions = options;
verticalOptions.g0 = inputs.g0;
verticalOptions.gd = inputs.gd;
vertical = WVInternal.buildFreeSurfaceBalancedModes(Lz,Nz,inputs.N2Function,verticalOptions);
activeMask = [isfinite(inputs.g0),isfinite(inputs.gd)];
endpointNames = ["surface","bottom"];
integratedN = integral(@(z) sqrt(inputs.N2Function(z)),-Lz,0);
horizontalWavenumberScale = abs(inputs.f0)*(Nz-1)^2/integratedN;
limit = WVInternal.supportedFreeSurfaceHorizontalWavenumber(vertical.apvBasis,vertical.apvTransform,inputs.N2Function, ...
    inputs.f0,options.g,endpointNames(activeMask),vertical.nEVP,options.quadraticAliasingTolerance,seedKh=horizontalWavenumberScale,vertical=vertical,inputs=inputs,boundaryResolutionTolerance=options.boundaryResolutionTolerance,modeConvergenceTolerance=options.modeConvergenceTolerance);

apvModeCount = length(vertical.apvTransform.modeNumber);
mdaModeCount = length(vertical.mdaTransform.modeNumber);
apvDiagnostics = vertical.apvAssessment.prefixDiagnostics(apvModeCount,:);
mdaDiagnostics = vertical.mdaAssessment.prefixDiagnostics(mdaModeCount,:);
assessment = struct(z=vertical.z,weights=vertical.weights,apvModeCount=apvModeCount,mdaModeCount=mdaModeCount, ...
    apvGramError=apvDiagnostics.gramError,mdaGramError=mdaDiagnostics.gramError, ...
    quadraticAliasingError=apvDiagnostics.quadraticAliasingError,gramTolerance=options.gramTolerance, ...
    quadraticAliasingTolerance=options.quadraticAliasingTolerance, ...
    horizontalWavenumberScale=horizontalWavenumberScale,isHorizontalLimitApplicable=limit.isApplicable, ...
    maximumSupportedKh=limit.maximumSupportedKh,firstRejectedKh=limit.firstRejectedKh, ...
    maximumSupportedError=limit.maximumSupportedError,firstRejectedError=limit.firstRejectedError, ...
    minimumHorizontalWavelength=limit.minimumHorizontalWavelength,limitingEndpoint=limit.limitingEndpoint, ...
    limitingAPVModeNumber=limit.limitingModeNumber,modeConvergenceTolerance=options.modeConvergenceTolerance,boundaryResolutionTolerance=options.boundaryResolutionTolerance);
if limit.isApplicable
    assessment.maximumSupportedBoundaryError=limit.maximumSupportedBoundaryError;
    assessment.firstRejectedBoundaryError=limit.firstRejectedBoundaryError;
    assessment.limitingMetric=limit.limitingMetric;
end
end
