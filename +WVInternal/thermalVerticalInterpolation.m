function matrix=thermalVerticalInterpolation(zNative,zQuery,depth,inverseScale)
% Interpolate stored thermal WKB samples using their exact physical coordinate.
% The coordinate is affine for constant N2 and exponential for the prescribed
% exponential profile. No fitted physical-depth coordinate or mode solve is
% needed. Diagnostics and state transfer use the same mean-field interpolation.
% - Topic: Developer utilities
arguments (Input)
    zNative (:,1) double {mustBeReal,mustBeFinite}
    zQuery (:,1) double {mustBeReal,mustBeFinite}
    depth (1,1) double {mustBePositive,mustBeFinite}
    inverseScale (1,1) double {mustBeReal,mustBeFinite}
end
arguments (Output)
    matrix (:,:) double
end
if inverseScale==0
    nodes=1+2*zNative/depth; targets=1+2*zQuery/depth;
else
    denominator=-expm1(-depth*inverseScale);
    nodes=1+2*expm1(inverseScale*zNative)/denominator;
    targets=1+2*expm1(inverseScale*zQuery)/denominator;
end
matrix=WVInternal.thermalInterpolation(nodes,targets);
end
