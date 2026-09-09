function result = measureProductProjection(context,sampleProducts,referenceProducts,endpointProducts,counts,options)
% Measure retained projection differences for explicitly listed scalar products.
%
% Columns are individual input products, never arbitrary superpositions.
% Signed target/sample Gram solves define projection. The induced positive
% target majorant and positive reference product norm define the error.
% The caller selects the input pairs for each count; all supplied columns
% are evaluated for every requested output prefix. Exterior coefficients
% are never added to the numerator. Exact zero products are handled without
% a small-denominator substitute; inconsistent zero references are errors.
% Optional projections are prepared value operators for this exact context
% and count sequence; omit them for an independent one-off measurement.
arguments (Input)
    context (1,1) struct
    sampleProducts (:,:) double {mustBeFinite}
    referenceProducts (:,:) double {mustBeFinite}
    endpointProducts (2,:) double {mustBeFinite}
    counts (1,:) double {mustBeInteger,mustBePositive}
    options.projections (:,1) cell = cell(0,1)
end
nProducts = size(sampleProducts,2);
if size(referenceProducts,2)~=nProducts || size(endpointProducts,2)~=nProducts || any(counts>size(context.targetGram,1))
    error('WVStudy:InvalidProductLayout','Product columns must agree and output counts must fit the target basis.')
end
projections = options.projections;
if isempty(projections), projections = prepareProductProjections(context,counts); end
if numel(projections) ~= numel(counts)
    error('WVStudy:InvalidProductLayout','Prepared projections must match the requested output prefixes.')
end
referencePairings = context.referenceValues'*(context.volumeWeights.*referenceProducts)+context.endpointValues'*(context.endpointMetric.*endpointProducts);
productNormSquared = real(sum(conj(referenceProducts).*(context.volumeWeights.*referenceProducts),1)+sum(abs(context.endpointMetric).*abs(endpointProducts).^2,1));
isZero = all(referenceProducts==0,1) & all(endpointProducts==0,1);
if any(isZero & any(sampleProducts~=0,1)) || any(productNormSquared(~isZero)<=0)
    error('WVStudy:InvalidReferenceNorm','A nonzero product requires a strictly positive reference norm; a zero reference must also be zero on the model grid.')
end
errors = zeros(length(counts),nProducts);
sampleCoefficients = cell(length(counts),1);
referenceCoefficients = cell(length(counts),1);
for j = 1:length(counts)
    active = find(context.active(1:counts(j)));
    targetGram = context.targetGram(active,active);
    projection = projections{j};
    if isempty(projection)
        errors(j,:) = Inf;
        sampleCoefficients{j} = nan(length(active),nProducts);
        referenceCoefficients{j} = nan(length(active),nProducts);
        continue
    end
    if projection.columnCount ~= counts(j)
        error('WVStudy:InvalidProductLayout','A prepared projection must retain the requested number of columns.')
    end
    sampled = projection.project(sampleProducts);
    sampleCoefficients{j} = sampled(active,:);
    referenceCoefficients{j} = targetGram\referencePairings(active,:);
    reference = zeros(counts(j),nProducts);
    reference(active,:) = referenceCoefficients{j};
    errors(j,:) = projection.productError(sampleProducts,reference,productNormSquared);
end
result = struct(error=errors,productNormSquared=productNormSquared,isZero=isZero,sampleCoefficients={sampleCoefficients},referenceCoefficients={referenceCoefficients});
end
