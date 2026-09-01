function assessment = supportedHorizontalWavenumber(apvBasis,apvTransform,N2Function,f0,g,endpoints,nEVP,tolerance,options)
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
    options.seedKh (1,1) double {mustBePositive} = 1
    options.rejectedKh double {mustBePositive} = zeros(0,1)
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
    if trial.error <= tolerance
        lowerKh = trialKh;
        lower = trial;
        for iStep = 1:maximumBracketSteps
            upperKh = 2*lowerKh;
            upper = evaluate(upperKh);
            if upper.error > tolerance
                break
            end
            lowerKh = upperKh;
            lower = upper;
        end
        if upper.error <= tolerance
            error('WVTransformFreeSurfaceQG:HorizontalLimitNotBracketed','The APV/zero-APV error did not exceed tolerance after %d wavenumber doublings.',maximumBracketSteps);
        end
    else
        upperKh = trialKh;
        upper = trial;
        for iStep = 1:maximumBracketSteps
            lowerKh = upperKh/2;
            lower = evaluate(lowerKh);
            if lower.error <= tolerance
                break
            end
            upperKh = lowerKh;
            upper = lower;
        end
        if lower.error > tolerance
            error('WVTransformFreeSurfaceQG:NoSupportedHorizontalWavenumber','No passing APV/zero-APV wavenumber was found after %d halvings.',maximumBracketSteps);
        end
    end
else
    upperKh = options.rejectedKh;
    upper = evaluate(upperKh);
    if upper.error <= tolerance
        error('WVTransformFreeSurfaceQG:InvalidRejectedHorizontalWavenumber','The supplied rejected wavenumber does not exceed the APV/zero-APV tolerance.');
    end
    for iStep = 1:maximumBracketSteps
        lowerKh = upperKh/2;
        lower = evaluate(lowerKh);
        if lower.error <= tolerance
            break
        end
        upperKh = lowerKh;
        upper = lower;
    end
    if lower.error > tolerance
        error('WVTransformFreeSurfaceQG:NoSupportedHorizontalWavenumber','No passing APV/zero-APV wavenumber was found after %d halvings.',maximumBracketSteps);
    end
end

for iStep = 1:20
    if upperKh/lowerKh-1 <= 0.01
        break
    end
    trialKh = sqrt(lowerKh*upperKh);
    trial = evaluate(trialKh);
    if trial.error <= tolerance
        lowerKh = trialKh;
        lower = trial;
    else
        upperKh = trialKh;
        upper = trial;
    end
end

assessment = struct(isApplicable=true,maximumSupportedKh=lowerKh,firstRejectedKh=upperKh, ...
    maximumSupportedError=lower.error,firstRejectedError=upper.error,minimumHorizontalWavelength=2*pi/lowerKh, ...
    limitingEndpoint=upper.limitingEndpoint,limitingModeNumber=upper.limitingModeNumber);

    function result = evaluate(kh)
        problem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2Function,zDomain=apvBasis.zDomain,f0=f0,g=g,k=kh,endpoints=endpoints,surfaceBoundary="freeSurface");
        zeroModes = IMSolverSpectral(nEVP=nEVP).solveGeostrophicZeroAPVModes(problem);
        result = WVTransformFreeSurfaceQG.measureAPVZeroAPVQuadraticError(apvBasis,apvTransform,zeroModes,1,2*nEVP);
    end
end
