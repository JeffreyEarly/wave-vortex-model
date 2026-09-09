function assessment = supportedFreeSurfaceHorizontalWavenumber(apvBasis,apvTransform,N2Function,f0,g,endpoints,nEVP,tolerance,options)
% Find a conservative APV/zero-APV horizontal-wavenumber limit.
arguments
    apvBasis (1,1) IMInternalModesBasis
    apvTransform (1,1) IMInternalModesDiscreteTransform
    N2Function function_handle
    f0 (1,1) double {mustBeReal,mustBeFinite,mustBeNonzero}
    g (1,1) double {mustBePositive}
    endpoints (1,:) string
    nEVP (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(nEVP,4)}
    tolerance (1,1) double {mustBePositive}
    options.shouldCheckQuadraticAliasing (1,1) logical = true
    options.seedKh (1,1) double {mustBePositive} = 1
    options.rejectedKh double {mustBePositive} = zeros(0,1)
    options.vertical (1,1) struct = struct()
    options.inputs (1,1) struct = struct()
    options.boundaryResolutionTolerance (1,1) double = 1e-2
    options.modeConvergenceTolerance (1,1) double = 1e-6
end

if isempty(endpoints)
    assessment = struct(isApplicable=false,maximumSupportedKh=NaN,firstRejectedKh=NaN, ...
        maximumSupportedError=NaN,firstRejectedError=NaN,minimumHorizontalWavelength=NaN, ...
        limitingEndpoint="",limitingModeNumber=NaN);
    return
end

maximumBracketSteps = 24;
if isempty(options.rejectedKh)
    trialKh = options.seedKh;
    trial = evaluate(trialKh);
    if trial.accepted
        lowerKh = trialKh;
        lower = trial;
        for iStep = 1:maximumBracketSteps
            upperKh = 2*lowerKh;
            upper = evaluate(upperKh);
            if ~upper.accepted
                break
            end
            lowerKh = upperKh;
            lower = upper;
        end
        if upper.accepted
            error('WVTransformFreeSurfaceQG:HorizontalLimitNotBracketed','The APV/zero-APV error did not exceed tolerance after %d wavenumber doublings.',maximumBracketSteps);
        end
    else
        upperKh = trialKh;
        upper = trial;
        for iStep = 1:maximumBracketSteps
            lowerKh = upperKh/2;
            lower = evaluate(lowerKh);
            if lower.accepted
                break
            end
            upperKh = lowerKh;
            upper = lower;
        end
        if ~lower.accepted
            error('WVTransformFreeSurfaceQG:NoSupportedHorizontalWavenumber','No passing APV/zero-APV wavenumber was found after %d halvings.',maximumBracketSteps);
        end
    end
else
    upperKh = options.rejectedKh;
    upper = evaluate(upperKh);
    if upper.accepted
        error('WVTransformFreeSurfaceQG:InvalidRejectedHorizontalWavenumber','The supplied rejected wavenumber does not exceed the APV/zero-APV tolerance.');
    end
    for iStep = 1:maximumBracketSteps
        lowerKh = upperKh/2;
        lower = evaluate(lowerKh);
        if lower.accepted
            break
        end
        upperKh = lowerKh;
        upper = lower;
    end
    if ~lower.accepted
        error('WVTransformFreeSurfaceQG:NoSupportedHorizontalWavenumber','No passing APV/zero-APV wavenumber was found after %d halvings.',maximumBracketSteps);
    end
end

for iStep = 1:20
    if upperKh/lowerKh-1 <= 0.01
        break
    end
    trialKh = sqrt(lowerKh*upperKh);
    trial = evaluate(trialKh);
    if trial.accepted
        lowerKh = trialKh;
        lower = trial;
    else
        upperKh = trialKh;
        upper = trial;
    end
end

assessment = struct(isApplicable=true,maximumSupportedKh=lowerKh,firstRejectedKh=upperKh, ...
    maximumSupportedError=lower.error,firstRejectedError=upper.error,minimumHorizontalWavelength=2*pi/lowerKh, ...
    limitingEndpoint=upper.limitingEndpoint,limitingModeNumber=upper.limitingModeNumber, ...
    maximumSupportedBoundaryError=lower.boundaryError,firstRejectedBoundaryError=upper.boundaryError,limitingMetric=upper.limitingMetric);

    function result = evaluate(kh)
        problem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2Function,zDomain=apvBasis.zDomain,f0=f0,g=g,k=kh,endpoints=endpoints,surfaceBoundary="freeSurface");
        zeroModes = IMSolverSpectral(nEVP=nEVP).solveGeostrophicZeroAPVModes(problem);
        if options.shouldCheckQuadraticAliasing
            result = WVInternal.measureFreeSurfaceCrossProductError(apvBasis,apvTransform,zeroModes,1,2*nEVP);
            result.accepted=result.error<=tolerance;
        else
            result=struct(error=NaN,accepted=true,limitingEndpoint="",limitingModeNumber=NaN);
        end
        result.boundaryError=NaN; result.limitingMetric="quadratic-product";
        if ~isempty(fieldnames(options.vertical))
            settings=struct(g=g,boundaryResolutionTolerance=options.boundaryResolutionTolerance,modeConvergenceTolerance=options.modeConvergenceTolerance,boundaryReportOnly=true);
            boundary=WVInternal.assessFreeSurfaceBoundaryGrid(zeroModes,problem,options.vertical,options.inputs,settings);
            [result.boundaryError,index]=max(boundary.pages.gridError);
            result.accepted=result.accepted && boundary.status=="accepted";
            if ~options.shouldCheckQuadraticAliasing || result.boundaryError/options.boundaryResolutionTolerance>result.error/tolerance
                result.limitingMetric="boundary-resolution";
                result.limitingEndpoint=boundary.pages.endpoint(index);
                result.limitingModeNumber=NaN;
            end
        end
    end
end
