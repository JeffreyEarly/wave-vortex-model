function mask = studyModePairMask(positionA,positionB,inputA,inputB,count,policy)
% Build cumulative low/middle/cutoff stresses with all special-family modes.
arguments
    positionA (1,:) double
    positionB (1,:) double
    inputA (1,1) string
    inputB (1,1) string
    count (1,1) double {mustBeInteger,mustBePositive}
    policy (1,1) string {mustBeMember(policy,["dense","fixed","targeted"])}
end
allowed=true(size(positionA));
if inputA=="wave", allowed=allowed & positionA<=count; end
if inputB=="wave", allowed=allowed & positionB<=count; end
if policy=="dense", mask=allowed; return; end
mask=false(size(positionA));
for prefix=1:count
    modes=unique([1 2 ceil(prefix/2) max(1,prefix-2):prefix]); modes=modes(modes<=prefix);
    selected=true(size(mask));
    if inputA=="wave", selected=selected & ismember(positionA,modes); end
    if inputB=="wave", selected=selected & ismember(positionB,modes); end
    mask=mask | selected;
end
mask=mask & allowed;
end
