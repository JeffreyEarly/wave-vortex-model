function assessment = supportedFreeSurfaceBoundaryWavenumber(endpoints,nEVP,tolerance,vertical,inputs,options)
% Find a conservative zero-APV boundary-resolution wavenumber limit.
arguments
    endpoints (1,:) string
    nEVP (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(nEVP,4)}
    tolerance (1,1) double {mustBePositive}
    vertical (1,1) struct
    inputs (1,1) struct
    options.seedKh (1,1) double {mustBePositive} = 1
    options.rejectedKh double {mustBePositive} = zeros(0,1)
    options.modeConvergenceTolerance (1,1) double {mustBePositive} = 1e-6
end

assessment=struct(status="not-applicable",isApplicable=~isempty(endpoints),maximumSupportedKh=NaN,firstRejectedKh=NaN, ...
    minimumHorizontalWavelength=NaN,limitingEndpoint="",maximumSupportedBoundaryError=NaN, ...
    firstRejectedBoundaryError=NaN,firstInconclusiveKh=NaN,firstInconclusiveReferenceError=NaN,inconclusiveEndpoint="");
if isempty(endpoints), return; end

maximumBracketSteps=24;
solver=IMSolverSpectral(nEVP=nEVP);
settings=struct(boundaryResolutionTolerance=tolerance,modeConvergenceTolerance=options.modeConvergenceTolerance,boundaryReportOnly=true);
trialKh=options.seedKh;
if ~isempty(options.rejectedKh), trialKh=options.rejectedKh; end
status=evaluate(trialKh);
if status=="reference-inconclusive", return; end
if status=="accepted" && ~isempty(options.rejectedKh)
    error('WVTransformFreeSurfaceQG:InvalidRejectedHorizontalWavenumber','The supplied rejected wavenumber does not exceed the zero-APV boundary tolerance.');
end
if status=="accepted"
    for iStep=1:maximumBracketSteps
        status=evaluate(2*assessment.maximumSupportedKh);
        if status=="reference-inconclusive", return; end
        if status=="rejected", break; end
    end
    if isnan(assessment.firstRejectedKh)
        assessment.status="candidate-ceiling";
        return
    end
else
    for iStep=1:maximumBracketSteps
        status=evaluate(assessment.firstRejectedKh/2);
        if status=="reference-inconclusive", return; end
        if status=="accepted", break; end
    end
    if isnan(assessment.maximumSupportedKh)
        assessment.status="no-supported-wavenumber";
        return
    end
end

for iStep=1:20
    if assessment.firstRejectedKh/assessment.maximumSupportedKh-1<=0.01, break; end
    status=evaluate(sqrt(assessment.maximumSupportedKh*assessment.firstRejectedKh));
    if status=="reference-inconclusive", return; end
end
assessment.status="bracketed";

    function status=evaluate(kh)
        problem=IMGeostrophicZeroAPVModes.atWavenumber(inputs.background,kh,endpoints=endpoints);
        zeroModes=solver.solveGeostrophicZeroAPVModes(problem);
        boundary=WVInternal.assessFreeSurfaceBoundaryGrid(zeroModes,problem,vertical,inputs,settings);
        status=boundary.status;
        if status=="reference-inconclusive"
            referenceErrors=boundary.pages.modeConvergenceError;
            index=find(~isfinite(referenceErrors),1);
            if isempty(index), [~,index]=max(referenceErrors); end
            assessment.status=status;
            assessment.firstInconclusiveKh=kh;
            assessment.firstInconclusiveReferenceError=referenceErrors(index);
            assessment.inconclusiveEndpoint=boundary.pages.endpoint(index);
            if isnan(assessment.firstRejectedKh)
                assessment.limitingEndpoint=assessment.inconclusiveEndpoint;
            end
        else
            [boundaryError,index]=max(boundary.pages.gridError);
            if status=="accepted"
                assessment.maximumSupportedKh=kh;
                assessment.minimumHorizontalWavelength=2*pi/kh;
                assessment.maximumSupportedBoundaryError=boundaryError;
            else
                assessment.firstRejectedKh=kh;
                assessment.firstRejectedBoundaryError=boundaryError;
                assessment.limitingEndpoint=boundary.pages.endpoint(index);
            end
        end
    end
end
