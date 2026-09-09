function scale = productReferenceScale(context,a,b,endpointA,endpointB)
% Bound a product in the positive physical source norm on reference nodes.
%
% Use min(||a||inf ||b||mu, ||b||inf ||a||mu), where mu contains volume
% weights and absolute endpoint weights. Derivative factors belong in b.
% This sampled bilinear scale is homogeneous in each input; it is neither
% an amplitude-independent superposition bound nor a denominator floor.
arguments (Input)
    context (1,1) struct
    a (:,:) double {mustBeFinite}
    b (:,:) double {mustBeFinite}
    endpointA (2,:) double {mustBeFinite}
    endpointB (2,:) double {mustBeFinite}
end
arguments (Output)
    scale (1,:) double
end
weights=[context.volumeWeights;abs(context.endpointMetric)];
a=[a;endpointA]; b=[b;endpointB];
if ~isequal(size(a),size(b)) || size(a,1)~=numel(weights) || any(weights<0)
    error('WVStudy:InvalidReferenceScale','Use aligned factors and nonnegative physical volume/majorant endpoint weights.');
end
active=weights>0; a=a(active,:); b=b(active,:); weights=weights(active);
sa=max(abs(a),[],1); sb=max(abs(b),[],1);
na=zeros(size(sa)); nb=zeros(size(sb));
selected=sa>0; na(selected)=sa(selected).*sqrt(sum(weights.*abs(a(:,selected)./sa(selected)).^2,1));
selected=sb>0; nb(selected)=sb(selected).*sqrt(sum(weights.*abs(b(:,selected)./sb(selected)).^2,1));
scale=min(sa.*nb,sb.*na);
end
