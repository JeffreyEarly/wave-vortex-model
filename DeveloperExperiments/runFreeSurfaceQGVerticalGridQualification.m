function results = runFreeSurfaceQGVerticalGridQualification(options)
% Qualify the fixed WKB vertical rule and its horizontal-wavenumber limit.
%
% The sweep records the complete production error set for constant and
% exponential stratification, independent APV/MDA mode counts, and every
% active-endpoint configuration. It uses only spectral mode evaluation and
% direct spectral integration.
%
% ```matlab
% results = runFreeSurfaceQGVerticalGridQualification();
% ```
arguments
    options.profileIds (1,:) string = ["constant" "exponential"]
    options.pointCounts (1,:) double {mustBeInteger,mustBePositive} = [33 65 129]
    options.endpointIds (1,:) string = ["surface" "bottom" "both"]
    options.Lz (1,1) double {mustBePositive} = 4000
    options.N0 (1,1) double {mustBePositive} = 5.2e-3
    options.exponentialScale (1,1) double {mustBePositive} = 1300
    options.latitude (1,1) double = 30
    options.g (1,1) double {mustBePositive} = 9.81
    options.surfaceAcceleration double = NaN
    options.bottomAcceleration (1,1) double = 0.03
    options.gramTolerance (1,1) double {mustBeNonnegative} = 1e-2
    options.quadraticDealiasing (1,1) string {mustBeMember(options.quadraticDealiasing,["none","fixedFraction","effectiveBandwidth"])} = "fixedFraction"
    options.retainedFraction (1,1) double {mustBeGreaterThanOrEqual(options.retainedFraction,0),mustBeLessThanOrEqual(options.retainedFraction,1)} = 2/3
    options.energyFraction (1,1) double {mustBeGreaterThan(options.energyFraction,0),mustBeLessThanOrEqual(options.energyFraction,1)} = .99
    options.bandwidthFraction (1,1) double {mustBeGreaterThanOrEqual(options.bandwidthFraction,0),mustBeLessThanOrEqual(options.bandwidthFraction,1)} = 2/3
    options.shouldPrint (1,1) logical = true
end

validateSelection(options.profileIds,["constant" "exponential"],"profile");
validateSelection(options.endpointIds,["surface" "bottom" "both"],"endpoint configuration");
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
originalPath = path;
cleanup = onCleanup(@()path(originalPath));
addpath(repositoryRoot);

nCases = numel(options.profileIds)*numel(options.pointCounts)*numel(options.endpointIds);
records = repmat(emptyRecord(),nCases,1);
iCase = 0;
for profileId = options.profileIds
    N2 = profileFunction(profileId,options);
    resolvedG0 = options.surfaceAcceleration;
    if isnan(resolvedG0)
        resolvedG0 = -integral(N2,-options.Lz,0);
    end
    for Nz = options.pointCounts
        for endpointId = options.endpointIds
            iCase = iCase+1;
            [g0,gd] = endpointParameters(endpointId,resolvedG0,options.bottomAcceleration);
            record = emptyRecord();
            record.profile = profileId;
            record.Nz = Nz;
            record.endpointConfiguration = endpointId;
            timer = tic;
            try
                assessment = WVTransformFreeSurfaceQG.assessVerticalResolution(options.Lz,Nz,N2Function=N2,latitude=options.latitude, ...
                    g=options.g,g0=g0,gd=gd,gramTolerance=options.gramTolerance, ...
                    quadraticDealiasing=options.quadraticDealiasing,retainedFraction=options.retainedFraction, ...
                    energyFraction=options.energyFraction,bandwidthFraction=options.bandwidthFraction);
                record.elapsedSeconds = toc(timer);
                record.apvModeCount = assessment.apvModeCount;
                record.mdaModeCount = assessment.mdaModeCount;
                record.apvGramError = assessment.apvGramError;
                record.mdaGramError = assessment.mdaGramError;
                record.apvLinearCount = assessment.apvLinearCount;
                record.apvFilteringCount = assessment.apvFilteringCount;
                record.quadraticDealiasing = assessment.dealiasing.quadraticDealiasing;
                record.minimumWeight = min(assessment.weights);
                record.depthClosureError = abs(sum(assessment.weights)-options.Lz)/options.Lz;
                record.horizontalWavenumberScale = assessment.horizontalWavenumberScale;
                record.maximumSupportedKh = assessment.maximumSupportedKh;
                record.firstRejectedKh = assessment.firstRejectedKh;
                record.maximumSupportedError = assessment.maximumSupportedError;
                record.firstRejectedError = assessment.firstRejectedError;
                record.minimumHorizontalWavelength = assessment.minimumHorizontalWavelength;
                record.scalingCoefficient = assessment.maximumSupportedKh/assessment.horizontalWavenumberScale;
                record.limitingEndpoint = assessment.limitingEndpoint;
                record.limitingAPVModeNumber = assessment.limitingAPVModeNumber;
                record.status = "complete";
            catch exception
                record.elapsedSeconds = toc(timer);
                record.status = "failed";
                record.failureIdentifier = string(exception.identifier);
                record.failureMessage = string(exception.message);
            end
            records(iCase) = record;
        end
    end
end

results = struct(configuration=configuration(options),cases=struct2table(records));
if options.shouldPrint
    fprintf("\nFixed WKB free-surface QG vertical-resolution qualification\n\n");
    disp(results.cases)
end
clear cleanup
end

function N2 = profileFunction(profileId,options)
if profileId == "constant"
    N2 = @(z) options.N0^2*ones(size(z));
else
    N2 = @(z) options.N0^2*exp(2*z/options.exponentialScale);
end
end

function [g0,gd] = endpointParameters(endpointId,surfaceAcceleration,bottomAcceleration)
switch endpointId
    case "surface"
        g0 = surfaceAcceleration;
        gd = Inf;
    case "bottom"
        g0 = Inf;
        gd = bottomAcceleration;
    case "both"
        g0 = surfaceAcceleration;
        gd = bottomAcceleration;
end
end

function validateSelection(actual,allowed,name)
unknown = setdiff(actual,allowed);
if ~isempty(unknown)
    error("WaveVortexExperiment:UnknownSelection","Unknown %s: %s.",name,join(unknown,", "));
end
end

function value = configuration(options)
value = rmfield(options,"shouldPrint");
value.gridKind = "chebyshevLobatto";
value.gridCoordinate = "wkb";
value.weightRule = "native physical spectral weights with exact-depth scalar adjustment";
value.apvPolicies = ["independent convergence" "F/G Gram" "quadratic-dealiasing prefix"];
value.mdaPolicies = "G Gram";
value.zeroAPVCrossReference = "fixed physical boundary response";
value.horizontalLimitScaling = "abs(f0)*(Nz-1)^2/integral(N dz)";
end

function record = emptyRecord()
record = struct(profile="",Nz=NaN,endpointConfiguration="",status="",elapsedSeconds=NaN, ...
    apvModeCount=NaN,mdaModeCount=NaN,apvGramError=NaN,mdaGramError=NaN, ...
    apvLinearCount=NaN,apvFilteringCount=NaN,quadraticDealiasing="", ...
    minimumWeight=NaN,depthClosureError=NaN,horizontalWavenumberScale=NaN,maximumSupportedKh=NaN, ...
    firstRejectedKh=NaN,maximumSupportedError=NaN,firstRejectedError=NaN,minimumHorizontalWavelength=NaN, ...
    scalingCoefficient=NaN,limitingEndpoint="",limitingAPVModeNumber=NaN,failureIdentifier="",failureMessage="");
end
