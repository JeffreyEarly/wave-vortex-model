function projections = prepareProductProjections(context,counts)
% Prepare prescribed physical duals once for a fixed measurement context.
%
% These value operators belong to the current assessment call. The caller
% prepares them again when its physical context or output prefixes change;
% no derived state is stored in a model or in the source-study preparation.
% Empty entries preserve the study's existing ill-conditioned-prefix rule.
arguments (Input)
    context (1,1) struct
    counts (1,:) double {mustBeInteger,mustBePositive}
end
arguments (Output)
    projections (:,1) cell
end
pairing = context.sampleValues'*context.sampleMetric;
projections = cell(numel(counts),1);
for j = 1:numel(counts)
    count = counts(j); active = find(context.active(1:count));
    if rcond(context.sampleGram(active,active))<1e-13 || rcond(context.targetGram(active,active))<1e-13
        continue
    end
    provenance = struct(kind="wvmStudyPrescribedDual",columnCoordinates="physical context order",referenceQualification="owned by calling study");
    projections{j} = IMProjection.fromPrescribedDual(pairing(1:count,:),context.sampleGram(1:count,1:count),context.targetGram(1:count,1:count),majorantGramMatrix=context.majorantGram(1:count,1:count),activeColumnMask=reshape(context.active(1:count),1,[]),provenance=provenance);
end
end
