function value = freeSurfaceQGCoefficientStoragePreference(separateSeconds,packedSeconds,options)
% Apply the bootstrap and practical-threshold rule for packed storage.
arguments
    separateSeconds (1,:) double {mustBePositive,mustBeFinite}
    packedSeconds (1,:) double {mustBePositive,mustBeFinite}
    options.bootstrapCount (1,1) double {mustBeInteger,mustBePositive} = 10000
    options.minimumMeaningfulSpeedup (1,1) double {mustBeGreaterThanOrEqual(options.minimumMeaningfulSpeedup,0),mustBeLessThan(options.minimumMeaningfulSpeedup,1)} = 0.03
    options.seed (1,1) double {mustBeInteger,mustBeNonnegative} = 34322
end

originalRng = rng;
cleanup = onCleanup(@()rng(originalRng));
rng(options.seed,"twister");
ratios = zeros(options.bootstrapCount,1);
for iBootstrap = 1:options.bootstrapCount
    separateSample = separateSeconds(randi(numel(separateSeconds),size(separateSeconds)));
    packedSample = packedSeconds(randi(numel(packedSeconds),size(packedSeconds)));
    ratios(iBootstrap) = median(packedSample)/median(separateSample);
end
ratios = sort(ratios);
indices = max(1,min(options.bootstrapCount,round([0.025 0.975]*(options.bootstrapCount-1)+1)));
interval = reshape(ratios(indices),1,2);
ratio = median(packedSeconds)/median(separateSeconds);
threshold = 1-options.minimumMeaningfulSpeedup;
value = struct( ...
    "packedToSeparateMedianRatio",ratio, ...
    "medianSpeedup",1/ratio, ...
    "ratioConfidenceInterval95",interval, ...
    "minimumMeaningfulSpeedup",options.minimumMeaningfulSpeedup, ...
    "thresholdRatio",threshold, ...
    "packedMeaningfullyFaster",interval(2)<threshold);
clear cleanup
end
