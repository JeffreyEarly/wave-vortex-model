function w = fromStratification(domainSize,gridSize,options)
% Construct a complete thermal basis and independently resolved MDA modes.
% Native sampling and assembly quadrature do not truncate thermal directions.
% - Topic: Create and restore a transform
% - Parameter domainSize: three physical lengths in m
% - Parameter gridSize: horizontal grid counts and increasing WKB Lobatto count
% - Parameter options.N2Function: positive constant or exponential N2 profile
% - Parameter options.thermalModeCount: complete polynomial-space dimension
% - Parameter options.mdaModeCount: independently retained mean dimension
% - Returns w: thermal transform with zero coefficients
arguments
    domainSize (1,3) double {mustBeReal,mustBeFinite,mustBePositive}
    gridSize (1,3) double {mustBeInteger,mustBeGreaterThanOrEqual(gridSize,4)}
    options.N2Function function_handle
    options.thermalModeCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.thermalModeCount,3)}
    options.mdaModeCount (1,1) double {mustBeInteger,mustBePositive}
    options.kappa_z (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 1e-5
    options.latitude (1,1) double {mustBeReal,mustBeFinite,mustBeGreaterThanOrEqual(options.latitude,-90),mustBeLessThanOrEqual(options.latitude,90)} = 24
    options.g (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 9.81
    options.shouldAntialias (1,1) logical = true
    options.assemblyQuadratureCount (1,1) double {mustBeInteger,mustBeNonnegative} = 0
    options.gramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-2
    options.modeConvergenceTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
    options.boundaryResolutionTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-2
    options.shouldCheckQuadraticAliasing (1,1) logical = false
end
if options.assemblyQuadratureCount==0, options.assemblyQuadratureCount=max(257,4*options.thermalModeCount+1); end
if options.shouldCheckQuadraticAliasing
    error('WV:ThermalNonlinearQualification','Thermal quadratic-product qualification belongs to T4; this constructor qualifies linear construction only.');
end
if options.assemblyQuadratureCount<2*options.thermalModeCount+1
    error('WV:ThermalAssemblyQuadrature','Use at least 2*thermalModeCount+1 physical-depth assembly points.');
end
[s,assessment]=WVInternal.buildThermalState(domainSize,gridSize,options);
w=WVTransformFreeSurfaceThermalQG(scientificState=s);
w.constructionAssessment=assessment;
end
