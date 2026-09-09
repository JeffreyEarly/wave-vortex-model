function report = qualifyProductReferences(context,low,high,counts,scale,relativeAllowance,absoluteAllowance)
% Qualify reference changes with separately declared relative/absolute budgets.
%
% Every product must satisfy delta <= relativeAllowance*P + absoluteAllowance*B,
% for both its norm and each retained coefficient norm. P is the smaller
% reference product norm; B is the sampled physical input-factor bound.
% Relative diagnostics are retained even when the absolute budget is needed.
arguments (Input)
    context (1,1) struct
    low (1,1) struct
    high (1,1) struct
    counts (1,:) double {mustBeInteger,mustBePositive}
    scale (1,:) double {mustBeFinite,mustBeNonnegative}
    relativeAllowance (1,1) double {mustBeFinite,mustBePositive}
    absoluteAllowance (1,1) double {mustBeFinite,mustBeNonnegative}
end
arguments (Output)
    report (1,1) struct
end
lo=sqrt(low.productNormSquared); hi=sqrt(high.productNormSquared);
if numel(scale)~=numel(hi), error('WVStudy:InvalidReferenceScale','Supply one factor bound per product.'); end
productNorm=min(lo,hi); budget=relativeAllowance*productNorm+absoluteAllowance*scale;
change=abs(lo-hi);
for j=1:numel(counts)
    active=find(context.active(1:counts(j)));
    delta=low.referenceCoefficients{j}-high.referenceCoefficients{j};
    magnitude=max(abs(delta),[],1); value=zeros(size(magnitude));
    finite=all(isfinite(delta),1); nonzero=finite & magnitude>0;
    value(~finite)=Inf;
    if any(nonzero)
        value(nonzero)=magnitude(nonzero).*IMProjection.relativeCoefficientNorm(delta(:,nonzero)./magnitude(nonzero),context.majorantGram(active,active),ones(1,nnz(nonzero)));
    end
    change=max(change,value);
end
fraction=change./budget; fraction(change==0 & budget==0)=0;
relativeError=change./productNorm; relativeError(change==0 & productNorm==0)=0;
scaledError=change./scale; scaledError(change==0 & scale==0)=0;
report=struct(allowanceFraction=fraction,relativeError=relativeError,scaledError=scaledError,usesAbsoluteAllowance=fraction<=1 & relativeError>relativeAllowance,productNorm=productNorm,factorScale=scale);
end
