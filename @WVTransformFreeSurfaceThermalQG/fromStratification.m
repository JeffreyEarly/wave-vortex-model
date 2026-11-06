function w = fromStratification(domainSize,gridSize,options)
% Construct a complete thermal basis and independently resolved MDA modes.
% Native sampling and assembly quadrature do not truncate thermal directions.
% The profile is fixed in time. The thermal basis uses Earth rotation, nonzero
% Coriolis frequency, and a surface density of 1025 kg per cubic meter.
% - Topic: Create and restore a transform
% - Parameter domainSize: three physical lengths in m
% - Parameter gridSize: horizontal grid counts and increasing WKB Lobatto count
% - Parameter options.N2Function: positive constant or exponential N2 profile
% - Parameter options.thermalModeCount: complete polynomial-space dimension
% - Parameter options.mdaModeCount: independently retained mean dimension
% - Parameter options.shouldCheckQuadraticAliasing: qualify mapped product quadrature for nonlinear registration
% - Parameter options.nonlinearQuadratureCount: independent product count; zero selects max(257,3*n+1)
% - Parameter options.nonlinearQuadratureTolerance: weighted moment Gram allowance, default 1e-8
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
    options.nonlinearQuadratureCount (1,1) double {mustBeInteger,mustBeNonnegative} = 0
    options.nonlinearQuadratureTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-8
    options.shouldCheckQuadraticAliasing (1,1) logical = false
end
if options.assemblyQuadratureCount==0, options.assemblyQuadratureCount=max(257,4*options.thermalModeCount+1); end
if options.assemblyQuadratureCount<2*options.thermalModeCount+1
    error('WV:ThermalAssemblyQuadrature','Use at least 2*thermalModeCount+1 physical-depth assembly points.');
end
[s,assessment,background]=WVInternal.buildThermalState(domainSize,gridSize,options);
s=WVInternal.upgradeThermalState(s);
s.nonlinearQuadratureTolerance=options.nonlinearQuadratureTolerance;
if options.shouldCheckQuadraticAliasing
    if ~options.shouldAntialias, error('WV:ThermalNonlinearQualification','Nonlinear thermal evolution requires horizontal antialiasing.'); end
    count=options.nonlinearQuadratureCount;
    if count==0, count=max(257,3*options.thermalModeCount+1); end
    if count<ceil(3*(options.thermalModeCount-1)/2)+1, error('WV:ThermalNonlinearQuadrature','The product rule has fewer points than its assessment polynomial dimension.'); end
    report=WVInternal.assessThermalQuadrature(options.thermalModeCount,background.D,s.N20,s.inverseScale, ...
        background.f0,background.g,count,options.nonlinearQuadratureTolerance);
    s.shouldCheckQuadraticAliasing=true; s.nonlinearQuadratureCount=count;
    s.nonlinearQuadratureResidual=max(report.residuals); s.nonlinearReferenceResidual=max(report.referenceResiduals);
    assessment.quadraticProducts=report;
end
w=WVTransformFreeSurfaceThermalQG(scientificState=s);
w.constructionAssessment=assessment;
end
