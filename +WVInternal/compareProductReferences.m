function discrepancy = compareProductReferences(context,low,high,counts)
% Bound integration changes in retained coefficients and product normalization.
discrepancy=0; usable=~high.isZero;
for j=1:length(counts)
    active=find(context.active(1:counts(j)));
    delta=low.referenceCoefficients{j}-high.referenceCoefficients{j};
    if all(isfinite(delta),'all')
        referenceError=IMProjection.relativeCoefficientNorm(delta(:,usable),context.majorantGram(active,active),high.productNormSquared(usable));
    else
        % Ill-conditioned prefixes retain the existing NaN coefficient
        % sentinel; their product error already rejects the candidate.
        numerator=real(sum(conj(delta).*(context.majorantGram(active,active)*delta),1));
        referenceError=sqrt(max(0,numerator(usable))./high.productNormSquared(usable));
    end
    discrepancy=max([discrepancy referenceError]);
end
normalizationDifference=abs(sqrt(low.productNormSquared(usable)./high.productNormSquared(usable))-1);
discrepancy=max([discrepancy normalizationDifference]);
end
