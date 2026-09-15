function assessment = supportedFreeSurfaceBoundaryWavenumber(zDomain,N2Function,f0,g,endpoints,nEVP,tolerance,vertical,inputs,options)
% Find a conservative zero-APV boundary-resolution wavenumber limit.
arguments
    zDomain (1,2) double {mustBeReal,mustBeFinite}
    N2Function function_handle
    f0 (1,1) double {mustBeReal,mustBeFinite,mustBeNonzero}
    g (1,1) double {mustBePositive}
    endpoints (1,:) string
    nEVP (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(nEVP,4)}
    tolerance (1,1) double {mustBePositive}
    vertical (1,1) struct
    inputs (1,1) struct
    options.seedKh (1,1) double {mustBePositive} = 1
    options.rejectedKh double {mustBePositive} = zeros(0,1)
    options.modeConvergenceTolerance (1,1) double {mustBePositive} = 1e-6
end

if isempty(endpoints)
    assessment = struct(isApplicable=false,maximumSupportedKh=NaN,firstRejectedKh=NaN, ...
        minimumHorizontalWavelength=NaN,limitingEndpoint="", ...
        maximumSupportedBoundaryError=NaN,firstRejectedBoundaryError=NaN);
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
            error('WVTransformFreeSurfaceQG:HorizontalLimitNotBracketed','The zero-APV boundary error did not exceed tolerance after %d wavenumber doublings.',maximumBracketSteps);
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
            error('WVTransformFreeSurfaceQG:NoSupportedHorizontalWavenumber','No passing zero-APV boundary wavenumber was found after %d halvings.',maximumBracketSteps);
        end
    end
else
    upperKh = options.rejectedKh;
    upper = evaluate(upperKh);
    if upper.accepted
        error('WVTransformFreeSurfaceQG:InvalidRejectedHorizontalWavenumber','The supplied rejected wavenumber does not exceed the zero-APV boundary tolerance.');
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
        error('WVTransformFreeSurfaceQG:NoSupportedHorizontalWavenumber','No passing zero-APV boundary wavenumber was found after %d halvings.',maximumBracketSteps);
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
    minimumHorizontalWavelength=2*pi/lowerKh,limitingEndpoint=upper.limitingEndpoint, ...
    maximumSupportedBoundaryError=lower.error,firstRejectedBoundaryError=upper.error);

    function result = evaluate(kh)
        problem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2Function,zDomain=zDomain,f0=f0,g=g,k=kh,endpoints=endpoints,surfaceBoundary="freeSurface");
        zeroModes = IMSolverSpectral(nEVP=nEVP).solveGeostrophicZeroAPVModes(problem);
        settings=struct(g=g,boundaryResolutionTolerance=tolerance,modeConvergenceTolerance=options.modeConvergenceTolerance,boundaryReportOnly=true);
        boundary=WVInternal.assessFreeSurfaceBoundaryGrid(zeroModes,problem,vertical,inputs,settings);
        [boundaryError,index]=max(boundary.pages.gridError);
        result=struct(error=boundaryError,accepted=boundary.status=="accepted",limitingEndpoint=boundary.pages.endpoint(index));
    end
end
