function mask = constructionModePairMask(a,b,familyA,familyB,countA,countB)
% Every configured endpoint, with a bounded set of scalar/wave input stresses.
mask=true(size(a));
if familyA~="boundary", mask=mask & ismember(a,WVInternal.constructionModeLevels(countA)); end
if familyB~="boundary", mask=mask & ismember(b,WVInternal.constructionModeLevels(countB)); end
end
